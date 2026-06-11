import SwiftUI
import SwiftData

@main
struct ShowmethemoneyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Stock.self,
            Strategy.self,
            Condition.self,
            Trade.self,
            Holding.self
        ])

        // CloudKit 동기화 활성화 방법:
        // 1. Xcode → Signing & Capabilities → + → iCloud 추가
        // 2. CloudKit 체크박스 활성화 후 컨테이너 ID 지정
        // 3. 아래 localConfig 대신 cloudConfig 사용

        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // CloudKit 활성화 후 교체:
        // let cloudConfig = ModelConfiguration(
        //     schema: schema,
        //     isStoredInMemoryOnly: false,
        //     cloudKitDatabase: .automatic
        // )

        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
