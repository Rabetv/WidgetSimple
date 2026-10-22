import SwiftUI

/// Look of the Clock widget (one style for all clock widgets).
struct ClockEditorView: View {
    @EnvironmentObject private var model: AppModel
    @State private var size: WidgetSizeOption = .medium

    var body: some View {
        List {
            Section {
                ClockPreview(style: model.clock, size: size)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                Picker("Size", selection: $size) {
                    ForEach(WidgetSizeOption.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Add it: hold the Home Screen › Edit › Add Widget › WidgetSimple › Clock.")
            }

            Section("Text") {
                NavigationLink {
                    FontPickerView(selection: $model.clock.fontID, previewSize: 24)
                } label: {
                    HStack {
                        Text("Font")
                        Spacer()
                        Text(FontCatalog.displayName(for: model.clock.fontID))
                            .font(FontCatalog.font(id: model.clock.fontID, size: 16))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Picker("Weight", selection: $model.clock.weight) {
                    ForEach(FontWeightOption.allCases) { Text($0.title).tag($0) }
                }
                ColorPicker("Color", selection: Binding(
                    get: { model.clock.color.color },
                    set: { model.clock.color = RGBA($0) }
                ), supportsOpacity: false)
            }

            Section("Background") {
                ColorSwatches(selection: $model.clock.background)
                NavigationLink {
                    NoEdgesView()
                } label: {
                    Label("Hide the edges", systemImage: "square.dashed")
                }
            }
        }
        .navigationTitle("Clock")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The clock at its real widget size, ticking every minute.
private struct ClockPreview: View {
    @EnvironmentObject private var model: AppModel
    let style: ClockStyle
    let size: WidgetSizeOption

    var body: some View {
        let target = model.metrics.size(for: size)
            ?? WidgetSizing.estimatedSize(for: size, screenWidth: ScreenInfo.width)
        TimelineView(.everyMinute) { context in
            ClockFace(date: context.date, style: style, size: size)
                .frame(width: target.width, height: target.height)
                .background(style.background.color)
                .clipShape(RoundedRectangle(cornerRadius: WidgetSizing.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: WidgetSizing.cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }
}
