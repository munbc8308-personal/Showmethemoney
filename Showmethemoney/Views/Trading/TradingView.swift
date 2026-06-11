import SwiftUI
import SwiftData

struct TradingView: View {
    @Query private var strategies: [Strategy]

    var activeStrategies: [Strategy] { strategies.filter { $0.isActive } }

    var body: some View {
        NavigationStack {
            List {
                if strategies.isEmpty {
                    ContentUnavailableView(
                        "전략 없음",
                        systemImage: "bolt.slash",
                        description: Text("전략 탭에서 퀀트 전략을 먼저 추가하세요")
                    )
                } else {
                    Section("실행 현황") {
                        statusRow(
                            label: "활성화된 전략",
                            value: "\(activeStrategies.count) / \(strategies.count)"
                        )
                        statusRow(
                            label: "자동매매",
                            value: activeStrategies.isEmpty ? "대기 중" : "실행 중"
                        )
                    }

                    Section("전략 활성화") {
                        ForEach(strategies) { strategy in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(strategy.name)
                                        .font(.subheadline)
                                    Text(strategy.type.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { strategy.isActive },
                                    set: { strategy.isActive = $0 }
                                ))
                                .labelsHidden()
                            }
                        }
                    }
                }
            }
            .navigationTitle("자동매매")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Label("macOS에서 실행됨", systemImage: "desktopcomputer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}
