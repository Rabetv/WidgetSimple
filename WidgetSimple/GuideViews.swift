import SwiftUI

struct GlassGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Since iOS 26, the system draws a thin Liquid Glass outline around every Home Screen widget. iOS 27 keeps it. There is no setting or developer API that turns it off for third-party widgets.")
                Text("WidgetSimple works around it: it gives the widget a background that is an exact copy of the wallpaper behind it. The outline then sits on identical pixels, so you just see text on your wallpaper.")
            } header: {
                Text("What's going on")
            }

            Section {
                GuideStep(number: 1, text: "Home Screen style must be Default: long-press the Home Screen › Edit › Customize › Default (Light/Dark/Auto). With Clear or Tinted, iOS replaces every widget background with glass and nothing can prevent that.")
                GuideStep(number: 2, text: "Edit Wallpaper › turn Blur off.")
                GuideStep(number: 3, text: "Settings › Accessibility › Motion › Reduce Motion ON. Otherwise the wallpaper shifts slightly when you tilt the phone and the match drifts.")
                GuideStep(number: 4, text: "Settings › Accessibility › Display & Text Size › Reduce Transparency and Increase Contrast OFF.")
                GuideStep(number: 5, text: "Open a layout › Background › Match wallpaper and follow the three steps (wallpaper screenshot, magenta screenshot, apply).")
            } header: {
                Text("Do this once")
            }

            Section {
                Text("Simple, dark or single-color wallpapers hide the outline best. Busy photos work too, but the faint highlight is easier to spot at the top and bottom edge.")
                Text("With a plain one-color wallpaper you can skip the screenshots: choose Background › Solid color and pick exactly the wallpaper color (or use the eyedropper).")
                Text("Moved the widget or changed the wallpaper? Repeat the steps for that layout.")
            } header: {
                Text("Tips")
            }

            Section {
                Text("The name under a widget is the app's Home Screen name. This build uses an invisible name, so the widget has no label.")
                Text("Alternative that hides every label: long-press › Edit › Customize › choose the large icon size.")
            } header: {
                Text("No name under the widget")
            }
        }
        .navigationTitle("Glass border")
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
                GuideStep(number: 5, text: "To make it look like plain text, follow “Hide the iOS 27 glass border”.")
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
