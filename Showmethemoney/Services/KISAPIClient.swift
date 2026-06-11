import Foundation

// 한국투자증권 KIS Open API Client
// 실거래: https://openapi.koreainvestment.com:9443
// 모의투자: https://openapivts.koreainvestment.com:29443
final class KISAPIClient {
    static let shared = KISAPIClient()
    private init() {}

    var isSandbox: Bool = false

    private var baseURL: String {
        isSandbox
            ? "https://openapivts.koreainvestment.com:29443"
            : "https://openapi.koreainvestment.com:9443"
    }

    private let session = URLSession.shared

    // MARK: - Authentication

    func fetchAccessToken() async throws -> String {
        guard let credential = APICredentialManager.shared.load(for: .kis) else {
            throw APIError.missingCredential
        }

        let url = URL(string: "\(baseURL)/oauth2/tokenP")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "client_credentials",
            "appkey": credential.appKey,
            "appsecret": credential.appSecret
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        struct TokenResponse: Decodable {
            let accessToken: String
            let expiresIn: Int
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case expiresIn = "expires_in"
            }
        }
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        APICredentialManager.shared.updateToken(tokenResponse.accessToken, expiry: expiry, for: .kis)

        return tokenResponse.accessToken
    }

    private func validToken() async throws -> String {
        if let credential = APICredentialManager.shared.load(for: .kis),
           credential.isTokenValid,
           let token = credential.accessToken {
            return token
        }
        return try await fetchAccessToken()
    }

    // MARK: - 주가 조회

    func fetchStockPrice(symbol: String) async throws -> StockPrice {
        let token = try await validToken()
        guard let credential = APICredentialManager.shared.load(for: .kis) else {
            throw APIError.missingCredential
        }

        var components = URLComponents(string: "\(baseURL)/uapi/domestic-stock/v1/quotations/inquire-price")!
        components.queryItems = [
            URLQueryItem(name: "FID_COND_MRKT_DIV_CODE", value: "J"),
            URLQueryItem(name: "FID_INPUT_ISCD", value: symbol)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credential.appKey, forHTTPHeaderField: "appkey")
        request.setValue(credential.appSecret, forHTTPHeaderField: "appsecret")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("FHKST01010100", forHTTPHeaderField: "tr_id")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let priceStr = output["stck_prpr"] as? String,
              let price = Double(priceStr),
              let changeRateStr = output["prdy_ctrt"] as? String,
              let changeRate = Double(changeRateStr)
        else { throw APIError.parseError }

        return StockPrice(symbol: symbol, price: price, changeRate: changeRate, currency: .krw)
    }

    // MARK: - 잔고 조회

    func fetchBalance() async throws -> AccountBalance {
        let token = try await validToken()
        guard let credential = APICredentialManager.shared.load(for: .kis) else {
            throw APIError.missingCredential
        }

        var components = URLComponents(string: "\(baseURL)/uapi/domestic-stock/v1/trading/inquire-balance")!
        components.queryItems = [
            URLQueryItem(name: "CANO", value: credential.accountNumber),
            URLQueryItem(name: "ACNT_PRDT_CD", value: "01"),
            URLQueryItem(name: "AFHR_FLPR_YN", value: "N"),
            URLQueryItem(name: "OFL_YN", value: ""),
            URLQueryItem(name: "INQR_DVSN", value: "02"),
            URLQueryItem(name: "UNPR_DVSN", value: "01"),
            URLQueryItem(name: "FUND_STTL_ICLD_YN", value: "N"),
            URLQueryItem(name: "FNCG_AMT_AUTO_RDPT_YN", value: "N"),
            URLQueryItem(name: "PRCS_DVSN", value: "01"),
            URLQueryItem(name: "CTX_AREA_FK100", value: ""),
            URLQueryItem(name: "CTX_AREA_NK100", value: "")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credential.appKey, forHTTPHeaderField: "appkey")
        request.setValue(credential.appSecret, forHTTPHeaderField: "appsecret")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(isSandbox ? "VTTC8434R" : "TTTC8434R", forHTTPHeaderField: "tr_id")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output2 = (json["output2"] as? [[String: Any]])?.first,
              let cashStr = output2["dnca_tot_amt"] as? String,
              let cash = Double(cashStr),
              let totalStr = output2["tot_evlu_amt"] as? String,
              let total = Double(totalStr)
        else { throw APIError.parseError }

        return AccountBalance(cash: cash, totalValue: total, currency: .krw)
    }

    // MARK: - 주문

    func placeOrder(symbol: String, type: TradeType, quantity: Int, price: Double? = nil) async throws -> String {
        let token = try await validToken()
        guard let credential = APICredentialManager.shared.load(for: .kis) else {
            throw APIError.missingCredential
        }

        let url = URL(string: "\(baseURL)/uapi/domestic-stock/v1/trading/order-cash")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credential.appKey, forHTTPHeaderField: "appkey")
        request.setValue(credential.appSecret, forHTTPHeaderField: "appsecret")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let trId: String
        if isSandbox {
            trId = type == .buy ? "VTTC0802U" : "VTTC0801U"
        } else {
            trId = type == .buy ? "TTTC0802U" : "TTTC0801U"
        }
        request.setValue(trId, forHTTPHeaderField: "tr_id")

        let body: [String: String] = [
            "CANO": credential.accountNumber,
            "ACNT_PRDT_CD": "01",
            "PDNO": symbol,
            "ORD_DVSN": price == nil ? "01" : "00",  // 01: 시장가, 00: 지정가
            "ORD_QTY": "\(quantity)",
            "ORD_UNPR": price != nil ? "\(Int(price!))" : "0"
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any]
        else { throw APIError.parseError }

        return output["ODNO"] as? String ?? ""
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
    }
}
