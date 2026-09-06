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
                    ForEach(
                        Array(pending.prefix(3).enumerated().reversed()),
                        id: \.element.id
                    ) { index, artwork in
                        let isTop = (index == 0)
                        ReviewCard(artwork: artwork)
                            .offset(isTop ? offset : .zero)
                            .rotationEffect(.degrees(isTop ? Double(offset.width) / 20 : 0))
                            .scaleEffect(isTop ? 1.0 : 0.95)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = value.translation
                                    }
                                    .onEnded { value in
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
                            .animation(.spring(), value: offset)
                    }

                    VStack {
                        Spacer()
                        if !session.mutations.isEmpty {
                            ProgressView("Approving...")
                        }
                        HStack(spacing: 48) {
                            Button {
                                hide()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color.azOrange)
                            }
                            Button {
                                approve()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color.azTeal)
                            }
                        }
                        .padding(.bottom, 32)
                        .disabled(!session.mutations.isEmpty)
                    }
                }
            }
            .navigationTitle("Review")
            .safeAreaInset(edge: .top) { SessionNotice() }
        }
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
