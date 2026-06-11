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

    // MARK: - 일봉 데이터 (차트용)

    func fetchDailyBars(symbol: String, startDate: Date) async throws -> [OHLCV] {
        return try await fetchBarsFrom(symbol: symbol, startDate: startDate)
    }

    func fetchDailyBars(symbol: String, period: ChartPeriod) async throws -> [OHLCV] {
        return try await fetchBarsFrom(symbol: symbol, startDate: period.startDate)
    }

    private func fetchBarsFrom(symbol: String, startDate: Date) async throws -> [OHLCV] {
        guard let credential = APICredentialManager.shared.load(for: .alpaca) else {
            throw APIError.missingCredential
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: Date())

        var components = URLComponents(string: "\(dataURL)/stocks/\(symbol)/bars")!
        components.queryItems = [
            URLQueryItem(name: "timeframe", value: "1Day"),
            URLQueryItem(name: "start", value: startStr),
            URLQueryItem(name: "end", value: endStr),
            URLQueryItem(name: "limit", value: "1000"),
            URLQueryItem(name: "adjustment", value: "raw")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(credential.appKey, forHTTPHeaderField: "APCA-API-KEY-ID")
        request.setValue(credential.appSecret, forHTTPHeaderField: "APCA-API-SECRET-KEY")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bars = json["bars"] as? [[String: Any]]
        else { throw APIError.parseError }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        return bars.compactMap { bar -> OHLCV? in
            guard let timeStr = bar["t"] as? String,
                  let date = dateFormatter.date(from: timeStr),
                  let open = bar["o"] as? Double,
                  let high = bar["h"] as? Double,
                  let low = bar["l"] as? Double,
                  let close = bar["c"] as? Double,
                  let volume = bar["v"] as? Double
            else { return nil }
            return OHLCV(date: date, open: open, high: high, low: low, close: close, volume: Int(volume))
        }
        .sorted { $0.date < $1.date }
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
