import SwiftUI
import SwiftData

struct ScoreDetailView: View {
    @Bindable var score: Score

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(PracticeTimer.self) private var timer
    @Environment(SubscriptionManager.self) private var store

    @State private var showAddPiece = false
    @State private var newPieceTitle = ""
    @State private var showSeries = false
    @State private var seriesPrefix = "N° "
    @State private var seriesCount = 10
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var aiLoading = false
    @State private var aiMessage: String?

    private var sessions: [PracticeSession] { score.allSessions }

    var body: some View {
        List {
            headerSection
            trackingSection
            if score.isContainer { contentSection }
            Section("Notes") {
                TextField("Doigtés, passages difficiles, conseils du professeur…", text: $score.notes, axis: .vertical)
                    .lineLimit(3...12)
            }
            historySection
        }
        .navigationTitle(score.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: { Label("Modifier", systemImage: "pencil") }
                    if !score.isContainer {
                        Button { showAddPiece = true } label: { Label("Découper en sous-parties", systemImage: "list.bullet.indent") }
                    }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Supprimer", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Nouvelle pièce", isPresented: $showAddPiece) {
            TextField("Titre", text: $newPieceTitle)
            Button("Ajouter") {
                Library.appendPieces([newPieceTitle], to: score, context: context)
                newPieceTitle = ""
            }
            Button("Annuler", role: .cancel) { newPieceTitle = "" }
        }
        .sheet(isPresented: $showSeries) { seriesSheet }
        .sheet(isPresented: $showEdit) { EditScoreSheet(score: score) }
        .confirmationDialog("Supprimer cette partition et tout son historique ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                let target = score
                dismiss()
                context.delete(target)
            }
        }
        .alert("Recherche IA", isPresented: Binding(get: { aiMessage != nil }, set: { if !$0 { aiMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(aiMessage ?? "")
        }
        .miniTimerBar()
    }

    // MARK: En-tête

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(score.title).font(.title2.weight(.bold))
                    if let parent = score.parent {
                        Text(parent.title).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !score.displayComposer.isEmpty {
                        Text(score.displayComposer).font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Text(score.isContainer && score.kind == .piece ? ScoreKind.collection.label : score.kind.label).badge()
                        if score.level > 0 { Text(Level.label(score.level)).badge() }
                        if let period = score.period { Text(period.label).badge() }
                    }
                    .padding(.top, 2)
                }
                HStack(spacing: 0) {
                    metric(Fmt.duration(score.totalSeconds), "Temps passé")
                    Divider()
                    metric("\(sessions.count)", "Séances")
                    Divider()
                    metric(score.lastPracticed.map { $0.formatted(.dateTime.day().month(.abbreviated)) } ?? "—", "Dernière fois")
                }
                .frame(height: 44)
                Button {
                    router.practice(score, timer: timer)
                } label: {
                    Label("Travailler maintenant", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 6)
        }
    }

    private func metric(_ value: String, _ title: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Suivi

    private var trackingSection: some View {
        Section("Suivi") {
            HStack {
                Text("Ma note")
                Spacer()
                StarRating(rating: $score.rating)
            }
            Toggle(isOn: Binding(get: { score.isDone }, set: { score.setDone($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Terminée")
                    if let doneAt = score.doneAt, score.isDone {
                        Text(doneAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Stepper(value: $score.targetTempo, in: 0...240, step: 4) {
                HStack {
                    Text("Tempo visé")
                    Spacer()
                    Text(score.targetTempo > 0 ? "♩ = \(score.targetTempo)" : "—").foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    // MARK: Contenu du recueil

    private var contentSection: some View {
        Section {
            ForEach(score.sortedChildren) { child in
                HStack(spacing: 12) {
                    DoneToggle(isDone: child.isDone) {
                        withAnimation { child.setDone(!child.isDone) }
                    }
                    NavigationLink(value: child) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(child.title)
                                .font(.subheadline)
                                .strikethrough(child.isDone, color: .secondary)
                                .foregroundStyle(child.isDone ? .secondary : .primary)
                            HStack(spacing: 8) {
                                if child.ownSeconds > 0 {
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock")
                                        Text(Fmt.duration(child.ownSeconds)).monospacedDigit()
                                    }
                                }
                                StarsLabel(rating: child.rating)
                                if !child.notes.isEmpty { Image(systemName: "note.text") }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        router.practice(child, timer: timer)
                    } label: {
                        Label("Travailler", systemImage: "play.fill")
                    }
                    .tint(.accentColor)
                }
            }
            .onDelete { offsets in
                let ordered = score.sortedChildren
                for index in offsets { context.delete(ordered[index]) }
            }
            .onMove { source, destination in
                var ordered = score.sortedChildren
                ordered.move(fromOffsets: source, toOffset: destination)
                for (index, child) in ordered.enumerated() { child.order = index }
            }

            Menu {
                Button { showAddPiece = true } label: { Label("Une pièce", systemImage: "plus") }
                Button { showSeries = true } label: { Label("Une série numérotée", systemImage: "list.number") }
                if OnlineCatalog.isAIAvailable && score.children.isEmpty {
                    Button { expandWithAI() } label: { Label("Retrouver le contenu avec l'IA", systemImage: "sparkles") }
                }
            } label: {
                if aiLoading {
                    HStack { ProgressView(); Text("Recherche du contenu…") }
                } else {
                    Label("Ajouter des pièces", systemImage: "plus.circle")
                }
            }
        } header: {
            HStack {
                Text("Contenu")
                Spacer()
                if !score.children.isEmpty {
                    Text(verbatim: "\(score.doneCount)/\(score.children.count)").monospacedDigit()
                }
            }
        } footer: {
            if !score.children.isEmpty {
                ProgressView(value: score.progress).tint(score.progress >= 1 ? .green : .accentColor)
            }
        }
    }

    private var seriesSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Préfixe", text: $seriesPrefix)
                    Stepper(value: $seriesCount, in: 1...200) {
                        Text("\(seriesCount) pièces")
                    }
                } footer: {
                    Text("Exemple : « Leçon » et 20 créent Leçon 1 à Leçon 20, à la suite du contenu existant.")
                }
            }
            .navigationTitle("Série numérotée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { showSeries = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        let start = score.children.count + 1
                        let prefix = seriesPrefix.hasSuffix(" ") || seriesPrefix.isEmpty ? seriesPrefix : seriesPrefix + " "
                        Library.appendPieces((start..<(start + seriesCount)).map { "\(prefix)\($0)" }, to: score, context: context)
                        showSeries = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func expandWithAI() {
        guard store.isPro else {
            router.showPaywall = true
            return
        }
        aiLoading = true
        Task {
            defer { aiLoading = false }
            do {
                let pieces = try await OnlineCatalog.expandWithAI(title: score.title, composer: score.composer)
                if pieces.isEmpty {
                    aiMessage = String(localized: "Le contenu de ce recueil n'a pas été retrouvé. Vous pouvez l'ajouter à la main.")
                } else {
                    Library.appendPieces(pieces, to: score, context: context)
                }
            } catch {
                aiMessage = error.localizedDescription
            }
        }
    }

    // MARK: Historique

    private var historySection: some View {
        Section {
            if sessions.isEmpty {
                Text("Aucune séance pour l'instant.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(sessions.prefix(60)) { session in
                SessionRow(session: session, showsDate: true)
            }
            .onDelete { offsets in
                let shown = Array(sessions.prefix(60))
                for index in offsets { context.delete(shown[index]) }
            }
        } header: {
            Text("Historique")
        }
    }
}

private extension Text {
    func badge() -> some View {
        self.font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }
}

struct EditScoreSheet: View {
    @Bindable var score: Score
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titre", text: $score.title)
                    if score.parent == nil {
                        TextField("Compositeur ou auteur", text: $score.composer)
                    }
                }
                Section {
                    if score.parent == nil {
                        Picker("Type", selection: $score.kindRaw) {
                            ForEach(ScoreKind.allCases) { Text($0.label).tag($0.rawValue) }
                        }
                    }
                    Picker("Niveau", selection: $score.level) {
                        Text("Non précisé").tag(0)
                        ForEach(Level.all, id: \.self) { Text(Level.label($0)).tag($0) }
                    }
                }
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
