import MediaPlayer
import SwiftUI

/// The iBoard record player: a vinyl disc that turns at 33⅓ rpm, a tonearm that tracks
/// the playhead from the outer groove to the label, a scrub bar and three keys. It is a
/// mechanical study for the layout, so it plays silence. With Music access it puts the
/// song the Music app is playing on the disc: its cover in the label, its title and artist.
struct RecordDeck: View {
    private struct Track {
        let title: String
        var artist = "WS Ensemble"
        let length: Double
    }

    private static let tracks = [
        Track(title: "Loop Study", length: 212),
        Track(title: "Grid Theory", length: 245),
        Track(title: "Quiet Index", length: 178),
        Track(title: "Hairline", length: 227),
    ]
    /// 33⅓ revolutions a minute.
    private static let degreesPerSecond = 200.0

    @State private var index = 0
    /// The playhead in seconds at `startedAt`; while playing it moves on from there.
    @State private var position: Double = 0
    @State private var startedAt: Date?
    @State private var scrubbing = false
    @State private var resumeAfterScrub = false
    @ObservedObject private var nowPlaying = NowPlayingMonitor.shared
    @Environment(\.openURL) private var openURL

    /// The song the Music app is playing, as a side of one track; the sample side otherwise.
    private var side: [Track] {
        guard let song = nowPlaying.song else { return Self.tracks }
        return [Track(title: song.title, artist: song.artist, length: song.length > 0 ? song.length : 240)]
    }
    private var track: Track { side[min(index, side.count - 1)] }
    private var playing: Bool { startedAt != nil }

    var body: some View {
        ModuleFrame("Deck · 33⅓", stamp: "Side A", foot: "Rpm 33.3", marks: [.topTrailing, .bottomLeading]) {
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !playing)) { context in
                deck(at: playhead(at: context.date))
            }
        }
        .task(id: startedAt) { await advanceAtEnd() }
        .onChange(of: nowPlaying.song?.key) {
            // A new record goes on from the outer groove.
            index = 0
            position = 0
            if playing { startedAt = .now }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: playing)
    }

    private func playhead(at date: Date) -> Double {
        let raw = startedAt.map { position + date.timeIntervalSince($0) } ?? position
        return min(raw, track.length)
    }

    private func deck(at time: Double) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                // Scrubbing turns the disc too, the way a hand on the record would.
                Turntable(angle: .degrees(time * Self.degreesPerSecond),
                          progress: time / track.length,
                          armDown: playing || (scrubbing && resumeAfterScrub),
                          cover: nowPlaying.song?.cover)
                    .frame(width: 168)
                VStack(alignment: .leading, spacing: 6) {
                    Micro(nowPlaying.song == nil
                          ? String(format: "Side A · %02d/%02d", index + 1, side.count)
                          : "Now playing · Music", size: 7.5)
                    Text(track.title)
                        .font(.metric(20))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Micro(track.artist, size: 7.5)
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        Button { skip(-1) } label: { Image(systemName: "backward.end") }
                            .buttonStyle(BevelKeyStyle(size: 38))
                            .accessibilityLabel("Previous track")
                        Button { toggle() } label: { Image(systemName: playing ? "pause" : "play") }
                            .buttonStyle(BevelKeyStyle(size: 38, selected: playing))
                            .accessibilityLabel(playing ? "Pause" : "Play")
                        Button { skip(1) } label: { Image(systemName: "forward.end") }
                            .buttonStyle(BevelKeyStyle(size: 38))
                            .accessibilityLabel("Next track")
                    }
                }
            }
            PlaybackBar(time: time, length: track.length) { fraction, ended in
                scrub(to: fraction, ended: ended)
            }
            source
        }
    }

    /// Where the record comes from, with the key that asks for Music access when the
    /// deck still plays the sample side.
    private var source: some View {
        HStack(spacing: 8) {
            Text(sourceCaption)
                .font(.micro(7))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            switch nowPlaying.access {
            case .notAsked:
                Button("Show Music's song") { nowPlaying.requestAccess() }
                    .buttonStyle(PillStyle(compact: true))
            case .denied:
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(PillStyle(compact: true))
            case .allowed:
                EmptyView()
            }
        }
    }

    private var sourceCaption: String {
        let reach = "Music app only, not Spotify"
        switch nowPlaying.access {
        case .notAsked: return "Sample side · " + reach
        case .denied: return "Music access off · " + reach
        case .allowed: return nowPlaying.song == nil ? "Nothing playing · " + reach : reach
        }
    }

    // MARK: Transport

    private func toggle() {
        if let startedAt {
            position = min(position + Date.now.timeIntervalSince(startedAt), track.length)
            self.startedAt = nil
        } else {
            if position >= track.length { position = 0 }
            startedAt = .now
        }
    }

    private func skip(_ step: Int) {
        let wasPlaying = playing
        index = (index + step + side.count) % side.count
        position = 0
        startedAt = wasPlaying ? .now : nil
    }

    private func scrub(to fraction: Double, ended: Bool) {
        if !scrubbing {
            scrubbing = true
            resumeAfterScrub = playing
        }
        position = min(max(fraction, 0), 1) * track.length
        startedAt = nil
        if ended {
            scrubbing = false
            if resumeAfterScrub { startedAt = .now }
        }
    }

    /// Moves to the next side's track when this one runs out, and keeps playing.
    private func advanceAtEnd() async {
        guard let startedAt else { return }
        let left = track.length - position
        try? await Task.sleep(for: .seconds(max(left, 0)))
        guard !Task.isCancelled, self.startedAt == startedAt else { return }
        index = (index + 1) % side.count
        position = 0
        self.startedAt = .now
    }
}

/// What the Music app is playing, read from the system music player while the app is in
/// front, for the deck and, through `NowPlayingStore`, for the widget. Only the Music app
/// reports to it: Spotify and other players don't.
@MainActor
final class NowPlayingMonitor: ObservableObject {
    static let shared = NowPlayingMonitor()

    struct Song {
        let key: String
        let title: String
        let artist: String
        let length: Double
        let cover: UIImage?
    }

    enum Access { case notAsked, denied, allowed }

    @Published private(set) var access = NowPlayingMonitor.currentAccess
    @Published private(set) var song: Song?
    private var following: Task<Void, Never>?

    private static var currentAccess: Access {
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized: .allowed
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    /// Asks for Media & Apple Music access. The deck's key calls it, never the launch.
    func requestAccess() {
        Task {
            _ = await MPMediaLibrary.requestAuthorization()
            resume()
        }
    }

    /// Reads the song afresh and follows its changes; called when the app comes to the front.
    func resume() {
        #if targetEnvironment(simulator)
        if let sample = Self.sample {
            access = .allowed
            show(sample)
            return
        }
        #endif
        access = Self.currentAccess
        guard access == .allowed else {
            show(nil)
            return
        }
        let player = MPMusicPlayerController.systemMusicPlayer
        if following == nil {
            player.beginGeneratingPlaybackNotifications()
            following = Task { [weak self] in
                let changes = NotificationCenter.default.notifications(
                    named: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
                for await _ in changes {
                    self?.read(player)
                }
            }
        }
        read(player)
    }

    /// Stops following when the app goes to the background.
    func pause() {
        guard let following else { return }
        following.cancel()
        self.following = nil
        MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
    }

    private func read(_ player: MPMusicPlayerController) {
        guard let item = player.nowPlayingItem else {
            show(nil)
            return
        }
        let title = item.title ?? "Untitled"
        let artist = item.artist ?? item.albumArtist ?? "Unknown artist"
        let side = NowPlayingStore.coverPixels
        show(Song(key: "\(item.persistentID)|\(title)|\(artist)", title: title, artist: artist,
                  length: item.playbackDuration,
                  cover: item.artwork?.image(at: CGSize(width: side, height: side))))
    }

    private func show(_ song: Song?) {
        self.song = song
        if let song {
            NowPlayingStore.save(key: song.key, title: song.title, artist: song.artist, cover: song.cover)
        } else {
            NowPlayingStore.clear()
        }
    }

    #if targetEnvironment(simulator)
    /// "-nowPlayingSample [1|2]" in a simulator build: a made-up song with a drawn cover,
    /// since the simulator has no Music app to play one.
    private static var sample: Song? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-nowPlayingSample") else { return nil }
        let second = args.indices.contains(index + 1) && args[index + 1] == "2"
        let side = NowPlayingStore.coverPixels
        let cover = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            let colors = second ? [UIColor.systemTeal, .systemIndigo] : [UIColor.systemOrange, .brown]
            colors[0].setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            colors[1].setFill()
            context.cgContext.fillEllipse(in: CGRect(x: side * 0.2, y: side * 0.2, width: side * 0.6, height: side * 0.6))
        }
        return second
            ? Song(key: "sample-2", title: "Second Sample", artist: "Simulator", length: 198, cover: cover)
            : Song(key: "sample-1", title: "Copper Folds", artist: "Simulator", length: 231, cover: cover)
    }
    #endif
}

/// The platter, the disc and the arm. Proportions are in units of the disc diameter d:
/// the frame is 1.2 d wide, the arm pivots at (1.13 d, 0.09 d) and reaches 0.75 d.
private struct Turntable: View {
    let angle: Angle
    let progress: Double
    let armDown: Bool
    let cover: UIImage?

    private static let pivot = CGPoint(x: 1.13, y: 0.09)
    private static let reach = 0.75

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.height, geo.size.width / 1.2)
            ZStack(alignment: .topLeading) {
                VinylDisc(cover: cover)
                    .frame(width: d, height: d)
                    .rotationEffect(angle)
                ArmRest(d: d)
                    .stroke(Color.primary.opacity(0.6), lineWidth: 1)
                ToneArm(d: d)
                    .rotationEffect(.radians(armDown ? Self.armAngle(progress: progress) : 0),
                                    anchor: UnitPoint(x: Self.pivot.x / 1.2, y: Self.pivot.y))
                    .animation(.spring(response: 0.8, dampingFraction: 0.82), value: armDown)
            }
            .frame(width: d * 1.2, height: d)
        }
        .aspectRatio(1.2, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Turntable")
        .accessibilityValue(armDown ? "Playing" : "Stopped")
    }

    /// The arm angle that puts the stylus on the groove for `progress`: 0 is the outer
    /// groove, 1 the edge of the label. Solved by bisection, since the stylus moves on
    /// an arc round the pivot rather than along a radius.
    static func armAngle(progress: Double) -> Double {
        let centre = CGPoint(x: 0.5, y: 0.5)
        let target = 0.44 - (0.44 - 0.2) * min(max(progress, 0), 1)
        func distance(_ phi: Double) -> Double {
            hypot(pivot.x - reach * sin(phi) - centre.x, pivot.y + reach * cos(phi) - centre.y)
        }
        var low = 0.0
        var high = atan2(pivot.x - centre.x, centre.y - pivot.y)
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if distance(mid) > target { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }
}

private struct VinylDisc: View {
    /// The playing song's cover, set in the label; nil keeps the printed label.
    let cover: UIImage?
    @Environment(\.displayScale) private var scale

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            var faint = context
            faint.opacity = 0.45
            var groove = context
            groove.opacity = 0.3

            context.stroke(ModuleDrawing.circle(c, r - 0.5), with: .foreground, lineWidth: 1)

            // The strobe ring round the platter edge.
            var strobe = Path()
            for i in 0..<72 {
                let a = Double(i) / 72 * 2 * .pi
                strobe.move(to: polarPoint(c, r - 4.5, a))
                strobe.addLine(to: polarPoint(c, r - 1.5, a))
            }
            faint.stroke(strobe, with: .foreground, lineWidth: 1 / scale)

            // Grooves, with a wider run-in gap between tracks.
            var grooves = Path()
            var ring = r * 0.88
            var count = 0
            while ring > r * 0.4 {
                grooves.addPath(ModuleDrawing.circle(c, ring))
                count += 1
                ring -= count % 5 == 0 ? r * 0.045 : r * 0.021
            }
            groove.stroke(grooves, with: .foreground, lineWidth: 1 / scale)

            // Two short sheen arcs: the only marks that show the disc turning.
            for (start, end, radius) in [(-62.0, -38.0, 0.78), (118.0, 140.0, 0.64)] {
                var sheen = Path()
                sheen.addArc(center: c, radius: r * radius, startAngle: .degrees(start),
                             endAngle: .degrees(end), clockwise: false)
                context.stroke(sheen, with: .foreground, style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }

            // The cover fills the label inside its hairline, cropped round from its middle.
            if let cover, cover.size.width > 0, cover.size.height > 0 {
                var label = context
                let side = r * 0.6
                let fill = max(side / cover.size.width, side / cover.size.height)
                let drawn = CGSize(width: cover.size.width * fill, height: cover.size.height * fill)
                label.clip(to: ModuleDrawing.circle(c, r * 0.3))
                label.draw(Image(uiImage: cover), in: CGRect(x: c.x - drawn.width / 2, y: c.y - drawn.height / 2,
                                                             width: drawn.width, height: drawn.height))
            }

            context.stroke(ModuleDrawing.circle(c, r * 0.34), with: .foreground, lineWidth: 1)
            faint.stroke(ModuleDrawing.circle(c, r * 0.3), with: .foreground, lineWidth: 1 / scale)
            context.stroke(ModuleDrawing.circle(c, r * 0.035), with: .foreground, lineWidth: 1)
            if cover == nil {
                context.draw(Text("WS · 27").font(.micro(7)).tracking(1.4), at: CGPoint(x: c.x, y: c.y - r * 0.17))
                context.draw(Text("33⅓").font(.micro(6.5)).foregroundStyle(.secondary), at: CGPoint(x: c.x, y: c.y + r * 0.17))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ToneArm: View {
    let d: CGFloat

    var body: some View {
        ZStack {
            ToneArmShape(d: d)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
            PivotShape(d: d)
                .stroke(Color.primary, lineWidth: 1)
        }
    }
}

/// Counterweight, tube, dog-leg and headshell, hanging straight down from the pivot.
private struct ToneArmShape: Shape {
    let d: CGFloat

    func path(in rect: CGRect) -> Path {
        let px = d * 1.13, py = d * 0.09, reach = d * 0.75
        var path = Path()
        path.addRoundedRect(in: CGRect(x: px - d * 0.04, y: py - d * 0.13, width: d * 0.08, height: d * 0.065),
                            cornerSize: CGSize(width: d * 0.015, height: d * 0.015))
        path.move(to: CGPoint(x: px, y: py - d * 0.065))
        path.addLine(to: CGPoint(x: px, y: py + reach - d * 0.09))
        path.addLine(to: CGPoint(x: px - d * 0.022, y: py + reach - d * 0.035))
        path.addRoundedRect(in: CGRect(x: px - d * 0.052, y: py + reach - d * 0.04, width: d * 0.06, height: d * 0.075),
                            cornerSize: CGSize(width: d * 0.012, height: d * 0.012))
        return path
    }
}

private struct PivotShape: Shape {
    let d: CGFloat

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: d * 1.13, y: d * 0.09)
        var path = ModuleDrawing.circle(centre, d * 0.05)
        path.addPath(ModuleDrawing.circle(centre, d * 0.018))
        return path
    }
}

/// The post the arm rests on, off the record.
private struct ArmRest: Shape {
    let d: CGFloat

    func path(in rect: CGRect) -> Path {
        let rest = CGPoint(x: d * 1.13, y: d * 0.86)
        var path = ModuleDrawing.circle(rest, d * 0.022)
        path.move(to: CGPoint(x: rest.x - d * 0.045, y: rest.y + d * 0.06))
        path.addLine(to: CGPoint(x: rest.x + d * 0.045, y: rest.y + d * 0.06))
        return path
    }
}

/// A linear playback bar: ticks every tenth, a heavier line for what has played and a
/// ringed head. Dragging anywhere on it cues the record.
private struct PlaybackBar: View {
    let time: Double
    let length: Double
    let scrub: (Double, Bool) -> Void
    @Environment(\.displayScale) private var scale

    private let edge: CGFloat = 6

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                Canvas { context, size in
                    let mid = size.height / 2
                    let usable = size.width - edge * 2
                    let x = edge + usable * CGFloat(min(max(time / length, 0), 1))
                    var faint = context
                    faint.opacity = 0.35

                    var track = Path()
                    track.move(to: CGPoint(x: edge, y: mid))
                    track.addLine(to: CGPoint(x: size.width - edge, y: mid))
                    faint.stroke(track, with: .foreground, lineWidth: 1 / scale)

                    var ticks = Path()
                    for i in 0...10 {
                        let tx = edge + usable * CGFloat(i) / 10
                        let tall: CGFloat = i % 5 == 0 ? 6 : 3
                        ticks.move(to: CGPoint(x: tx, y: mid - tall))
                        ticks.addLine(to: CGPoint(x: tx, y: mid + tall))
                    }
                    faint.stroke(ticks, with: .foreground, lineWidth: 1 / scale)

                    var played = Path()
                    played.move(to: CGPoint(x: edge, y: mid))
                    played.addLine(to: CGPoint(x: x, y: mid))
                    context.stroke(played, with: .foreground, lineWidth: 2)
                    context.stroke(ModuleDrawing.circle(CGPoint(x: x, y: mid), 5.5), with: .foreground, lineWidth: 1)
                    context.stroke(ModuleDrawing.circle(CGPoint(x: x, y: mid), 1.5), with: .foreground, lineWidth: 1)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { scrub(Double(($0.location.x - edge) / max(width - edge * 2, 1)), false) }
                        .onEnded { scrub(Double(($0.location.x - edge) / max(width - edge * 2, 1)), true) }
                )
            }
            .frame(height: 24)
            HStack {
                Text(Clockwork.minutesSeconds(time)).font(.metric(13)).monospacedDigit()
                Spacer()
                Micro("Scrub to cue", size: 7)
                Spacer()
                Text("−" + Clockwork.minutesSeconds(length - time))
                    .font(.metric(13))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Clockwork.minutesSeconds(time)) of \(Clockwork.minutesSeconds(length))")
        .accessibilityAdjustableAction { direction in
            let step = 10 / length
            switch direction {
            case .increment: scrub(time / length + step, true)
            case .decrement: scrub(time / length - step, true)
            @unknown default: break
            }
        }
    }
}
