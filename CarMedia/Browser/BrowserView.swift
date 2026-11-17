// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import SwiftUI
import SwiftData
import WebKit

struct BrowserView: View {
    @StateObject private var model = BrowserModel.shared
    @Environment(\.modelContext) private var context
    @Query private var favorites: [Favorite]
    @Query(sort: \HistoryEntry.visitedAt, order: .reverse) private var history: [HistoryEntry]

    @State private var address: String = ""
    @State private var showFavorites = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                if let err = model.loadError {
                    errorBanner(err)
                }
                WebViewHost(model: model)
                    .overlay {
                        if model.isLoading { ProgressView().controlSize(.large) }
                    }
                quickLinksBar
            }
            .navigationTitle("Navegador")
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { model.goBack() } label: { Image(systemName: "chevron.backward") }
                        .disabled(!model.canGoBack)
                    Button { model.goForward() } label: { Image(systemName: "chevron.forward") }
                        .disabled(!model.canGoForward)
                    Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                    Button { model.goHome() } label: { Image(systemName: "house") }
                    Spacer()
                    Button { addFavorite() } label: { Image(systemName: "star") }
                        .disabled(model.currentURL == nil)
                    Menu {
                        Button("Favoritos") { showFavorites = true }
                        Button("Histórico") { showHistory = true }
                        NavigationLink("Adicionar…") { AddFavoriteSheet(model: model) }
                    } label: { Image(systemName: "square.and.arrow.up") }
                }
            }
            .sheet(isPresented: $showFavorites) { FavoritesList() }
            .sheet(isPresented: $showHistory) { HistoryList(model: model) }
            .environment(\.modelContext, Persistence.container.mainContext)
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("URL ou pesquisa", text: $address)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { model.submit(address) }
            Button("Ir") { model.submit(address) }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private func errorBanner(_ err: BrowserModel.BrowserError) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(err.message).font(.footnote)
            Spacer()
            Button { model.loadError = nil } label: { Image(systemName: "xmark.circle") }
        }
        .padding(8)
        .background(.yellow.opacity(0.15))
    }

    private var quickLinksBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(QuickLinks.all) { link in
                    VStack(alignment: .leading, spacing: 2) {
                        Button(link.name) {
                            address = link.url
                            model.submit(link.url)
                        }
                        .buttonStyle(.bordered)
                        if let note = QuickLinks.drmNote(for: link) {
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 150, alignment: .leading)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }

    private func addFavorite() {
        guard let url = model.currentURL else { return }
        let ctx = Persistence.container.mainContext
        // URL is not a #Predicate operand in SwiftData — dedupe client-side.
        let all = (try? ctx.fetch(FetchDescriptor<Favorite>())) ?? []
        if all.contains { $0.url == url } { return }
        ctx.insert(Favorite(url: url, title: model.pageTitle.isEmpty ? url.host ?? "" : model.pageTitle))
        try? ctx.save()
    }
}

// MARK: - WebView host

struct WebViewHost: UIViewRepresentable {
    @ObservedObject var model: BrowserModel
    func makeUIView(context: Context) -> WKWebView { model.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Favorites

struct FavoritesList: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Favorite.addedAt, order: .reverse) private var favorites: [Favorite]

    var body: some View {
        NavigationStack {
            List {
                ForEach(favorites) { fav in
                    FavoriteRow(favorite: fav)
                        .swipeActions {
                            Button(role: .destructive) {
                                context.delete(fav); try? context.save()
                            } label: { Label("Remover", systemImage: "trash") }
                        }
                }
            }
            .overlay { if favorites.isEmpty { ContentUnavailableView("Sem favoritos", systemImage: "star", description: Text("Toque na estrela ao navegar.")) } }
            .navigationTitle("Favoritos")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
            .environment(\.modelContext, Persistence.container.mainContext)
        }
    }
}

struct FavoriteRow: View {
    @Bindable var favorite: Favorite
    @Environment(\.modelContext) private var context
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Nome", text: $favorite.title)
                .textFieldStyle(.plain)
                .font(.headline)
            Text(favorite.url.absoluteString)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .onDisappear { try? context.save() }   // edits persist
    }
}

struct AddFavoriteSheet: View {
    @ObservedObject var model: BrowserModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            if let url = model.currentURL {
                Button("Salvar «\((model.pageTitle.isEmpty ? url.host ?? "" : model.pageTitle))»") {
                    let ctx = Persistence.container.mainContext
                    ctx.insert(Favorite(url: url, title: model.pageTitle))
                    try? ctx.save()
                    dismiss()
                }
            } else {
                Text("Nenhuma página carregada").foregroundStyle(.secondary)
            }
        }
        .environment(\.modelContext, Persistence.container.mainContext)
    }
}

// MARK: - History

struct HistoryList: View {
    @ObservedObject var model: BrowserModel
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \HistoryEntry.visitedAt, order: .reverse) private var history: [HistoryEntry]

    var body: some View {
        NavigationStack {
            List {
                ForEach(history) { entry in
                    Button {
                        model.load(entry.url)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(entry.title).font(.headline).lineLimit(1)
                            Text(entry.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            Text(entry.visitedAt, style: .date).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { idx in
                    let ctx = Persistence.container.mainContext
                    idx.map { history[$0] }.forEach(ctx.delete)
                    try? ctx.save()
                }
            }
            .overlay { if history.isEmpty { ContentUnavailableView("Sem histórico", systemImage: "clock") } }
            .navigationTitle("Histórico")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Limpar", role: .destructive) {
                        let ctx = Persistence.container.mainContext
                        history.forEach(ctx.delete); try? ctx.save()
                    }
                }
            }
            .environment(\.modelContext, Persistence.container.mainContext)
        }
    }
}
