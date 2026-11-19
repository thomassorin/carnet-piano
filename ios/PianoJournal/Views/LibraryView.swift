import SwiftUI
import SwiftData

struct LibraryView: View {
    enum StatusFilter: Hashable { case all, inProgress, done }

    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(SubscriptionManager.self) private var store
    @Query(sort: \Score.addedAt, order: .reverse) private var scores: [Score]

    @State private var status: StatusFilter = .all
    @State private var query = ""
    @State private var showCustom = false
    @State private var path = NavigationPath()

    private var topLevel: [Score] { scores.filter { $0.parent == nil } }

    private var visible: [Score] {
        let needle = Fmt.normalized(query).trimmingCharacters(in: .whitespaces)
        return topLevel.filter { score in
            switch status {
            case .all: break
            case .inProgress: if score.isDone { return false }
            case .done: if !score.isDone { return false }
            }
            guard !needle.isEmpty else { return true }
            let haystack = Fmt.normalized(([score.title, score.composer] + score.children.map(\.title)).joined(separator: " "))
            return needle.split(separator: " ").allSatisfy { haystack.contains($0) }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if topLevel.isEmpty {
                    ContentUnavailableView {
                        Label("Aucune partition", systemImage: "music.note.list")
                    } description: {
                        Text("Trouvez votre recueil ou votre morceau dans le catalogue, ou créez-le à la main.")
                    } actions: {
                        Button("Ouvrir le catalogue") { router.tab = .catalog }
                            .buttonStyle(.borderedProminent)
                        Button("Créer une partition") { addCustom() }
                    }
                } else {
                    List {
                        Picker("Filtre", selection: $status) {
                            Text("Toutes").tag(StatusFilter.all)
                            Text("En cours").tag(StatusFilter.inProgress)
                            Text("Terminées").tag(StatusFilter.done)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                        ForEach(visible) { score in
                            NavigationLink(value: score) { ScoreRow(score: score) }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(visible[index]) }
                        }

                        if visible.isEmpty {
                            Text("Aucune partition ne correspond.").foregroundStyle(.secondary)
                        }
                    }
                    .searchable(text: $query, prompt: "Rechercher dans mes partitions")
                }
            }
            .navigationTitle("Mes partitions")
            .navigationDestination(for: Score.self) { ScoreDetailView(score: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { router.tab = .catalog } label: { Label("Chercher dans le catalogue", systemImage: "magnifyingglass") }
                        Button { addCustom() } label: { Label("Créer une partition", systemImage: "square.and.pencil") }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Ajouter"))
                }
            }
            .sheet(isPresented: $showCustom) { AddCustomScoreView() }
            .miniTimerBar()
            #if DEBUG
            .task {
                try? await Task.sleep(for: .milliseconds(600))
                if UserDefaults.standard.bool(forKey: "uiOpenFirst"), let first = topLevel.last(where: { !$0.children.isEmpty }) {
                    path.append(first)
                }
            }
            #endif
        }
    }

    private func addCustom() {
        if store.isPro || topLevel.count < Config.freeScoreLimit {
            showCustom = true
        } else {
            router.showPaywall = true
        }
    }
}

// MARK: - Création manuelle

struct AddCustomScoreView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State var title = ""
    @State private var composer = ""
    @State private var kind: ScoreKind = .piece
    @State private var level = 0
    @State private var piecesText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titre", text: $title)
                    TextField("Compositeur ou auteur", text: $composer)
                }
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(ScoreKind.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Niveau", selection: $level) {
                        Text("Non précisé").tag(0)
                        ForEach(Level.all, id: \.self) { Text(Level.label($0)).tag($0) }
                    }
                }
                if kind != .piece {
                    Section {
                        TextField("Une pièce par ligne", text: $piecesText, axis: .vertical)
                            .lineLimit(4...12)
                    } header: {
                        Text("Contenu du recueil")
                    } footer: {
                        Text("Facultatif : vous pourrez ajouter, renommer ou réordonner les pièces ensuite.")
                    }
                }
            }
            .navigationTitle("Nouvelle partition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let score = Score(title: title.trimmingCharacters(in: .whitespaces),
                          composer: composer.trimmingCharacters(in: .whitespaces), kind: kind)
        score.level = level
        context.insert(score)
        if kind != .piece {
            Library.appendPieces(piecesText.components(separatedBy: .newlines), to: score, context: context)
        }
        dismiss()
    }
}
