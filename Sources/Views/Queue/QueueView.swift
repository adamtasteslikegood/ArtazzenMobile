import ArtazzenCore
import SwiftUI

@MainActor
struct QueueView: View {
    @Environment(AppSession.self) private var session
    @State private var searchText = ""
    @State private var statusFilter: Artwork.ArtworkStatus? = .pending

    var filtered: [Artwork] {
        let source = session.pending + session.gallery
        return source.filter { art in
            if let filter = statusFilter, art.status != filter { return false }
            if searchText.isEmpty { return true }
            let q = searchText.lowercased()
            return art.title.lowercased().contains(q)
                || art.description.lowercased().contains(q)
                || art.filename.lowercased().contains(q)
                || art.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.isLoading && session.pending.isEmpty && session.gallery.isEmpty {
                    ProgressView("Loading queue...")
                } else if let error = session.lastError, filtered.isEmpty {
                    ContentUnavailableView {
                        Label("Queue Unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { Task { await session.refresh() } }
                    }
                } else if filtered.isEmpty {
                    ContentUnavailableView {
                        Label("No Artwork", systemImage: "list.bullet")
                    } description: {
                        Text(
                            session.hasCredentials
                                ? "Nothing matches this filter. Pull to refresh after capturing."
                                : "Add the artazzen.com admin URL and credentials in Settings."
                        )
                    }
                } else {
                    List(filtered) { artwork in
                        NavigationLink(value: artwork) {
                            QueueCard(artwork: artwork)
                        }
                    }
                }
            }
            .navigationTitle("Queue")
            .safeAreaInset(edge: .top) { SessionNotice() }
            .searchable(text: $searchText, prompt: "Search artwork")
            .refreshable { await session.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All") { statusFilter = nil }
                        ForEach(Artwork.ArtworkStatus.allCases, id: \.self) { s in
                            Button(s.rawValue.capitalized) { statusFilter = s }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .navigationDestination(for: Artwork.self) { artwork in
                ArtworkDetailView(artwork: artwork)
            }
        }
    }
}
