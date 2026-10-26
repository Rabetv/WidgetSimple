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

/// The three steps from the Home Screen to a working widget.
struct TutorialSteps: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            step(1, "Touch and hold the Home Screen, then tap **Edit › Add Widget**.")
            step(2, "Search **WidgetSimple** and pick a size.")
            step(3, "Tap the widget's **Edit Widget** and choose your apps.")
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(number == 1 ? Color.black : Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Circle().fill(number == 1 ? Color.accentColor : Color.accentColor.opacity(0.18)))
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
