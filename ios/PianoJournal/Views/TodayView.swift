import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PracticeTimer.self) private var timer
    @Query(sort: \PracticeSession.startedAt, order: .reverse) private var sessions: [PracticeSession]
    @Query private var scores: [Score]
    @AppStorage("dailyGoalMinutes") private var dailyGoal = 15

    @State private var showPicker = false
    @State private var showSettings = false
    @State private var pendingStart = false
    @State private var pendingScore: Score?

    private var stats: PracticeStats { PracticeStats(sessions: sessions) }

    /// Dernières partitions travaillées, sans doublon.
    private var recentScores: [Score] {
        var seen = Set<UUID>()
        var result: [Score] = []
        for session in sessions {
            guard let score = session.score, seen.insert(score.uuid).inserted else { continue }
            result.append(score)
            if result.count == 4 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    streakCard
                    goalCard
                    startButton
                    if scores.isEmpty {
                        emptyLibraryCard
                    } else if !recentScores.isEmpty {
                        recentCard
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Piano Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(Text("Réglages"))
                }
            }
            .sheet(isPresented: $showPicker, onDismiss: {
                if pendingStart {
                    pendingStart = false
                    router.practice(pendingScore, timer: timer)
                    pendingScore = nil
                }
            }) {
                ScorePickerSheet { score in
                    pendingScore = score
                    pendingStart = true
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .miniTimerBar()
        }
    }

    // MARK: Série

    private var streakCard: some View {
        let stats = self.stats
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(stats.currentStreak > 0 ? Color.orange : Color.secondary.opacity(0.4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Fmt.days(stats.currentStreak))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(stats.currentStreak > 0 ? LocalizedStringKey("Série en cours") : LocalizedStringKey("Jouez aujourd'hui pour lancer votre série"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack {
                    ForEach(days, id: \.self) { day in
                        let played = stats.seconds(on: day) > 0
                        VStack(spacing: 6) {
                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2).foregroundStyle(.secondary)
                            ZStack {
                                Circle().fill(played ? Color.orange : Color(.tertiarySystemFill))
                                if played {
                                    Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white)
                                }
                            }
                            .frame(width: 30, height: 30)
                            .overlay {
                                if calendar.isDateInToday(day) {
                                    Circle().stroke(Color.accentColor, lineWidth: 2).padding(-3)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: Objectif du jour

    private var goalCard: some View {
        let done = stats.todaySeconds
        let goalSeconds = max(1, dailyGoal * 60)
        let fraction = min(1, Double(done) / Double(goalSeconds))
        return Card {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color(.tertiarySystemFill), lineWidth: 8)
                    Circle().trim(from: 0, to: fraction)
                        .stroke(fraction >= 1 ? Color.green : Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: fraction >= 1 ? "checkmark" : "pianokeys")
                        .font(.headline)
                        .foregroundStyle(fraction >= 1 ? Color.green : Color.accentColor)
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aujourd'hui").font(.caption).foregroundStyle(.secondary)
                    Text(verbatim: "\(Fmt.duration(done)) / \(dailyGoal) min")
                        .font(.title3.weight(.semibold)).monospacedDigit()
                    Text(fraction >= 1 ? LocalizedStringKey("Objectif atteint, bravo !") : LocalizedStringKey("Objectif quotidien"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var startButton: some View {
        Button {
            if timer.phase == .idle {
                showPicker = true
            } else {
                router.showTimer = true
            }
        } label: {
            Label(timer.phase == .idle ? LocalizedStringKey("Démarrer une séance") : LocalizedStringKey("Reprendre la séance"),
                  systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
    }

    private var recentCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reprendre").font(.headline)
                ForEach(recentScores) { score in
                    Button {
                        router.practice(score, timer: timer)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill").font(.title).foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(score.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                                Text(score.parent?.title ?? score.displayComposer)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(Fmt.duration(score.totalSeconds)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyLibraryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Ajoutez votre première partition", systemImage: "book.closed")
                    .font(.headline)
                Text("Cherchez votre recueil ou votre morceau dans le catalogue : les pièces d'un recueil sont ajoutées automatiquement.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Ouvrir le catalogue") { router.tab = .catalog }
                    .buttonStyle(.bordered)
            }
        }
    }
}
