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

/// A ready-made placed design: a widget size and its blocks where they sit. Using one
/// copies it, with new ids, into the sandbox; nothing is saved until Save.
struct DesignBlueprint: Identifiable {
    enum Family: String, CaseIterable, Identifiable {
        case blank, iboard, text, retro, clocks, apps

        var id: String { rawValue }

        var title: String {
            switch self {
            case .blank: return "Blank"
            case .iboard: return "iBoard"
            case .text: return "Text Grids"
            case .retro: return "Retro Mechanics"
            case .clocks: return "Clock Hubs"
            case .apps: return "App Matrices"
            }
        }

        var code: String {
            switch self {
            case .blank: return "C-00"
            case .iboard: return "C-01"
            case .text: return "C-02"
            case .retro: return "C-03"
            case .clocks: return "C-04"
            case .apps: return "C-05"
            }
        }

        var note: String {
            switch self {
            case .blank: return "An empty widget. Add what you like and put it anywhere."
            case .iboard: return "The date, the week and your apps, like the Home page."
            case .text: return "Words first: the time in words, greetings, short lists."
            case .retro: return "Dials, platters and other moving parts."
            case .clocks: return "Clocks of every kind, from one city or four."
            case .apps: return "Open App words, packed in grids."
            }
        }
    }

    let id: String
    let name: String
    let family: Family
    let canvas: FaceSize
    /// The blocks, placed. Their ids are replaced every time the blueprint is used.
    let blocks: [DesignBlock]
    /// The blueprint's own touches on the look it starts from.
    var align: TextAlign?
    var letterCase: LetterCase?

    var note: String {
        let slots = min(blocks.filter { $0.kind == .apps }.reduce(0) { $0 + $1.slots }, DesignBlock.maxSlots)
        if blocks.isEmpty { return "\(canvas.title) · empty" }
        return "\(canvas.title) · \(blocks.count) blocks · \(slots) apps"
    }

    /// A fresh design from the blueprint, in `look` with the blueprint's own touches.
    func design(name: String, look base: Look) -> WidgetDesign {
        var look = base
        if let align { look.align = align }
        if let letterCase { look.letterCase = letterCase }
        let copies = blocks.map { block -> DesignBlock in
            var copy = block
            copy.id = UUID()
            if copy.kind == .daysUntil, copy.date == nil {
                copy.date = Calendar.current.date(byAdding: .day, value: 30, to: .now)
            }
            return copy
        }
        return WidgetDesign(name: name, look: look, blocks: copies, canvas: canvas)
    }

    static var all: [DesignBlueprint] { blanks + placed }

    static func blank(_ size: FaceSize) -> DesignBlueprint {
        DesignBlueprint(id: "BL-" + (size == .extraLarge ? "XL" : String(size.title.prefix(1))), name: "Blank \(size.title)",
                        family: .blank, canvas: size, blocks: [])
    }

    static let blanks: [DesignBlueprint] = FaceSize.allCases.map(blank)

    static let placed: [DesignBlueprint] = [
        // iBoard
        DesignBlueprint(id: "IB-01", name: "iBoard Today", family: .iboard, canvas: .medium, blocks: [
            block(.bigDate, 0.05, 0.1, 0.26, 0.8),
            block(.weekStrip, 0.35, 0.1, 0.6, 0.3),
            block(.apps, 0.35, 0.48, 0.6, 0.42) { $0.slots = 4 },
        ]),
        DesignBlueprint(id: "IB-02", name: "iBoard Deck", family: .iboard, canvas: .large, blocks: [
            block(.digitalClock, 0.06, 0.05, 0.88, 0.17) { $0.clock = .timeAndDate },
            block(.vinyl, 0.06, 0.25, 0.42, 0.36),
            block(.calendarIcon, 0.52, 0.25, 0.42, 0.36),
            block(.apps, 0.06, 0.65, 0.88, 0.3) { $0.slots = 6 },
        ]),
        DesignBlueprint(id: "IB-03", name: "iBoard Pocket", family: .iboard, canvas: .small, blocks: [
            block(.digitalClock, 0.1, 0.08, 0.8, 0.3),
            block(.apps, 0.1, 0.44, 0.8, 0.48) { $0.slots = 3 },
        ]),
        DesignBlueprint(id: "IB-04", name: "iBoard Tower", family: .iboard, canvas: .extraLarge, blocks: [
            block(.digitalClock, 0.06, 0.03, 0.88, 0.12) { $0.clock = .timeAndDate },
            block(.weekStrip, 0.06, 0.17, 0.88, 0.08),
            block(.vinyl, 0.06, 0.28, 0.42, 0.24),
            block(.calendarIcon, 0.52, 0.28, 0.42, 0.24),
            block(.apps, 0.06, 0.56, 0.88, 0.4) { $0.slots = 8 },
        ]),
        // Text grids
        DesignBlueprint(id: "TX-01", name: "Word Clock", family: .text, canvas: .medium, blocks: [
            block(.wordClock, 0.05, 0.1, 0.55, 0.8),
            block(.apps, 0.64, 0.1, 0.31, 0.8) { $0.slots = 3 },
        ]),
        DesignBlueprint(id: "TX-02", name: "Greeting", family: .text, canvas: .medium, blocks: [
            block(.greeting, 0.05, 0.1, 0.9, 0.32),
            block(.quote, 0.05, 0.48, 0.55, 0.42) {
                $0.lines = ["Small steps count.", "One thing at a time.", "Keep it simple."]
            },
            block(.apps, 0.64, 0.48, 0.31, 0.42) { $0.slots = 2 },
        ]),
        DesignBlueprint(id: "TX-03", name: "Text Grid", family: .text, canvas: .large, blocks: [
            block(.text, 0.06, 0.05, 0.42, 0.18) { $0.text = "Make" },
            block(.text, 0.52, 0.05, 0.42, 0.18) { $0.text = "Read" },
            block(.text, 0.06, 0.26, 0.42, 0.18) { $0.text = "Move" },
            block(.text, 0.52, 0.26, 0.42, 0.18) { $0.text = "Rest" },
            block(.apps, 0.06, 0.5, 0.88, 0.45) { $0.slots = 6 },
        ], letterCase: .upper),
        // Retro mechanics
        DesignBlueprint(id: "RM-01", name: "Turntable", family: .retro, canvas: .medium, blocks: [
            block(.vinyl, 0.04, 0.08, 0.34, 0.84),
            block(.analogClock, 0.4, 0.08, 0.2, 0.42),
            block(.battery, 0.4, 0.55, 0.2, 0.37),
            block(.apps, 0.63, 0.08, 0.33, 0.84) { $0.slots = 4 },
        ]),
        DesignBlueprint(id: "RM-02", name: "Analog Desk", family: .retro, canvas: .medium, blocks: [
            block(.analogClock, 0.04, 0.1, 0.26, 0.8),
            block(.countdownRing, 0.32, 0.1, 0.26, 0.8),
            block(.apps, 0.62, 0.1, 0.34, 0.8) { $0.slots = 4 },
        ]),
        DesignBlueprint(id: "RM-03", name: "Record Shelf", family: .retro, canvas: .large, blocks: [
            block(.vinyl, 0.06, 0.05, 0.88, 0.45),
            block(.calendarIcon, 0.06, 0.53, 0.4, 0.42),
            block(.apps, 0.5, 0.53, 0.44, 0.42) { $0.slots = 4 },
        ]),
        // Clock hubs
        DesignBlueprint(id: "CH-01", name: "World Hub", family: .clocks, canvas: .medium, blocks: [
            block(.analogClock, 0.04, 0.1, 0.26, 0.8),
            block(.worldClock, 0.34, 0.1, 0.62, 0.8),
        ]),
        DesignBlueprint(id: "CH-02", name: "Big Time", family: .clocks, canvas: .small, blocks: [
            block(.digitalClock, 0.08, 0.1, 0.84, 0.5) { $0.clock = .timeAndDate },
            block(.moon, 0.08, 0.64, 0.84, 0.28),
        ]),
        DesignBlueprint(id: "CH-03", name: "Clock Tower", family: .clocks, canvas: .large, blocks: [
            block(.analogClock, 0.2, 0.04, 0.6, 0.4),
            block(.digitalClock, 0.06, 0.46, 0.88, 0.12) { $0.clock = .date },
            block(.worldClock, 0.06, 0.6, 0.88, 0.2),
            block(.apps, 0.06, 0.82, 0.88, 0.14) { $0.slots = 2 },
        ], align: .center),
        DesignBlueprint(id: "CH-04", name: "Clock Column", family: .clocks, canvas: .extraLarge, blocks: [
            block(.analogClock, 0.15, 0.03, 0.7, 0.36),
            block(.worldClock, 0.06, 0.42, 0.88, 0.22),
            block(.apps, 0.06, 0.68, 0.88, 0.28) { $0.slots = 4 },
        ], align: .center),
        // App matrices
        DesignBlueprint(id: "AM-01", name: "Four Keys", family: .apps, canvas: .small, blocks: [
            block(.apps, 0.1, 0.1, 0.8, 0.8) { $0.slots = 4 },
        ]),
        DesignBlueprint(id: "AM-02", name: "Six Keys", family: .apps, canvas: .medium, blocks: [
            block(.apps, 0.05, 0.1, 0.9, 0.8) { $0.slots = 6 },
        ]),
        DesignBlueprint(id: "AM-03", name: "Two Columns", family: .apps, canvas: .medium, blocks: [
            block(.apps, 0.05, 0.1, 0.43, 0.8) { $0.slots = 4 },
            block(.apps, 0.52, 0.1, 0.43, 0.8) { $0.slots = 4 },
        ]),
        DesignBlueprint(id: "AM-04", name: "Twelve", family: .apps, canvas: .large, blocks: [
            block(.apps, 0.06, 0.05, 0.88, 0.9) { $0.slots = 12 },
        ]),
        DesignBlueprint(id: "AM-05", name: "Tall Keys", family: .apps, canvas: .extraLarge, blocks: [
            block(.apps, 0.06, 0.03, 0.88, 0.94) { $0.slots = 12 },
        ]),
    ]

    private static func block(_ kind: BlockKind, _ x: Double, _ y: Double, _ width: Double, _ height: Double,
                              _ edit: (inout DesignBlock) -> Void = { _ in }) -> DesignBlock {
        var block = DesignBlock(kind)
        block.frame = BlockFrame(x: x, y: y, width: width, height: height)
        edit(&block)
        return block
    }
}
