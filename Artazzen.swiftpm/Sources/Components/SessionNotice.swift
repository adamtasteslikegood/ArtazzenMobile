import ArtazzenCore
import SwiftUI

@MainActor
struct SessionNotice: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        VStack(spacing: 6) {
            if let error = session.lastError {
                Text(error).foregroundStyle(.red)
                Button("Refresh Artwork") { Task { await session.refresh() } }
            }
            if let error = session.collectionsError {
                Text(error).foregroundStyle(.orange)
                Button("Retry Collections") { Task { await session.retryCollections() } }
            }
            if let error = session.configError {
                Text(error).foregroundStyle(.orange)
                Button("Retry AI Settings") { Task { await session.retryConfig() } }
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .background(.regularMaterial)
    }
}
