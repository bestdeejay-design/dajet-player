// The app's icon, drawn rather than exported.
//
// The mark is Dajet's wave — the same shape the brand canon fixes in
// brand/signs/dajet-player/icon.svg, and the website's mark (systems/player).
// It is reproduced here from its own path data, at the canon's numbers, so it
// stays a crisp vector at every size instead of a raster scaled up, and so the
// repository carries no image asset.
//
// The canon, in one place: a plate #15181C filling the whole 1024 canvas, its
// corner a superellipse n = 5 (0.2253 × canvas); the wave in terracotta
// #E8AE8C, stroke 92, round caps and joins; nothing else — no gradient, no
// shadow, no glow, no transparency, exactly two colours.
//
//   swift Icon/icon.swift build/AppIcon.iconset
//   swift Icon/icon.swift build/AppIcon.iconset build/AppIcon.icon
//
// The first argument is where the ten PNGs of a .iconset go. The second, when
// given, is an Icon Composer document (macOS 26's Dark, Clear and Tinted Dock
// styles), which build.sh hands to actool.

import AppKit

let args = CommandLine.arguments
let out = URL(fileURLWithPath: args.count > 1 ? args[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// The canon's own numbers.
let canvas = 1024.0
let plateHex = "#15181C"
let markHex = "#E8AE8C"
let strokeWidth = 92.0
let cornerFactor = 0.2253
// The superellipse's exponent. 5 is the canon's "continuous" corner, between a
// rounded rectangle and Apple's squircle; higher is squarer.
let cornerN = 5.0

func color(_ hex: String) -> NSColor {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    return NSColor(
        red: CGFloat((v >> 16) & 0xFF) / 255,
        green: CGFloat((v >> 8) & 0xFF) / 255,
        blue: CGFloat(v & 0xFF) / 255,
        alpha: 1
    )
}

/// A tiny reader for the one path the wave is: absolute M, L, H, V, C, Z — what
/// Figma writes for a flattened shape, and nothing else.
func svgCommands(_ d: String) -> [(Character, [CGFloat])] {
    var out: [(Character, [CGFloat])] = []
    var current: Character?
    var numbers: [CGFloat] = []
    var token = ""
    func flushNumber() {
        if !token.isEmpty, let v = Double(token) { numbers.append(CGFloat(v)) }
        token = ""
    }
    for ch in d {
        if "MLHVCZmlhvcz".contains(ch) {
            flushNumber()
            if let current { out.append((current, numbers)) }
            current = ch
            numbers = []
        } else if ch == " " || ch == "," {
            flushNumber()
        } else if ch == "-" && !token.isEmpty && !token.hasSuffix("e") {
            flushNumber()
            token = "-"
        } else {
            token.append(ch)
        }
    }
    flushNumber()
    if let current { out.append((current, numbers)) }
    return out
}

/// The wave, on its own 512 × 512 canvas — the path from the canon, with the
/// plate's 230.7 offset and doubled stroke stripped, so it can be placed on any
/// body. `crest` is the half-height it swings to; the knots are the original
/// ones, scaled, and the polyline is stroked, not filled, the way the SVG does.
struct Wave {
    static let knots: [(CGFloat, CGFloat)] = [
        (141.6699, 512), (147.4610, 497.1371), (153.2396, 482.4233), (159.0307, 467.9953),
        (164.8217, 453.9775), (170.6004, 440.5313), (176.3915, 427.7685), (182.1701, 415.8136),
        (187.9612, 404.7907), (193.7522, 394.7992), (199.5309, 385.9386), (205.3219, 378.2959),
        (211.1130, 371.9332), (216.8917, 366.9126), (222.6827, 363.2963), (228.4614, 361.1216),
        (234.2524, 360.3883), (240.0435, 361.1216), (245.8221, 363.2963), (251.6132, 366.9126),
        (257.4043, 371.9332), (263.1829, 378.2959), (268.9740, 385.9386), (274.7526, 394.7992),
        (280.5437, 404.7907), (286.3348, 415.8136), (292.1134, 427.7685), (297.9045, 440.5313),
        (303.6955, 453.9775), (309.4742, 467.9953), (315.2652, 482.4233), (321.0439, 497.1371),
        (326.8350, 512), (332.6260, 526.8629), (338.4047, 541.5767), (344.1957, 556.0047),
        (349.9868, 570.0225), (355.7654, 583.4687), (361.5565, 596.2315), (367.3351, 608.1864),
        (373.1262, 619.2093), (378.9173, 629.2008), (384.6959, 638.0614), (390.4870, 645.7041),
        (396.2781, 652.0668), (402.0567, 657.0874), (407.8478, 660.7037), (413.6264, 662.8784),
        (419.4175, 663.6117), (425.2085, 662.8784), (430.9872, 660.7037), (436.7783, 657.0874),
        (442.5693, 652.0668), (448.3480, 645.7041), (454.1390, 638.0614), (459.9177, 629.2008),
        (465.7087, 619.2093), (471.4998, 608.1864), (477.2784, 596.2315), (483.0695, 583.4687),
        (488.8606, 570.0225), (494.6392, 556.0047), (500.4303, 541.5767), (506.2089, 526.8629),
        (512.0000, 512), (517.7911, 497.1371), (523.5697, 482.4233), (529.3608, 467.9953),
        (535.1518, 453.9775), (540.9305, 440.5313), (546.7216, 427.7685), (552.5002, 415.8136),
        (558.2913, 404.7907), (564.0823, 394.7992), (569.8610, 385.9386), (575.6520, 378.2959),
        (581.4431, 371.9332), (587.2217, 366.9126), (593.0128, 363.2963), (598.7915, 361.1216),
        (604.5825, 360.3883), (610.3736, 361.1216), (616.1522, 363.2963), (621.9433, 366.9126),
        (627.7344, 371.9332), (633.5130, 378.2959), (639.3041, 385.9386), (645.0827, 394.7992),
        (650.8738, 404.7907), (656.6649, 415.8136), (662.4435, 427.7685), (668.2346, 440.5313),
        (674.0256, 453.9775), (679.8043, 467.9953), (685.5953, 482.4233), (691.3740, 497.1371),
        (697.1650, 512), (702.9561, 526.8629), (708.7348, 541.5767), (714.5258, 556.0047),
        (720.3169, 570.0225), (726.0955, 583.4687), (731.8866, 596.2315), (737.6652, 608.1864),
        (743.4563, 619.2093), (749.2474, 629.2008), (755.0260, 638.0614), (760.8171, 645.7041),
        (766.6082, 652.0668), (772.3868, 657.0874), (778.1779, 660.7037), (783.9565, 662.8784),
        (789.7476, 663.6117), (795.5386, 662.8784), (801.3173, 660.7037), (807.1083, 657.0874),
        (812.8994, 652.0668), (818.6781, 645.7041), (824.4691, 638.0614), (830.2478, 629.2008),
        (836.0388, 619.2093), (841.8299, 608.1864), (847.6085, 596.2315), (853.3996, 583.4687),
        (859.1907, 570.0225), (864.9693, 556.0047), (870.7604, 541.5767), (876.5390, 526.8629),
        (882.3301, 512),
    ]

    /// Two crests, centred horizontally, on the plate's middle line. The canon's
    /// stroke is 92 on a canvas of 1024, so it scales with the body.
    static func path(in body: NSRect) -> NSBezierPath {
        let s = body.width / canvas
        let midY = body.midY
        // The canon's wave rides high: its middle line (512) sits above the
        // canvas centre (512), and the crest reaches 663.6 — 151.6 below it.
        // Keep that feel by centring the crest band on the plate's middle.
        let baseline = midY + 12 * s
        let path = NSBezierPath()
        path.lineWidth = strokeWidth * s
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        for (i, knot) in knots.enumerated() {
            // The knot's own y, flipped: SVG grows downward, AppKit upward.
            let x = body.minX + knot.0 * s
            let y = baseline + (512 - knot.1) * s
            if i == 0 { path.move(to: NSPoint(x: x, y: y)) } else { path.line(to: NSPoint(x: x, y: y)) }
        }
        return path
    }
}

/// The plate: a superellipse, not a rounded rectangle. Rendered as a polygon of
/// the parametric curve, so the corner is the canon's continuous one at every
/// size, and drawn on the whole canvas with no transparent margin (macOS 26
/// wraps a margined icon in a plate of its own, an icon inside an icon).
///
/// The polygon's chords fall a hair inside the true curve, and every drawn edge
/// is antialiased, so a plate that merely *touches* the canvas leaves its outer
/// row of pixels a blend rather than the plate colour — the `edge` check in
/// media/check-icns.mjs then reads a margin where the eye sees none. The plate
/// is therefore overhung: the curve is drawn out to `rect` plus the antialias
/// fringe, so the canvas's own edge lands well inside the solid plate.
func platePath(in rect: NSRect) -> NSBezierPath {
    // One pixel of overhang, in the rect's own units, is enough to swallow the
    // antialiased edge; a little more keeps the corners solid after downscale.
    let overhang = rect.width * 0.006
    let grown = rect.insetBy(dx: -overhang, dy: -overhang)
    let a = grown.width / 2
    let b = grown.height / 2
    let cx = grown.midX
    let cy = grown.midY
    let path = NSBezierPath()
    // Dense enough that the chord sag stays far under one pixel at 1024: with
    // 2880 steps the straight segments differ from the curve by <0.05 px.
    let steps = max(2880, Int(grown.width * 3))
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let ct = cos(t)
        let st = sin(t)
        // |x/a|^n + |y/b|^n = 1, solved for x and y by the signed power.
        let x = cx + a * CGFloat(copysign(pow(abs(ct), 2 / cornerN), ct))
        let y = cy + b * CGFloat(copysign(pow(abs(st), 2 / cornerN), st))
        let p = NSPoint(x: x, y: y)
        if i == 0 { path.move(to: p) } else { path.line(to: p) }
    }
    path.close()
    return path
}

func draw(_ pixels: CGFloat) {
    let canvasRect = NSRect(x: 0, y: 0, width: pixels, height: pixels)

    color(plateHex).setFill()
    platePath(in: canvasRect).fill()

    let body = canvasRect.insetBy(dx: canvasRect.width * cornerFactor * 0.5,
                                  dy: canvasRect.height * cornerFactor * 0.5)
    color(markHex).setStroke()
    Wave.path(in: body).stroke()
}

/// Draws the icon straight into a bitmap the requested pixel size — one focus,
/// no NSImage round-trip, so nothing resamples the plate's own edge.
func bitmap(_ pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.shouldAntialias = true
    draw(CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// One master, downscaled: the plate's edge is solid in the master, and every
// smaller size is a filtered reduction of it rather than a fresh draw.
let master = bitmap(1024)

// The .icns' entries: the ten PNG types Apple's own icon sets carry, in their
// order. Only PNG types are written — `iconutil` also emits the legacy raw
// bitmap types (ic04, ic05, info), which a modern reader cannot decode and
// media/check-icns.mjs flags as defects.
let entries: [(String, Int)] = [
    ("icp4", 16), ("icp5", 32), ("ic07", 128), ("ic08", 256), ("ic09", 512),
    ("ic10", 1024), ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512),
]

func pngData(_ pixels: Int) -> Data? {
    if pixels == 1024 {
        return master.representation(using: .png, properties: [:])
    }
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    master.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

func be32(_ v: Int) -> Data {
    var b = UInt32(v).bigEndian
    return Data(bytes: &b, count: 4)
}

/// A modern .icns: an `icns` header and one PNG chunk per entry, each chunk a
/// four-byte type, its length (including those eight bytes) and the PNG.
func writeICNS(to url: URL) {
    var body = Data()
    for (type, pixels) in entries {
        guard let png = pngData(pixels) else { continue }
        body.append(type.data(using: .ascii)!)
        body.append(be32(png.count + 8))
        body.append(png)
    }
    var file = Data()
    file.append("icns".data(using: .ascii)!)
    file.append(be32(body.count + 8))
    file.append(body)
    try? file.write(to: url)
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        guard let png = pngData(pixels) else { continue }
        try? png.write(to: out.appendingPathComponent(name))
    }
}
print("drew: \(out.path)")

// The same ten rasters as one .icns, written beside the iconset (same stem),
// so build.sh needs no iconutil.
let icns = out.deletingPathExtension().appendingPathExtension("icns")
writeICNS(to: icns)
print("wrote: \(icns.path)")

// The same icon as an Icon Composer document, when a second path is given.
// macOS 26 lets the Dock show icons Dark, Clear or Tinted, and it can only do
// that well with an icon that says what each style should be. Here the plate
// and the wave are separate layers, so Dark turns them round — a terracotta
// wave on the ink plate — and Tinted gets a white wave whose brightness the
// system tints. build.sh compiles the document with actool; the images above
// stay the .icns, the disk image's icon and the fallback.
if args.count > 2 {
    let doc = URL(fileURLWithPath: args[2])
    let assets = doc.appendingPathComponent("Assets")
    try? FileManager.default.removeItem(at: doc)
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

    // The wave as one stroked polyline in its own 1024 box — the canon's
    // coordinates, so the SVG is exactly what Canvas shows.
    var d = ""
    for (i, knot) in Wave.knots.enumerated() {
        d += i == 0 ? "M \(knot.0) \(knot.1)" : " L \(knot.0) \(knot.1)"
    }
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\
    <path fill="none" stroke="\(markHex)" stroke-width="\(strokeWidth)" stroke-linecap="round" stroke-linejoin="round" d="\(d)"/></svg>
    """
    try svg.write(to: assets.appendingPathComponent("wave.svg"), atomically: true, encoding: .utf8)

    let plate = #"{ "solid" : "srgb:0.08235,0.09412,0.10980,1.00000" }"#
    let terracotta = #"{ "solid" : "srgb:0.90980,0.68235,0.54902,1.00000" }"#
    let white = #"{ "solid" : "srgb:1.00000,1.00000,1.00000,1.00000" }"#
    let json = """
    {
      "fill" : \(plate),
      "fill-specializations" : [
        { "value" : \(plate) },
        { "appearance" : "dark", "value" : \(plate) }
      ],
      "groups" : [
        {
          "layers" : [
            {
              "name" : "wave",
              "image-name" : "wave.svg",
              "glass" : false,
              "fill-specializations" : [
                { "value" : \(terracotta) },
                { "appearance" : "dark", "value" : \(terracotta) },
                { "appearance" : "tinted", "value" : \(white) }
              ]
            }
          ],
          "shadow" : { "kind" : "none", "opacity" : 0.5 },
          "specular" : false,
          "translucency" : { "enabled" : false, "value" : 0.5 }
        }
      ],
      "supported-platforms" : { "squares" : [ "macOS" ] }
    }
    """
    try json.write(to: doc.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
    print("wrote: \(doc.path)")
}
