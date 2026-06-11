import Foundation

struct APICredential: Codable {
    var appKey: String
    var appSecret: String
    var accountNumber: String  // KIS: 계좌번호 앞 8자리 / Alpaca: 미사용
    var accessToken: String?
    var tokenExpiry: Date?

    var isTokenValid: Bool {
        guard let token = accessToken, !token.isEmpty,
              let expiry = tokenExpiry else { return false }
        return expiry > Date()
    }
}

final class APICredentialManager {
    static let shared = APICredentialManager()
    private init() {}

    private let service = "com.showmethemoney.credentials"

    func save(_ credential: APICredential, for broker: Broker) {
        guard let data = try? JSONEncoder().encode(credential) else { return }
        KeychainHelper.save(data, service: service, account: broker.rawValue)
    }

    func load(for broker: Broker) -> APICredential? {
        guard let data = KeychainHelper.load(service: service, account: broker.rawValue),
              let credential = try? JSONDecoder().decode(APICredential.self, from: data)
        else { return nil }
        return credential
    }

    func delete(for broker: Broker) {
        KeychainHelper.delete(service: service, account: broker.rawValue)
    }

    func hasCredential(for broker: Broker) -> Bool {
        load(for: broker) != nil
    }

    func updateToken(_ token: String, expiry: Date, for broker: Broker) {
        guard var credential = load(for: broker) else { return }
        credential.accessToken = token
        credential.tokenExpiry = expiry
        save(credential, for: broker)
    }
}
