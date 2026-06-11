import Foundation

struct StockPrice {
    let symbol: String
    let price: Double
    let changeRate: Double
    let currency: Currency
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
