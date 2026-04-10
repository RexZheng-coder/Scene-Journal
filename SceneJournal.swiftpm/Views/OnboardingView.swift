import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Capture Any Live Moment",
            subtitle: "Journal concerts, Broadway, and everyday scenes in one place.",
            screenshotName: "first_page",
            fallbackSystemImage: "sparkles.rectangle.stack.fill",
            color: .indigo
        ),
        OnboardingPage(
            title: "Find Places on Maps",
            subtitle: "Use Find on Maps to choose a location and preview it instantly.",
            screenshotName: "maps",
            fallbackSystemImage: "map.circle.fill",
            color: .teal
        ),
        OnboardingPage(
            title: "Keep Memories Rich",
            subtitle: "Add photos, smart highlights, and export your entries as a single PDF.",
            screenshotName: "share_pdf",
            fallbackSystemImage: "photo.on.rectangle.angled",
            color: .pink
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.cyan.opacity(0.15), Color.indigo.opacity(0.16), Color.teal.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingCard(page: page)
                            .tag(index)
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.snappy(duration: 0.25, extraBounce: 0)) {
                            currentPage += 1
                        }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(pages[currentPage].color)
                .accessibilityLabel(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                .accessibilityHint(currentPage == pages.count - 1 ? "Finish onboarding and open Scene Journal" : "Go to the next onboarding page")
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct OnboardingCard: View {
    let page: OnboardingPage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            screenshotBlock

            Text(page.title)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 0.8)
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var screenshotBlock: some View {
        if let uiImage = onboardingImage(named: page.screenshotName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(page.title) preview screenshot")
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.4), lineWidth: 0.8)
                )
        } else {
            Image(systemName: page.fallbackSystemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(page.color)
                .padding(12)
                .background(page.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func onboardingImage(named fileName: String) -> UIImage? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "png", subdirectory: "Onboarding") {
            return UIImage(contentsOfFile: url.path)
        }
        if let url = Bundle.main.url(forResource: fileName, withExtension: "png") {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let screenshotName: String
    let fallbackSystemImage: String
    let color: Color
}
