import Foundation

enum Market: String, Codable, CaseIterable {
    case kospi = "KOSPI"
    case kosdaq = "KOSDAQ"
    case nyse = "NYSE"
    case nasdaq = "NASDAQ"

    var isKorean: Bool { self == .kospi || self == .kosdaq }
    var currency: Currency { isKorean ? .krw : .usd }
    var broker: Broker { isKorean ? .kis : .alpaca }
}

enum Currency: String, Codable, CaseIterable {
    case krw = "KRW"
    case usd = "USD"

    var symbol: String {
        switch self {
        case .krw: return "₩"
        case .usd: return "$"
        }
    }
}

enum StrategyType: String, Codable, CaseIterable {
    case momentum = "모멘텀"
    case meanReversion = "평균회귀"
    case trendFollowing = "추세추종"
    case valueFactor = "밸류팩터"
    case qualityFactor = "퀄리티팩터"
    case lowVolatility = "저변동성"
    case dividendFactor = "배당팩터"
    case multiFactor = "멀티팩터"
    case pairsTrading = "페어트레이딩"
    case sectorRotation = "섹터로테이션"
}

enum TradeType: String, Codable {
    case buy = "매수"
    case sell = "매도"
}

enum Broker: String, Codable, CaseIterable {
    case kis = "한국투자증권"
    case alpaca = "Alpaca"
}

enum RebalancePeriod: String, Codable, CaseIterable {
    case daily = "매일"
    case weekly = "매주"
    case monthly = "매월"
    case quarterly = "분기"
    case yearly = "매년"
}

enum ConditionIndicator: String, Codable, CaseIterable {
    case ma = "이동평균(MA)"
    case ema = "지수이동평균(EMA)"
    case rsi = "RSI"
    case macd = "MACD"
    case bollingerBand = "볼린저밴드"
    case volume = "거래량"
    case price52WeekHigh = "52주신고가"
    case adx = "ADX"
    case priceChangeRate = "등락률"
}

enum ConditionOperator: String, Codable, CaseIterable {
    case greaterThan = "초과"
    case lessThan = "미만"
    case greaterThanOrEqual = "이상"
    case lessThanOrEqual = "이하"
    case crossAbove = "상향돌파"
    case crossBelow = "하향돌파"
}
