import SwiftUI

/// The Widgets tab: the widget on the Home Screen, a way to add another, templates.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var adding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("On your Home Screen")
                            .font(.title2.bold())
                        NavigationLink {
                            EditorView()
                        } label: {
                            HStack(spacing: 14) {
                                WidgetPreviewCard(look: model.look, clock: model.clock, size: .medium)
                                    .frame(width: 140)
                                    .allowsHitTesting(false)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Launcher")
                                        .font(.headline)
                                    Text("Every launcher widget uses this look.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .glassPanel(cornerRadius: 26)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Start from a template")
                            .font(.title2.bold())
                        TemplateGrid()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("Widgets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        adding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityLabel("Add a widget")
                }
            }
            .sheet(isPresented: $adding) {
                NewWidgetView()
            }
        }
    }
}

/// The Templates tab.
struct TemplatesView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                TemplateGrid()
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("Templates")
        }
    }
}

/// How to put a widget on the Home Screen. iOS adds widgets only from its own gallery,
/// so the sheet explains the steps instead of adding anything itself.
struct AddWidgetSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Text("Aa")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundStyle(.tint)
                            .frame(width: 44, height: 44)
                            .glassPanel(cornerRadius: 12, tint: .accentColor.opacity(0.25))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launcher").font(.headline)
                            Text("Apps as words. Tap a word, open the app.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(cornerRadius: 22)

                    TutorialSteps()
                        .padding(18)
                        .glassPanel(cornerRadius: 26)
                }
                .padding(18)
            }
            .background(AppBackground())
            .navigationTitle("Add a Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
