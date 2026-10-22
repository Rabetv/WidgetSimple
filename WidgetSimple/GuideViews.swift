import SwiftUI

struct GlassGuideView: View {
    var body: some View {
        List {
            Section {
                Text("New layouts use the Transparent background: the widget draws no background at all, so your wallpaper shows straight through and only the words are visible. Nothing has to be lined up, any wallpaper works, and you can keep motion effects on.")
                Text("This needs iOS 26 or later. Older iOS versions always painted a widget background.")
            } header: {
                Text("How it works")
            }

            Section {
                GuideStep(number: 1, text: "Default style (Light, Dark or Automatic): your text keeps its exact fonts and colors and sits right on the wallpaper. Start here.")
                GuideStep(number: 2, text: "Clear style (long-press › Edit › Customize › Clear, then Light): the most see-through look iOS offers; widgets get a very light clear glass. iOS normally turns widget text white here; WidgetSimple keeps your colors (toggle in each layout's Background).")
                GuideStep(number: 3, text: "Tinted style works too, but tints everything around your words.")
            } header: {
                Text("Which Home Screen style")
            }

            Section {
                Text("iOS 26 and 27 draw a thin glass edge on top of every widget. A widget can't paint over it, but the edge only shows the wallpaper behind it, bent and highlighted.")
                Text("To make it disappear: open a layout › Background › Hide the glass edge. WidgetSimple saves a flat wallpaper and fills the widget with exactly the same color, so the glass has nothing to show. It also walks you through the iPhone settings that matter and can fine-tune the color from a screenshot.")
                Text("With a transparent widget on a photo wallpaper the edge stays faint; calm or darker wallpapers hide it best.")
                Text("If your iPhone shows a solid box instead of your wallpaper, use Background › Wallpaper copy for that layout as a fallback.")
            } header: {
                Text("The glass edge")
            }

            Section {
                Text("The name under a widget is the app's Home Screen name. This build uses an invisible name, so the widget has no label.")
                Text("Alternative that hides every label: long-press › Edit › Customize › choose the large icon size.")
            } header: {
                Text("No name under the widget")
            }
        }
        .navigationTitle("Transparent widgets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AddWidgetGuideView: View {
    var body: some View {
        List {
            Section {
                GuideStep(number: 1, text: "Design a layout in WidgetSimple (add apps, pick fonts and sizes).")
                GuideStep(number: 2, text: "Go to the Home Screen, long-press an empty spot until the icons wiggle, tap Edit › Add Widget.")
                GuideStep(number: 3, text: "Scroll to WidgetSimple (black “Aa” icon), choose Text Launcher, swipe to Medium (or Large) and tap Add Widget.")
                GuideStep(number: 4, text: "Long-press the new widget › Edit Widget › Layout › pick your layout.")
                GuideStep(number: 5, text: "New layouts are transparent, so the words sit right on your wallpaper. See “Transparent widgets” for the best Home Screen style.")
            } header: {
                Text("Add the widget")
            }
            Section {
                Text("Make several layouts and add several widgets, e.g. one at the top and one at the bottom of a page, each with its own background match.")
            } header: {
                Text("Several widgets")
            }
        }
        .navigationTitle("Add the widget")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LaunchSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                Picker("Launch method", selection: $model.settings.launchMethod) {
                    ForEach(LaunchMethod.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("When you tap a word on the widget")
            } footer: {
                Text(footer)
            }

            Section {
                Text("Automatic: websites and universal links open straight from the widget. App links (like spotify://) go through WidgetSimple, which forwards the tap instantly on a black screen. This is the only method Apple documents for opening any app from a widget.")
                Text("Always direct: also sends app links straight to iOS. On recent iOS versions this skips WidgetSimple completely, but Apple doesn't guarantee it for other apps' links. If a tap does nothing, switch back to Automatic.")
                Text("Always via WidgetSimple: every tap goes through the app. Most compatible.")
            } header: {
                Text("Details")
            }
        }
        .navigationTitle("How apps open")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var footer: String {
        switch model.settings.launchMethod {
        case .auto: return "Recommended."
        case .direct: return "Experimental. Test each app on your iPhone."
        case .viaApp: return "Every tap briefly opens WidgetSimple first."
        }
    }
}

struct GuideStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold().monospacedDigit())
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
