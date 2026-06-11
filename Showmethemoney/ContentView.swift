import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("홈", systemImage: "chart.line.uptrend.xyaxis") }

            WatchlistView()
                .tabItem { Label("관심종목", systemImage: "list.star") }

            StrategyListView()
                .tabItem { Label("전략", systemImage: "chart.bar.doc.horizontal") }

            TradingView()
                .tabItem { Label("자동매매", systemImage: "bolt.fill") }

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
    }
}
