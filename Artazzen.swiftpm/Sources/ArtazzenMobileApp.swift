import ArtazzenCore
import SwiftUI

@main
@MainActor
struct ArtazzenMobileApp: App {
    @State private var session = AppSession()
    @AppStorage(SettingsStorage.darkMode) private var darkMode = false

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(session)
                .preferredColorScheme(darkMode ? .dark : .light)
                .task {
                    await session.refresh()
                }
        }
    }
}
