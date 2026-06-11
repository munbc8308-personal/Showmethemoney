import SwiftUI
import Charts

struct StockDetailView: View {
    let stock: Stock

    @State private var price: StockPrice?
    @State private var bars: [OHLCV] = []
    @State private var selectedPeriod: ChartPeriod = .oneMonth
    @State private var isLoadingPrice = false
    @State private var isLoadingChart = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                priceHeader
                chartSection
                statsSection
            }
            .padding()
        }
        .navigationTitle(stock.symbol)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadAll() }
        .onChange(of: selectedPeriod) { _, _ in
            Task { await loadChart() }
        }
    }

    // MARK: - Price Header

    private var priceHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stock.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isLoadingPrice {
                ProgressView()
                    .frame(height: 44)
            } else if let price {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(price.currency.symbol)\(price.price, specifier: "%.0f")")
                        .font(.system(size: 36, weight: .bold))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: price.isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.caption2)
                            Text(String(format: "%.0f", abs(price.changeAmount)))
                                .font(.subheadline)
                        }
                        Text(String(format: "%.2f%%", abs(price.changeRate)))
                            .font(.caption.bold())
                    }
                    .foregroundStyle(price.isPositive ? .red : .blue)
                }
            } else if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text(stock.market.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.blue.opacity(0.15), in: Capsule())
                .foregroundStyle(.blue)
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("기간", selection: $selectedPeriod) {
                ForEach(ChartPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if isLoadingChart {
                ProgressView("차트 불러오는 중...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if bars.isEmpty {
                ContentUnavailableView(
                    "차트 없음",
                    systemImage: "chart.line.flattrend.xyaxis",
                    description: Text("API 키를 설정하면 차트를 볼 수 있어요")
                )
                .frame(minHeight: 200)
            } else {
                lineChart
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var lineChart: some View {
        let minPrice = bars.map(\.low).min() ?? 0
        let maxPrice = bars.map(\.high).max() ?? 0
        let isUp = (bars.last?.close ?? 0) >= (bars.first?.close ?? 0)

        return Chart(bars) { bar in
            LineMark(
                x: .value("날짜", bar.date),
                y: .value("종가", bar.close)
            )
            .foregroundStyle(isUp ? .red : .blue)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("날짜", bar.date),
                yStart: .value("최저", minPrice),
                yEnd: .value("종가", bar.close)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [isUp ? .red.opacity(0.2) : .blue.opacity(0.2), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartYScale(domain: minPrice * 0.99 ... maxPrice * 1.01)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 200)
    }

    // MARK: - Stats

    private var statsSection: some View {
        let recentBars = bars.suffix(5)
        let high52 = bars.map(\.high).max()
        let low52 = bars.map(\.low).min()
        let avgVolume = bars.isEmpty ? 0 : bars.map(\.volume).reduce(0, +) / bars.count

        return VStack(alignment: .leading, spacing: 8) {
            Text("통계")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let high = high52 {
                    statCard(title: "기간 최고가", value: "\(stock.currency.symbol)\(String(format: "%.0f", high))")
                }
                if let low = low52 {
                    statCard(title: "기간 최저가", value: "\(stock.currency.symbol)\(String(format: "%.0f", low))")
                }
                statCard(title: "평균 거래량", value: formatVolume(avgVolume))
                if let lastBar = recentBars.last {
                    statCard(title: "거래량", value: formatVolume(lastBar.volume))
                }
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Data Loading

    private func loadAll() async {
        async let priceTask: Void = loadPrice()
        async let chartTask: Void = loadChart()
        _ = await (priceTask, chartTask)
    }

    private func loadPrice() async {
        isLoadingPrice = true
        errorMessage = nil
        defer { isLoadingPrice = false }
        do {
            if stock.market.isKorean {
                price = try await KISAPIClient.shared.fetchStockPrice(symbol: stock.symbol)
            } else {
                price = try await AlpacaAPIClient.shared.fetchStockPrice(symbol: stock.symbol)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadChart() async {
        isLoadingChart = true
        defer { isLoadingChart = false }
        do {
            if stock.market.isKorean {
                bars = try await KISAPIClient.shared.fetchDailyBars(symbol: stock.symbol, period: selectedPeriod)
            } else {
                bars = try await AlpacaAPIClient.shared.fetchDailyBars(symbol: stock.symbol, period: selectedPeriod)
            }
        } catch {
            bars = []
        }
    }

    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", Double(volume) / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.0fK", Double(volume) / 1_000)
        }
        return "\(volume)"
    }
}
