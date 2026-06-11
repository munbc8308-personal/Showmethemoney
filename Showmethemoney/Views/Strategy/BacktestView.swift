import SwiftUI
import Charts

struct BacktestView: View {
    let strategy: Strategy

    @State private var symbol: String = ""
    @State private var selectedPeriod: BacktestPeriod = .oneYear
    @State private var initialCapital: Double = 10_000_000
    @State private var isRunning = false
    @State private var result: BacktestResult? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                configSection
                if isRunning {
                    ProgressView("백테스팅 실행 중...")
                        .padding(.vertical, 40)
                } else if let result {
                    resultSection(result)
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("백테스팅")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if symbol.isEmpty {
                symbol = strategy.targetSymbols.first ?? ""
            }
        }
    }

    // MARK: - 설정 섹션

    private var configSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("설정")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 10) {
                HStack {
                    Text("종목 코드")
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    TextField("예: 005930, AAPL", text: $symbol)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                HStack {
                    Text("기간")
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    Picker("", selection: $selectedPeriod) {
                        ForEach(BacktestPeriod.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                HStack {
                    Text("초기 자본")
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    TextField("초기 자본", value: $initialCapital, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    Text("원")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }

            Button {
                Task { await runBacktest() }
            } label: {
                Label("백테스팅 실행", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(symbol.isEmpty ? .gray : .blue, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                    .font(.headline)
            }
            .disabled(symbol.isEmpty || isRunning)
        }
    }

    // MARK: - 결과 섹션

    private func resultSection(_ result: BacktestResult) -> some View {
        VStack(spacing: 16) {
            resultHeader(result)
            equityChart(result)
            metricsGrid(result)
            tradeList(result)
        }
    }

    private func resultHeader(_ result: BacktestResult) -> some View {
        let isProfit = result.totalReturn >= 0
        return VStack(spacing: 4) {
            HStack {
                Text("\(result.symbol) · \(result.period.rawValue) 백테스팅")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%+.2f%%", result.totalReturn))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(isProfit ? .red : .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("총 수익률")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("연환산 \(String(format: "%+.1f%%", result.annualizedReturn))")
                        .font(.caption)
                        .foregroundStyle(isProfit ? .red : .blue)
                }
                Spacer()
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func equityChart(_ result: BacktestResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("에퀴티 커브")
                .font(.subheadline.bold())

            if result.equityCurve.isEmpty {
                Text("거래 데이터 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                let isProfit = result.totalReturn >= 0
                Chart(result.equityCurve) { point in
                    LineMark(
                        x: .value("날짜", point.date),
                        y: .value("자산", point.value)
                    )
                    .foregroundStyle(isProfit ? .red : .blue)
                    .interpolationMethod(.catmullRom)

                    RuleMark(y: .value("초기자본", result.initialCapital))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).year())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatCapital(v))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func metricsGrid(_ result: BacktestResult) -> some View {
        let metrics: [(String, String, Bool)] = [
            ("총 수익률", String(format: "%+.2f%%", result.totalReturn), result.totalReturn >= 0),
            ("연환산 수익률", String(format: "%+.1f%%", result.annualizedReturn), result.annualizedReturn >= 0),
            ("샤프 비율", String(format: "%.2f", result.sharpeRatio), result.sharpeRatio >= 1),
            ("최대낙폭(MDD)", String(format: "-%.2f%%", result.mdd), false),
            ("승률", String(format: "%.1f%%", result.winRate), result.winRate >= 50),
            ("손익비", String(format: "%.2f", result.profitFactor), result.profitFactor >= 1),
            ("총 거래수", "\(result.trades.count)회", true),
            ("평균 보유일", String(format: "%.1f일", result.averageHoldDays), true)
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(metrics, id: \.0) { title, value, isPositive in
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.subheadline.bold())
                        .foregroundStyle(title.contains("총 수익") || title.contains("연환산") || title.contains("승률") || title.contains("손익비")
                            ? (isPositive ? .red : .blue) : .primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func tradeList(_ result: BacktestResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("거래 내역")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(result.trades.count)건")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if result.trades.isEmpty {
                Text("조건을 충족하는 거래가 없었습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(result.trades.prefix(20)) { trade in
                    tradeRow(trade)
                }
                if result.trades.count > 20 {
                    Text("... 외 \(result.trades.count - 20)건 더")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func tradeRow(_ trade: BacktestTrade) -> some View {
        let df = DateFormatter()
        df.dateFormat = "MM/dd"

        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(df.string(from: trade.buyDate)) → \(df.string(from: trade.sellDate))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(trade.exitReason.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%+.1f%%", trade.profitPct))
                    .font(.caption.bold())
                    .foregroundStyle(trade.isWin ? .red : .blue)
                Text(String(format: "%+.0f원", trade.profit))
                    .font(.caption2)
                    .foregroundStyle(trade.isWin ? .red : .blue)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 백테스팅 실행

    private func runBacktest() async {
        guard !symbol.isEmpty else { return }
        isRunning = true
        errorMessage = nil
        result = nil

        do {
            let bars: [OHLCV]
            let upperSymbol = symbol.uppercased()
            let isKorean = upperSymbol.allSatisfy { $0.isNumber }

            if isKorean {
                bars = try await KISAPIClient.shared.fetchDailyBars(
                    symbol: upperSymbol,
                    startDate: selectedPeriod.startDate
                )
            } else {
                bars = try await AlpacaAPIClient.shared.fetchDailyBars(
                    symbol: upperSymbol,
                    startDate: selectedPeriod.startDate
                )
            }

            guard !bars.isEmpty else {
                errorMessage = "데이터를 불러오지 못했습니다. API 키를 확인해주세요."
                isRunning = false
                return
            }

            result = BacktestEngine.run(
                strategy: strategy,
                symbol: upperSymbol,
                bars: bars,
                initialCapital: initialCapital
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }

    private func formatCapital(_ value: Double) -> String {
        if value >= 100_000_000 { return String(format: "%.0f억", value / 100_000_000) }
        if value >= 10_000 { return String(format: "%.0f만", value / 10_000) }
        return String(format: "%.0f", value)
    }
}
