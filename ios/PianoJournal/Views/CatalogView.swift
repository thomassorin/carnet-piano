import SwiftUI
import SwiftData

struct CatalogView: View {
    @Environment(\.modelContext) private var context
    @Environment(CatalogStore.self) private var catalog
    @Environment(AppRouter.self) private var router
    @Environment(SubscriptionManager.self) private var store
    @Query private var scores: [Score]

    @State private var query = ""
    @State private var filter = CatalogFilter()
    @State private var classical: [CatalogItem] = []
    @State private var songs: [CatalogItem] = []
    @State private var aiItems: [CatalogItem] = []
    @State private var aiQuery = ""
    @State private var aiLoading = false
    @State private var aiError: String?
    @State private var onlineLoading = false
    @State private var showCustom = false
    @State private var addingID: String?

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isBrowsing: Bool { trimmedQuery.isEmpty && filter.isEmpty }
    private var addedIDs: Set<String> { Set(scores.compactMap(\.catalogID)) }
    private var topLevelCount: Int { scores.filter { $0.parent == nil }.count }

    /// Recherche envoyée aux sources en ligne (compositeur filtré + texte saisi).
    private var onlineQuery: String {
        [filter.composer, trimmedQuery].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterBar
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                }
                if isBrowsing {
                    browseSections
                } else {
                    resultSections
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Catalogue")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Titre, compositeur, opus…")
            .autocorrectionDisabled()
            .navigationDestination(for: CatalogItem.self) { item in
                CatalogItemDetailView(item: item)
            }
            .task(id: onlineQuery) { await searchOnline() }
            .sheet(isPresented: $showCustom) { AddCustomScoreView(title: trimmedQuery) }
            .miniTimerBar()
        }
    }

    // MARK: Filtres

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: filter.kind?.pluralLabel ?? String(localized: "Type"), isActive: filter.kind != nil) {
                    Picker("Type", selection: $filter.kind) {
                        Text("Tous les types").tag(ScoreKind?.none)
                        ForEach(ScoreKind.allCases) { Text($0.pluralLabel).tag(Optional($0)) }
                    }
                }
                FilterChip(title: filter.level.map(Level.label) ?? String(localized: "Niveau"), isActive: filter.level != nil) {
                    Picker("Niveau", selection: $filter.level) {
                        Text("Tous les niveaux").tag(Int?.none)
                        ForEach(Level.all, id: \.self) { Text(Level.label($0)).tag(Optional($0)) }
                    }
                }
                FilterChip(title: filter.period?.label ?? String(localized: "Époque"), isActive: filter.period != nil) {
                    Picker("Époque", selection: $filter.period) {
                        Text("Toutes les époques").tag(Period?.none)
                        ForEach(Period.allCases) { Text($0.label).tag(Optional($0)) }
                    }
                }
                FilterChip(title: filter.composer ?? String(localized: "Compositeur"), isActive: filter.composer != nil) {
                    Picker("Compositeur", selection: $filter.composer) {
                        Text("Tous les compositeurs").tag(String?.none)
                        ForEach(catalog.composers) { Text($0.name).tag(Optional($0.name)) }
                    }
                }
                if !filter.isEmpty {
                    Button { filter = CatalogFilter() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Effacer les filtres"))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Parcourir (aucune recherche)

    @ViewBuilder
    private var browseSections: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(catalog.topComposers) { composer in
                    Button {
                        filter.composer = composer.name
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(composer.name.split(separator: " ").last.map(String.init) ?? composer.name)
                                .font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text("\(composer.count) partitions").font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        } header: {
            Text("Compositeurs")
        }

        Section {
            ForEach(catalog.starters) { item in row(item) }
        } header: {
            Text("Pour bien débuter")
        } footer: {
            Text("\(catalog.itemCount) recueils et morceaux, \(catalog.pieceCount) pièces détaillées, consultables hors ligne. Tapez un titre pour chercher aussi dans les catalogues en ligne.")
        }
    }

    // MARK: Résultats

    @ViewBuilder
    private var resultSections: some View {
        let local = catalog.search(trimmedQuery, filter: filter)
        let localIDs = Set(local.map { Fmt.normalized($0.title + " " + $0.composer) })

        if !local.isEmpty {
            Section {
                ForEach(local) { item in row(item, matches: catalog.matchingPieces(in: item, query: trimmedQuery)) }
            } header: {
                Text("\(local.count) résultats")
            }
        }

        let classicalShown = classical.filter { filter.matches($0, strict: false) && !localIDs.contains(Fmt.normalized($0.title + " " + $0.composer)) }
        if !classicalShown.isEmpty {
            Section("Répertoire classique en ligne") {
                ForEach(classicalShown) { item in row(item) }
            }
        }

        let songsShown = songs.filter { filter.matches($0, strict: false) }
        if !songsShown.isEmpty {
            Section("Albums et chansons") {
                ForEach(songsShown) { item in row(item) }
            }
        }

        if onlineLoading {
            Section {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Recherche en ligne…").foregroundStyle(.secondary)
                }
            }
        }

        if OnlineCatalog.isAIAvailable && onlineQuery.count >= 3 {
            Section {
                if aiQuery == onlineQuery {
                    ForEach(aiItems) { item in row(item) }
                    if let aiError { Text(aiError).font(.footnote).foregroundStyle(.secondary) }
                    if aiItems.isEmpty && aiError == nil && !aiLoading {
                        Text("L'IA n'a rien trouvé de fiable pour cette recherche.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if aiLoading {
                    HStack(spacing: 10) { ProgressView(); Text("L'IA cherche votre partition…").foregroundStyle(.secondary) }
                } else if aiQuery != onlineQuery {
                    Button { searchAI() } label: {
                        Label("Chercher « \(onlineQuery) » avec l'IA", systemImage: "sparkles")
                    }
                }
            } header: {
                Text("Recherche IA")
            } footer: {
                Text("L'IA retrouve les recueils rares et détaille leur contenu. Vérifiez les titres avant de vous y fier.")
            }
        }

        Section {
            Button { addCustom() } label: {
                Label("Créer la partition à la main", systemImage: "square.and.pencil")
            }
        } footer: {
            if local.isEmpty && classicalShown.isEmpty && songsShown.isEmpty && !onlineLoading {
                Text("Aucun résultat. Vérifiez l'orthographe, retirez un filtre, ou créez la partition vous-même.")
            }
        }
    }

    private func row(_ item: CatalogItem, matches: [String] = []) -> some View {
        HStack(spacing: 10) {
            NavigationLink(value: item) {
                HStack(spacing: 12) {
                    Image(systemName: item.kind.icon)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.subheadline.weight(.medium)).lineLimit(2)
                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        if let first = matches.first {
                            Label(matches.count > 1 ? "\(first) +\(matches.count - 1)" : first, systemImage: "arrow.turn.down.right")
                                .font(.caption2).foregroundStyle(Color.accentColor).lineLimit(1)
                        }
                    }
                }
            }
            if addedIDs.contains(item.id) {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.green)
                    .accessibilityLabel(Text("Déjà dans mes partitions"))
            } else if addingID == item.id {
                ProgressView().frame(width: 28)
            } else {
                Button { add(item) } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Ajouter à mes partitions"))
            }
        }
    }

    // MARK: Actions

    private func add(_ item: CatalogItem) {
        guard store.isPro || topLevelCount < Config.freeScoreLimit else {
            router.showPaywall = true
            return
        }
        addingID = item.id
        Task {
            var pieces = item.pieces ?? []
            if pieces.isEmpty, item.source == .itunes, item.kind == .collection, let remote = item.remoteID {
                pieces = await OnlineCatalog.albumTracks(remote)
            }
            Library.add(item, pieces: pieces, to: context)
            addingID = nil
        }
    }

    private func addCustom() {
        if store.isPro || topLevelCount < Config.freeScoreLimit {
            showCustom = true
        } else {
            router.showPaywall = true
        }
    }

    private func searchOnline() async {
        let text = onlineQuery
        guard text.count >= 3 else {
            classical = []
            songs = []
            onlineLoading = false
            return
        }
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        onlineLoading = true
        async let classicalResults = OnlineCatalog.searchClassical(text)
        async let songResults = OnlineCatalog.searchSongs(text)
        let (c, s) = await (classicalResults, songResults)
        guard !Task.isCancelled else { return }
        classical = c
        songs = s
        onlineLoading = false
    }

    private func searchAI() {
        guard store.isPro else {
            router.showPaywall = true
            return
        }
        let text = onlineQuery
        aiQuery = text
        aiItems = []
        aiError = nil
        aiLoading = true
        Task {
            do {
                aiItems = try await OnlineCatalog.askAI(text)
            } catch {
                aiError = error.localizedDescription
            }
            aiLoading = false
        }
    }
}

private struct FilterChip<MenuContent: View>: View {
    let title: String
    let isActive: Bool
    @ViewBuilder var menu: MenuContent

    var body: some View {
        Menu {
            menu
        } label: {
            HStack(spacing: 4) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .background(isActive ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
        }
    }
}

// MARK: - Fiche d'une entrée du catalogue

struct CatalogItemDetailView: View {
    let item: CatalogItem

    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(SubscriptionManager.self) private var store
    @Query private var scores: [Score]

    @State private var pieces: [String] = []
    @State private var loading = false
    @State private var message: String?

    private var isAdded: Bool { scores.contains { $0.catalogID == item.id } }
    private var topLevelCount: Int { scores.filter { $0.parent == nil }.count }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(item.kind.label, systemImage: item.kind.icon)
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                    Text(item.title).font(.title2.weight(.bold))
                    if !item.composer.isEmpty {
                        Text(item.composer).font(.headline).foregroundStyle(.secondary)
                    }
                    let details = [item.period?.label, item.genre, item.level.map(Level.label)].compactMap { $0 }.filter { !$0.isEmpty }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if loading {
                Section { HStack(spacing: 10) { ProgressView(); Text("Chargement du contenu…").foregroundStyle(.secondary) } }
            }

            if !pieces.isEmpty {
                Section {
                    ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                        Text(piece).font(.subheadline)
                    }
                } header: {
                    Text("\(pieces.count) pièces")
                } footer: {
                    Text("Chaque pièce devient un sous-chapitre que vous pourrez cocher, noter et chronométrer.")
                }
            } else if !loading && item.kind != .piece {
                Section {
                    if OnlineCatalog.isAIAvailable {
                        Button { expand() } label: { Label("Retrouver le contenu avec l'IA", systemImage: "sparkles") }
                    }
                } footer: {
                    Text("Le détail de ce recueil n'est pas encore connu. Vous pourrez ajouter ses pièces ou une série numérotée après l'avoir ajouté.")
                }
            }

            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                add()
            } label: {
                Label(isAdded ? LocalizedStringKey("Dans mes partitions") : LocalizedStringKey("Ajouter à mes partitions"),
                      systemImage: isAdded ? "checkmark" : "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .disabled(isAdded || loading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .task {
            pieces = item.pieces ?? []
            if pieces.isEmpty, item.source == .itunes, item.kind == .collection, let remote = item.remoteID {
                loading = true
                pieces = await OnlineCatalog.albumTracks(remote)
                loading = false
            }
        }
    }

    private func add() {
        guard store.isPro || topLevelCount < Config.freeScoreLimit else {
            router.showPaywall = true
            return
        }
        Library.add(item, pieces: pieces, to: context)
    }

    private func expand() {
        guard store.isPro else {
            router.showPaywall = true
            return
        }
        loading = true
        message = nil
        Task {
            do {
                pieces = try await OnlineCatalog.expandWithAI(title: item.title, composer: item.composer)
                if pieces.isEmpty { message = String(localized: "Le contenu de ce recueil n'a pas été retrouvé.") }
            } catch {
                message = error.localizedDescription
            }
            loading = false
        }
    }
}
