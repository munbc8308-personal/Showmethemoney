import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Stock.addedAt, order: .reverse) private var stocks: [Stock]
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
                        stockRow(stock)
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
            }
            .sheet(isPresented: $showAddStock) {
                AddStockView()
            }
        }
    }

    private func stockRow(_ stock: Stock) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(stock.symbol)
                    .font(.subheadline.bold())
                Text(stock.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(stock.market.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.blue.opacity(0.15), in: Capsule())
                .foregroundStyle(.blue)
        }
    }

    private func deleteStocks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(stocks[index])
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
