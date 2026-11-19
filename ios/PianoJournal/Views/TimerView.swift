import SwiftUI
import SwiftData
import UIKit

struct TimerView: View {
    @Environment(PracticeTimer.self) private var timer
    @Environment(Metronome.self) private var metronome
    @Environment(\.dismiss) private var dismiss

    @State private var finishing: PracticeTimer.Result?
    @State private var wasRunning = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Réduire"))
                Spacer()
            }
            .padding(.horizontal, 8)

            Spacer()

            VStack(spacing: 6) {
                Text(timer.title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                if !timer.subtitle.isEmpty {
                    Text(timer.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(.horizontal, 24)

            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                Text(Fmt.clock(timer.elapsed(at: context.date)))
                    .font(.system(size: 76, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(timer.phase == .paused ? .secondary : .primary)
            }
            .padding(.top, 28)
            .padding(.horizontal, 16)

            Text(timer.phase == .paused ? LocalizedStringKey("En pause") : LocalizedStringKey("Séance en cours"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            metronomeControl
                .padding(.horizontal, 20)

            HStack(spacing: 14) {
                Button {
                    timer.phase == .running ? timer.pause() : timer.resume()
                } label: {
                    Label(timer.phase == .running ? LocalizedStringKey("Pause") : LocalizedStringKey("Reprendre"),
                          systemImage: timer.phase == .running ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button {
                    wasRunning = timer.phase == .running
                    timer.pause()
                    finishing = timer.snapshot()
                } label: {
                    Label("Terminer", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .padding(20)
        }
        .background(Color(.systemBackground))
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(item: $finishing) { result in
            FinishSessionSheet(result: result, metronomeBPM: metronome.bpm) { outcome in
                switch outcome {
                case .saved, .discarded:
                    metronome.stop()
                    timer.reset()
                    dismiss()
                case .continued:
                    if wasRunning { timer.resume() }
                }
            }
        }
    }

    private var metronomeControl: some View {
        HStack(spacing: 14) {
            Image(systemName: "metronome").font(.title3).foregroundStyle(.secondary)
            Button { metronome.setBPM(metronome.bpm - 4) } label: {
                Image(systemName: "minus").frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered).buttonBorderShape(.circle)
            VStack(spacing: 0) {
                Text(verbatim: "\(metronome.bpm)").font(.title2.weight(.semibold)).monospacedDigit()
                Text(verbatim: "BPM").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(minWidth: 56)
            Button { metronome.setBPM(metronome.bpm + 4) } label: {
                Image(systemName: "plus").frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered).buttonBorderShape(.circle)
            Spacer()
            Button { metronome.toggle() } label: {
                Image(systemName: metronome.isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.circle)
            .tint(metronome.isPlaying ? .accentColor : .gray)
            .accessibilityLabel(Text("Métronome"))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Fin de séance

struct FinishSessionSheet: View {
    enum Outcome { case saved, discarded, continued }

    let result: PracticeTimer.Result
    let metronomeBPM: Int
    let onClose: (Outcome) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var keepTempo = false
    @State private var tempo = 80
    @State private var rating = 0
    @State private var markDone = false
    @State private var score: Score?
    @State private var outcome: Outcome = .continued

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(score?.title ?? String(localized: "Pratique libre")).font(.headline)
                            if let parent = score?.parent { Text(parent.title).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text(Fmt.duration(result.seconds)).font(.title3.weight(.semibold)).monospacedDigit()
                    }
                }
                Section("Notes de séance") {
                    TextField("Ce qui a été travaillé, ce qui reste à revoir…", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    Toggle("Noter le tempo atteint", isOn: $keepTempo)
                    if keepTempo {
                        Stepper(value: $tempo, in: Metronome.range, step: 2) {
                            Text(verbatim: "♩ = \(tempo)").monospacedDigit()
                        }
                    }
                }
                if score != nil {
                    Section("Cette partition") {
                        HStack {
                            Text("Ma note")
                            Spacer()
                            StarRating(rating: $rating)
                        }
                        Toggle("Marquer comme terminée", isOn: $markDone)
                    }
                }
                Section {
                    Button("Supprimer cette séance", role: .destructive) {
                        outcome = .discarded
                        dismiss()
                    }
                }
            }
            .navigationTitle("Séance terminée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Continuer") { outcome = .continued; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }.fontWeight(.semibold)
                }
            }
            .onAppear {
                tempo = metronomeBPM
                if let uuid = result.scoreUUID, let found = context.score(uuid: uuid) {
                    score = found
                    rating = found.rating
                    markDone = found.isDone
                }
            }
            .onDisappear { onClose(outcome) }
        }
        .interactiveDismissDisabled()
    }

    private func save() {
        let session = PracticeSession(startedAt: result.startedAt, seconds: max(result.seconds, 1),
                                      note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                      tempo: keepTempo ? tempo : 0, score: score)
        context.insert(session)
        if let score {
            score.rating = rating
            if score.isDone != markDone { score.setDone(markDone) }
        }
        outcome = .saved
        dismiss()
    }
}
