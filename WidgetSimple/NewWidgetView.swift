import SwiftUI

/// The New Widget sheet from the design: a surface switcher and every widget type as a
/// card. Types that are only designed are dimmed and do not open.
struct NewWidgetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var surface: WidgetSurface = .home
    @State private var selected: WidgetType?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            HStack {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 17))
                Spacer()
                Text("New Widget")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Color.clear.frame(width: 52, height: 1)
            }

            surfacePicker

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(WidgetType.on(surface)) { type in
                        card(type)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background {
            ZStack {
                AppBackground()
                Rectangle().fill(.white.opacity(0.09))
            }
            .ignoresSafeArea()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(item: $selected) { type in
            TypeDetailView(type: type) { dismiss() }
                .presentationDetents([.medium])
        }
    }

    private var surfacePicker: some View {
        HStack(spacing: 2) {
            ForEach(WidgetSurface.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { surface = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(surface == item ? .white.opacity(0.30) : .clear)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
        }
    }

    private func card(_ type: WidgetType) -> some View {
        Button {
            if type.available { selected = type }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(type.glyph)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#FFC766"))
                        .frame(width: 32, height: 32)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(hex: "#FFC766").opacity(0.22))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color(hex: "#FFC766").opacity(0.35), lineWidth: 1)
                                }
                        }
                    Spacer(minLength: 0)
                }
                Text(type.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(type.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
            }
            .opacity(type.available ? 1 : 0.38)
        }
        .buttonStyle(.plain)
        .disabled(!type.available)
        .accessibilityLabel("\(type.name). \(type.detail)")
    }
}

/// What to do with a type that is built: how to put it on the Home Screen.
struct TypeDetailView: View {
    let type: WidgetType
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(type.name).font(.title2.bold())
                    Text(type.detail).foregroundStyle(.secondary)
                    if let gallery = type.galleryName {
                        Text("In the widget gallery it is called \(gallery).")
                            .font(.footnote)
                    }
                    TutorialSteps()
                        .padding(16)
                        .glassPanel(cornerRadius: 24)
                }
                .padding(18)
            }
            .background(AppBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss(); onClose() }
                }
            }
        }
    }
}
