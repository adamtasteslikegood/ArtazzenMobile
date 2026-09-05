import SwiftUI

struct AIFieldRow<Content: View>: View {
    let label: String
    let field: Artwork.AIField
    @Binding var artwork: Artwork
    @ViewBuilder var content: () -> Content

    @Environment(AppSession.self) private var session
    @State private var isRegenerating = false

    private var isAIGenerated: Bool {
        artwork.aiFields.contains(field)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.azMono)
                    .foregroundStyle(.secondary)
                Spacer()
                if isAIGenerated {
                    Text("AI")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.azViolet.opacity(0.15))
                        .foregroundStyle(Color.azViolet)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                Button {
                    isRegenerating = true
                    Task {
                        if let updated = await session.regenerate(
                            image: artwork.filename,
                            fields: [field]
                        ) {
                            artwork = updated
                        }
                        isRegenerating = false
                    }
                } label: {
                    if isRegenerating {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
                .tint(Color.azViolet)
            }
            content()
        }
    }
}
