import ArtazzenCore
import SwiftUI

@MainActor
struct SwipeDeckView: View {
    @Environment(AppSession.self) private var session
    @State private var offset: CGSize = .zero

    private let threshold: CGFloat = 120

    private var pending: [Artwork] { session.pending }

    var body: some View {
        NavigationStack {
            ZStack {
                if session.isLoading && pending.isEmpty {
                    ProgressView("Loading review deck...")
                } else if pending.isEmpty {
                    ContentUnavailableView(
                        session.hasCredentials ? "No Pending Artwork" : "Connect in Settings",
                        systemImage: session.hasCredentials
                            ? "checkmark.circle" : "person.crop.circle.badge.questionmark",
                        description: Text(
                            session.hasCredentials
                                ? "All artwork has been reviewed."
                                : "Add admin credentials in Settings to load pending work."
                        )
                    )
                } else {
                    ScrollView {
                        ZStack(alignment: .top) {
                            ForEach(
                                Array(pending.prefix(3).enumerated().reversed()),
                                id: \.element.id
                            ) { index, artwork in
                                let isTop = (index == 0)
                                ReviewCard(artwork: artwork)
                                    .offset(isTop ? offset : CGSize(width: 0, height: 8))
                                    .rotationEffect(.degrees(isTop ? Double(offset.width) / 20 : 0))
                                    .scaleEffect(isTop ? 1.0 : 0.95, anchor: .top)
                                    .simultaneousGesture(
                                        DragGesture()
                                            .onChanged { value in
                                                guard
                                                    abs(value.translation.width)
                                                        > abs(value.translation.height)
                                                else { return }
                                                offset = CGSize(
                                                    width: value.translation.width, height: 0)
                                            }
                                            .onEnded { value in
                                                guard
                                                    abs(value.translation.width)
                                                        > abs(value.translation.height)
                                                else {
                                                    withAnimation(.spring()) { offset = .zero }
                                                    return
                                                }
                                                if value.translation.width > threshold {
                                                    approve()
                                                } else if value.translation.width < -threshold {
                                                    hide()
                                                } else {
                                                    withAnimation(.spring()) { offset = .zero }
                                                }
                                            }
                                    )
                                    .allowsHitTesting(isTop && session.mutations.isEmpty)
                                    .accessibilityHidden(!isTop)
                                    .animation(.spring(), value: offset)
                            }
                        }
                        .frame(maxWidth: 560)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !pending.isEmpty { reviewActions }
            }
            .navigationTitle("Review")
            .safeAreaInset(edge: .top) { SessionNotice() }
        }
    }

    private var reviewActions: some View {
        VStack(spacing: 8) {
            if !session.mutations.isEmpty {
                ProgressView("Approving...")
            } else {
                Text("\(pending.count) pending")
                    .font(.azMono)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 40) {
                Button(action: hide) {
                    Label("Hide", systemImage: "xmark.circle.fill")
                }
                .tint(Color.azOrange)
                .accessibilityHint("Hides this artwork for this session only")
                Button(action: approve) {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                }
                .tint(Color.azTeal)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!session.mutations.isEmpty)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func approve() {
        guard let artwork = pending.first, session.mutations.isEmpty else { return }
        withAnimation(.spring()) { offset = .zero }
        Task { await session.approve(artwork) }
    }

    private func hide() {
        guard let artwork = pending.first, session.mutations.isEmpty else { return }
        let generation = session.connectionID
        withAnimation(.easeOut(duration: 0.3)) {
            offset = CGSize(width: -500, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard generation == session.connectionID else { return }
            session.hide(artwork)
            offset = .zero
        }
    }
}
