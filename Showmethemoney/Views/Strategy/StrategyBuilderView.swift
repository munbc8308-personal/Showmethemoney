import SwiftUI
import SwiftData

// 전략 상세 편집 화면 (조건 추가/삭제, 파라미터 수정)
struct StrategyBuilderView: View {
    @Bindable var strategy: Strategy
    @Environment(\.modelContext) private var modelContext
    @State private var showAddCondition = false
    @State private var addingBuyCondition = true

    var body: some View {
        Form {
            basicSection
            riskSection
            symbolSection
            buyConditionsSection
            sellConditionsSection
        }
        .navigationTitle(strategy.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showAddCondition) {
            AddConditionView(strategy: strategy, isBuyCondition: addingBuyCondition)
        }
    }

    // MARK: - 기본 정보

    private var basicSection: some View {
        Section("기본 정보") {
            HStack {
                Text("전략 이름")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("이름", text: $strategy.name)
                    .multilineTextAlignment(.trailing)
            }
            Picker("전략 유형", selection: $strategy.type) {
                ForEach(StrategyType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            Picker("리밸런싱 주기", selection: $strategy.rebalancePeriod) {
                ForEach(RebalancePeriod.allCases, id: \.self) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            Toggle("자동매매 활성화", isOn: $strategy.isActive)
                .tint(.green)
        }
    }

    // MARK: - 리스크 설정

    private var riskSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("포지션 크기")
                    Spacer()
                    Text(String(format: "%.0f%%", strategy.positionSizePct))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $strategy.positionSizePct, in: 1...100, step: 1)
                    .tint(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("손절")
                    Spacer()
                    Text(String(format: "-%.1f%%", strategy.stopLossPct))
                        .foregroundStyle(.red)
                }
                Slider(value: $strategy.stopLossPct, in: 0.5...30, step: 0.5)
                    .tint(.red)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("익절")
                    Spacer()
                    Text(String(format: "+%.1f%%", strategy.takeProfitPct))
                        .foregroundStyle(.green)
                }
                Slider(value: $strategy.takeProfitPct, in: 0.5...100, step: 0.5)
                    .tint(.green)
            }
        } header: {
            Text("리스크 관리")
        } footer: {
            Text("포지션 크기: 총 자산 대비 이 종목에 투자할 최대 비중")
        }
    }

    // MARK: - 적용 종목

    private var symbolSection: some View {
        Section {
            ForEach(strategy.targetSymbols, id: \.self) { symbol in
                Text(symbol)
            }
            .onDelete { offsets in
                strategy.targetSymbols.remove(atOffsets: offsets)
            }
            Button {
                strategy.targetSymbols.append("종목코드")
            } label: {
                Label("종목 추가", systemImage: "plus.circle")
            }
        } header: {
            Text("적용 종목 (\(strategy.targetSymbols.count)개)")
        }
    }

    // MARK: - 매수 조건

    private var buyConditionsSection: some View {
        Section {
            if strategy.buyConditions.isEmpty {
                Text("조건 없음 — 항상 매수")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(strategy.buyConditions) { condition in
                    conditionRow(condition)
                }
                .onDelete { offsets in
                    deleteConditions(at: offsets, isBuy: true)
                }
            }
            Button {
                addingBuyCondition = true
                showAddCondition = true
            } label: {
                Label("매수 조건 추가", systemImage: "plus.circle")
                    .foregroundStyle(.blue)
            }
        } header: {
            Text("매수 조건 (\(strategy.buyConditions.count)개) — AND 결합")
        } footer: {
            Text("모든 조건을 동시에 만족할 때 매수 신호 발생")
        }
    }

    // MARK: - 매도 조건

    private var sellConditionsSection: some View {
        Section {
            if strategy.sellConditions.isEmpty {
                Text("조건 없음 — 손절/익절만 적용")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(strategy.sellConditions) { condition in
                    conditionRow(condition)
                }
                .onDelete { offsets in
                    deleteConditions(at: offsets, isBuy: false)
                }
            }
            Button {
                addingBuyCondition = false
                showAddCondition = true
            } label: {
                Label("매도 조건 추가", systemImage: "plus.circle")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("매도 조건 (\(strategy.sellConditions.count)개) — AND 결합")
        } footer: {
            Text("손절/익절은 별도로 항상 적용됩니다")
        }
    }

    private func conditionRow(_ condition: Condition) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(condition.displayText)
                .font(.subheadline)
            Text(condition.isBuyCondition ? "매수 조건" : "매도 조건")
                .font(.caption2)
                .foregroundStyle(condition.isBuyCondition ? .blue : .red)
        }
        .padding(.vertical, 2)
    }

    private func deleteConditions(at offsets: IndexSet, isBuy: Bool) {
        let filtered = strategy.conditions.filter { $0.isBuyCondition == isBuy }
        for index in offsets {
            let condition = filtered[index]
            modelContext.delete(condition)
        }
    }
}

// MARK: - 조건 추가 시트

struct AddConditionView: View {
    let strategy: Strategy
    let isBuyCondition: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var indicator: ConditionIndicator = .rsi
    @State private var conditionOp: ConditionOperator = .lessThan
    @State private var value: Double = 30
    @State private var period: Int = 14

    private var indicatorNeedsPeriod: Bool {
        switch indicator {
        case .price52WeekHigh, .priceChangeRate: return false
        default: return true
        }
    }

    private var isCrossover: Bool {
        conditionOp == .crossAbove || conditionOp == .crossBelow
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("지표") {
                    Picker("지표 선택", selection: $indicator) {
                        ForEach(ConditionIndicator.allCases, id: \.self) { i in
                            Text(i.rawValue).tag(i)
                        }
                    }
                    if indicatorNeedsPeriod {
                        Stepper("기간: \(period)일", value: $period, in: 2...200)
                    }
                }

                Section("조건") {
                    Picker("비교 연산", selection: $conditionOp) {
                        ForEach(availableOperators, id: \.self) { op in
                            Text(op.rawValue).tag(op)
                        }
                    }
                    .pickerStyle(.segmented)

                    if !isCrossover {
                        HStack {
                            Text(valueLabel)
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("값", value: $value, format: .number)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                    } else if indicator == .ma || indicator == .ema {
                        Stepper("비교 기간: \(Int(value))일", value: $value, in: 2...500)
                    }
                }

                Section {
                    conditionPreview
                }
            }
            .navigationTitle("\(isBuyCondition ? "매수" : "매도") 조건 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") { addCondition() }
                }
            }
        }
    }

    private var availableOperators: [ConditionOperator] {
        switch indicator {
        case .ma, .ema:
            return ConditionOperator.allCases
        case .macd:
            return [.crossAbove, .crossBelow, .greaterThan, .lessThan]
        default:
            return [.greaterThan, .lessThan, .greaterThanOrEqual, .lessThanOrEqual]
        }
    }

    private var valueLabel: String {
        switch indicator {
        case .rsi: return "기준값 (0-100)"
        case .bollingerBand: return "밴드 위치 (-2:하단, 0:중간, 2:상단)"
        case .price52WeekHigh: return "비율 (%)"
        case .priceChangeRate: return "등락률 (%)"
        case .volume: return "평균 대비 (%)"
        default: return "기준값"
        }
    }

    private var conditionPreview: some View {
        let condition = Condition(
            indicator: indicator,
            conditionOperator: conditionOp,
            value: value,
            period: period,
            isBuyCondition: isBuyCondition
        )
        return VStack(alignment: .leading, spacing: 4) {
            Text("미리보기")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(condition.displayText)
                .font(.subheadline.bold())
                .foregroundStyle(isBuyCondition ? .blue : .red)
        }
    }

    private func addCondition() {
        let condition = Condition(
            indicator: indicator,
            conditionOperator: conditionOp,
            value: value,
            period: period,
            isBuyCondition: isBuyCondition
        )
        condition.strategy = strategy
        strategy.conditions.append(condition)
        modelContext.insert(condition)
        dismiss()
    }
}
