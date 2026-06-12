import Foundation
import SwiftData
import UserNotifications

struct TradingLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: Level
    let symbol: String?
    let message: String

    enum Level { case info, buy, sell, error }
}

@Observable
@MainActor
final class AutoTradingService {
    static let shared = AutoTradingService()
    private init() {}

    var isRunning = false
    var lastCheckTime: Date?
    var nextCheckTime: Date?
    var logs: [TradingLog] = []

    private var loopTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    func configure(container: ModelContainer) {
        modelContext = ModelContext(container)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        loopTask = Task { await runLoop() }
        addLog(.info, nil, "자동매매 엔진 시작")
    }

    func stop() {
        isRunning = false
        loopTask?.cancel()
        loopTask = nil
        nextCheckTime = nil
        addLog(.info, nil, "자동매매 엔진 중지")
    }

    func checkNow() {
        Task { await performCheck() }
    }

    func clearLogs() {
        logs.removeAll()
    }

    // MARK: - Loop

    private func runLoop() async {
        while !Task.isCancelled && isRunning {
            await performCheck()
            guard isRunning && !Task.isCancelled else { break }
            nextCheckTime = Date().addingTimeInterval(60)
            try? await Task.sleep(for: .seconds(60))
        }
    }

    private func performCheck() async {
        lastCheckTime = Date()
        guard let modelContext else {
            addLog(.error, nil, "ModelContext 미설정")
            return
        }

        let koreanOpen = checkKoreanMarketOpen()
        let usOpen = checkUSMarketOpen()

        guard koreanOpen || usOpen else {
            addLog(.info, nil, "장외 시간 — 체크 건너뜀")
            return
        }

        let descriptor = FetchDescriptor<Strategy>(predicate: #Predicate { $0.isActive })
        guard let strategies = try? modelContext.fetch(descriptor), !strategies.isEmpty else {
            addLog(.info, nil, "활성 전략 없음")
            return
        }

        addLog(.info, nil, "체크 시작 — 전략 \(strategies.count)개")

        for strategy in strategies {
            for symbol in strategy.targetSymbols {
                let korean = isKoreanSymbol(symbol)
                if korean && !koreanOpen { continue }
                if !korean && !usOpen { continue }
                await processSymbol(symbol, strategy: strategy, isKorean: korean, context: modelContext)
            }
        }
    }

    // MARK: - Strategy Processing

    private func processSymbol(_ symbol: String, strategy: Strategy, isKorean: Bool, context: ModelContext) async {
        do {
            let startDate = Calendar.current.date(byAdding: .day, value: -400, to: Date())!
            let bars: [OHLCV]
            if isKorean {
                bars = try await KISAPIClient.shared.fetchDailyBars(symbol: symbol, startDate: startDate)
            } else {
                bars = try await AlpacaAPIClient.shared.fetchDailyBars(symbol: symbol, startDate: startDate)
            }
            guard bars.count >= 30 else { return }

            let currentPrice: Double
            if isKorean {
                currentPrice = try await KISAPIClient.shared.fetchStockPrice(symbol: symbol).price
            } else {
                currentPrice = try await AlpacaAPIClient.shared.fetchStockPrice(symbol: symbol).price
            }

            let holdingDesc = FetchDescriptor<Holding>(predicate: #Predicate { $0.symbol == symbol })
            let existing = (try? context.fetch(holdingDesc)) ?? []

            if let holding = existing.first {
                let pnlPct = (currentPrice - holding.averageCost) / holding.averageCost * 100

                if pnlPct <= -strategy.stopLossPct {
                    await placeOrder(symbol: symbol, type: .sell, quantity: holding.quantity, price: currentPrice,
                                     reason: String(format: "손절 (%.1f%%)", pnlPct),
                                     isKorean: isKorean, strategy: strategy, holding: holding, context: context)
                    return
                }
                if pnlPct >= strategy.takeProfitPct {
                    await placeOrder(symbol: symbol, type: .sell, quantity: holding.quantity, price: currentPrice,
                                     reason: String(format: "익절 (+%.1f%%)", pnlPct),
                                     isKorean: isKorean, strategy: strategy, holding: holding, context: context)
                    return
                }
                if StrategyEngine.shouldSell(strategy: strategy, bars: bars) {
                    await placeOrder(symbol: symbol, type: .sell, quantity: holding.quantity, price: currentPrice,
                                     reason: "매도 조건 충족",
                                     isKorean: isKorean, strategy: strategy, holding: holding, context: context)
                }
            } else {
                if StrategyEngine.shouldBuy(strategy: strategy, bars: bars) {
                    let balance: AccountBalance
                    if isKorean {
                        balance = try await KISAPIClient.shared.fetchBalance()
                    } else {
                        balance = try await AlpacaAPIClient.shared.fetchBalance()
                    }
                    let investAmount = balance.totalValue * (strategy.positionSizePct / 100.0)
                    let quantity = max(1, Int(investAmount / currentPrice))
                    await placeOrder(symbol: symbol, type: .buy, quantity: quantity, price: currentPrice,
                                     reason: "매수 조건 충족",
                                     isKorean: isKorean, strategy: strategy, holding: nil, context: context)
                }
            }
        } catch {
            addLog(.error, symbol, error.localizedDescription)
        }
    }

    private func placeOrder(
        symbol: String, type: TradeType, quantity: Int, price: Double,
        reason: String, isKorean: Bool, strategy: Strategy,
        holding: Holding?, context: ModelContext
    ) async {
        do {
            let orderId: String
            if isKorean {
                orderId = try await KISAPIClient.shared.placeOrder(symbol: symbol, type: type, quantity: quantity)
            } else {
                orderId = try await AlpacaAPIClient.shared.placeOrder(symbol: symbol, type: type, quantity: quantity)
            }

            let market: Market = isKorean ? .kospi : .nyse
            let broker: Broker = isKorean ? .kis : .alpaca

            if type == .buy {
                let h = Holding(symbol: symbol, stockName: symbol, market: market, broker: broker,
                                quantity: quantity, averageCost: price)
                context.insert(h)
                addLog(.buy, symbol, "\(quantity)주 매수 @ \(priceText(price, korean: isKorean)) — \(reason)")
            } else if let holding {
                let profit = (price - holding.averageCost) * Double(holding.quantity)
                let pct = (price - holding.averageCost) / holding.averageCost * 100
                let trade = Trade(symbol: symbol, stockName: symbol, market: market, broker: broker,
                                  type: .sell, price: price, quantity: quantity,
                                  strategyName: strategy.name, orderId: orderId)
                trade.profit = profit
                trade.profitPct = pct
                context.insert(trade)
                context.delete(holding)
                addLog(.sell, symbol, "\(quantity)주 매도 @ \(priceText(price, korean: isKorean)) — \(reason)")
            }

            try? context.save()
            await sendNotification(symbol: symbol, type: type, price: price, reason: reason, isKorean: isKorean)
        } catch {
            addLog(.error, symbol, "주문 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - Market Hours

    var isKoreanMarketOpen: Bool { checkKoreanMarketOpen() }
    var isUSMarketOpen: Bool { checkUSMarketOpen() }

    private func checkKoreanMarketOpen() -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        guard weekday != 1 && weekday != 7 else { return false }
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let mins = h * 60 + m
        return mins >= 540 && mins < 930  // 09:00–15:30
    }

    private func checkUSMarketOpen() -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        guard weekday != 1 && weekday != 7 else { return false }
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let mins = h * 60 + m
        return mins >= 570 && mins < 960  // 09:30–16:00
    }

    // MARK: - Helpers

    private func isKoreanSymbol(_ symbol: String) -> Bool {
        symbol.count == 6 && symbol.allSatisfy(\.isNumber)
    }

    private func priceText(_ price: Double, korean: Bool) -> String {
        korean ? "\(Int(price))원" : String(format: "$%.2f", price)
    }

    private func addLog(_ level: TradingLog.Level, _ symbol: String?, _ message: String) {
        let log = TradingLog(timestamp: Date(), level: level, symbol: symbol, message: message)
        logs.insert(log, at: 0)
        if logs.count > 200 { logs = Array(logs.prefix(200)) }
    }

    private func sendNotification(symbol: String, type: TradeType, price: Double, reason: String, isKorean: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = type == .buy ? "매수 체결" : "매도 체결"
        content.body = "\(symbol) — \(reason) @ \(priceText(price, korean: isKorean))"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
