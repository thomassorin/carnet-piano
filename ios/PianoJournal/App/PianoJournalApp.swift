import SwiftUI
import SwiftData

@main
struct PianoJournalApp: App {
    @State private var router = AppRouter()
    @State private var timer = PracticeTimer()
    @State private var metronome = Metronome()
    @State private var catalog = CatalogStore()
    @State private var store = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(timer)
                .environment(metronome)
                .environment(catalog)
                .environment(store)
        }
        .modelContainer(for: [Score.self, PracticeSession.self])
    }
}

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PracticeTimer.self) private var timer
    @Environment(Metronome.self) private var metronome
    @Environment(CatalogStore.self) private var catalog
    @Environment(SubscriptionManager.self) private var store
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            TodayView()
                .tabItem { Label("Aujourd'hui", systemImage: "flame") }
                .tag(AppRouter.Tab.today)
            LibraryView()
                .tabItem { Label("Partitions", systemImage: "music.note.list") }
                .tag(AppRouter.Tab.library)
            CatalogView()
                .tabItem { Label("Catalogue", systemImage: "magnifyingglass") }
                .tag(AppRouter.Tab.catalog)
            TrackingView()
                .tabItem { Label("Suivi", systemImage: "chart.bar.xaxis") }
                .tag(AppRouter.Tab.tracking)
        }
        .fullScreenCover(isPresented: $router.showTimer) {
            TimerView()
                .environment(router)
                .environment(timer)
                .environment(metronome)
        }
        .sheet(isPresented: $router.showPaywall) {
            PaywallView()
                .environment(store)
        }
        #if DEBUG
        .task { DebugLaunch.apply(router: router, timer: timer, catalog: catalog, context: context) }
        #endif
    }
}
