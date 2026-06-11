import Foundation

// 순수 함수로만 구성된 기술적 지표 계산 엔진
// 입력: 종가 배열 또는 OHLCV 배열
// 출력: 지표 값 배열 (입력과 동일한 인덱스 대응)
enum IndicatorEngine {

    // MARK: - 이동평균 (MA)

    static func ma(closes: [Double], period: Int) -> [Double] {
        guard period > 0, closes.count >= period else { return [] }
        var result = [Double](repeating: 0, count: closes.count)
        for i in (period - 1)..<closes.count {
            result[i] = closes[(i - period + 1)...i].reduce(0, +) / Double(period)
        }
        return result
    }

    // MARK: - 지수이동평균 (EMA)

    static func ema(closes: [Double], period: Int) -> [Double] {
        guard period > 0, closes.count >= period else { return [] }
        let multiplier = 2.0 / Double(period + 1)
        var result = [Double](repeating: 0, count: closes.count)

        // 첫 EMA는 SMA로 초기화
        let firstSMA = closes[0..<period].reduce(0, +) / Double(period)
        result[period - 1] = firstSMA

        for i in period..<closes.count {
            result[i] = (closes[i] - result[i - 1]) * multiplier + result[i - 1]
        }
        return result
    }

    // MARK: - RSI

    static func rsi(closes: [Double], period: Int = 14) -> [Double] {
        guard period > 0, closes.count > period else { return [] }
        var result = [Double](repeating: 0, count: closes.count)

        var gains = [Double](repeating: 0, count: closes.count)
        var losses = [Double](repeating: 0, count: closes.count)

        for i in 1..<closes.count {
            let change = closes[i] - closes[i - 1]
            gains[i] = max(change, 0)
            losses[i] = max(-change, 0)
        }

        // 첫 평균 (단순평균)
        var avgGain = gains[1...period].reduce(0, +) / Double(period)
        var avgLoss = losses[1...period].reduce(0, +) / Double(period)

        if avgLoss == 0 {
            result[period] = 100
        } else {
            result[period] = 100 - (100 / (1 + avgGain / avgLoss))
        }

        for i in (period + 1)..<closes.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
            if avgLoss == 0 {
                result[i] = 100
            } else {
                result[i] = 100 - (100 / (1 + avgGain / avgLoss))
            }
        }
        return result
    }

    // MARK: - MACD (12, 26, 9)

    struct MACDResult {
        let macd: [Double]
        let signal: [Double]
        let histogram: [Double]
    }

    static func macd(closes: [Double], fast: Int = 12, slow: Int = 26, signal: Int = 9) -> MACDResult {
        guard closes.count > slow else {
            return MACDResult(macd: [], signal: [], histogram: [])
        }
        let fastEMA = ema(closes: closes, period: fast)
        let slowEMA = ema(closes: closes, period: slow)

        var macdLine = [Double](repeating: 0, count: closes.count)
        for i in 0..<closes.count {
            macdLine[i] = fastEMA[i] - slowEMA[i]
        }

        let signalLine = ema(closes: macdLine, period: signal)
        var histogram = [Double](repeating: 0, count: closes.count)
        for i in 0..<closes.count {
            histogram[i] = macdLine[i] - signalLine[i]
        }

        return MACDResult(macd: macdLine, signal: signalLine, histogram: histogram)
    }

    // MARK: - 볼린저 밴드

    struct BollingerResult {
        let upper: [Double]
        let middle: [Double]
        let lower: [Double]
    }

    static func bollingerBands(closes: [Double], period: Int = 20, stdDev: Double = 2.0) -> BollingerResult {
        guard closes.count >= period else {
            return BollingerResult(upper: [], middle: [], lower: [])
        }
        let middle = ma(closes: closes, period: period)
        var upper = [Double](repeating: 0, count: closes.count)
        var lower = [Double](repeating: 0, count: closes.count)

        for i in (period - 1)..<closes.count {
            let slice = Array(closes[(i - period + 1)...i])
            let mean = middle[i]
            let variance = slice.map { pow($0 - mean, 2) }.reduce(0, +) / Double(period)
            let sd = sqrt(variance)
            upper[i] = mean + stdDev * sd
            lower[i] = mean - stdDev * sd
        }
        return BollingerResult(upper: upper, middle: middle, lower: lower)
    }

    // MARK: - ADX

    static func adx(bars: [OHLCV], period: Int = 14) -> [Double] {
        guard bars.count > period * 2 else { return [] }
        var trValues = [Double]()
        var plusDM = [Double]()
        var minusDM = [Double]()

        for i in 1..<bars.count {
            let high = bars[i].high, low = bars[i].low
            let prevHigh = bars[i-1].high, prevLow = bars[i-1].low
            let prevClose = bars[i-1].close

            let tr = max(high - low, abs(high - prevClose), abs(low - prevClose))
            trValues.append(tr)

            let upMove = high - prevHigh
            let downMove = prevLow - low
            plusDM.append(upMove > downMove && upMove > 0 ? upMove : 0)
            minusDM.append(downMove > upMove && downMove > 0 ? downMove : 0)
        }

        // Wilder 스무딩 (period-bar 지수평균)
        func wilderSmooth(_ values: [Double]) -> [Double] {
            guard values.count >= period else { return [] }
            var result = [Double](repeating: 0, count: values.count)
            result[period - 1] = values[0..<period].reduce(0, +)
            for i in period..<values.count {
                result[i] = result[i-1] - result[i-1] / Double(period) + values[i]
            }
            return result
        }

        let smoothTR = wilderSmooth(trValues)
        let smoothPDM = wilderSmooth(plusDM)
        let smoothMDM = wilderSmooth(minusDM)

        var adxResult = [Double](repeating: 0, count: bars.count)
        var dxValues = [Double]()

        for i in 0..<smoothTR.count {
            guard smoothTR[i] > 0 else { continue }
            let pdi = 100 * smoothPDM[i] / smoothTR[i]
            let mdi = 100 * smoothMDM[i] / smoothTR[i]
            let sum = pdi + mdi
            let dx = sum > 0 ? 100 * abs(pdi - mdi) / sum : 0
            dxValues.append(dx)
        }

        // ADX = DX의 스무딩 이동평균
        if dxValues.count >= period {
            var adx = dxValues[0..<period].reduce(0, +) / Double(period)
            let offset = bars.count - dxValues.count + period - 1
            adxResult[offset] = adx
            for i in 1..<(dxValues.count - period + 1) {
                adx = (adx * Double(period - 1) + dxValues[period - 1 + i]) / Double(period)
                adxResult[offset + i] = adx
            }
        }
        return adxResult
    }

    // MARK: - 52주 신고가 비율 (현재가 / 52주최고가 * 100)

    static func priceToHighRatio(bars: [OHLCV]) -> Double? {
        guard !bars.isEmpty else { return nil }
        let high52 = bars.map(\.high).max() ?? 0
        guard high52 > 0 else { return nil }
        return bars.last!.close / high52 * 100
    }

    // MARK: - 이격도 (현재가 / MA * 100 - 100)

    static func divergenceRate(closes: [Double], period: Int) -> [Double] {
        let maValues = ma(closes: closes, period: period)
        return zip(closes, maValues).map { close, ma in
            ma > 0 ? (close / ma * 100 - 100) : 0
        }
    }

    // MARK: - 편의 메서드: 최신값만 반환

    static func latestMA(closes: [Double], period: Int) -> Double? {
        let values = ma(closes: closes, period: period)
        return values.last.flatMap { $0 > 0 ? $0 : nil }
    }

    static func latestEMA(closes: [Double], period: Int) -> Double? {
        let values = ema(closes: closes, period: period)
        return values.last.flatMap { $0 > 0 ? $0 : nil }
    }

    static func latestRSI(closes: [Double], period: Int = 14) -> Double? {
        let values = rsi(closes: closes, period: period)
        return values.last.flatMap { $0 > 0 ? $0 : nil }
    }

    static func latestMACD(closes: [Double]) -> (macd: Double, signal: Double, histogram: Double)? {
        let result = macd(closes: closes)
        guard let m = result.macd.last, let s = result.signal.last, let h = result.histogram.last,
              m != 0 || s != 0 else { return nil }
        return (m, s, h)
    }

    static func latestBollinger(closes: [Double], period: Int = 20) -> (upper: Double, middle: Double, lower: Double)? {
        let result = bollingerBands(closes: closes, period: period)
        guard let u = result.upper.last, let m = result.middle.last, let l = result.lower.last,
              u > 0 else { return nil }
        return (u, m, l)
    }

    // MARK: - 크로스오버 감지

    static func didCrossAbove(series1: [Double], series2: [Double]) -> Bool {
        guard series1.count >= 2, series2.count >= 2 else { return false }
        let prev1 = series1[series1.count - 2], curr1 = series1[series1.count - 1]
        let prev2 = series2[series2.count - 2], curr2 = series2[series2.count - 1]
        return prev1 <= prev2 && curr1 > curr2
    }

    static func didCrossBelow(series1: [Double], series2: [Double]) -> Bool {
        guard series1.count >= 2, series2.count >= 2 else { return false }
        let prev1 = series1[series1.count - 2], curr1 = series1[series1.count - 1]
        let prev2 = series2[series2.count - 2], curr2 = series2[series2.count - 1]
        return prev1 >= prev2 && curr1 < curr2
    }
}
