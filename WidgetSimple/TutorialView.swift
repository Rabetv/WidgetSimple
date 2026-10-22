import SwiftUI

/// Quick tutorial, shown on first launch and from the "?" button.
struct TutorialView: View {
    let onDone: () -> Void

    @State private var page = 0

    private struct Page {
        let symbol: String
        let title: String
        let text: String
    }

    private let pages = [
        Page(symbol: "checklist", title: "Pick your apps", text: "Tick the apps you want. They show up as words."),
        Page(symbol: "plus.square.on.square", title: "Add the widget", text: "Hold the Home Screen › Edit › Add Widget › WidgetSimple."),
        Page(symbol: "square.dashed", title: "Hide the edges", text: "Plain wallpaper, same widget color, 4 settings. The app shows you."),
        Page(symbol: "clock", title: "Clock widget", text: "Day, time and week, in your font."),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onDone)
                    .opacity(isLast ? 0 : 1)
            }
            .padding()

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 20) {
                        Image(systemName: pages[index].symbol)
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(Color.accentColor)
                        Text(pages[index].title)
                            .font(.title.bold())
                        Text(pages[index].text)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if isLast {
                    onDone()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(isLast ? "Start" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(24)
        }
    }
}
