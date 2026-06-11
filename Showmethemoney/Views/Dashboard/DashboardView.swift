import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var holdings: [Holding]
    @Query(sort: \Trade.executedAt, order: .reverse) private var recentTrades: [Trade]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    portfolioSummarySection
                    holdingsSection
                    recentTradesSection
                }
                .padding()
            }
            .navigationTitle("홈")
        }
    }

    private var portfolioSummarySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("포트폴리오")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 16) {
                summaryCard(title: "국내", broker: .kis)
                summaryCard(title: "해외", broker: .alpaca)
            }
        }
    }

    private func summaryCard(title: String, broker: Broker) -> some View {
        let brokerHoldings = holdings.filter { $0.broker == broker }
        let totalCost = brokerHoldings.reduce(0) { $0 + $1.totalCost }
        let currency = broker == .kis ? Currency.krw : .usd

        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(currency.symbol)\(totalCost, specifier: "%.0f")")
                .font(.title3.bold())
            Text("\(brokerHoldings.count)개 종목")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var holdingsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("보유 종목")
                    .font(.headline)
                Spacer()
                Text("\(holdings.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if holdings.isEmpty {
                emptyStateView(message: "보유 종목이 없습니다")
            } else {
                ForEach(holdings) { holding in
                    holdingRow(holding)
                }
            }
        }
    }

    private func holdingRow(_ holding: Holding) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol)
                    .font(.subheadline.bold())
                Text(holding.stockName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(holding.currency.symbol)\(holding.averageCost, specifier: "%.0f")")
                    .font(.subheadline)
                Text("\(holding.quantity)주")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var recentTradesSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("최근 체결")
                    .font(.headline)
                Spacer()
            }

            let trades = Array(recentTrades.prefix(5))
            if trades.isEmpty {
                emptyStateView(message: "체결 내역이 없습니다")
            } else {
                ForEach(trades) { trade in
                    tradeRow(trade)
                }
            }
        }
    }

    private func tradeRow(_ trade: Trade) -> some View {
        HStack {
            Text(trade.type == .buy ? "매수" : "매도")
                .font(.caption.bold())
                .foregroundStyle(trade.type == .buy ? .blue : .red)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(trade.symbol)
                    .font(.subheadline.bold())
                Text(trade.strategyName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(trade.currency.symbol)\(trade.price, specifier: "%.0f")")
                    .font(.subheadline)
                Text("\(trade.quantity)주")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func emptyStateView(message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
