import ArtazzenCore
import SwiftUI

@MainActor
struct GalleryView: View {
    @Environment(AppSession.self) private var session
    @State private var searchText = ""
    @State private var selectedCollection: String?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var filtered: [Artwork] {
        session.gallery.filter { art in
            art.status == .approved
                && (selectedCollection == nil || art.collection == selectedCollection)
                && (searchText.isEmpty
                    || art.title.lowercased().contains(searchText.lowercased()))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.isLoading && session.gallery.isEmpty {
                    ProgressView("Loading gallery...")
                } else if filtered.isEmpty {
                    ContentUnavailableView(
                        session.hasCredentials ? "No Approved Artwork" : "Connect in Settings",
                        systemImage: "photo.on.rectangle",
                        description: Text(
                            session.hasCredentials
                                ? "Approved pieces from artazzen.com will show up here."
                                : "Add admin credentials to load the live gallery."
                        )
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filtered) { artwork in
                                NavigationLink(value: artwork) {
                                    GalleryGrid.Cell(artwork: artwork)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Gallery")
            .safeAreaInset(edge: .top) { SessionNotice() }
            .searchable(text: $searchText, prompt: "Search artwork")
            .refreshable { await session.refresh() }
            .toolbar {
                if !session.collections.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("All Collections") { selectedCollection = nil }
                            ForEach(session.collections) { col in
                                Button(col.displayName) { selectedCollection = col.id }
                            }
                        } label: {
                            Label("Collection", systemImage: "folder")
                        }
                    }
                }
            }
            .navigationDestination(for: Artwork.self) { artwork in
                ArtworkDetailView(artwork: artwork)
            }
        }
    }
}
