import SwiftUI
import SwiftData

struct StrategyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Strategy.createdAt, order: .reverse) private var strategies: [Strategy]
    @State private var showAddStrategy = false

    var body: some View {
        NavigationStack {
            List {
                if strategies.isEmpty {
                    ContentUnavailableView(
                        "전략 없음",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("+ 버튼을 눌러 퀀트 전략을 추가하세요")
                    )
                } else {
                    ForEach(strategies) { strategy in
                        NavigationLink(destination: StrategyDetailView(strategy: strategy)) {
                            strategyRow(strategy)
                        }
                    }
                    .onDelete(perform: deleteStrategies)
                }
            }
            .navigationTitle("전략")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddStrategy = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddStrategy) {
                AddStrategyView()
            }
        }
    }

    private func strategyRow(_ strategy: Strategy) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(strategy.name)
                        .font(.subheadline.bold())
                    if strategy.isActive {
                        Circle()
                            .fill(.green)
                            .frame(width: 7, height: 7)
                    }
                }
                Text(strategy.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("매수 \(strategy.buyConditions.count)개 / 매도 \(strategy.sellConditions.count)개 조건")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { strategy.isActive },
                set: { strategy.isActive = $0 }
            ))
            .labelsHidden()
        }
    }

    private func deleteStrategies(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(strategies[index])
        }
    }
}

struct StrategyDetailView: View {
    @Bindable var strategy: Strategy

    var body: some View {
        Form {
            Section("기본 정보") {
                LabeledContent("유형", value: strategy.type.rawValue)
                LabeledContent("리밸런싱", value: strategy.rebalancePeriod.rawValue)
            }
            Section("리스크 설정") {
                LabeledContent("포지션 크기", value: String(format: "%.1f%%", strategy.positionSizePct))
                LabeledContent("손절", value: String(format: "%.1f%%", strategy.stopLossPct))
                LabeledContent("익절", value: String(format: "%.1f%%", strategy.takeProfitPct))
            }
            Section("매수 조건 (\(strategy.buyConditions.count)개)") {
                ForEach(strategy.buyConditions) { condition in
                    Text(condition.displayText).font(.caption)
                }
            }
            Section("매도 조건 (\(strategy.sellConditions.count)개)") {
                ForEach(strategy.sellConditions) { condition in
                    Text(condition.displayText).font(.caption)
                }
            }
            Section("적용 종목 (\(strategy.targetSymbols.count)개)") {
                ForEach(strategy.targetSymbols, id: \.self) { symbol in
                    Text(symbol)
                }
            }
        }
        .navigationTitle(strategy.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct AddStrategyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: StrategyType = .momentum

    var body: some View {
        NavigationStack {
            Form {
                Section("전략 정보") {
                    TextField("전략 이름", text: $name)
                    Picker("전략 유형", selection: $type) {
                        ForEach(StrategyType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }
            }
            .navigationTitle("전략 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") { addStrategy() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func addStrategy() {
        let strategy = Strategy(name: name, type: type)
        modelContext.insert(strategy)
        dismiss()
    }
}
