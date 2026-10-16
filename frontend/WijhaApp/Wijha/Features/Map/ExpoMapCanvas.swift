import SwiftUI

// ============================================================================
// The site map engine.
//
// One map for the whole app (الرحلة · استكشف · اختيار جناح): it fills its container,
// the visitor pinches and drags inside a "window" that excludes the controls and cards
// laid over it (`insets`), and a rest camera opens on the part of the trip that matters
// now. Markers, route, labels and the pop-up share one coordinate transform on both
// bases (مصوّرة photo / توضيحية drawn), so nothing moves on a style switch.
// ============================================================================

// a numbered stop handed in by the journey screen
struct MapStop: Identifiable, Hashable {
    let pavilionId: Int
    let number: Int
    let state: StopNumber.StopState
    var id: Int { pavilionId }
}

// how a pavilion is drawn
enum MapMarkerKind: Equatable {
    case plain                 // any pavilion
    case picked                // in the plan / chosen (explore, pick a pavilion)
    case upcoming(Int)         // a stop still ahead, with its number
    case next(Int)             // the next stop
    case visited(Int)          // a stop already visited
    case visitedPlain          // visited, no number
}

// the planned walk split in three: behind you, ahead of you, and the way out
struct RouteLines: Equatable {
    var walked: [CGPoint] = []
    var remaining: [CGPoint] = []
    var exit: [CGPoint] = []
    var all: [CGPoint] = []               // the whole walk, gate to gate
    var stopAt: [Int: CGFloat] = [:]      // where (0…1 along the walk) the line reaches each stop (pavilion id)
    var passAt: [Int: CGFloat] = [:]      // where the walk passes close to ANY pavilion, for the playback name tags
    var entrance: CGPoint? = nil
    var exitGate: CGPoint? = nil

    @MainActor
    static func build(route: RoadmapRoute?, stops: [RoadmapStop], expo: ExpoStore) -> RouteLines {
        guard let pts = route?.route, !pts.isEmpty else { return RouteLines() }
        let points = pts.map { CGPoint(x: $0.x, y: $0.y) }
        let ids = pts.map(\.id)
        var distance: [CGFloat] = [0]
        for i in points.indices.dropFirst() {
            distance.append(distance[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y))
        }
        let total = max(1, distance.last ?? 1)
        var indexes: [Int] = []
        var cursor = 0
        var lastVisited = 0
        var stopAt: [Int: CGFloat] = [:]
        for stop in stops.sorted(by: { ($0.stopOrder ?? 0) < ($1.stopOrder ?? 0) }) {
            guard let locationId = expo.pavilion(stop.pavilionId)?.location?.id else { continue }
            // searched in order so a pavilion passed twice keeps its own spot
            if let found = ids[cursor...].firstIndex(of: locationId) {
                indexes.append(found)
                cursor = found
                if stop.visited { lastVisited = found }
                if let pid = stop.pavilionId { stopAt[pid] = distance[found] / total }
            }
        }
        let lastStop = indexes.last ?? (points.count - 1)
        // every pavilion within reach of the walk, at the first point where the line comes closest
        var passAt: [Int: CGFloat] = [:]
        for pavilion in expo.pavilions {
            guard let loc = pavilion.location else { continue }
            var bestIndex: Int? = nil
            var bestDistance: CGFloat = 34          // data units: close enough to "pass by" the pavilion
            for (i, p) in points.enumerated() {
                let d = hypot(p.x - CGFloat(loc.x), p.y - CGFloat(loc.y))
                if d < bestDistance { bestDistance = d; bestIndex = i }
            }
            if let bestIndex { passAt[pavilion.id] = distance[bestIndex] / total }
        }
        for (pid, at) in stopAt { passAt[pid] = at }
        var lines = RouteLines()
        lines.all = points
        lines.stopAt = stopAt
        lines.passAt = passAt
        lines.entrance = points.first
        lines.exitGate = points.last
        if lastVisited > 0 { lines.walked = Array(points[0...lastVisited]) }
        if lastStop >= lastVisited { lines.remaining = Array(points[lastVisited...lastStop]) }
        if lastStop < points.count - 1 { lines.exit = Array(points[lastStop...]) }
        return lines
    }
}

// ===== geometry =====
// Data coordinates run 0…1000 with north up. The aerial asset (expo-map.png, square) covers
// the rectangle −50…1050 × −20…1020 of that space, so the gates sit on its edges and the
// central plaza on its centre. The drawn base uses the same rectangle.
enum MapGeo {
    static let minX: CGFloat = -50
    static let minY: CGFloat = -20
    static let spanX: CGFloat = 1100
    static let spanY: CGFloat = 1040
    static let minScale: CGFloat = 1
    static let maxScale: CGFloat = 4.2

    // the map at scale 1 inside a container: as wide as possible, aspect kept
    static func fitSize(_ box: CGSize) -> CGSize {
        let w = max(1, min(box.width, box.height * spanX / spanY))
        return CGSize(width: w, height: w * spanY / spanX)
    }

    // the part of the container not covered by controls or cards
    static func window(_ box: CGSize, _ insets: EdgeInsets) -> CGRect {
        CGRect(x: insets.leading, y: insets.top,
               width: max(1, box.width - insets.leading - insets.trailing),
               height: max(1, box.height - insets.top - insets.bottom))
    }

    // the smallest scale at which the map covers the whole container (no empty corners)
    static func coverScale(_ box: CGSize, _ insets: EdgeInsets) -> CGFloat {
        let w = window(box, insets)
        let f = fitSize(w.size)
        return max(1, max(box.width / f.width, box.height / f.height))
    }

    // keep the map covering the container: no gap on any side
    static func clampCover(_ o: CGSize, scale: CGFloat, box: CGSize, insets: EdgeInsets) -> CGSize {
        let w = window(box, insets)
        let f = fitSize(w.size)
        let mw = f.width * scale
        let mh = f.height * scale
        let loX = box.width - mw / 2 - w.midX
        let hiX = mw / 2 - w.midX
        let loY = box.height - mh / 2 - w.midY
        let hiY = mh / 2 - w.midY
        let x = loX <= hiX ? min(hiX, max(loX, o.width)) : (loX + hiX) / 2
        var y = loY <= hiY ? min(hiY, max(loY, o.height)) : (loY + hiY) / 2
        // when the whole map fits in the window (zoomed out), let it sit a bit higher than dead centre
        if loY > hiY && mh < w.height {
            y -= (w.height - mh) * 0.46   // sit near the top controls, not floating in the middle
        }
        return CGSize(width: x, height: y)
    }

    // the offset that puts a data point in the middle of the window
    static func center(on p: CGPoint, scale: CGFloat, box: CGSize, insets: EdgeInsets) -> CGSize {
        let t = MapTransform(box: box, insets: insets, scale: scale, offset: .zero)
        let w = t.window
        let s = t.point(p)
        return CGSize(width: w.midX - s.x, height: w.midY - s.y)
    }

    // the rest camera: the map covers the screen and shows the given points (your current leg)
    static func restCamera(_ pts: [CGPoint], box: CGSize, insets: EdgeInsets) -> (CGFloat, CGSize) {
        let cover = coverScale(box, insets)
        guard !pts.isEmpty else {
            return (cover, clampCover(.zero, scale: cover, box: box, insets: insets))
        }
        let probe = MapTransform(box: box, insets: insets, scale: 1, offset: .zero)
        let screen = pts.map { probe.point($0) }
        let xs = screen.map(\.x), ys = screen.map(\.y)
        let legW = (xs.max() ?? 0) - (xs.min() ?? 0)
        let legH = (ys.max() ?? 0) - (ys.min() ?? 0)
        let w = probe.window
        let fitScale = min(max(60, w.width - 110) / max(1, legW), max(60, w.height - 110) / max(1, legH))
        // always a little zoomed in so the pins and labels read, never past the detail limit
        let s = max(max(cover, 1.7), min(3.1, fitScale))
        let dx = pts.map(\.x), dy = pts.map(\.y)
        let mid = CGPoint(x: ((dx.max() ?? 0) + (dx.min() ?? 0)) / 2, y: ((dy.max() ?? 0) + (dy.min() ?? 0)) / 2)
        let o = center(on: mid, scale: s, box: box, insets: insets)
        return (s, clampCover(o, scale: s, box: box, insets: insets))
    }

    static func length(_ pts: [CGPoint]) -> CGFloat {
        var d: CGFloat = 0
        for i in pts.indices.dropFirst() { d += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y) }
        return d
    }

    static func point(along pts: [CGPoint], at distance: CGFloat) -> CGPoint {
        guard var prev = pts.first else { return .zero }
        var left = distance
        for p in pts.dropFirst() {
            let seg = hypot(p.x - prev.x, p.y - prev.y)
            if seg > 0 && left <= seg {
                let k = left / seg
                return CGPoint(x: prev.x + (p.x - prev.x) * k, y: prev.y + (p.y - prev.y) * k)
            }
            left -= seg
            prev = p
        }
        return prev
    }

    // radius of a zone disc: its farthest pavilion plus a margin (data units)
    static func zoneRadius(_ zone: Zone) -> CGFloat {
        guard let c = zone.location else { return 150 }
        let d = (zone.pavilions ?? []).compactMap { p -> CGFloat? in
            guard let l = p.location else { return nil }
            return hypot(CGFloat(l.x - c.x), CGFloat(l.y - c.y))
        }
        return min(190, (d.max() ?? 120) + 34)
    }

    // one colour per zone from the Wijha ramps (lime stays reserved for "next" and the route)
    static func zoneColor(_ name: String?, _ index: Int) -> Color {
        let all: [Color] = [
            Color.dynamic(dark: Palette.blue400, light: Palette.blue600),       // Technology
            Color.dynamic(dark: Palette.green400, light: Palette.green600),     // Planet
            Color.dynamic(dark: Palette.mint500, light: Palette.mint700),       // Collaboration
            Color.dynamic(dark: Palette.amber500, light: Palette.amber700),     // Culture
            Color.dynamic(dark: Color(hex: 0xB49CFF), light: Color(hex: 0x6B55E0)) // Humanity
        ]
        switch name ?? "" {
        case "Technology": return all[0]
        case "Planet": return all[1]
        case "Collaboration": return all[2]
        case "Culture": return all[3]
        case "Humanity": return all[4]
        default: return all[abs(index) % all.count]
        }
    }

    // a four point star for zone centres (the Wijha spark)
    static func spark(_ c: CGPoint, _ s: CGFloat) -> Path {
        let k = s * 0.28
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - s))
        p.addLine(to: CGPoint(x: c.x + k, y: c.y - k))
        p.addLine(to: CGPoint(x: c.x + s, y: c.y))
        p.addLine(to: CGPoint(x: c.x + k, y: c.y + k))
        p.addLine(to: CGPoint(x: c.x, y: c.y + s))
        p.addLine(to: CGPoint(x: c.x - k, y: c.y + k))
        p.addLine(to: CGPoint(x: c.x - s, y: c.y))
        p.addLine(to: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }
}

// data → screen, with the current zoom and pan
struct MapTransform {
    var box: CGSize
    var insets: EdgeInsets
    var scale: CGFloat
    var offset: CGSize

    var window: CGRect { MapGeo.window(box, insets) }
    var fit: CGSize { MapGeo.fitSize(window.size) }
    var unit: CGFloat { fit.width / MapGeo.spanX * scale }   // screen points per data unit

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        let w = window
        let f = fit
        let qx = (x - MapGeo.minX) / MapGeo.spanX * f.width
        let qy = (y - MapGeo.minY) / MapGeo.spanY * f.height
        return CGPoint(x: w.midX + (qx - f.width / 2) * scale + offset.width,
                       y: w.midY + (qy - f.height / 2) * scale + offset.height)
    }

    func point(_ p: CGPoint) -> CGPoint { point(p.x, p.y) }
    func point(_ l: LocationDTO) -> CGPoint { point(CGFloat(l.x), CGFloat(l.y)) }

    var mapRect: CGRect {
        let a = point(MapGeo.minX, MapGeo.minY)
        let b = point(MapGeo.minX + MapGeo.spanX, MapGeo.minY + MapGeo.spanY)
        return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
    }
}

// ============================================================================
// The map view
// ============================================================================
struct ExpoMapView<Popup: View>: View {
    var markers: [Int: MapMarkerKind] = [:]
    var route: RouteLines = RouteLines()
    var directions: [CGPoint] = []        // the walk to one pavilion (data points)
    var selectedId: Int? = nil
    var showsPopup = true                 // false = highlight the pin only (directions)
    var tripNeeds: [String] = []          // pavilions that don't suit these needs are faded
    var crowdLayer = false                // colour every pavilion by its queue now
    var showLabels = true
    var dimUnmarked = false
    var interactive = true
    var insets = EdgeInsets()             // space taken by controls above and cards below
    var focus: [CGPoint] = []             // the rest camera shows these points
    var playToken = 0                     // bump to replay the trip
    var recenterToken = 0                 // bump to go back to the rest camera
    var zoomToken = 0                     // +1 zooms in a step, −1 zooms out a step
    var onTap: (Int) -> Void = { _ in }
    var onTapEmpty: () -> Void = {}
    @ViewBuilder var popup: (Pavilion) -> Popup

    @Environment(ExpoStore.self) private var expo
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseScale: CGFloat = 1
    @State private var baseOffset: CGSize = .zero
    @State private var lastDrag: CGSize = .zero
    @State private var pinching = false
    @State private var box: CGSize = .zero
    @State private var userMoved = false
    // trip playback
    @State private var progress: CGFloat = 1
    @State private var follow: CGFloat = 0
    @State private var playing = false
    @State private var playId = 0
    @State private var pendingPlay = false
    @State private var playTask: Task<Void, Never>?

    private var window: CGRect { MapGeo.window(box, insets) }

    var body: some View {
        GeometryReader { geo in
            MapStage(markers: markers, route: route, directions: directions, selectedId: selectedId, showsPopup: showsPopup,
                     tripNeeds: tripNeeds, crowdLayer: crowdLayer, showLabels: showLabels, dimUnmarked: dimUnmarked,
                     insets: insets, box: geo.size, scale: scale, offsetX: offset.width, offsetY: offset.height,
                     progress: progress, follow: follow, playing: playing,
                     onTap: { id in if playing { skip() } else { onTap(id) } },
                     onTapEmpty: { if playing { skip() } else { onTapEmpty() } },
                     popup: popup)
                .contentShape(Rectangle())
                .gesture(zoomGesture.simultaneously(with: panGesture), including: interactive && !playing ? .all : .subviews)
                .clipped()
                .onAppear {
                    box = geo.size
                    rest(geo.size, animated: false)
                    tryPlay()
                }
                .onChange(of: geo.size) { _, size in
                    box = size
                    if !userMoved && !playing { rest(size, animated: false) }
                }
        }
        .environment(\.layoutDirection, .leftToRight)   // the map is a picture, it never mirrors
        .onChange(of: focus) { _, _ in
            guard !playing else { return }
            userMoved = false
            rest(box, animated: true)
        }
        .onChange(of: insets) { _, _ in
            guard !playing, !userMoved else { return }
            rest(box, animated: true)
        }
        .onChange(of: recenterToken) { _, _ in
            userMoved = false
            rest(box, animated: true)
        }
        .onChange(of: zoomToken) { old, new in
            zoom(by: new > old ? 1.5 : 1 / 1.5)
        }
        .onChange(of: playToken) { _, _ in
            pendingPlay = true
            tryPlay()
        }
        .onChange(of: route.all.count) { _, _ in tryPlay() }
    }

    // ===== rest camera =====
    private func rest(_ size: CGSize, animated: Bool) {
        guard size.width > 1, size.height > 1 else { return }
        let (s, o) = MapGeo.restCamera(focus, box: size, insets: insets)
        if animated {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                scale = s
                offset = o
            }
        } else {
            scale = s
            offset = o
        }
        baseScale = s
        baseOffset = o
    }

    // ===== zoom buttons: a step in or out around the middle of the window =====
    private func zoom(by factor: CGFloat) {
        if playing { skip() }
        userMoved = true
        let s = min(MapGeo.maxScale, max(MapGeo.minScale, baseScale * factor))
        let k = s / baseScale
        let o = MapGeo.clampCover(CGSize(width: baseOffset.width * k, height: baseOffset.height * k), scale: s, box: box, insets: insets)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            scale = s
            offset = o
        }
        baseScale = s
        baseOffset = o
    }

    // ===== playback: the line draws itself gate to gate and the camera follows its head =====
    // Driven by one task with explicit waits (not animation completion handlers), so a tap, a new
    // play or a zoom always leaves the map in a clean state.
    private func tryPlay() {
        guard pendingPlay, route.all.count > 1, box.width > 1 else { return }
        pendingPlay = false
        play()
    }

    private func play() {
        playTask?.cancel()
        playId += 1
        let id = playId
        let seconds = Double(min(30, max(14, MapGeo.length(route.all) / 120)))
        if selectedId != nil { onTapEmpty() }
        userMoved = false
        playing = true
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { progress = 0 }
        playTask = Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.9)) { follow = 1 }
            try? await Task.sleep(for: .milliseconds(950))
            guard !Task.isCancelled, id == playId else { return }
            withAnimation(.linear(duration: seconds)) { progress = 1 }     // even pace, the middle as calm as the ends
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, id == playId else { return }
            await finish(id, duration: 1.1)
        }
    }

    // back to the rest camera, softly
    private func finish(_ id: Int, duration: Double) async {
        rest(box, animated: false)
        withAnimation(.easeInOut(duration: duration)) {
            progress = 1
            follow = 0
        }
        try? await Task.sleep(for: .seconds(duration))
        guard id == playId else { return }
        playing = false
    }

    // a tap during playback skips to the end
    private func skip() {
        playTask?.cancel()
        playId += 1
        let id = playId
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { progress = 1 }
        playTask = Task { @MainActor in await finish(id, duration: 0.6) }
    }

    // ===== pinch and drag =====
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                pinching = true
                userMoved = true
                let s = min(MapGeo.maxScale, max(MapGeo.minScale, baseScale * value.magnification))
                let w = window
                let ax = value.startLocation.x - w.midX
                let ay = value.startLocation.y - w.midY
                let k = s / baseScale
                let o = CGSize(width: ax - (ax - baseOffset.width) * k, height: ay - (ay - baseOffset.height) * k)
                scale = s
                offset = MapGeo.clampCover(o, scale: s, box: box, insets: insets)
            }
            .onEnded { _ in
                pinching = false
                baseScale = scale
                baseOffset = offset
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let dx = value.translation.width - lastDrag.width
                let dy = value.translation.height - lastDrag.height
                lastDrag = value.translation
                guard !pinching else { return }
                userMoved = true
                offset = MapGeo.clampCover(CGSize(width: offset.width + dx, height: offset.height + dy), scale: scale, box: box, insets: insets)
            }
            .onEnded { _ in
                lastDrag = .zero
                baseOffset = offset
            }
    }
}

extension ExpoMapView where Popup == EmptyView {
    init(markers: [Int: MapMarkerKind] = [:], route: RouteLines = RouteLines(), directions: [CGPoint] = [],
         selectedId: Int? = nil, showsPopup: Bool = true, tripNeeds: [String] = [], crowdLayer: Bool = false, showLabels: Bool = true,
         dimUnmarked: Bool = false, interactive: Bool = true, insets: EdgeInsets = EdgeInsets(),
         focus: [CGPoint] = [], playToken: Int = 0, recenterToken: Int = 0, zoomToken: Int = 0,
         onTap: @escaping (Int) -> Void = { _ in }, onTapEmpty: @escaping () -> Void = {}) {
        self.markers = markers
        self.route = route
        self.directions = directions
        self.selectedId = selectedId
        self.showsPopup = showsPopup
        self.tripNeeds = tripNeeds
        self.crowdLayer = crowdLayer
        self.showLabels = showLabels
        self.dimUnmarked = dimUnmarked
        self.interactive = interactive
        self.insets = insets
        self.focus = focus
        self.playToken = playToken
        self.recenterToken = recenterToken
        self.zoomToken = zoomToken
        self.onTap = onTap
        self.onTapEmpty = onTapEmpty
        self.popup = { _ in EmptyView() }
    }
}

// ============================================================================
// The drawing: animates smoothly when zoom, pan or playback change
// ============================================================================
private struct MapStage<Popup: View>: View, Animatable {
    @Environment(ExpoStore.self) private var expo
    @Environment(AppSettings.self) private var s
    @Environment(\.colorScheme) private var scheme
    var markers: [Int: MapMarkerKind]
    var route: RouteLines
    var directions: [CGPoint]
    var selectedId: Int?
    var showsPopup: Bool
    var tripNeeds: [String]
    var crowdLayer: Bool
    var showLabels: Bool
    var dimUnmarked: Bool
    var insets: EdgeInsets
    var box: CGSize
    var scale: CGFloat
    var offsetX: CGFloat
    var offsetY: CGFloat
    var progress: CGFloat
    var follow: CGFloat
    var playing: Bool
    var onTap: (Int) -> Void
    var onTapEmpty: () -> Void
    var popup: (Pavilion) -> Popup

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get { AnimatablePair(AnimatablePair(progress, follow), AnimatablePair(scale, AnimatablePair(offsetX, offsetY))) }
        set {
            progress = newValue.first.first
            follow = newValue.first.second
            scale = newValue.second.first
            offsetX = newValue.second.second.first
            offsetY = newValue.second.second.second
        }
    }

    private var head: CGPoint {
        MapGeo.point(along: route.all, at: MapGeo.length(route.all) * min(1, max(0, progress)))
    }

    // the rest camera, blended towards the line head while the trip plays
    private var transform: MapTransform {
        var sc = scale
        var o = CGSize(width: offsetX, height: offsetY)
        if follow > 0.001 && route.all.count > 1 {
            let target = max(MapGeo.coverScale(box, insets), 2.5)
            let es = sc + (target - sc) * follow
            let fo = MapGeo.clampCover(MapGeo.center(on: head, scale: es, box: box, insets: insets), scale: es, box: box, insets: insets)
            o = CGSize(width: o.width + (fo.width - o.width) * follow, height: o.height + (fo.height - o.height) * follow)
            sc = es
        }
        return MapTransform(box: box, insets: insets, scale: sc, offset: o)
    }

    private var photo: Bool { s.mapStyle == .image }
    private var dark: Bool { scheme == .dark }

    var body: some View {
        let t = transform
        ZStack(alignment: .topLeading) {
            ground(t)
                .contentShape(Rectangle())
                .onTapGesture { onTapEmpty() }
            if showLabels { zoneLabels(t) }
            gates(t)
            pavilions(t)
            if playing {
                ZStack { playbackCallout(t) }
                    .frame(width: box.width, height: box.height, alignment: .topLeading)
                    .animation(.spring(response: 0.45, dampingFraction: 0.7), value: reachedStopId)
                    .allowsHitTesting(false)
            }
            if showsPopup, let id = selectedId, let pavilion = expo.pavilion(id), let loc = pavilion.location {
                popupLayer(pavilion, at: t.point(loc))
            }
        }
        .frame(width: box.width, height: box.height)
    }

    // ===== ground =====
    @ViewBuilder
    private func ground(_ t: MapTransform) -> some View {
        let r = t.mapRect
        ZStack {
            if photo {
                // the same aerial, blurred, fills any corner the sharp one leaves
                Image(dark ? "ExpoMap" : "ExpoMapLight")
                    .resizable()
                    .scaledToFill()
                    .frame(width: box.width, height: box.height)
                    .blur(radius: 24, opaque: true)
                    .overlay(Palette.ink900.opacity(dark ? 0.5 : 0.2))
                    .clipped()
                Image(dark ? "ExpoMap" : "ExpoMapLight")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: max(1, r.width), height: max(1, r.height))
                    .position(x: r.midX, y: r.midY)
                // a navy veil in the dark so pins and glass controls keep their contrast
                Palette.ink900.opacity(dark ? 0.30 : 0)
                RadialGradient(colors: [.clear, Palette.ink900.opacity(dark ? 0.35 : 0.14)],
                               center: .center, startRadius: box.width * 0.35, endRadius: max(box.width, box.height) * 0.8)
            } else {
                illustrated(t)
            }
            routeLayer(t)
        }
        .frame(width: box.width, height: box.height)
    }

    // ===== the drawn base: zones, avenues, lanes and gardens from the data =====
    private func illustrated(_ t: MapTransform) -> some View {
        var hubIds = Set<Int>()
        for z in expo.zones { if let id = z.location?.id { hubIds.insert(id) } }
        for e in expo.entrances { if let id = e.location?.id { hubIds.insert(id) } }
        var avenues = Path()
        var lanes = Path()
        for p in expo.paths {
            guard let a = p.fromLocation, let b = p.toLocation else { continue }
            if hubIds.contains(a.id) && hubIds.contains(b.id) {
                avenues.move(to: t.point(a)); avenues.addLine(to: t.point(b))
            } else {
                lanes.move(to: t.point(a)); lanes.addLine(to: t.point(b))
            }
        }
        var centers: [CGPoint] = []
        var radii: [CGFloat] = []
        var colors: [Color] = []
        for (i, z) in expo.zones.enumerated() {
            guard let loc = z.location else { continue }
            centers.append(t.point(loc))
            radii.append(MapGeo.zoneRadius(z) * t.unit)
            colors.append(MapGeo.zoneColor(z.name, i))
        }
        let unit = t.unit
        let rect = t.mapRect
        // soft gardens in the four corners, like the real site
        let gardenSpots: [(CGFloat, CGFloat)] = [(90, 110), (910, 110), (90, 880), (910, 880), (500, 170), (500, 800)]
        let gardens: [(CGPoint, CGFloat)] = gardenSpots.map { (t.point($0.0, $0.1), 110 * unit) }
        var grid = Path()
        var gx = MapGeo.minX
        while gx <= MapGeo.minX + MapGeo.spanX + 0.5 {
            grid.move(to: t.point(gx, MapGeo.minY)); grid.addLine(to: t.point(gx, MapGeo.minY + MapGeo.spanY)); gx += 50
        }
        var gy = MapGeo.minY
        while gy <= MapGeo.minY + MapGeo.spanY + 0.5 {
            grid.move(to: t.point(MapGeo.minX, gy)); grid.addLine(to: t.point(MapGeo.minX + MapGeo.spanX, gy)); gy += 50
        }
        let avenuesPath = avenues, lanesPath = lanes, gridPath = grid

        let g0 = dark ? Palette.ink800 : Color(hex: 0xF3F7FC)
        let g1 = dark ? Palette.ink950 : Color(hex: 0xDCE5F1)
        let gridColor = dark ? Color.white.opacity(0.035) : Palette.ink900.opacity(0.045)
        let garden = (dark ? Palette.green900 : Palette.green200).opacity(dark ? 0.6 : 0.65)
        let avenue = dark ? Palette.ink650 : Color.white
        let avenueEdge = dark ? Palette.ink850 : Palette.ink200
        let lane = dark ? Palette.ink600.opacity(0.75) : Palette.ink200
        let disc = dark ? Palette.ink900 : Color.white

        return Canvas { ctx, size in
            let full = Path(CGRect(origin: .zero, size: size))
            ctx.fill(full, with: .color(g1))
            ctx.fill(full, with: .radialGradient(Gradient(colors: [g0, g1]),
                                                 center: CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.04),
                                                 startRadius: 0, endRadius: max(rect.width, rect.height) * 0.7))
            ctx.stroke(gridPath, with: .color(gridColor), lineWidth: 0.6)
            for (c, r) in gardens {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [garden, garden.opacity(0)]), center: c, startRadius: 0, endRadius: r))
            }
            for i in centers.indices {
                let c = centers[i], r = radii[i], col = colors[i]
                let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                ctx.fill(circle, with: .radialGradient(Gradient(stops: [
                    .init(color: col.opacity(dark ? 0.22 : 0.16), location: 0),
                    .init(color: col.opacity(0.07), location: 0.75),
                    .init(color: col.opacity(dark ? 0.03 : 0.04), location: 1)
                ]), center: c, startRadius: 0, endRadius: r))
                ctx.stroke(circle, with: .color(col.opacity(dark ? 0.55 : 0.6)), lineWidth: 1.6)
                let ir = r * 0.62
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - ir, y: c.y - ir, width: ir * 2, height: ir * 2)),
                           with: .color(col.opacity(0.22)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 4]))
            }
            ctx.stroke(avenuesPath, with: .color(avenueEdge), style: StrokeStyle(lineWidth: max(3, 16 * unit), lineCap: .round))
            ctx.stroke(avenuesPath, with: .color(avenue), style: StrokeStyle(lineWidth: max(2, 10.5 * unit), lineCap: .round))
            if dark {
                ctx.stroke(avenuesPath, with: .color(Palette.ink400.opacity(0.5)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }
            ctx.stroke(lanesPath, with: .color(lane), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            for i in centers.indices {
                let c = centers[i]
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(disc.opacity(0.92)))
                ctx.fill(MapGeo.spark(c, 6.5), with: .color(colors[i]))
            }
        }
        .allowsHitTesting(false)
    }

    // ===== route and directions =====
    private func routeLayer(_ t: MapTransform) -> some View {
        let walked = route.walked.map { t.point($0) }
        let remaining = route.remaining.map { t.point($0) }
        let exit = route.exit.map { t.point($0) }
        let dir = directions.map { t.point($0) }
        let lw = MapGeo.length(route.walked), lr = MapGeo.length(route.remaining), le = MapGeo.length(route.exit)
        let drawn = playing ? (lw + lr + le) * min(1, max(0, progress)) : (lw + lr + le)
        let fw: CGFloat = lw > 0 ? min(1, max(0, drawn / lw)) : 0
        let fr: CGFloat = lr > 0 ? min(1, max(0, (drawn - lw) / lr)) : 0
        let fe: CGFloat = le > 0 ? min(1, max(0, (drawn - lw - lr) / le)) : 0
        let headPoint: CGPoint? = (playing && progress < 0.999 && route.all.count > 1) ? t.point(head) : nil
        let ahead = Theme.routeAhead
        let behind = Theme.routeWalked
        let nav = Color(hex: 0x12C4DE)
        let casing = Palette.ink900
        return TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: playing)) { timeline in
            let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate * 5)   // slow, calm drift along the walk
            Canvas { ctx, _ in
                func line(_ pts: [CGPoint]) -> Path {
                    var p = Path()
                    guard let f = pts.first else { return p }
                    p.move(to: f)
                    for q in pts.dropFirst() { p.addLine(to: q) }
                    return p
                }
                let rem = line(remaining).trimmedPath(from: 0, to: fr)
                let wk = line(walked).trimmedPath(from: 0, to: fw)
                let ex = line(exit).trimmedPath(from: 0, to: fe)
                // ahead: lime over a navy casing, with a soft glow and dashes that walk forward
                if remaining.count > 1 && fr > 0 {
                    ctx.drawLayer { g in
                        g.addFilter(.blur(radius: 6))
                        g.stroke(rem, with: .color(ahead.opacity(0.5)), style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
                    }
                }
                ctx.stroke(rem, with: .color(casing.opacity(0.85)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                ctx.stroke(rem, with: .color(ahead), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                if !playing {
                    ctx.stroke(rem, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [7, 16], dashPhase: -phase))
                }
                // behind you: blue dashes on a white casing
                ctx.stroke(wk, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round))
                ctx.stroke(wk, with: .color(behind), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round, dash: [6, 6]))
                // the way out: thin lime dots
                ctx.stroke(ex, with: .color(casing.opacity(0.7)), style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round))
                ctx.stroke(ex, with: .color(ahead.opacity(0.95)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [2, 6]))
                // directions to one pavilion: cyan with marching light
                if dir.count > 1 {
                    let d = line(dir)
                    ctx.stroke(d, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                    ctx.stroke(d, with: .color(nav), style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round))
                    ctx.stroke(d, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 2.4, lineCap: .butt, dash: [12, 18], dashPhase: -phase))
                    if let first = dir.first {
                        let r: CGFloat = 7
                        ctx.fill(Path(ellipseIn: CGRect(x: first.x - r, y: first.y - r, width: r * 2, height: r * 2)), with: .color(nav))
                        ctx.stroke(Path(ellipseIn: CGRect(x: first.x - r, y: first.y - r, width: r * 2, height: r * 2)), with: .color(.white), lineWidth: 2)
                    }
                }
                // the head of the line while the trip plays
                if let h = headPoint {
                    let glow: CGFloat = 22
                    ctx.fill(Path(ellipseIn: CGRect(x: h.x - glow, y: h.y - glow, width: glow * 2, height: glow * 2)),
                             with: .radialGradient(Gradient(colors: [ahead.opacity(0.8), ahead.opacity(0)]), center: h, startRadius: 0, endRadius: glow))
                    let dot = CGRect(x: h.x - 6, y: h.y - 6, width: 12, height: 12)
                    ctx.fill(Path(ellipseIn: dot), with: .color(.white))
                    ctx.stroke(Path(ellipseIn: dot), with: .color(ahead), lineWidth: 3)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // ===== while the trip plays: the stop the line just reached gets a name tag =====
    private var reachedStopId: Int? {
        var best: (Int, CGFloat)? = nil
        for (id, at) in route.passAt where at <= progress + 0.002 {
            if best == nil || at > best!.1 { best = (id, at) }
        }
        return best?.0
    }

    @ViewBuilder
    private func playbackCallout(_ t: MapTransform) -> some View {
        if let id = reachedStopId, let pavilion = expo.pavilion(id), let loc = pavilion.location {
            let p = t.point(loc)
            let number: Int? = {
                switch markers[id] {
                case .upcoming(let n), .next(let n), .visited(let n): return n
                default: return nil
                }
            }()
            // the tag opens above the pin and never leaves the screen sideways
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    if let number {
                        Text("\(number)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.ink900)
                            .frame(width: 20, height: 20)
                            .background(Palette.lime500, in: Circle())
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(s.pavilionName(pavilion.name)).font(WJFont.captionBold).foregroundStyle(Theme.textPrimary).lineLimit(1)
                        if let country = pavilion.country, !country.isEmpty {
                            Text(s.countryName(country)).font(WJFont.micro).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(Theme.surface.opacity(0.75))
                }
                .overlay(Capsule().stroke(Palette.lime500.opacity(0.7), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                .environment(\.layoutDirection, s.layoutDirection)
                Triangle().fill(Theme.surface.opacity(0.9)).frame(width: 10, height: 6)
            }
            .fixedSize()
            .id(id)
            .transition(.asymmetric(insertion: .scale(scale: 0.6, anchor: .bottom).combined(with: .opacity),
                                    removal: .opacity))
            .position(x: min(max(p.x, 90), box.width - 90), y: p.y - 44)
            .allowsHitTesting(false)
            .zIndex(4)
        }
    }

    // ===== zone names =====
    @ViewBuilder
    private func zoneLabels(_ t: MapTransform) -> some View {
        ForEach(Array(expo.zones.enumerated()), id: \.element.id) { i, zone in
            if let loc = zone.location {
                let c = t.point(loc)
                let r = MapGeo.zoneRadius(zone) * t.unit
                let col = MapGeo.zoneColor(zone.name, i)
                MapPill(text: s.zoneTitle(zone.name), dot: col, stroke: col.opacity(0.55))
                    .position(x: c.x, y: c.y - r + 6)
                    .allowsHitTesting(false)
            }
        }
    }

    // ===== gates =====
    @ViewBuilder
    private func gates(_ t: MapTransform) -> some View {
        ForEach(expo.entrances) { gate in
            if let loc = gate.location {
                let p = t.point(loc)
                let isStart = route.entrance.map { abs($0.x - CGFloat(loc.x)) < 1 && abs($0.y - CGFloat(loc.y)) < 1 } ?? false
                let isExit = route.exitGate.map { abs($0.x - CGFloat(loc.x)) < 1 && abs($0.y - CGFloat(loc.y)) < 1 } ?? false
                // side gates grow inwards so their name never leaves the screen
                let side: CGFloat = loc.x < 200 ? 1 : (loc.x > 800 ? -1 : 0)
                let anchor: Alignment = side > 0 ? .leading : (side < 0 ? .trailing : .center)
                Color.clear
                    .frame(width: 1, height: 1)
                    .overlay(alignment: anchor) {
                        gateView(gate, start: isStart, exit: isExit).offset(x: side * -14)
                    }
                    .position(p)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func gateView(_ gate: Entrance, start: Bool, exit: Bool) -> some View {
        if start {
            MapPill(text: s.entranceName(gate.name), icon: "figure.walk.arrival", fill: Palette.lime500, fg: Palette.ink900, stroke: .white.opacity(0.6))
        } else if exit {
            MapPill(text: s.t("map.exitGate"), icon: "figure.walk.departure", fill: Theme.primary, fg: .white, stroke: .white.opacity(0.6))
        } else if route.entrance != nil || !showLabels {
            MapGateToken()
        } else {
            MapPill(text: s.entranceName(gate.name), icon: "door.left.hand.open")
        }
    }

    // ===== pavilions =====
    @ViewBuilder
    private func pavilions(_ t: MapTransform) -> some View {
        let zoneIndex = Dictionary(expo.zones.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { a, _ in a })
        ForEach(expo.pavilions) { pavilion in
            if let loc = pavilion.location {
                let kind = markers[pavilion.id] ?? .plain
                let sel = selectedId == pavilion.id
                let zone = expo.zone(of: pavilion.id)
                let accent = MapGeo.zoneColor(zone?.name, zoneIndex[zone?.id ?? -1] ?? 0)
                let waiting = playing && kind != .plain && (route.stopAt[pavilion.id] ?? 0) > progress + 0.002
                let unsuited = !tripNeeds.isEmpty && !pavilion.suits(tripNeeds)
                marker(kind, selected: sel, accent: accent, crowd: crowdLayer ? expo.crowd[pavilion.id]?.level : nil)
                    .scaleEffect(waiting ? 0.3 : 1)
                    .opacity(waiting ? 0 : 1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.55), value: waiting)
                    .opacity((dimUnmarked && markers[pavilion.id] == nil) || unsuited ? 0.4 : 1)
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
                    .onTapGesture { onTap(pavilion.id) }
                    .position(t.point(loc))
                    .zIndex(sel ? 2 : (kind == .plain ? 0 : 1))
                    .accessibilityLabel(s.pavilionName(pavilion.name))
            }
        }
    }

    @ViewBuilder
    private func marker(_ kind: MapMarkerKind, selected: Bool, accent: Color, crowd: String?) -> some View {
        ZStack {
            if selected {
                Circle().fill(Color.white.opacity(0.8)).frame(width: 32, height: 32).blur(radius: 6)
            }
            switch kind {
            case .plain:
                if let crowd {
                    // the queue now: mint calm, amber moderate, red crowded
                    Circle().fill(crowdColor(crowd)).frame(width: selected ? 14 : 11, height: selected ? 14 : 11)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                } else if photo {
                    // the aerial already shows the buildings: a quiet dot, bright when chosen
                    Circle().fill(selected ? Color.white : Color.white.opacity(0.75))
                        .frame(width: selected ? 13 : 7, height: selected ? 13 : 7)
                        .overlay(Circle().stroke(selected ? Palette.lime500 : Palette.ink900.opacity(0.5), lineWidth: selected ? 2.5 : 1))
                } else {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(dark ? Palette.ink700 : Color.white)
                        .frame(width: selected ? 13 : 8, height: selected ? 13 : 8)
                        .overlay(RoundedRectangle(cornerRadius: 2.5, style: .continuous).stroke(selected ? Palette.lime500 : accent, lineWidth: selected ? 2 : 1.4))
                }
            case .picked:
                Circle().fill(Theme.routeAhead).frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Palette.ink900, lineWidth: 2))
                    .shadow(color: .black.opacity(0.35), radius: 2.5, y: 1)
            case .visitedPlain:
                Circle().fill(Theme.routeWalked).frame(width: 18, height: 18)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white))
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.35), radius: 2.5, y: 1)
            case .upcoming(let n):
                numbered(n, size: 22, fill: Theme.primary, text: .white)
            case .next(let n):
                ZStack {
                    MapPulse(color: Palette.lime500)
                    numbered(n, size: 28, fill: Palette.lime500, text: Palette.ink900)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                }
            case .visited(_):
                Circle().fill(Theme.routeWalked).frame(width: 22, height: 22)
                    .overlay(Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white))
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1.5)
            }
        }
    }

    private func crowdColor(_ level: String) -> Color {
        switch level {
        case "CALM": return Palette.mint500
        case "CROWDED": return Palette.red500
        default: return Palette.amber500
        }
    }

    private func numbered(_ n: Int, size: CGFloat, fill: Color, text: Color) -> some View {
        Circle().fill(fill).frame(width: size, height: size)
            .overlay(Text("\(n)").font(.system(size: size * 0.48, weight: .heavy, design: .rounded)).foregroundStyle(text))
            .overlay(Circle().stroke(Palette.ink900.opacity(0.9), lineWidth: 2))
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1.5)
    }

    // ===== pop-up over the chosen pavilion, kept inside the window =====
    private func popupLayer(_ pavilion: Pavilion, at p: CGPoint) -> some View {
        let width: CGFloat = min(330, box.width - 2 * Metrics.margin)
        let half: CGFloat = 135
        let top = insets.top + 8
        let bottom = box.height - insets.bottom - 8
        let above = p.y > (top + bottom) / 2
        let wanted = above ? max(top + half, p.y - 30 - half) : min(bottom - half, p.y + 30 + half)
        let y = min(max(wanted, half + 8), box.height - half - 8)
        return popup(pavilion)
            .frame(width: width)
            .environment(\.layoutDirection, s.layoutDirection)
            .fixedSize(horizontal: false, vertical: true)
            .position(x: min(max(p.x, width / 2 + 12), box.width - width / 2 - 12), y: y)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
            .zIndex(5)
    }
}

// ============================================================================
// Small map parts
// ============================================================================

// the little pointer under the playback tag
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// a glass label on the map (zone or gate name)
struct MapPill: View {
    var text: String
    var dot: Color? = nil
    var icon: String? = nil
    var fill: Color? = nil
    var fg: Color = Theme.textPrimary
    var stroke: Color = Theme.border

    @Environment(AppSettings.self) private var s

    var body: some View {
        HStack(spacing: 5) {
            if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(fg) }
            Text(text).font(WJFont.micro).foregroundStyle(fg).lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background {
            if let fill {
                Capsule().fill(fill)
            } else {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Theme.surface.opacity(0.6))
            }
        }
        .overlay(Capsule().stroke(stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 3, y: 1.5)
        .fixedSize()
        .environment(\.layoutDirection, s.layoutDirection)
    }
}

// a gate without its name (when a route is shown)
struct MapGateToken: View {
    var body: some View {
        Image(systemName: "door.left.hand.open")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 22, height: 16)
            .background {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Theme.surface.opacity(0.6))
            }
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

// the pulse around the next stop
struct MapPulse: View {
    var color: Color
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
            Circle()
                .stroke(color, lineWidth: 2.5)
                .frame(width: 28, height: 28)
                .scaleEffect(CGFloat(1 + t * 0.9))
                .opacity(0.85 * (1 - t))
        }
        .allowsHitTesting(false)
    }
}

// legend chip: words, never colour alone
struct MapLegend: View {
    enum Kind { case route, plan, explore, crowd }
    var kind: Kind = .route
    @Environment(AppSettings.self) private var s

    var body: some View {
        HStack(spacing: 10) {
            switch kind {
            case .route:
                item(Theme.routeAhead, s.t("map.ahead"))
                item(Theme.routeWalked, s.t("map.visited"))
            case .plan:
                item(Theme.routeAhead, s.t("map.legendInPlan"))
                item(Theme.routeWalked, s.t("map.visited"))
            case .explore:
                item(Theme.textSecondary, s.t("map.pavilion"))
                item(Theme.mapGate, s.t("map.gate"))
            case .crowd:
                item(Palette.mint500, s.t("crowd.calm"))
                item(Palette.amber500, s.t("crowd.moderate"))
                item(Palette.red500, s.t("crowd.crowded"))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(Theme.surface.opacity(0.6))
        }
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .environment(\.layoutDirection, s.layoutDirection)
    }

    private func item(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textPrimary)
        }
    }
}

// glass + / − so everyone can zoom, not only with two fingers
struct MapZoomControl: View {
    @Environment(AppSettings.self) private var s
    let zoomIn: () -> Void
    let zoomOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            button("plus", s.t("map.zoomIn"), zoomIn)
            Rectangle().fill(Theme.border).frame(width: 26, height: 1)
            button("minus", s.t("map.zoomOut"), zoomOut)
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface.opacity(0.6))
        }
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private func button(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// the lime play button that replays the trip
struct MapPlayButton: View {
    @Environment(AppSettings.self) private var s
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.ink900)
                .frame(width: 40, height: 40)
                .background(Palette.lime500, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                .shadow(color: Palette.lime500.opacity(0.45), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(s.t("map.watchTrip"))
    }
}

// توضيحية / مصوّرة switch (2 segment glass control with words)
struct MapStyleSwitch: View {
    @Environment(AppSettings.self) private var s
    var body: some View {
        @Bindable var settings = s
        SegmentedPill(options: [(MapStyle.illustrated, s.t("map.illustrated"), "map"), (MapStyle.image, s.t("map.photo"), "photo")],
                      selection: $settings.mapStyle)
            .fixedSize()   // the labels are never truncated, whatever sits beside the switch
    }
}

// overlays report their height so the map keeps its camera (and pop-ups) clear of them
struct MapTopInsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct MapBottomInsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

extension View {
    func reportHeight<K: PreferenceKey>(_ key: K.Type) -> some View where K.Value == CGFloat {
        background(GeometryReader { geo in
            Color.clear.preference(key: key, value: geo.size.height)
        })
    }
}
