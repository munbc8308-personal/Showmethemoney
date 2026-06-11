import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("증권사 API") {
                    NavigationLink("한국투자증권 (KIS)") {
                        KISCredentialView()
                    }
                    NavigationLink("Alpaca (미국주식)") {
                        AlpacaCredentialView()
                    }
                }
                Section("정보") {
                    LabeledContent("버전", value: "1.0.0 (Phase 1)")
                }
            }
            .navigationTitle("설정")
        }
    }
}

// MARK: - KIS 설정

struct KISCredentialView: View {
    @State private var appKey = ""
    @State private var appSecret = ""
    @State private var accountNumber = ""
    @State private var isSandbox = false
    @State private var showSaved = false
    @State private var showDeleted = false

    var body: some View {
        Form {
            Section {
                Toggle("모의투자 모드", isOn: $isSandbox)
                    .onChange(of: isSandbox) { _, value in
                        KISAPIClient.shared.isSandbox = value
                    }
            } footer: {
                Text(isSandbox
                     ? "모의투자 서버(https://openapivts.koreainvestment.com)를 사용합니다."
                     : "실거래 서버(https://openapi.koreainvestment.com)를 사용합니다.")
            }

            Section("인증 정보") {
                TextField("App Key", text: $appKey)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                SecureField("App Secret", text: $appSecret)
                TextField("계좌번호 (앞 8자리)", text: $accountNumber)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }

            Section {
                Button("저장") { saveCredential() }
                    .disabled(appKey.isEmpty || appSecret.isEmpty || accountNumber.isEmpty)
                if APICredentialManager.shared.hasCredential(for: .kis) {
                    Button("삭제", role: .destructive) { deleteCredential() }
                }
            }
        }
        .navigationTitle("KIS 설정")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { loadCredential() }
        .alert("저장됨", isPresented: $showSaved) { Button("확인") {} }
        .alert("삭제됨", isPresented: $showDeleted) { Button("확인") {} }
    }

    private func loadCredential() {
        guard let credential = APICredentialManager.shared.load(for: .kis) else { return }
        appKey = credential.appKey
        appSecret = credential.appSecret
        accountNumber = credential.accountNumber
    }

    private func saveCredential() {
        let credential = APICredential(appKey: appKey, appSecret: appSecret, accountNumber: accountNumber)
        APICredentialManager.shared.save(credential, for: .kis)
        KISAPIClient.shared.isSandbox = isSandbox
        showSaved = true
    }

    private func deleteCredential() {
        APICredentialManager.shared.delete(for: .kis)
        appKey = ""; appSecret = ""; accountNumber = ""
        showDeleted = true
    }
}

// MARK: - Alpaca 설정

struct AlpacaCredentialView: View {
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var isSandbox = true
    @State private var showSaved = false
    @State private var showDeleted = false

    var body: some View {
        Form {
            Section {
                Toggle("Paper Trading 모드", isOn: $isSandbox)
                    .onChange(of: isSandbox) { _, value in
                        AlpacaAPIClient.shared.isSandbox = value
                    }
            } footer: {
                Text(isSandbox
                     ? "Paper Trading(모의투자) 서버를 사용합니다. 실제 주문이 발생하지 않습니다."
                     : "실거래 서버를 사용합니다. 실제 주문이 발생합니다.")
            }

            Section("인증 정보") {
                TextField("API Key ID", text: $apiKey)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                SecureField("API Secret Key", text: $apiSecret)
            }

            Section {
                Button("저장") { saveCredential() }
                    .disabled(apiKey.isEmpty || apiSecret.isEmpty)
                if APICredentialManager.shared.hasCredential(for: .alpaca) {
                    Button("삭제", role: .destructive) { deleteCredential() }
                }
            }
        }
        .navigationTitle("Alpaca 설정")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { loadCredential() }
        .alert("저장됨", isPresented: $showSaved) { Button("확인") {} }
        .alert("삭제됨", isPresented: $showDeleted) { Button("확인") {} }
    }

    private func loadCredential() {
        guard let credential = APICredentialManager.shared.load(for: .alpaca) else { return }
        apiKey = credential.appKey
        apiSecret = credential.appSecret
    }

    private func saveCredential() {
        let credential = APICredential(appKey: apiKey, appSecret: apiSecret, accountNumber: "")
        APICredentialManager.shared.save(credential, for: .alpaca)
        AlpacaAPIClient.shared.isSandbox = isSandbox
        showSaved = true
    }

    private func deleteCredential() {
        APICredentialManager.shared.delete(for: .alpaca)
        apiKey = ""; apiSecret = ""
        showDeleted = true
    }
}
