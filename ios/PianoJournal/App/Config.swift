import Foundation

/// Réglages centraux de l'application. Tout ce qui est susceptible de changer se trouve ici.
enum Config {
    /// Identifiant de l'abonnement mensuel, à créer à l'identique dans App Store Connect.
    static let monthlyProductID = "pianojournal.pro.monthly"
    /// Prix affiché tant que l'App Store n'a pas répondu (le prix réel vient toujours de l'App Store).
    static let fallbackPrice = "2,00 €"
    /// Nombre de partitions (ou recueils) utilisables gratuitement avant l'abonnement.
    static let freeScoreLimit = 3

    /// Adresse du service de recherche IA (dossier `backend/`). Vide = recherche IA masquée.
    static let aiEndpoint = ""
    /// Clé partagée avec le service IA (variable APP_KEY du Worker).
    static let aiAppKey = ""

    static let privacyURL = URL(string: "https://github.com/thomassorin/carnet-piano/blob/ios-app/ios/docs/confidentialite.md")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let supportURL = URL(string: "https://github.com/thomassorin/carnet-piano/issues")!
}

enum Fmt {
    /// « 25 min », « 1 h 05 », « 40 s »
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h) h \(String(format: "%02d", m))" : "\(h) h"
        }
        if m > 0 { return "\(m) min" }
        return seconds > 0 ? "\(seconds) s" : "0 min"
    }

    /// « 12:07 » ou « 1:02:45 »
    static func clock(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    /// Texte simplifié pour la recherche : sans accents, sans ponctuation, en minuscules.
    static func normalized(_ text: String) -> String {
        let folded = text
            .replacingOccurrences(of: "♭", with: "b")
            .replacingOccurrences(of: "♯", with: "#")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
        var out = ""
        out.reserveCapacity(folded.count)
        for ch in folded {
            out.append(ch.isLetter || ch.isNumber || ch == "#" ? ch : " ")
        }
        return out
    }

    static func days(_ count: Int) -> String {
        count == 1 ? String(localized: "1 jour") : String(localized: "\(count) jours")
    }

    static func day(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return String(localized: "Aujourd'hui") }
        if cal.isDateInYesterday(date) { return String(localized: "Hier") }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
