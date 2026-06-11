import Foundation

// 전략 조건을 OHLCV 데이터에 대해 평가하는 엔진
// 조건 인코딩 규칙:
//   - RSI(14) < 30  → indicator:.rsi, period:14, operator:.lessThan, value:30
//   - MA(20) 상향돌파 MA(50) → indicator:.ma, period:20, operator:.crossAbove, value:50 (value = 비교 대상 period)
//   - 볼린저 하단 터치 → indicator:.bollingerBand, period:20, operator:.lessThanOrEqual, value:-2 (value = sigma 배수)
//   - 52주신고가 95% 이상 → indicator:.price52WeekHigh, operator:.greaterThanOrEqual, value:95
//   - 등락률 -5% 이하 → indicator:.priceChangeRate, period:1, operator:.lessThanOrEqual, value:-5
enum StrategyEngine {

    struct EvalResult {
        let isMet: Bool
        let indicatorValue: Double?
        let description: String
    }

    static func evaluate(condition: Condition, bars: [OHLCV]) -> EvalResult {
        guard bars.count >= 2 else {
            return EvalResult(isMet: false, indicatorValue: nil, description: "데이터 부족")
        }

        let closes = bars.map(\.close)

        switch condition.indicator {
        case .ma:
            return evaluateMA(closes: closes, condition: condition)

        case .ema:
            return evaluateEMA(closes: closes, condition: condition)

        case .rsi:
            let rsiValues = IndicatorEngine.rsi(closes: closes, period: condition.period)
            guard let latest = rsiValues.last, latest > 0 else {
                return EvalResult(isMet: false, indicatorValue: nil, description: "RSI 계산 불가")
            }
            let met = compare(latest, condition.conditionOperator, condition.value)
            return EvalResult(
                isMet: met,
                indicatorValue: latest,
                description: "RSI(\(condition.period)) = \(String(format: "%.1f", latest))"
            )

        case .macd:
            return evaluateMACD(closes: closes, condition: condition)

        case .bollingerBand:
            return evaluateBollinger(closes: closes, condition: condition)

        case .volume:
            return evaluateVolume(bars: bars, condition: condition)

        case .price52WeekHigh:
            guard let ratio = IndicatorEngine.priceToHighRatio(bars: bars) else {
                return EvalResult(isMet: false, indicatorValue: nil, description: "데이터 부족")
            }
            let met = compare(ratio, condition.conditionOperator, condition.value)
            return EvalResult(
                isMet: met,
                indicatorValue: ratio,
                description: "52주신고가 대비 \(String(format: "%.1f", ratio))%"
            )

        case .adx:
            let adxValues = IndicatorEngine.adx(bars: bars, period: condition.period)
            guard let latest = adxValues.last, latest > 0 else {
                return EvalResult(isMet: false, indicatorValue: nil, description: "ADX 계산 불가")
            }
            let met = compare(latest, condition.conditionOperator, condition.value)
            return EvalResult(
                isMet: met,
                indicatorValue: latest,
                description: "ADX(\(condition.period)) = \(String(format: "%.1f", latest))"
            )

        case .priceChangeRate:
            guard let prevClose = bars.dropLast().last?.close,
                  let latestClose = bars.last?.close,
                  prevClose > 0
            else {
                return EvalResult(isMet: false, indicatorValue: nil, description: "데이터 부족")
            }
            let changeRate = (latestClose - prevClose) / prevClose * 100
            let met = compare(changeRate, condition.conditionOperator, condition.value)
            return EvalResult(
                isMet: met,
                indicatorValue: changeRate,
                description: "등락률 \(String(format: "%.2f", changeRate))%"
            )
        }
    }

    // MARK: - 전략 전체 평가 (모든 매수/매도 조건 AND 결합)

    static func shouldBuy(strategy: Strategy, bars: [OHLCV]) -> Bool {
        let conditions = strategy.buyConditions
        guard !conditions.isEmpty else { return false }
        return conditions.allSatisfy { evaluate(condition: $0, bars: bars).isMet }
    }

    static func shouldSell(strategy: Strategy, bars: [OHLCV]) -> Bool {
        let conditions = strategy.sellConditions
        guard !conditions.isEmpty else { return false }
        return conditions.allSatisfy { evaluate(condition: $0, bars: bars).isMet }
    }

    // 조건별 상세 결과 반환
    static func evaluateAll(strategy: Strategy, bars: [OHLCV]) -> [EvalResult] {
        strategy.conditions.map { evaluate(condition: $0, bars: bars) }
    }

    // MARK: - 개별 평가 로직

    private static func evaluateMA(closes: [Double], condition: Condition) -> EvalResult {
        let period = condition.period
        let maValues = IndicatorEngine.ma(closes: closes, period: period)

        if condition.conditionOperator == .crossAbove || condition.conditionOperator == .crossBelow {
            let comparePeriod = Int(condition.value)
            let compareMA = IndicatorEngine.ma(closes: closes, period: comparePeriod)
            let met = condition.conditionOperator == .crossAbove
                ? IndicatorEngine.didCrossAbove(series1: maValues, series2: compareMA)
                : IndicatorEngine.didCrossBelow(series1: maValues, series2: compareMA)
            let latestMA = maValues.last ?? 0
            return EvalResult(
                isMet: met,
                indicatorValue: latestMA,
                description: "MA(\(period)) \(condition.conditionOperator.rawValue) MA(\(comparePeriod))"
            )
        }

        guard let latest = maValues.last, latest > 0 else {
            return EvalResult(isMet: false, indicatorValue: nil, description: "MA 계산 불가")
        }
        let met = compare(latest, condition.conditionOperator, condition.value)
        return EvalResult(
            isMet: met,
            indicatorValue: latest,
            description: "MA(\(period)) = \(String(format: "%.0f", latest))"
        )
    }

    private static func evaluateEMA(closes: [Double], condition: Condition) -> EvalResult {
        let period = condition.period
        let emaValues = IndicatorEngine.ema(closes: closes, period: period)

        if condition.conditionOperator == .crossAbove || condition.conditionOperator == .crossBelow {
            let comparePeriod = Int(condition.value)
            let compareEMA = IndicatorEngine.ema(closes: closes, period: comparePeriod)
            let met = condition.conditionOperator == .crossAbove
                ? IndicatorEngine.didCrossAbove(series1: emaValues, series2: compareEMA)
                : IndicatorEngine.didCrossBelow(series1: emaValues, series2: compareEMA)
            return EvalResult(
                isMet: met,
                indicatorValue: emaValues.last,
                description: "EMA(\(period)) \(condition.conditionOperator.rawValue) EMA(\(comparePeriod))"
            )
        }

        guard let latest = emaValues.last, latest > 0 else {
            return EvalResult(isMet: false, indicatorValue: nil, description: "EMA 계산 불가")
        }
        let met = compare(latest, condition.conditionOperator, condition.value)
        return EvalResult(
            isMet: met,
            indicatorValue: latest,
            description: "EMA(\(period)) = \(String(format: "%.0f", latest))"
        )
    }

    private static func evaluateMACD(closes: [Double], condition: Condition) -> EvalResult {
        guard let latest = IndicatorEngine.latestMACD(closes: closes) else {
            return EvalResult(isMet: false, indicatorValue: nil, description: "MACD 계산 불가")
        }
        let macdResult = IndicatorEngine.macd(closes: closes)

        if condition.conditionOperator == .crossAbove {
            let met = IndicatorEngine.didCrossAbove(series1: macdResult.macd, series2: macdResult.signal)
            return EvalResult(isMet: met, indicatorValue: latest.macd, description: "MACD 골든크로스")
        }
        if condition.conditionOperator == .crossBelow {
            let met = IndicatorEngine.didCrossBelow(series1: macdResult.macd, series2: macdResult.signal)
            return EvalResult(isMet: met, indicatorValue: latest.macd, description: "MACD 데드크로스")
        }

        // 히스토그램 값 비교
        let met = compare(latest.histogram, condition.conditionOperator, condition.value)
        return EvalResult(
            isMet: met,
            indicatorValue: latest.histogram,
            description: "MACD 히스토그램 = \(String(format: "%.2f", latest.histogram))"
        )
    }

    private static func evaluateBollinger(closes: [Double], condition: Condition) -> EvalResult {
        guard let latest = IndicatorEngine.latestBollinger(closes: closes, period: condition.period),
              let currentClose = closes.last
        else {
            return EvalResult(isMet: false, indicatorValue: nil, description: "볼린저밴드 계산 불가")
        }

        // value: -2 = 하단밴드, 0 = 중간(MA), +2 = 상단밴드
        let targetBand: Double
        if condition.value <= -1 {
            targetBand = latest.lower
        } else if condition.value >= 1 {
            targetBand = latest.upper
        } else {
            targetBand = latest.middle
        }

        let met = compare(currentClose, condition.conditionOperator, targetBand)
        let bandName = condition.value <= -1 ? "하단" : condition.value >= 1 ? "상단" : "중간"
        return EvalResult(
            isMet: met,
            indicatorValue: currentClose,
            description: "볼린저 \(bandName)밴드(\(condition.period)) \(condition.conditionOperator.rawValue)"
        )
    }

    private static func evaluateVolume(bars: [OHLCV], condition: Condition) -> EvalResult {
        guard let latest = bars.last else {
            return EvalResult(isMet: false, indicatorValue: nil, description: "데이터 없음")
        }
        let avgVolume = Double(bars.map(\.volume).reduce(0, +)) / Double(bars.count)
        let ratio = avgVolume > 0 ? Double(latest.volume) / avgVolume * 100 : 0
        let met = compare(ratio, condition.conditionOperator, condition.value)
        return EvalResult(
            isMet: met,
            indicatorValue: ratio,
            description: "거래량 평균 대비 \(String(format: "%.0f", ratio))%"
        )
    }

    // MARK: - 비교 연산자

    private static func compare(_ lhs: Double, _ op: ConditionOperator, _ rhs: Double) -> Bool {
        switch op {
        case .greaterThan: return lhs > rhs
        case .lessThan: return lhs < rhs
        case .greaterThanOrEqual: return lhs >= rhs
        case .lessThanOrEqual: return lhs <= rhs
        case .crossAbove, .crossBelow: return false // 별도 처리
        }
    }
}
