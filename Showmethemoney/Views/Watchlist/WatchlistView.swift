import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Stock.addedAt, order: .reverse) private var stocks: [Stock]
    @State private var prices: [String: StockPrice] = [:]
    @State private var isRefreshing = false
    @State private var showAddStock = false

    var body: some View {
        NavigationStack {
            List {
                if stocks.isEmpty {
                    ContentUnavailableView(
                        "관심종목 없음",
                        systemImage: "list.star",
                        description: Text("+ 버튼을 눌러 종목을 추가하세요")
                    )
                } else {
                    ForEach(stocks) { stock in
                        NavigationLink(destination: StockDetailView(stock: stock)) {
                            stockRow(stock)
                        }
                    }
                    .onDelete(perform: deleteStocks)
                }
            }
            .navigationTitle("관심종목")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddStock = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await refreshAllPrices() }
                    } label: {
                        if isRefreshing {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
            .refreshable { await refreshAllPrices() }
            .sheet(isPresented: $showAddStock) {
                AddStockView()
            }
            .task { await refreshAllPrices() }
        }
    }

    private func stockRow(_ stock: Stock) -> some View {
        let price = prices[stock.symbol]
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(stock.symbol)
                    .font(.subheadline.bold())
                Text(stock.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let price {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(price.currency.symbol)\(price.price, specifier: "%.0f")")
                        .font(.subheadline.bold())
                    HStack(spacing: 2) {
                        Image(systemName: price.isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                        Text(String(format: "%.2f%%", abs(price.changeRate)))
                            .font(.caption)
                    }
                    .foregroundStyle(price.isPositive ? .red : .blue)
                }
            } else {
                ProgressView().scaleEffect(0.7)
            }
        }
        .padding(.vertical, 2)
    }

    private func deleteStocks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(stocks[index])
        }
    }

    private func refreshAllPrices() async {
        guard !stocks.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: (String, StockPrice?).self) { group in
            for stock in stocks {
                let symbol = stock.symbol
                let isKorean = stock.market.isKorean
                group.addTask {
                    do {
                        let price: StockPrice
                        if isKorean {
                            price = try await KISAPIClient.shared.fetchStockPrice(symbol: symbol)
                        } else {
                            price = try await AlpacaAPIClient.shared.fetchStockPrice(symbol: symbol)
                        }
                        return (symbol, price)
                    } catch {
                        return (symbol, nil)
                    }
                }
            }
            for await (symbol, price) in group {
                if let price {
                    prices[symbol] = price
                }
            }
        }
    }
}

struct AddStockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var symbol = ""
    @State private var name = ""
    @State private var market: Market = .kospi

    var body: some View {
        NavigationStack {
            Form {
                Section("종목 정보") {
                    TextField("종목 코드 (예: 005930, AAPL)", text: $symbol)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                    TextField("종목명 (예: 삼성전자, Apple)", text: $name)
                        .autocorrectionDisabled()
                    Picker("시장", selection: $market) {
                        ForEach(Market.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                }
            }
            .navigationTitle("종목 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") { addStock() }
                        .disabled(symbol.isEmpty || name.isEmpty)
                }
            }
        }
    }

    private func addStock() {
        let stock = Stock(symbol: symbol.uppercased(), name: name, market: market)
        modelContext.insert(stock)
        dismiss()
    }
}
