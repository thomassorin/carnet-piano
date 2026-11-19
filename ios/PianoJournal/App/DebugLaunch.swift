#if DEBUG
import Foundation
import SwiftData

/// Aides de mise au point (compilation Debug uniquement) : données de démonstration et ouverture
/// directe d'un écran, via des arguments de lancement. Sert aux captures d'écran automatiques.
///   -seedDemo YES · -uiTab library|catalog|tracking · -uiOpen paywall|timer · -uiQuery "texte" · -uiOpenFirst YES
enum DebugLaunch {
    @MainActor
    static func apply(router: AppRouter, timer: PracticeTimer, catalog: CatalogStore, context: ModelContext) {
        let args = UserDefaults.standard
        if args.bool(forKey: "seedDemo") { seed(catalog: catalog, context: context) }
        switch args.string(forKey: "uiTab") {
        case "library": router.tab = .library
        case "catalog": router.tab = .catalog
        case "tracking": router.tab = .tracking
        default: break
        }
        switch args.string(forKey: "uiOpen") {
        case "paywall": router.showPaywall = true
        case "timer":
            let scores = (try? context.fetch(FetchDescriptor<Score>())) ?? []
            router.practice(scores.first { $0.parent != nil && !$0.isDone } ?? scores.first, timer: timer)
        default: break
        }
    }

    @MainActor
    private static func seed(catalog: CatalogStore, context: ModelContext) {
        guard ((try? context.fetchCount(FetchDescriptor<Score>())) ?? 0) == 0 else { return }
        let calendar = Calendar.current
        func add(_ query: String) -> Score? {
            guard let item = catalog.search(query, filter: CatalogFilter()).first else { return nil }
            return Library.add(item, pieces: item.pieces ?? [], to: context)
        }
        func session(_ score: Score?, daysAgo: Int, minutes: Int, note: String = "", tempo: Int = 0) {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date().addingTimeInterval(-3600)) ?? Date()
            context.insert(PracticeSession(startedAt: date, seconds: minutes * 60, note: note, tempo: tempo, score: score))
        }
        if let burgmuller = add("Burgmüller études faciles op. 100") {
            let pieces = burgmuller.sortedChildren
            for (index, piece) in pieces.prefix(4).enumerated() {
                piece.setDone(true)
                piece.rating = [5, 4, 4, 3][index]
            }
            session(pieces[0], daysAgo: 8, minutes: 20)
            session(pieces[1], daysAgo: 6, minutes: 25, note: "Main gauche plus légère, bien lier les doubles croches.", tempo: 96)
            session(pieces[2], daysAgo: 5, minutes: 15)
            session(pieces[3], daysAgo: 3, minutes: 30)
            session(pieces[4], daysAgo: 1, minutes: 22, note: "Mesures 9 à 16 à reprendre lentement.", tempo: 72)
            session(pieces[4], daysAgo: 0, minutes: 12)
            pieces[4].rating = 3
        }
        if let anna = add("Petit livre d'Anna Magdalena") {
            let pieces = anna.sortedChildren
            pieces[1].setDone(true)
            pieces[1].rating = 5
            session(pieces[1], daysAgo: 4, minutes: 18)
            session(pieces[2], daysAgo: 2, minutes: 20, tempo: 88)
        }
        if let satie = add("Satie Gymnopédies") {
            session(satie.sortedChildren.first, daysAgo: 7, minutes: 35)
            session(satie.sortedChildren.first, daysAgo: 2, minutes: 16)
        }
        session(nil, daysAgo: 0, minutes: 6, note: "Gammes de do et sol.")
        try? context.save()
    }
}
#endif
