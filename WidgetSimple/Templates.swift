import SwiftUI

/// A ready-made look for the launcher widget. Applying one replaces the current look
/// and clock for every launcher widget.
struct LookTemplate: Identifiable {
    let id: String
    let name: LocalizedStringKey
    let look: Look
    let clock: ClockOption

    static let all: [LookTemplate] = [
        LookTemplate(id: "thin", name: "Thin clock", look: make {
            $0.size = 19
            $0.shadow = true
        }, clock: .time),
        LookTemplate(id: "serif", name: "Serif list", look: make {
            $0.fontID = "sys:serif"
            $0.size = 21
            $0.spacing = 1.2
        }, clock: .off),
        LookTemplate(id: "amber", name: "Amber caps", look: make {
            $0.tone = .custom
            $0.customHex = "#FFC766"
            $0.letterCase = .upper
            $0.size = 16
            $0.spacing = 1.4
        }, clock: .off),
        LookTemplate(id: "centred", name: "Centred", look: make {
            $0.fontID = "sys:rounded"
            $0.align = .center
            $0.vAlign = .middle
            $0.size = 20
        }, clock: .timeAndDate),
        LookTemplate(id: "mono", name: "Mono", look: make {
            $0.fontID = "sys:mono"
            $0.size = 15
            $0.spacing = 1.3
        }, clock: .date),
        LookTemplate(id: "big", name: "Big words", look: make {
            $0.size = 30
            $0.spacing = 0.9
            $0.shadow = true
        }, clock: .off)
    ]

    private static func make(_ edit: (inout Look) -> Void) -> Look {
        var look = Look()
        edit(&look)
        return look
    }
}

/// The templates as a grid of small live previews; tapping one asks before applying.
struct TemplateGrid: View {
    @EnvironmentObject private var model: AppModel
    @State private var pending: LookTemplate?

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(LookTemplate.all) { template in
                Button {
                    pending = template
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        WidgetPreviewCard(look: template.look, clock: template.clock, size: .small)
                            .allowsHitTesting(false)
                        Text(template.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                    }
                    .padding(10)
                    .glassPanel(cornerRadius: 26)
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog("Use this template?", isPresented: presenting, presenting: pending) { template in
            Button("Apply to all launcher widgets") {
                model.look = template.look
                model.clock = template.clock
            }
        } message: { _ in
            Text("Your current font, colour and layout are replaced.")
        }
    }

    private var presenting: Binding<Bool> {
        Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
    }
}
