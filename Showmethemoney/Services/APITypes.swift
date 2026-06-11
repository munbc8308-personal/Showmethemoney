import Foundation

struct StockPrice {
    let symbol: String
    let price: Double
    let changeRate: Double
    let changeAmount: Double
    let currency: Currency
    let volume: Int

    init(symbol: String, price: Double, changeRate: Double, changeAmount: Double = 0, currency: Currency, volume: Int = 0) {
        self.symbol = symbol
        self.price = price
        self.changeRate = changeRate
        self.changeAmount = changeAmount
        self.currency = currency
        self.volume = volume
    }

    var isPositive: Bool { changeRate >= 0 }
}

struct OHLCV: Identifiable {
    let id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}

enum ChartPeriod: String, CaseIterable {
    case oneWeek = "1주"
    case oneMonth = "1달"
    case threeMonths = "3달"
    case sixMonths = "6달"
    case oneYear = "1년"

    var days: Int {
        switch self {
        case .oneWeek: return 7
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        }
    }

    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}

struct AccountBalance {
    let cash: Double
    let totalValue: Double
    let currency: Currency

    var investedValue: Double { totalValue - cash }
}

enum APIError: LocalizedError {
    case missingCredential
    case invalidResponse
    case httpError(Int)
    case parseError
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .missingCredential: return "API 키가 설정되지 않았습니다. 설정에서 등록해주세요."
        case .invalidResponse: return "잘못된 응답입니다."
        case .httpError(let code): return "HTTP 오류: \(code)"
        case .parseError: return "데이터 파싱 오류입니다."
        case .unauthorized: return "인증에 실패했습니다. API 키를 확인해주세요."
        }
    }
}
