import Foundation
import Observation
import AVFoundation
import StoreKit
import UserNotifications

// MARK: - Navigation

@Observable
final class AppRouter {
    enum Tab: Hashable { case today, library, catalog, tracking }
    var tab: Tab = .today
    var showTimer = false
    var showPaywall = false

    /// Démarre (ou rouvre) le minuteur sur une partition.
    func practice(_ score: Score?, timer: PracticeTimer) {
        if timer.phase == .idle {
            timer.start(scoreUUID: score?.uuid,
                        title: score?.title ?? String(localized: "Pratique libre"),
                        subtitle: score.map { $0.parent?.title ?? $0.displayComposer } ?? "")
        }
        showTimer = true
    }
}

// MARK: - Minuteur

/// Minuteur de séance. Basé sur des dates : il continue de compter écran verrouillé ou app fermée.
@Observable
final class PracticeTimer {
    enum Phase: String { case idle, running, paused }

    struct Result: Identifiable {
        let id = UUID()
        let startedAt: Date
        let seconds: Int
        let scoreUUID: UUID?
    }

    private(set) var phase: Phase = .idle
    private(set) var scoreUUID: UUID?
    private(set) var title = ""
    private(set) var subtitle = ""
    private(set) var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private var resumedAt: Date?

    private let defaults = UserDefaults.standard

    init() { restore() }

    func elapsed(at now: Date = Date()) -> TimeInterval {
        accumulated + (resumedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    func start(scoreUUID: UUID?, title: String, subtitle: String) {
        self.scoreUUID = scoreUUID
        self.title = title
        self.subtitle = subtitle
        accumulated = 0
        startedAt = Date()
        resumedAt = Date()
        phase = .running
        persist()
    }

    func pause() {
        guard phase == .running else { return }
        accumulated = elapsed()
        resumedAt = nil
        phase = .paused
        persist()
    }

    func resume() {
        guard phase == .paused else { return }
        resumedAt = Date()
        phase = .running
        persist()
    }

    /// Séance en cours, sans l'arrêter (appeler `reset()` une fois enregistrée ou abandonnée).
    func snapshot() -> Result {
        Result(startedAt: startedAt ?? Date(), seconds: Int(elapsed().rounded()), scoreUUID: scoreUUID)
    }

    func reset() {
        phase = .idle
        scoreUUID = nil
        title = ""
        subtitle = ""
        accumulated = 0
        resumedAt = nil
        startedAt = nil
        persist()
    }

    private func persist() {
        defaults.set(phase.rawValue, forKey: "timer.phase")
        defaults.set(scoreUUID?.uuidString, forKey: "timer.score")
        defaults.set(title, forKey: "timer.title")
        defaults.set(subtitle, forKey: "timer.subtitle")
        defaults.set(accumulated, forKey: "timer.accumulated")
        defaults.set(resumedAt, forKey: "timer.resumedAt")
        defaults.set(startedAt, forKey: "timer.startedAt")
    }

    private func restore() {
        guard let raw = defaults.string(forKey: "timer.phase"), let saved = Phase(rawValue: raw), saved != .idle else { return }
        phase = saved
        scoreUUID = defaults.string(forKey: "timer.score").flatMap(UUID.init(uuidString:))
        title = defaults.string(forKey: "timer.title") ?? ""
        subtitle = defaults.string(forKey: "timer.subtitle") ?? ""
        accumulated = defaults.double(forKey: "timer.accumulated")
        resumedAt = defaults.object(forKey: "timer.resumedAt") as? Date
        startedAt = defaults.object(forKey: "timer.startedAt") as? Date
        // Garde-fou : un minuteur oublié depuis plus de 6 h est mis en pause sur le temps déjà compté.
        if saved == .running, let resumedAt, Date().timeIntervalSince(resumedAt) > 6 * 3600 {
            self.resumedAt = nil
            phase = .paused
            persist()
        }
    }
}

// MARK: - Métronome

@Observable
final class Metronome {
    static let range = 30...240

    private(set) var bpm: Int = UserDefaults.standard.object(forKey: "metronome.bpm") as? Int ?? 80
    private(set) var isPlaying = false

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var player: AVAudioPlayerNode?
    @ObservationIgnored private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    func setBPM(_ value: Int) {
        bpm = min(max(value, Self.range.lowerBound), Self.range.upperBound)
        UserDefaults.standard.set(bpm, forKey: "metronome.bpm")
        if isPlaying { schedule() }
    }

    func toggle() { isPlaying ? stop() : start() }

    func start() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            if engine == nil {
                let engine = AVAudioEngine()
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                self.engine = engine
                self.player = player
            }
            try engine?.start()
            isPlaying = true
            schedule()
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        engine?.stop()
        isPlaying = false
    }

    /// Une mesure d'un temps : un « clic » court suivi de silence, joué en boucle.
    private func schedule() {
        guard let player else { return }
        let frames = AVAudioFrameCount(44_100.0 * 60.0 / Double(bpm))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames
        let clickFrames = min(Int(frames), 1_800)
        for i in 0..<Int(frames) {
            if i < clickFrames {
                let t = Double(i) / 44_100.0
                channel[i] = Float(sin(2 * Double.pi * 1_200 * t) * exp(-t * 90) * 0.9)
            } else {
                channel[i] = 0
            }
        }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
    }
}

// MARK: - Abonnement (StoreKit 2)

@MainActor
@Observable
final class SubscriptionManager {
    private(set) var product: Product?
    private(set) var isPro = false
    private(set) var isPurchasing = false
    var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task { [weak self] in await self?.load() }
    }

    var displayPrice: String { product?.displayPrice ?? Config.fallbackPrice }

    /// Durée de l'essai gratuit proposé par l'App Store, s'il y en a un (ex. « 1 semaine »).
    var trialDescription: String? {
        guard let offer = product?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        let days: Int
        switch period.unit {
        case .day: days = period.value
        case .week: days = period.value * 7
        case .month: days = period.value * 30
        case .year: days = period.value * 365
        @unknown default: days = period.value
        }
        return String(localized: "\(days) jours gratuits")
    }

    func load() async {
        if product == nil {
            product = try? await Product.products(for: [Config.monthlyProductID]).first
        }
        await refresh()
    }

    func refresh() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Config.monthlyProductID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    @discardableResult
    func purchase() async -> Bool {
        if product == nil { await load() }
        guard let product else {
            errorMessage = String(localized: "L'App Store ne répond pas. Vérifiez votre connexion puis réessayez.")
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refresh()
                    return isPro
                }
                errorMessage = String(localized: "L'achat n'a pas pu être vérifié.")
                return false
            case .pending:
                errorMessage = String(localized: "Achat en attente de validation.")
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refresh()
        if !isPro, errorMessage == nil {
            errorMessage = String(localized: "Aucun abonnement actif trouvé pour ce compte.")
        }
    }
}

// MARK: - Rappel quotidien

enum Reminders {
    private static let identifier = "daily-practice"

    /// Programme le rappel quotidien. Renvoie `false` si les notifications sont refusées.
    static func schedule(minutesAfterMidnight: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = String(localized: "C'est l'heure du piano")
        content.body = String(localized: "Cinq minutes suffisent pour garder votre série.")
        content.sound = .default
        var components = DateComponents()
        components.hour = minutesAfterMidnight / 60
        components.minute = minutesAfterMidnight % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
