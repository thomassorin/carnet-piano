import SwiftUI
import SwiftData
import Charts

struct TrackingView: View {
    enum Mode: Hashable { case stats, history }

    @Environment(\.modelContext) private var context
    @Query(sort: \PracticeSession.startedAt, order: .reverse) private var sessions: [PracticeSession]
    @Query private var scores: [Score]

    @State private var mode: Mode = .stats
    @State private var showAddSession = false

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .stats: statsView
                case .history: historyView
                }
            }
            .navigationTitle("Suivi")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Affichage", selection: $mode) {
                        Text("Statistiques").tag(Mode.stats)
                        Text("Historique").tag(Mode.history)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSession = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Text("Ajouter une séance"))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddSession) { AddSessionSheet() }
            .miniTimerBar()
        }
    }

    // MARK: Statistiques

    private struct DayBar: Identifiable {
        let day: Date
        let minutes: Double
        var id: Date { day }
    }

    private var statsView: some View {
        let stats = PracticeStats(sessions: sessions)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let bars: [DayBar] = (0..<14).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { DayBar(day: $0, minutes: Double(stats.seconds(on: $0)) / 60) }
        }
        let weekSeconds = bars.suffix(7).reduce(0.0) { $0 + $1.minutes } * 60
        let ranked = scores.filter { $0.parent == nil && $0.totalSeconds > 0 }.sorted { $0.totalSeconds > $1.totalSeconds }
        let maxSeconds = max(1, ranked.first?.totalSeconds ?? 1)

        return ScrollView {
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    StatCard(title: "Série en cours", value: Fmt.days(stats.currentStreak), icon: "flame.fill", tint: .orange)
                    StatCard(title: "Meilleure série", value: Fmt.days(stats.longestStreak), icon: "trophy.fill", tint: .yellow)
                    StatCard(title: "Temps total", value: Fmt.duration(stats.totalSeconds), icon: "clock.fill")
                    StatCard(title: "7 derniers jours", value: Fmt.duration(Int(weekSeconds)), icon: "calendar")
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("14 derniers jours").font(.headline)
                        Chart(bars) { bar in
                            BarMark(x: .value("Jour", bar.day, unit: .day), y: .value("Minutes", bar.minutes))
                                .foregroundStyle(Color.accentColor.gradient)
                                .cornerRadius(3)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                                AxisValueLabel(format: .dateTime.day(), centered: true)
                            }
                        }
                        .chartYAxisLabel("min")
                        .frame(height: 170)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Temps par partition").font(.headline)
                        if ranked.isEmpty {
                            Text("Vos partitions les plus travaillées apparaîtront ici.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(ranked.prefix(10)) { score in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(score.title).font(.subheadline).lineLimit(1)
                                    Spacer()
                                    Text(Fmt.duration(score.totalSeconds)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                                }
                                GeometryReader { proxy in
                                    Capsule().fill(Color.accentColor.opacity(0.75))
                                        .frame(width: max(4, proxy.size.width * CGFloat(score.totalSeconds) / CGFloat(maxSeconds)))
                                }
                                .frame(height: 6)
                            }
                        }
                    }
                }

                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "\(stats.sessionCount)").font(.title2.weight(.semibold)).monospacedDigit()
                            Text("Séances enregistrées").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(verbatim: "\(scores.filter { $0.isDone && $0.children.isEmpty }.count)").font(.title2.weight(.semibold)).monospacedDigit()
                            Text("Pièces terminées").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Historique

    private var historyView: some View {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }
        let days = grouped.keys.sorted(by: >)

        return Group {
            if sessions.isEmpty {
                ContentUnavailableView("Aucune séance", systemImage: "clock",
                                       description: Text("Vos séances apparaîtront ici, jour après jour."))
            } else {
                List {
                    ForEach(days, id: \.self) { day in
                        let items = grouped[day] ?? []
                        Section {
                            ForEach(items) { session in
                                SessionRow(session: session)
                            }
                            .onDelete { offsets in
                                for index in offsets { context.delete(items[index]) }
                            }
                        } header: {
                            HStack {
                                Text(Fmt.day(day))
                                Spacer()
                                Text(Fmt.duration(items.reduce(0) { $0 + $1.seconds })).monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Saisie manuelle d'une séance

struct AddSessionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Score.addedAt, order: .reverse) private var scores: [Score]

    @State private var selected: UUID?
    @State private var date = Date()
    @State private var minutes = 15
    @State private var note = ""

    /// Partitions à plat : recueil puis ses pièces.
    private var choices: [(uuid: UUID, label: String)] {
        var result: [(uuid: UUID, label: String)] = []
        for score in scores where score.parent == nil {
            result.append((score.uuid, score.title))
            for child in score.sortedChildren { result.append((child.uuid, "    \(child.title)")) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Partition", selection: $selected) {
                        Text("Pratique libre").tag(UUID?.none)
                        ForEach(choices, id: \.uuid) { choice in
                            Text(choice.label).tag(Optional(choice.uuid))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    DatePicker("Date", selection: $date, in: ...Date())
                    Stepper(value: $minutes, in: 1...600) {
                        HStack {
                            Text("Durée")
                            Spacer()
                            Text(Fmt.duration(minutes * 60)).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
                Section("Notes de séance") {
                    TextField("Facultatif", text: $note, axis: .vertical).lineLimit(2...6)
                }
            }
            .navigationTitle("Ajouter une séance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let score = selected.flatMap { context.score(uuid: $0) }
                        context.insert(PracticeSession(startedAt: date, seconds: minutes * 60,
                                                       note: note.trimmingCharacters(in: .whitespacesAndNewlines), score: score))
                        dismiss()
                    }
                }
            }
        }
    }
}
