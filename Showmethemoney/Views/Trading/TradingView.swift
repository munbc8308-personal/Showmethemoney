import SwiftUI
import SwiftData

struct TradingView: View {
    @Environment(AutoTradingService.self) private var service
    @Query private var strategies: [Strategy]
    @Query(sort: \Holding.updatedAt, order: .reverse) private var holdings: [Holding]

    var activeCount: Int { strategies.filter { $0.isActive }.count }

    var body: some View {
        NavigationStack {
            List {
                engineSection
                marketSection
                if !holdings.isEmpty {
                    holdingsSection
                }
                logsSection
                strategiesSection
            }
            .navigationTitle("자동매매")
            .refreshable { service.checkNow() }
        }
    }

    // MARK: - Engine Status

    private var engineSection: some View {
        Section {
            HStack(spacing: 12) {
                Circle()
                    .fill(service.isRunning ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(service.isRunning ? "실행 중" : "중지됨")
                        .font(.headline)
                    if let last = service.lastCheckTime {
                        Text("마지막 체크: \(last, style: .relative) 전")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let next = service.nextCheckTime, service.isRunning {
                        Text("다음 체크: \(next, style: .relative) 후")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                #if os(macOS)
                VStack(spacing: 6) {
                    Button(service.isRunning ? "중지" : "시작") {
                        if service.isRunning { service.stop() } else { service.start() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(service.isRunning ? .red : .green)
                    .controlSize(.small)

                    Button("지금 체크") { service.checkNow() }
                        .controlSize(.small)
                        .disabled(service.isRunning)
                }
                #else
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(.secondary)
                    Text("Mac에서 실행")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                #endif
            }
            .padding(.vertical, 4)
        } header: {
            Text("엔진 상태")
        }
    }

    // MARK: - Market Hours

    private var marketSection: some View {
        Section("시장 현황") {
            marketRow("한국 (KST 09:00–15:30)", isOpen: service.isKoreanMarketOpen)
            marketRow("미국 (EST 09:30–16:00)", isOpen: service.isUSMarketOpen)
        }
    }

    private func marketRow(_ name: String, isOpen: Bool) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
            Spacer()
            Text(isOpen ? "개장" : "폐장")
                .font(.caption.bold())
                .foregroundStyle(isOpen ? .green : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(isOpen ? Color.green.opacity(0.12) : Color.secondary.opacity(0.1), in: Capsule())
        }
    }

    // MARK: - Holdings

    private var holdingsSection: some View {
        Section("보유 종목 (\(holdings.count))") {
            ForEach(holdings) { holding in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(holding.symbol)
                            .font(.subheadline.bold())
                        Text("\(holding.quantity)주 · 평단 \(costText(holding))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(holding.market.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func costText(_ h: Holding) -> String {
        h.currency == .krw ? "\(Int(h.averageCost))원" : String(format: "$%.2f", h.averageCost)
    }

    // MARK: - Logs

    private var logsSection: some View {
        Section {
            if service.logs.isEmpty {
                Text("실행 로그 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(service.logs.prefix(30)) { log in
                    logRow(log)
                }
            }
        } header: {
            HStack {
                Text("실행 로그")
                Spacer()
                if !service.logs.isEmpty {
                    Button("지우기") { service.clearLogs() }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func logRow(_ log: TradingLog) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: logIcon(log.level))
                .foregroundStyle(logColor(log.level))
                .font(.caption)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if let symbol = log.symbol {
                        Text(symbol)
                            .font(.caption.bold())
                    }
                    Text(log.message)
                        .font(.caption)
                        .foregroundStyle(log.symbol == nil ? .secondary : .primary)
                }
                Text(log.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 1)
    }

    private func logIcon(_ level: TradingLog.Level) -> String {
        switch level {
        case .info:  return "info.circle"
        case .buy:   return "arrow.up.circle.fill"
        case .sell:  return "arrow.down.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    private func logColor(_ level: TradingLog.Level) -> Color {
        switch level {
        case .info:  return .secondary
        case .buy:   return .blue
        case .sell:  return .red
        case .error: return .orange
        }
    }

    // MARK: - Strategies

    private var strategiesSection: some View {
        Section {
            if strategies.isEmpty {
                ContentUnavailableView(
                    "전략 없음",
                    systemImage: "bolt.slash",
                    description: Text("전략 탭에서 퀀트 전략을 먼저 추가하세요")
                )
            } else {
                ForEach(strategies) { strategy in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(strategy.name)
                                .font(.subheadline)
                            Text("\(strategy.type.rawValue) · \(strategy.targetSymbols.count)종목")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { strategy.isActive },
                            set: { strategy.isActive = $0 }
                        ))
                        .labelsHidden()
                        .tint(.green)
                    }
                }
            }
        } header: {
            Text("전략 활성화 (\(activeCount)/\(strategies.count))")
        } footer: {
            Text("활성화된 전략은 자동매매 엔진이 매 60초마다 조건을 체크합니다")
        }
    }
}
