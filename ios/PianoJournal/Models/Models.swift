import Foundation
import SwiftData

enum ScoreKind: String, Codable, CaseIterable, Identifiable {
    case piece, collection, method
    var id: String { rawValue }

    var label: String {
        switch self {
        case .piece: return String(localized: "Pièce")
        case .collection: return String(localized: "Recueil")
        case .method: return String(localized: "Méthode")
        }
    }

    var pluralLabel: String {
        switch self {
        case .piece: return String(localized: "Pièces")
        case .collection: return String(localized: "Recueils")
        case .method: return String(localized: "Méthodes")
        }
    }

    var icon: String {
        switch self {
        case .piece: return "music.note"
        case .collection: return "book.closed"
        case .method: return "graduationcap"
        }
    }
}

enum Period: String, Codable, CaseIterable, Identifiable {
    case baroque, classique, romantique, moderne, contemporain, populaire
    var id: String { rawValue }

    var label: String {
        switch self {
        case .baroque: return String(localized: "Baroque")
        case .classique: return String(localized: "Classique")
        case .romantique: return String(localized: "Romantique")
        case .moderne: return String(localized: "Moderne (XXe)")
        case .contemporain: return String(localized: "Contemporain et film")
        case .populaire: return String(localized: "Chanson, pop, jazz")
        }
    }
}

enum Level {
    static let all = [1, 2, 3, 4, 5]
    static func label(_ level: Int) -> String {
        switch level {
        case 1: return String(localized: "Débutant")
        case 2: return String(localized: "Élémentaire")
        case 3: return String(localized: "Intermédiaire")
        case 4: return String(localized: "Avancé")
        case 5: return String(localized: "Virtuose")
        default: return ""
        }
    }
}

/// Une partition de la bibliothèque : une pièce, ou un recueil / une méthode contenant des pièces.
@Model
final class Score {
    var uuid: UUID = UUID()
    var title: String = ""
    var composer: String = ""
    var kindRaw: String = ScoreKind.piece.rawValue
    var catalogID: String?
    var periodRaw: String?
    var genre: String?
    var level: Int = 0
    var order: Int = 0
    var isDone: Bool = false
    var doneAt: Date?
    var rating: Int = 0
    var notes: String = ""
    var targetTempo: Int = 0
    var addedAt: Date = Date()

    var parent: Score?
    @Relationship(deleteRule: .cascade, inverse: \Score.parent) var children: [Score] = []
    @Relationship(deleteRule: .cascade, inverse: \PracticeSession.score) var sessions: [PracticeSession] = []

    init(title: String, composer: String = "", kind: ScoreKind = .piece) {
        self.title = title
        self.composer = composer
        self.kindRaw = kind.rawValue
    }

    var kind: ScoreKind {
        get { ScoreKind(rawValue: kindRaw) ?? .piece }
        set { kindRaw = newValue.rawValue }
    }

    var period: Period? { periodRaw.flatMap(Period.init(rawValue:)) }

    /// Vrai pour un recueil, une méthode, ou toute partition découpée en sous-parties.
    var isContainer: Bool { kind != .piece || !children.isEmpty }

    var sortedChildren: [Score] { children.sorted { $0.order < $1.order } }

    var displayComposer: String { composer.isEmpty ? (parent?.composer ?? "") : composer }

    var ownSeconds: Int { sessions.reduce(0) { $0 + $1.seconds } }

    /// Temps passé sur la partition, sous-parties comprises.
    var totalSeconds: Int { ownSeconds + children.reduce(0) { $0 + $1.ownSeconds } }

    var allSessions: [PracticeSession] {
        (sessions + children.flatMap(\.sessions)).sorted { $0.startedAt > $1.startedAt }
    }

    var lastPracticed: Date? { allSessions.first?.startedAt }

    var doneCount: Int { children.filter(\.isDone).count }

    var progress: Double {
        if children.isEmpty { return isDone ? 1 : 0 }
        return Double(doneCount) / Double(children.count)
    }

    func setDone(_ done: Bool) {
        isDone = done
        doneAt = done ? Date() : nil
        if let parent, !parent.children.isEmpty {
            let allDone = parent.children.allSatisfy(\.isDone)
            if parent.isDone != allDone {
                parent.isDone = allDone
                parent.doneAt = allDone ? Date() : nil
            }
        }
    }
}

/// Une séance de travail chronométrée (ou saisie à la main).
@Model
final class PracticeSession {
    var uuid: UUID = UUID()
    var startedAt: Date = Date()
    var seconds: Int = 0
    var note: String = ""
    var tempo: Int = 0
    var score: Score?

    init(startedAt: Date, seconds: Int, note: String = "", tempo: Int = 0, score: Score? = nil) {
        self.startedAt = startedAt
        self.seconds = seconds
        self.note = note
        self.tempo = tempo
        self.score = score
    }

    /// « Recueil — Pièce » ou « Pratique libre »
    var label: String {
        guard let score else { return String(localized: "Pratique libre") }
        if let parent = score.parent { return "\(score.title) · \(parent.title)" }
        return score.title
    }
}

extension ModelContext {
    func score(uuid: UUID) -> Score? {
        var descriptor = FetchDescriptor<Score>(predicate: #Predicate { $0.uuid == uuid })
        descriptor.fetchLimit = 1
        return try? fetch(descriptor).first
    }
}

/// Statistiques calculées à partir des séances.
struct PracticeStats {
    let dayTotals: [Date: Int]
    let totalSeconds: Int
    let sessionCount: Int
    let currentStreak: Int
    let longestStreak: Int
    let todaySeconds: Int

    init(sessions: [PracticeSession], calendar: Calendar = .current, now: Date = Date()) {
        var totals: [Date: Int] = [:]
        var total = 0
        for s in sessions {
            totals[calendar.startOfDay(for: s.startedAt), default: 0] += s.seconds
            total += s.seconds
        }
        dayTotals = totals
        totalSeconds = total
        sessionCount = sessions.count

        let today = calendar.startOfDay(for: now)
        todaySeconds = totals[today] ?? 0

        // Série en cours : aujourd'hui, ou hier si rien n'a encore été joué aujourd'hui.
        var streak = 0
        var cursor = today
        if totals[cursor] == nil, let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = yesterday
        }
        while totals[cursor] != nil {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        currentStreak = streak

        var longest = 0, run = 0
        var previousDay: Date?
        for day in totals.keys.sorted() {
            if let p = previousDay, let next = calendar.date(byAdding: .day, value: 1, to: p), calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previousDay = day
        }
        longestStreak = longest
    }

    func seconds(on day: Date, calendar: Calendar = .current) -> Int {
        dayTotals[calendar.startOfDay(for: day)] ?? 0
    }
}
