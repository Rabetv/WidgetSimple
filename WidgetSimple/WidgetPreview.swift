import SwiftUI
import UIKit

/// The in-app preview of a layout, drawn at the real widget size when known.
struct WidgetPreview: View {
    @EnvironmentObject private var model: AppModel
    let layout: LauncherLayout
    var onTap: ((LaunchItem) -> Void)? = nil

    @State private var lightImage: UIImage?
    @State private var darkImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            let target = previewSize(available: geo.size.width)
            let scale = min(1, geo.size.width / max(target.width, 1))
            ZStack {
                if layout.background.mode == .clear {
                    ClearBackdrop()
                }
                WidgetBackgroundView(layout: layout, lightImage: lightImage, darkImage: darkImage)
                LauncherCanvas(layout: layout, mode: .preview(onTap: onTap))
            }
            .frame(width: target.width, height: target.height)
            .clipShape(RoundedRectangle(cornerRadius: WidgetSizing.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WidgetSizing.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(scale, anchor: .top)
            .frame(width: geo.size.width, height: target.height * scale, alignment: .top)
        }
        .frame(height: scaledHeight)
        .task(id: imageKey) { loadImages() }
    }

    private var scaledHeight: CGFloat {
        let size = previewSize(available: ScreenInfo.width - 40)
        return size.height * min(1, (ScreenInfo.width - 40) / max(size.width, 1))
    }

    private var imageKey: String {
        "\(layout.id)-\(layout.background.imageVersion)-\(layout.background.mode.rawValue)"
    }

    private func previewSize(available: CGFloat) -> CGSize {
        if let real = model.metrics.size(for: layout.size) { return real }
        return WidgetSizing.estimatedSize(for: layout.size, screenWidth: ScreenInfo.width)
    }

    private func loadImages() {
        guard layout.background.mode == .wallpaper else {
            lightImage = nil
            darkImage = nil
            return
        }
        lightImage = layout.background.hasLightImage ? model.store.loadBackground(layoutID: layout.id, dark: false) : nil
        darkImage = layout.background.hasDarkImage ? model.store.loadBackground(layoutID: layout.id, dark: true) : nil
    }
}

/// What a clear widget shows in the app: a stand-in for the wallpaper.
struct ClearBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.16, green: 0.20, blue: 0.32), Color(red: 0.36, green: 0.24, blue: 0.38)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum ScreenInfo {
    @MainActor static var bounds: CGRect {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return scene?.screen.bounds ?? CGRect(x: 0, y: 0, width: 393, height: 852)
    }

    @MainActor static var width: CGFloat { bounds.width }

    @MainActor static var scale: CGFloat {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return scene?.screen.scale ?? 3
    }
}
