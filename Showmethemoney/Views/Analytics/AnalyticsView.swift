import SwiftUI
import SwiftData
import Charts

private struct MonthlyPnL: Identifiable {
    let id = UUID()
    let label: String
    let profit: Double
    let sortDate: Date
}

private struct StrategyStats: Identifiable {
    let id = UUID()
    let name: String
    let totalTrades: Int
    let winCount: Int
    let totalProfit: Double
    var winRate: Double { guard totalTrades > 0 else { return 0 }; return Double(winCount) / Double(totalTrades) * 100 }
}

struct AnalyticsView: View {
    @Query(sort: \Trade.executedAt) private var allTrades: [Trade]

    private var sellTrades: [Trade] { allTrades.filter { $0.type == .sell && $0.profit != nil } }

    // MARK: - Aggregates

    private var totalProfit: Double { sellTrades.compactMap { $0.profit }.reduce(0, +) }

    private var winTrades: [Trade] { sellTrades.filter { ($0.profit ?? 0) > 0 } }
    private var lossTrades: [Trade] { sellTrades.filter { ($0.profit ?? 0) <= 0 } }

    private var winRate: Double {
        guard !sellTrades.isEmpty else { return 0 }
        return Double(winTrades.count) / Double(sellTrades.count) * 100
    }

    private var avgWinPct: Double {
        guard !winTrades.isEmpty else { return 0 }
        return winTrades.compactMap { $0.profitPct }.reduce(0, +) / Double(winTrades.count)
    }

    private var avgLossPct: Double {
        guard !lossTrades.isEmpty else { return 0 }
        return abs(lossTrades.compactMap { $0.profitPct }.reduce(0, +) / Double(lossTrades.count))
    }

    private var profitFactor: Double {
        let gross = winTrades.compactMap { $0.profit }.reduce(0, +)
        let grossLoss = abs(lossTrades.compactMap { $0.profit }.reduce(0, +))
        guard grossLoss > 0 else { return gross > 0 ? 99.9 : 0 }
        return gross / grossLoss
    }

    private var cumulativePoints: [EquityPoint] {
        var cum = 0.0
        return sellTrades.map { trade in
            cum += trade.profit ?? 0
            return EquityPoint(date: trade.executedAt, value: cum)
        }
    }

    private var monthlyPnL: [MonthlyPnL] {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM"
        let disp = DateFormatter(); disp.dateFormat = "yy.MM"
        var dict: [String: (profit: Double, date: Date)] = [:]
        for t in sellTrades {
            let key = fmt.string(from: t.executedAt)
            dict[key] = ((dict[key]?.profit ?? 0) + (t.profit ?? 0), t.executedAt)
        }
        return dict.map { _, v in MonthlyPnL(label: disp.string(from: v.date), profit: v.profit, sortDate: v.date) }
            .sorted { $0.sortDate < $1.sortDate }
    }

    private var strategyStats: [StrategyStats] {
        var dict: [String: (wins: Int, total: Int, profit: Double)] = [:]
        for t in sellTrades {
            let name = t.strategyName.isEmpty ? "미분류" : t.strategyName
            var s = dict[name] ?? (0, 0, 0)
            s.total += 1
            if (t.profit ?? 0) > 0 { s.wins += 1 }
            s.profit += t.profit ?? 0
            dict[name] = s
        }
        return dict.map { name, s in StrategyStats(name: name, totalTrades: s.total, winCount: s.wins, totalProfit: s.profit) }
            .sorted { $0.totalProfit > $1.totalProfit }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if sellTrades.isEmpty {
                    ContentUnavailableView(
                        "거래 내역 없음",
                        systemImage: "chart.bar.xaxis",
                        description: Text("자동매매 체결 후 성과 데이터가 표시됩니다")
                    )
                    .padding(.top, 60)
                } else {
                    summarySection
                    if cumulativePoints.count >= 2 { equityCurveSection }
                    if !monthlyPnL.isEmpty { monthlySection }
                    if !strategyStats.isEmpty { strategySection }
                    tradeHistorySection
                }
            }
            .padding()
        }
        .navigationTitle("성과 분석")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - Summary Cards

    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("전체 성과")
                    .font(.headline)
                Spacer()
                Text("체결 \(sellTrades.count)건 (승 \(winTrades.count) / 패 \(lossTrades.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCard(title: "총 실현 손익", value: signedProfit(totalProfit), tint: totalProfit >= 0 ? .green : .red)
                statCard(title: "승률", value: String(format: "%.1f%%", winRate), tint: winRate >= 50 ? .green : .orange)
                statCard(title: "손익비 (Profit Factor)", value: String(format: "%.2f", profitFactor), tint: profitFactor >= 1 ? .green : .orange)
                statCard(title: "평균 수익 / 손실", value: String(format: "+%.1f%% / -%.1f%%", avgWinPct, avgLossPct), tint: .primary)
            }
        }
    }

    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Equity Curve

    private var equityCurveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("누적 손익 커브")
                .font(.headline)

            Chart(cumulativePoints) { point in
                LineMark(x: .value("날짜", point.date), y: .value("손익", point.value))
                    .foregroundStyle(totalProfit >= 0 ? Color.green : Color.red)
                AreaMark(x: .value("날짜", point.date), y: .value("손익", point.value))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [totalProfit >= 0 ? .green.opacity(0.25) : .red.opacity(0.25), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Monthly P&L

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("월별 손익")
                .font(.headline)

            Chart(monthlyPnL) { item in
                BarMark(x: .value("월", item.label), y: .value("손익", item.profit))
                    .foregroundStyle(item.profit >= 0 ? Color.green.gradient : Color.red.gradient)
                    .cornerRadius(4)
            }
            .frame(height: 140)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Strategy Comparison

    private var strategySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("전략별 성과")
                .font(.headline)

            HStack {
                Text("전략").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text("건수").font(.caption).foregroundStyle(.secondary).frame(width: 36)
                Text("승률").font(.caption).foregroundStyle(.secondary).frame(width: 48)
                Text("손익").font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
            }

            Divider()

            ForEach(strategyStats) { stat in
                HStack {
                    Text(stat.name)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    Text("\(stat.totalTrades)")
                        .font(.caption).foregroundStyle(.secondary).frame(width: 36)
                    Text(String(format: "%.0f%%", stat.winRate))
                        .font(.caption)
                        .foregroundStyle(stat.winRate >= 50 ? .green : .secondary)
                        .frame(width: 48)
                    Text(signedProfit(stat.totalProfit))
                        .font(.caption.bold())
                        .foregroundStyle(stat.totalProfit >= 0 ? .green : .red)
                        .frame(width: 80, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Trade History

    private var tradeHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("전체 거래 내역")
                .font(.headline)

            ForEach(allTrades.reversed()) { trade in
                HStack(spacing: 10) {
                    Text(trade.type == .buy ? "매수" : "매도")
                        .font(.caption.bold())
                        .foregroundStyle(trade.type == .buy ? .blue : .red)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(trade.symbol)
                            .font(.subheadline.bold())
                        Text(trade.strategyName.isEmpty
                             ? trade.executedAt.formatted(date: .abbreviated, time: .shortened)
                             : trade.strategyName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(trade.currency.symbol)\(Int(trade.price))")
                            .font(.subheadline)
                        if let profit = trade.profit {
                            Text(profit >= 0
                                 ? String(format: "+%@%d", trade.currency.symbol, Int(profit))
                                 : String(format: "%@%d", trade.currency.symbol, Int(profit)))
                                .font(.caption.bold())
                                .foregroundStyle(profit >= 0 ? .green : .red)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Helpers

    private func signedProfit(_ profit: Double) -> String {
        profit >= 0 ? "+\(Int(profit))" : "\(Int(profit))"
    }
}
