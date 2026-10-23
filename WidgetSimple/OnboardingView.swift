import SwiftUI

/// Shown once on first launch (and again from Settings): what the app does and the
/// three steps to put the widget on the Home Screen.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            WidgetPreviewCard(look: model.look, clock: model.clock, size: .medium)
                .allowsHitTesting(false)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your apps,\nas words.")
                    .font(.largeTitle.bold())
                Text("Three steps, once. After that you style everything here.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            TutorialSteps()
                .padding(18)
                .glassPanel(cornerRadius: 26)

            Spacer(minLength: 0)

            Button(action: done) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .background(AppBackground())
    }
}
