import SwiftUI

@main
struct SceneJournalApp: App {
    @AppStorage("scene_journal_has_seen_onboarding") private var hasSeenOnboarding = false
    @State private var isShowingOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .fullScreenCover(isPresented: $isShowingOnboarding) {
                    OnboardingView {
                        hasSeenOnboarding = true
                        isShowingOnboarding = false
                    }
                }
                .onAppear {
                    if !hasSeenOnboarding {
                        isShowingOnboarding = true
                    }
                }
        }
    }
}
