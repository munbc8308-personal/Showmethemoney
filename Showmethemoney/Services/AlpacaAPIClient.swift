import Foundation

// Alpaca API Client (미국 주식)
// 실거래: https://api.alpaca.markets
// 모의투자(Paper): https://paper-api.alpaca.markets
final class AlpacaAPIClient {
    static let shared = AlpacaAPIClient()
    private init() {}

    var isSandbox: Bool = true

    private var baseURL: String {
        isSandbox
            ? "https://paper-api.alpaca.markets/v2"
            : "https://api.alpaca.markets/v2"
    }
    private let dataURL = "https://data.alpaca.markets/v2"

    private let session = URLSession.shared

    // MARK: - 주가 조회

    func fetchStockPrice(symbol: String) async throws -> StockPrice {
        guard let credential = APICredentialManager.shared.load(for: .alpaca) else {
            throw APIError.missingCredential
        }

        let url = URL(string: "\(dataURL)/stocks/\(symbol)/quotes/latest")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(credential.appKey, forHTTPHeaderField: "APCA-API-KEY-ID")
        request.setValue(credential.appSecret, forHTTPHeaderField: "APCA-API-SECRET-KEY")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quote = json["quote"] as? [String: Any],
              let askPrice = quote["ap"] as? Double
        else { throw APIError.parseError }

        return StockPrice(symbol: symbol, price: askPrice, changeRate: 0, currency: .usd)
    }

    // MARK: - 잔고 조회

    func fetchBalance() async throws -> AccountBalance {
        guard let credential = APICredentialManager.shared.load(for: .alpaca) else {
            throw APIError.missingCredential
        }

        let url = URL(string: "\(baseURL)/account")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(credential.appKey, forHTTPHeaderField: "APCA-API-KEY-ID")
        request.setValue(credential.appSecret, forHTTPHeaderField: "APCA-API-SECRET-KEY")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cashStr = json["cash"] as? String,
              let cash = Double(cashStr),
              let equityStr = json["equity"] as? String,
              let equity = Double(equityStr)
        else { throw APIError.parseError }

        return AccountBalance(cash: cash, totalValue: equity, currency: .usd)
    }

    // MARK: - 주문

    func placeOrder(symbol: String, type: TradeType, quantity: Int, price: Double? = nil) async throws -> String {
        guard let credential = APICredentialManager.shared.load(for: .alpaca) else {
            throw APIError.missingCredential
        }

        let url = URL(string: "\(baseURL)/orders")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credential.appKey, forHTTPHeaderField: "APCA-API-KEY-ID")
        request.setValue(credential.appSecret, forHTTPHeaderField: "APCA-API-SECRET-KEY")

        var body: [String: Any] = [
            "symbol": symbol,
            "qty": "\(quantity)",
            "side": type == .buy ? "buy" : "sell",
            "type": price == nil ? "market" : "limit",
            "time_in_force": "day"
        ]
        if let price { body["limit_price"] = "\(price)" }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let orderId = json["id"] as? String
        else { throw APIError.parseError }

        return orderId
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
    }
}
