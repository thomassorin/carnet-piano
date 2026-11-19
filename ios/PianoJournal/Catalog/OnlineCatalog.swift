import Foundation

/// Sources en ligne : Open Opus (répertoire classique), iTunes (albums et chansons), service IA.
enum OnlineCatalog {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private struct FlexibleID: Decodable {
        let value: String
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) { value = s }
            else if let i = try? c.decode(Int.self) { value = String(i) }
            else { value = "" }
        }
    }

    private static func pathComponent(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? text
    }

    // MARK: Open Opus — https://openopus.org (libre, sans clé)

    private struct OpenOpusResponse: Decodable {
        struct Result: Decodable {
            struct Composer: Decodable {
                let name: String?
                let complete_name: String?
                let epoch: String?
            }
            struct Work: Decodable {
                let id: FlexibleID?
                let title: String?
                let subtitle: String?
                let genre: String?
            }
            let composer: Composer?
            let work: Work?
        }
        let results: [Result]?
    }

    private static func period(fromEpoch epoch: String?) -> Period? {
        switch epoch {
        case "Medieval", "Renaissance", "Baroque": return .baroque
        case "Classical": return .classique
        case "Early Romantic", "Romantic", "Late Romantic": return .romantique
        case "20th Century": return .moderne
        case "Post-War", "21st Century": return .contemporain
        default: return nil
        }
    }

    static func searchClassical(_ query: String) async -> [CatalogItem] {
        guard let url = URL(string: "https://api.openopus.org/omnisearch/\(pathComponent(query))/0.json"),
              let (data, _) = try? await session.data(from: url),
              let decoded = try? JSONDecoder().decode(OpenOpusResponse.self, from: data) else { return [] }
        var seen = Set<String>()
        var keyboard: [CatalogItem] = []
        var others: [CatalogItem] = []
        for result in decoded.results ?? [] {
            guard let work = result.work, let title = work.title, let id = work.id?.value, !id.isEmpty,
                  seen.insert(id).inserted else { continue }
            let fullTitle = (work.subtitle?.isEmpty == false) ? "\(title) — \(work.subtitle!)" : title
            var item = CatalogItem(id: "oo-\(id)", title: fullTitle,
                                   composer: result.composer?.complete_name ?? result.composer?.name ?? "",
                                   kind: .piece, period: period(fromEpoch: result.composer?.epoch))
            item.source = .openOpus
            if work.genre == "Keyboard" {
                item.genre = String(localized: "Clavier")
                keyboard.append(item)
            } else {
                item.genre = work.genre
                others.append(item)
            }
        }
        return Array((keyboard + others).prefix(40))
    }

    // MARK: iTunes Search — albums (≈ recueils) et morceaux

    private struct ITunesResponse: Decodable {
        struct Result: Decodable {
            let wrapperType: String?
            let collectionId: Int?
            let collectionName: String?
            let trackId: Int?
            let trackName: String?
            let artistName: String?
            let trackCount: Int?
            let trackNumber: Int?
            let discNumber: Int?
        }
        let results: [Result]
    }

    private static func itunes(_ path: String, _ items: [URLQueryItem]) async -> [ITunesResponse.Result] {
        var components = URLComponents(string: "https://itunes.apple.com/\(path)")!
        components.queryItems = items + [URLQueryItem(name: "country", value: Locale.current.region?.identifier ?? "FR")]
        guard let url = components.url,
              let (data, _) = try? await session.data(from: url),
              let decoded = try? JSONDecoder().decode(ITunesResponse.self, from: data) else { return [] }
        return decoded.results
    }

    static func searchSongs(_ query: String) async -> [CatalogItem] {
        async let songResults = itunes("search", [.init(name: "term", value: query), .init(name: "media", value: "music"),
                                                  .init(name: "entity", value: "song"), .init(name: "limit", value: "12")])
        async let albumResults = itunes("search", [.init(name: "term", value: query), .init(name: "media", value: "music"),
                                                   .init(name: "entity", value: "album"), .init(name: "limit", value: "8")])
        var seen = Set<String>()
        var items: [CatalogItem] = []
        for r in await albumResults {
            guard let id = r.collectionId, let name = r.collectionName, (r.trackCount ?? 0) > 1 else { continue }
            var item = CatalogItem(id: "it-a-\(id)", title: name, composer: r.artistName ?? "", kind: .collection, period: .populaire)
            item.source = .itunes
            item.remoteID = String(id)
            item.genre = String(localized: "Album")
            items.append(item)
        }
        for r in await songResults {
            guard let id = r.trackId, let name = r.trackName else { continue }
            let key = Fmt.normalized(name + " " + (r.artistName ?? ""))
            guard seen.insert(key).inserted else { continue }
            var item = CatalogItem(id: "it-s-\(id)", title: name, composer: r.artistName ?? "", kind: .piece, period: .populaire)
            item.source = .itunes
            items.append(item)
        }
        return items
    }

    static func albumTracks(_ collectionID: String) async -> [String] {
        let results = await itunes("lookup", [.init(name: "id", value: collectionID), .init(name: "entity", value: "song"),
                                              .init(name: "limit", value: "200")])
        return results
            .filter { $0.wrapperType == "track" && $0.trackName != nil }
            .sorted { ($0.discNumber ?? 1, $0.trackNumber ?? 0) < ($1.discNumber ?? 1, $1.trackNumber ?? 0) }
            .compactMap(\.trackName)
    }

    // MARK: Recherche IA (service du dossier backend/)

    static var isAIAvailable: Bool { !Config.aiEndpoint.isEmpty }

    enum AIError: LocalizedError {
        case unavailable, server
        var errorDescription: String? {
            switch self {
            case .unavailable: return String(localized: "La recherche IA n'est pas disponible.")
            case .server: return String(localized: "La recherche IA n'a pas répondu. Réessayez dans un instant.")
            }
        }
    }

    private struct AIResponse: Decodable {
        struct Item: Decodable {
            let title: String
            let composer: String?
            let kind: String?
            let period: String?
            let level: Int?
            let genre: String?
            let pieces: [String]?
        }
        let items: [Item]
    }

    /// `mode` : "search" (trouver des partitions) ou "expand" (lister le contenu d'un recueil).
    static func askAI(_ query: String, mode: String = "search") async throws -> [CatalogItem] {
        guard isAIAvailable, let url = URL(string: Config.aiEndpoint) else { throw AIError.unavailable }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.aiAppKey, forHTTPHeaderField: "X-App-Key")
        let lang = Locale.current.language.languageCode?.identifier ?? "fr"
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query, "mode": mode, "lang": lang])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(AIResponse.self, from: data) else { throw AIError.server }
        return decoded.items.enumerated().map { index, raw in
            var item = CatalogItem(id: "ai-\(Fmt.normalized(raw.title + " " + (raw.composer ?? "")).replacingOccurrences(of: " ", with: "-"))-\(index)",
                                   title: raw.title, composer: raw.composer ?? "",
                                   kind: ScoreKind(rawValue: raw.kind ?? "") ?? ((raw.pieces?.isEmpty == false) ? .collection : .piece),
                                   period: raw.period.flatMap(Period.init(rawValue:)),
                                   level: raw.level.flatMap { (1...5).contains($0) ? $0 : nil },
                                   genre: raw.genre,
                                   pieces: (raw.pieces?.isEmpty == false) ? raw.pieces : nil)
            item.source = .ai
            return item
        }
    }

    static func expandWithAI(title: String, composer: String) async throws -> [String] {
        let items = try await askAI("\(title) — \(composer)", mode: "expand")
        return items.first?.pieces ?? []
    }
}
