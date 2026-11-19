import Foundation
import Observation
import SwiftData

/// Une entrée du catalogue (embarqué, en ligne ou proposée par l'IA).
struct CatalogItem: Codable, Identifiable, Hashable {
    enum Source: String, Codable { case bundled, openOpus, itunes, ai }

    var id: String
    var title: String
    var composer: String
    var kind: ScoreKind
    var period: Period?
    var level: Int?
    var genre: String?
    var pieces: [String]?
    var source: Source = .bundled
    /// Identifiant distant (ex. album iTunes) pour charger le contenu à la demande.
    var remoteID: String? = nil

    private enum CodingKeys: String, CodingKey {
        case id, title, composer, kind, period, level, genre, pieces
    }

    var pieceCount: Int { pieces?.count ?? 0 }

    var subtitle: String {
        var parts: [String] = []
        if !composer.isEmpty { parts.append(composer) }
        if pieceCount > 0 { parts.append(String(localized: "\(pieceCount) pièces")) }
        if let level, level > 0 { parts.append(Level.label(level)) }
        return parts.joined(separator: " · ")
    }
}

struct CatalogFilter: Equatable {
    var kind: ScoreKind?
    var level: Int?
    var period: Period?
    var composer: String?

    var isEmpty: Bool { kind == nil && level == nil && period == nil && composer == nil }

    /// `strict` : exige que l'attribut soit connu (catalogue embarqué). Sinon les attributs inconnus passent.
    func matches(_ item: CatalogItem, strict: Bool = true) -> Bool {
        if let kind, item.kind != kind { return false }
        if let level {
            if let l = item.level { if l != level { return false } } else if strict { return false }
        }
        if let period {
            if let p = item.period { if p != period { return false } } else if strict { return false }
        }
        if let composer, strict, item.composer != composer { return false }
        return true
    }
}

struct ComposerInfo: Identifiable, Hashable {
    let name: String
    let count: Int
    var id: String { name }
    var sortKey: String { Fmt.normalized(name.split(separator: " ").last.map(String.init) ?? name) }
}

/// Catalogue embarqué : disponible hors ligne, recherche instantanée.
@Observable
final class CatalogStore {
    private struct Entry {
        let item: CatalogItem
        let head: String   // titre + compositeur + genre
        let body: String   // titres des pièces
    }

    private var entries: [Entry] = []
    private(set) var composers: [ComposerInfo] = []
    private(set) var itemCount = 0
    private(set) var pieceCount = 0

    init() {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([CatalogItem].self, from: data) else { return }
        entries = items.map { item in
            Entry(item: item,
                  head: Fmt.normalized([item.title, item.composer, item.genre ?? "", item.kind.label].joined(separator: " ")),
                  body: Fmt.normalized((item.pieces ?? []).joined(separator: " ")))
        }
        itemCount = items.count
        pieceCount = items.reduce(0) { $0 + $1.pieceCount }
        var counts: [String: Int] = [:]
        for item in items where item.composer != "Divers compositeurs" { counts[item.composer, default: 0] += 1 }
        composers = counts.map { ComposerInfo(name: $0.key, count: $0.value) }.sorted { $0.sortKey < $1.sortKey }
    }

    var topComposers: [ComposerInfo] {
        Array(composers.sorted { ($0.count, $1.sortKey) > ($1.count, $0.sortKey) }.prefix(12))
    }

    var starters: [CatalogItem] {
        Array(entries.map(\.item).filter { $0.kind != .piece && ($0.level ?? 9) <= 2 }.prefix(10))
    }

    func search(_ query: String, filter: CatalogFilter) -> [CatalogItem] {
        let tokens = Fmt.normalized(query).split(separator: " ").map(String.init)
        var ranked: [(rank: Int, index: Int, item: CatalogItem)] = []
        for (index, entry) in entries.enumerated() where filter.matches(entry.item) {
            if tokens.isEmpty {
                ranked.append((1, index, entry.item))
                continue
            }
            if tokens.allSatisfy({ entry.head.contains($0) }) {
                let title = Fmt.normalized(entry.item.title)
                ranked.append((title.hasPrefix(tokens[0]) ? 0 : 1, index, entry.item))
            } else if tokens.allSatisfy({ entry.head.contains($0) || entry.body.contains($0) }) {
                ranked.append((2, index, entry.item))
            }
        }
        return ranked.sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }.map(\.item)
    }

    /// Pièces d'un recueil qui correspondent à la recherche (pour montrer « où » se trouve le résultat).
    func matchingPieces(in item: CatalogItem, query: String) -> [String] {
        let tokens = Fmt.normalized(query).split(separator: " ").map(String.init)
        guard !tokens.isEmpty, let pieces = item.pieces else { return [] }
        return pieces.filter { piece in
            let n = Fmt.normalized(piece)
            return tokens.contains { $0.count > 2 && n.contains($0) }
        }
    }
}

/// Ajout d'entrées du catalogue dans la bibliothèque.
enum Library {
    @discardableResult
    static func add(_ item: CatalogItem, pieces: [String], to context: ModelContext) -> Score {
        let score = Score(title: item.title, composer: item.composer, kind: item.kind)
        score.catalogID = item.id
        score.periodRaw = item.period?.rawValue
        score.genre = item.genre
        score.level = item.level ?? 0
        context.insert(score)
        appendPieces(pieces, to: score, context: context)
        return score
    }

    static func appendPieces(_ titles: [String], to score: Score, context: ModelContext) {
        var order = (score.children.map(\.order).max() ?? -1) + 1
        for title in titles {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let child = Score(title: trimmed, composer: "", kind: .piece)
            child.order = order
            child.level = score.level
            child.parent = score
            context.insert(child)
            order += 1
        }
        if score.kind == .piece, !score.children.isEmpty { score.kind = .collection }
    }
}
