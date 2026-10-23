import SwiftUI
import UIKit

/// The whole app: a live preview of the widget and every control that styles it.
/// The widget itself is see-through, so there is no wallpaper setup here — only
/// the look, the clock, and the hint that the apps are picked in Edit Widget.
struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                appsSection
                clockSection
                styleSection
            }
            .navigationTitle("WidgetSimple")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Sections

    private var previewSection: some View {
        Section {
            WidgetPreviewCard(look: model.look, clock: model.clock)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } header: {
            Text("Preview")
        } footer: {
            Text("The widget is see-through — the wallpaper shows behind the words. Add it once from the Home Screen and style it here.")
        }
    }

    private var appsSection: some View {
        Section {
            Label("Hold the widget › Edit Widget to pick the apps.", systemImage: "hand.tap")
            Label("A tap on a word opens that app directly.", systemImage: "arrow.up.forward.app")
            Label("Every widget can open a different set.", systemImage: "square.grid.2x2")
        } header: {
            Text("Apps")
        } footer: {
            Text("iOS only lets the system fill the app list, so it lives in Edit Widget.")
        }
    }

    private var clockSection: some View {
        Section("Clock") {
            Picker("Clock", selection: $model.clock) {
                ForEach(ClockOption.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var styleSection: some View {
        Section {
            NavigationLink {
                FontPickerView(selection: $model.look.fontID)
            } label: {
                LabeledContent("Font", value: FontCatalog.displayName(for: model.look.fontID))
            }

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Size", value: "\(Int(model.look.size)) pt")
                Slider(value: $model.look.size, in: 12...34, step: 1)
            }

            Picker("Alignment", selection: $model.look.align) {
                ForEach(TextAlign.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Position", selection: $model.look.vAlign) {
                ForEach(TextVAlign.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Arrangement", selection: $model.look.arrangement) {
                ForEach(Arrangement.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if model.look.arrangement == .free {
                Picker("Clock position", selection: $model.look.clockPosition) {
                    ForEach(WidgetPosition.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)

                nudge("Clock nudge", x: $model.look.clockDX, y: $model.look.clockDY)

                Picker("Apps position", selection: $model.look.appsPosition) {
                    ForEach(WidgetPosition.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)

                nudge("Apps nudge", x: $model.look.appsDX, y: $model.look.appsDY)
            }

            Picker("Letter case", selection: $model.look.letterCase) {
                ForEach(LetterCase.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Color", selection: $model.look.tone) {
                ForEach(TextTone.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if model.look.tone == .custom {
                ColorPicker("Custom color", selection: customColorBinding, supportsOpacity: false)
            }

            Toggle("Shadow", isOn: $model.look.shadow)

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Spacing", value: String(format: "%.1f×", model.look.spacing))
                Slider(value: $model.look.spacing, in: 0.6...2.0, step: 0.1)
            }
        } header: {
            Text("Style")
        }
    }

    /// Two sliders that move a block by points on top of its anchor.
    private func nudge(_ title: String, x: Binding<Double>, y: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(title, value: "\(Int(x.wrappedValue)), \(Int(y.wrappedValue)) pt")
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: x, in: -80...80, step: 1)
            }
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.and.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: y, in: -80...80, step: 1)
            }
        }
    }

    /// The custom colour, kept as a hex string in the look.
    private var customColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: model.look.customHex) },
            set: { model.look.customHex = $0.toHex() }
        )
    }
}

// MARK: - Preview

/// The widget as it will look on the Home Screen: just the words.
private struct WidgetPreviewCard: View {
    let look: Look
    let clock: ClockOption

    var body: some View {
        TimelineView(.everyMinute) { context in
            LauncherFace(look: look, clock: clock, date: context.date, size: .medium,
                         apps: ["Phone", "Messages", "Music"], color: look.color)
        }
        .aspectRatio(338.0 / 158.0, contentMode: .fit)
        .padding(18)
        .background(LinearGradient.sampleWallpaper)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: look)
        .frame(maxWidth: .infinity)
    }
}

private extension LinearGradient {
    /// Stands in for a wallpaper in the app's preview.
    static let sampleWallpaper = LinearGradient(
        colors: [Color(red: 0.98, green: 0.55, blue: 0.45), Color(red: 0.45, green: 0.35, blue: 0.85)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

private extension Color {
    /// "#RRGGBB", matching the decoder in `Models.swift`.
    func toHex() -> String {
        let ui = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X",
                      Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}
