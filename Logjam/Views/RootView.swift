import SwiftUI

struct RootView: View {
    @StateObject private var filterRequest = LibraryFilterRequest()

    var body: some View {
        TabView(selection: $filterRequest.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            LibraryView()
                .tabItem { Label("Library", systemImage: "square.stack") }
                .tag(AppTab.library)
            DiaryView()
                .tabItem { Label("Diary", systemImage: "book.closed") }
                .tag(AppTab.diary)
            SellQueueView()
                .tabItem { Label("Sell Queue", systemImage: "tag") }
                .tag(AppTab.sellQueue)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(AppTab.stats)
        }
        .tint(LJTheme.accent)
        .preferredColorScheme(.dark)
        .environmentObject(filterRequest)
    }
}
