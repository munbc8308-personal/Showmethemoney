import Foundation

// MARK: - 백테스팅 결과 데이터 타입

struct BacktestTrade: Identifiable {
    let id = UUID()
    let symbol: String
    let buyDate: Date
    let buyPrice: Double
    let sellDate: Date
    let sellPrice: Double
    let quantity: Int
    let profit: Double
    let profitPct: Double
    let exitReason: ExitReason

    enum ExitReason: String {
        case condition = "조건 충족"
        case stopLoss = "손절"
        case takeProfit = "익절"
        case endOfPeriod = "기간 종료"
    }

    var isWin: Bool { profit > 0 }
}

struct EquityPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct BacktestResult {
    let symbol: String
    let period: BacktestPeriod
    let initialCapital: Double
    let finalCapital: Double
    let trades: [BacktestTrade]
    let equityCurve: [EquityPoint]

    var totalReturn: Double {
        (finalCapital - initialCapital) / initialCapital * 100
    }

    var annualizedReturn: Double {
        guard let first = equityCurve.first, let last = equityCurve.last else { return 0 }
        let years = last.date.timeIntervalSince(first.date) / (365.25 * 24 * 3600)
        guard years > 0 else { return 0 }
        return (pow(finalCapital / initialCapital, 1.0 / years) - 1) * 100
    }

    var mdd: Double {
        guard !equityCurve.isEmpty else { return 0 }
        var peak = equityCurve[0].value
        var maxDrawdown = 0.0
        for point in equityCurve {
            if point.value > peak { peak = point.value }
            let drawdown = (peak - point.value) / peak * 100
            if drawdown > maxDrawdown { maxDrawdown = drawdown }
        }
        return maxDrawdown
    }

    var sharpeRatio: Double {
        guard equityCurve.count > 1 else { return 0 }
        var dailyReturns = [Double]()
        for i in 1..<equityCurve.count {
            let prev = equityCurve[i - 1].value
            let curr = equityCurve[i].value
            if prev > 0 { dailyReturns.append((curr - prev) / prev) }
        }
        guard dailyReturns.count > 1 else { return 0 }
        let mean = dailyReturns.reduce(0, +) / Double(dailyReturns.count)
        let variance = dailyReturns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(dailyReturns.count)
        let stdDev = sqrt(variance)
        guard stdDev > 0 else { return 0 }
        let riskFreeDaily = 0.03 / 252  // 연 3% 무위험수익률
        return (mean - riskFreeDaily) / stdDev * sqrt(252)
    }

    var winRate: Double {
        guard !trades.isEmpty else { return 0 }
        let wins = trades.filter { $0.isWin }.count
        return Double(wins) / Double(trades.count) * 100
    }

    var profitFactor: Double {
        let totalGain = trades.filter { $0.profit > 0 }.map(\.profit).reduce(0, +)
        let totalLoss = abs(trades.filter { $0.profit < 0 }.map(\.profit).reduce(0, +))
        guard totalLoss > 0 else { return totalGain > 0 ? 999 : 0 }
        return totalGain / totalLoss
    }

    var averageHoldDays: Double {
        guard !trades.isEmpty else { return 0 }
        let totalDays = trades.map { $0.sellDate.timeIntervalSince($0.buyDate) / 86400 }.reduce(0, +)
        return totalDays / Double(trades.count)
    }
}

// MARK: - 백테스팅 엔진

enum BacktestEngine {

    static func run(
        strategy: Strategy,
        symbol: String,
        bars: [OHLCV],
        initialCapital: Double = 10_000_000
    ) -> BacktestResult {
        guard bars.count > 30 else {
            return emptyResult(symbol: symbol, period: .oneYear, capital: initialCapital)
        }

        // 지표 계산에 필요한 최소 룩백 기간
        let lookback = maxLookback(strategy: strategy)
        guard bars.count > lookback else {
            return emptyResult(symbol: symbol, period: .oneYear, capital: initialCapital)
        }

        var cash = initialCapital
        var position: Position? = nil
        var completedTrades = [BacktestTrade]()
        var equityCurve = [EquityPoint]()

        for i in lookback..<bars.count {
            let currentBar = bars[i]
            let barsUpToNow = Array(bars[0...i])
            let currentPrice = currentBar.close

            // 보유 포지션 처리 (손절/익절/매도 조건 체크)
            if let pos = position {
                let changeRate = (currentPrice - pos.buyPrice) / pos.buyPrice * 100

                var exitReason: BacktestTrade.ExitReason? = nil

                if changeRate <= -strategy.stopLossPct {
                    exitReason = .stopLoss
                } else if changeRate >= strategy.takeProfitPct {
                    exitReason = .takeProfit
                } else if StrategyEngine.shouldSell(strategy: strategy, bars: barsUpToNow) {
                    exitReason = .condition
                }

                if let reason = exitReason {
                    let trade = closePosition(
                        position: pos,
                        sellDate: currentBar.date,
                        sellPrice: currentPrice,
                        reason: reason
                    )
                    completedTrades.append(trade)
                    cash += currentPrice * Double(pos.quantity)
                    position = nil
                }
            }

            // 포지션 없을 때 매수 조건 체크
            if position == nil {
                if StrategyEngine.shouldBuy(strategy: strategy, bars: barsUpToNow) {
                    let investAmount = cash * (strategy.positionSizePct / 100)
                    let quantity = max(1, Int(investAmount / currentPrice))
                    let cost = currentPrice * Double(quantity)
                    if cost <= cash {
                        cash -= cost
                        position = Position(
                            symbol: symbol,
                            buyDate: currentBar.date,
                            buyPrice: currentPrice,
                            quantity: quantity
                        )
                    }
                }
            }

            // 에퀴티 커브 기록
            let positionValue = position.map { Double($0.quantity) * currentPrice } ?? 0
            equityCurve.append(EquityPoint(date: currentBar.date, value: cash + positionValue))
        }

        // 마지막 포지션 강제 청산
        if let pos = position, let lastBar = bars.last {
            let trade = closePosition(
                position: pos,
                sellDate: lastBar.date,
                sellPrice: lastBar.close,
                reason: .endOfPeriod
            )
            completedTrades.append(trade)
            cash += lastBar.close * Double(pos.quantity)
        }

        return BacktestResult(
            symbol: symbol,
            period: .oneYear,
            initialCapital: initialCapital,
            finalCapital: cash,
            trades: completedTrades,
            equityCurve: equityCurve
        )
    }

    // MARK: - Helpers

    private struct Position {
        let symbol: String
        let buyDate: Date
        let buyPrice: Double
        let quantity: Int
    }

    private static func closePosition(
        position: Position,
        sellDate: Date,
        sellPrice: Double,
        reason: BacktestTrade.ExitReason
    ) -> BacktestTrade {
        let profit = (sellPrice - position.buyPrice) * Double(position.quantity)
        let profitPct = (sellPrice - position.buyPrice) / position.buyPrice * 100
        return BacktestTrade(
            symbol: position.symbol,
            buyDate: position.buyDate,
            buyPrice: position.buyPrice,
            sellDate: sellDate,
            sellPrice: sellPrice,
            quantity: position.quantity,
            profit: profit,
            profitPct: profitPct,
            exitReason: reason
        )
    }

    private static func maxLookback(strategy: Strategy) -> Int {
        let periods = strategy.conditions.map { $0.period }
        let maxPeriod = periods.max() ?? 14
        return maxPeriod * 3
    }

    private static func emptyResult(symbol: String, period: BacktestPeriod, capital: Double) -> BacktestResult {
        return BacktestResult(
            symbol: symbol,
            period: period,
            initialCapital: capital,
            finalCapital: capital,
            trades: [],
            equityCurve: []
        )
    }
}
