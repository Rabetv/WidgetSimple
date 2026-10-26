import SwiftUI

/// The app's one background: an original drawing of brown and copper folds, kept as
/// vector art in the asset catalog. Every surface on top of it is Liquid Glass.
struct AppBackground: View {
    var body: some View {
        Image("AppBackground")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

extension View {
    /// A Liquid Glass panel in a rounded rectangle, optionally tinted.
    func glassPanel(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular,
                    in: .rect(cornerRadius: cornerRadius, style: .continuous))
    }
}
