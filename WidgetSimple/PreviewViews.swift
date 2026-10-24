import SwiftUI
import UIKit

/// Draws `content` at a widget's real point size and scales the result to the space
/// available. Text is laid out exactly as on the Home Screen, then shrunk as a picture.
struct ScaledCanvas<Content: View>: View {
    let size: CGSize
    var maxScale: CGFloat = 1.6
    @ViewBuilder let content: (CGFloat) -> Content

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / max(size.width, 1), geo.size.height / max(size.height, 1), maxScale)
            content(scale)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(size.width / max(size.height, 1), contentMode: .fit)
    }
}

/// The widget as it will look on the Home Screen: the same `LauncherFace`, at the size the
/// widget reported, over this widget size's matched piece of the person's wallpaper.
struct WidgetPreviewCard: View {
    let look: Look
    let clock: ClockOption
    let size: FaceSize
    var apps: [String] = ["Phone", "Messages", "Music"]
    var layout: LayoutDocument? = nil
    /// True for template thumbnails: a neutral panel instead of the wallpaper, so six
    /// cards do not all show the same picture.
    var plainBackdrop = false

    var body: some View {
        let geometry = FaceMetrics.geometry(for: size)
        ScaledCanvas(size: geometry.size) { _ in
            ZStack {
                if plainBackdrop {
                    LinearGradient(colors: [look.color.opacity(0.30), Color.black.opacity(0.55)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    PreviewBackdrop(size: size)
                }
                TimelineView(.everyMinute) { context in
                    LauncherFace(look: look, clock: clock, date: context.date, size: size,
                                 apps: apps, color: look.color, layout: layout,
                                 insets: FaceMetrics.margins(geometry))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .animation(.easeInOut(duration: 0.2), value: look)
        .frame(maxWidth: .infinity)
    }

    /// The Home Screen widget corner radius, near enough for a preview.
    static let cornerRadius: CGFloat = 22
}

/// What sits behind the preview: this size's matched piece, else the middle of the
/// wallpaper screenshot, else the app's background art.
struct PreviewBackdrop: View {
    let size: FaceSize
    @EnvironmentObject private var model: AppModel
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image("AppBackground").resizable().scaledToFill()
            }
        }
        .task(id: "\(size.rawValue)-\(model.seeThrough.generation ?? "none")-\(model.seeThrough.hasWallpaper)") {
            image = Self.load(size: size)
        }
    }

    private static func load(size: FaceSize) -> UIImage? {
        let store = SharedStore.shared
        if let piece = store.previewSpotImage(family: size.spotFamily) { return piece }
        guard let data = store.loadWallpaper(), let wallpaper = UIImage(data: data)?.cgImage else { return nil }
        let geometry = FaceMetrics.geometry(for: size)
        let scale = CGFloat(wallpaper.width) / max(FaceMetrics.screenWidth, 1)
        let w = geometry.size.width * scale, h = geometry.size.height * scale
        let rect = CGRect(x: (CGFloat(wallpaper.width) - w) / 2, y: (CGFloat(wallpaper.height) - h) / 2,
                          width: w, height: h).integral
        return wallpaper.cropping(to: rect).map { UIImage(cgImage: $0) }
    }
}

// MARK: - Layout harness

/// Every widget size × app count × text size, drawn at real point sizes, with what the
/// planner reports: fits, shrunk (and by how much), or names overlapping. This is the
/// check for "no clipping, no overlap" without a device.
struct PreviewHarnessView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var clock: ClockOption = .time

    private static let counts = [1, 2, 4, 8, 12]
    private static let textSizes: [Double] = [17, 21, 26]
    private static let sampleNames = ["Phone", "Messages", "Camera", "Music", "Maps", "Calendar",
                                      "Photos", "Settings", "Weather", "Notes", "Reminders", "App Store"]

    var body: some View {
        List {
            Section {
                Picker("Clock", selection: $clock) {
                    ForEach(ClockOption.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Uses your font, colour and spacing. Sizes come from your widgets once they have run.")
            }
            .listRowBackground(GlassRowBackground())

            ForEach(FaceSize.allCases) { size in
                Section(size.title) {
                    ForEach(Self.textSizes, id: \.self) { textSize in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: Spacing.s) {
                                ForEach(Self.counts, id: \.self) { count in
                                    cell(size: size, textSize: textSize, count: count)
                                }
                            }
                            .padding(.vertical, Spacing.xxs)
                        }
                    }
                }
                .listRowBackground(GlassRowBackground())
            }
        }
        .glassList()
        .navigationTitle("Layout check")
    }

    private func cell(size: FaceSize, textSize: Double, count: Int) -> some View {
        var look = model.look
        look.size = textSize
        let names = Array(Self.sampleNames.prefix(count))
        let verdict = Self.verdict(look: look, clock: clock, size: size, names: names,
                                   typeFactor: Typography.dynamicFactor(dynamicTypeSize))
        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            WidgetPreviewCard(look: look, clock: clock, size: size, apps: names)
                .frame(width: size == .small ? 120 : 220)
                .allowsHitTesting(false)
            Text("\(count) · \(Int(textSize)) pt · \(verdict.text)")
                .font(.caption2)
                .foregroundStyle(verdict.ok ? Color.secondary : Color.orange)
        }
    }

    /// What the planner did with this combination.
    static func verdict(look: Look, clock: ClockOption, size: FaceSize, names: [String],
                        typeFactor: Double) -> (ok: Bool, text: String) {
        let geometry = FaceMetrics.geometry(for: size)
        let input = FacePlanInput(canvas: geometry.size, insets: FaceMetrics.margins(geometry), size: size,
                                  look: look, layout: nil, names: names,
                                  clock: ClockContent.make(date: .now, option: clock, size: size),
                                  typeFactor: typeFactor)
        let plan = FacePlanner.plan(input)
        var frames = plan.names.map(\.frame)
        if let clockFrame = plan.clock?.frame { frames.append(clockFrame) }
        let overlapping = frames.indices.contains { i in
            frames.indices.contains { j in j > i && FacePlanner.overlap(frames[i], frames[j]) > 0.01 }
        }
        let bounds = CGRect(origin: .zero, size: geometry.size).insetBy(dx: -0.5, dy: -0.5)
        let outside = frames.contains { !bounds.contains($0) }
        if overlapping { return (false, String(localized: "overlap")) }
        if outside { return (false, String(localized: "clipped")) }
        if plan.scale < 0.999 { return (plan.scale >= Typography.minimumScale, String(localized: "shrunk to \(Int(plan.scale * 100))%")) }
        return (true, String(localized: "fits"))
    }
}
