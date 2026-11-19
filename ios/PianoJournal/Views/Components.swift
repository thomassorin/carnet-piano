import SwiftUI
import SwiftData

// MARK: - Petits composants partagés

struct StarRating: View {
    @Binding var rating: Int
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.yellow : Color.secondary.opacity(0.5))
                    .onTapGesture { rating = (rating == star) ? 0 : star }
                    .accessibilityLabel(Text("\(star) sur 5"))
            }
        }
    }
}

struct StarsLabel: View {
    let rating: Int
    var body: some View {
        if rating > 0 {
            HStack(spacing: 1) {
                ForEach(0..<rating, id: \.self) { _ in
                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                }
            }
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    var tint: Color = .accentColor

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
                Text(value).font(.title2.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct DoneToggle: View {
    let isDone: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isDone ? Color.green : Color.secondary.opacity(0.6))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isDone ? Text("Terminée") : Text("Marquer comme terminée"))
    }
}

/// Ligne d'une partition de la bibliothèque.
struct ScoreRow: View {
    let score: Score

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: score.isContainer ? (score.kind == .method ? "graduationcap" : "book.closed") : "music.note")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(score.title).font(.body.weight(.medium)).lineLimit(2)
                HStack(spacing: 6) {
                    if !score.displayComposer.isEmpty {
                        Text(score.displayComposer).lineLimit(1)
                    }
                    StarsLabel(rating: score.rating)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !score.children.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView(value: score.progress).tint(score.progress >= 1 ? .green : .accentColor)
                        Text(verbatim: "\(score.doneCount)/\(score.children.count)")
                            .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                if score.totalSeconds > 0 {
                    Text(Fmt.duration(score.totalSeconds)).font(.caption.weight(.medium)).monospacedDigit()
                }
                if score.isDone {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Ligne d'une séance dans un historique.
struct SessionRow: View {
    let session: PracticeSession
    var showsDate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.label).font(.subheadline.weight(.medium)).lineLimit(2)
                Spacer()
                Text(Fmt.duration(session.seconds)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(showsDate
                     ? session.startedAt.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
                     : session.startedAt.formatted(.dateTime.hour().minute()))
                if session.tempo > 0 {
                    Label { Text(verbatim: "\(session.tempo)") } icon: { Image(systemName: "metronome") }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !session.note.isEmpty {
                Text(session.note).font(.caption).foregroundStyle(.primary.opacity(0.8))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Barre du minuteur en cours

struct MiniTimerBar: ViewModifier {
    @Environment(PracticeTimer.self) private var timer
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if timer.phase != .idle {
                Button {
                    router.showTimer = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: timer.phase == .running ? "waveform" : "pause.fill")
                            .symbolEffect(.variableColor.iterative, isActive: timer.phase == .running)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(timer.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(timer.phase == .running ? LocalizedStringKey("Séance en cours") : LocalizedStringKey("Séance en pause")).font(.caption2).opacity(0.85)
                        }
                        Spacer()
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(Fmt.clock(timer.elapsed(at: context.date))).font(.headline).monospacedDigit()
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension View {
    func miniTimerBar() -> some View { modifier(MiniTimerBar()) }
}

// MARK: - Choix d'une partition (pour démarrer une séance)

struct ScorePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Score.addedAt, order: .reverse) private var scores: [Score]
    let onPick: (Score?) -> Void

    private var topLevel: [Score] { scores.filter { $0.parent == nil } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        pick(nil)
                    } label: {
                        Label("Pratique libre (gammes, déchiffrage…)", systemImage: "pianokeys")
                    }
                }
                Section("Mes partitions") {
                    if topLevel.isEmpty {
                        Text("Aucune partition pour l'instant. Ajoutez-en depuis le catalogue.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(topLevel) { score in
                        if score.children.isEmpty {
                            Button { pick(score) } label: { pickerLabel(score) }
                        } else {
                            DisclosureGroup {
                                Button { pick(score) } label: {
                                    Text("Tout le recueil").font(.subheadline).foregroundStyle(.secondary)
                                }
                                ForEach(score.sortedChildren) { child in
                                    Button { pick(child) } label: {
                                        HStack {
                                            Text(child.title).font(.subheadline)
                                            Spacer()
                                            if child.isDone { Image(systemName: "checkmark").font(.caption).foregroundStyle(.green) }
                                        }
                                    }
                                }
                            } label: {
                                pickerLabel(score)
                            }
                        }
                    }
                }
            }
            .tint(.primary)
            .navigationTitle("Que travaillez-vous ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
        }
    }

    private func pickerLabel(_ score: Score) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(score.title).font(.body.weight(.medium))
            if !score.composer.isEmpty { Text(score.composer).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func pick(_ score: Score?) {
        onPick(score)
        dismiss()
    }
}
