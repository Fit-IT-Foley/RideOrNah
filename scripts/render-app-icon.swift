// Draws the app icon, option E ("Tachometer") on the design canvas's "App icon — wordmark with
// gauge" board, and writes it as an opaque 1024 × 1024 PNG into the iPhone and watch apps' AppIcon
// asset catalogs. Run it with `make app-icon` after changing the design.
//
// The geometry is the board's, in its 300-point space. The wordmark uses the same system fonts as
// the app's `Wordmark`: heavy condensed for RIDE and NAH, semibold italic serif for "or".
import AppKit
import CoreText

let pixels = 1024
let unit = CGFloat(pixels) / 300
let center = CGPoint(x: 150, y: 152)

let ground = CGColor(srgbRed: 0x0A / 255, green: 0x0B / 255, blue: 0x0D / 255, alpha: 1)
let ink = CGColor(srgbRed: 0xF2 / 255, green: 0xF1 / 255, blue: 0xEE / 255, alpha: 1)
let accent = CGColor(srgbRed: 0xFF / 255, green: 0x6B / 255, blue: 0x1A / 255, alpha: 1)
let nah = CGColor(srgbRed: 0xBF / 255, green: 0xD8 / 255, blue: 0xEE / 255, alpha: 1)

/// A point on the dial in the board's space, where y grows downward.
func point(radius: CGFloat, degrees: CGFloat) -> CGPoint {
    let radians = degrees * .pi / 180
    return CGPoint(x: center.x + radius * cos(radians), y: center.y - radius * sin(radians))
}

guard
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("Couldn't create the drawing context") }

// Work in the board's space: origin top left, 300 points across.
context.translateBy(x: 0, y: CGFloat(pixels))
context.scaleBy(x: unit, y: -unit)
context.setFillColor(ground)
context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
context.setLineCap(.round)

// 21 ticks across 270°, from lower left over the top to lower right. Every fifth is major.
// Ticks on the Ride side are orange and the rest blue.
for index in 0..<21 {
    let degrees = 225 - CGFloat(index) * 270 / 20
    let major = index % 5 == 0
    context.setStrokeColor(degrees > 76 ? accent : nah)
    context.setLineWidth(major ? 7 : 5)
    context.move(to: point(radius: major ? 108 : 116, degrees: degrees))
    context.addLine(to: point(radius: major ? 132 : 130, degrees: degrees))
    context.strokePath()
}

// The needle, on Ride.
context.setStrokeColor(ink)
context.setLineWidth(9)
context.move(to: point(radius: 92, degrees: 148))
context.addLine(to: point(radius: 140, degrees: 148))
context.strokePath()

/// Draws one line of the wordmark centered on the icon, with its baseline at `baseline`.
func draw(_ text: String, font: NSFont, color: CGColor, baseline: CGFloat, tracking: CGFloat = 0) {
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: tracking]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let width = CTLineGetTypographicBounds(line, nil, nil, nil) - Double(tracking)
    context.saveGState()
    // Text draws upward, so flip back around the baseline.
    context.translateBy(x: 150 - CGFloat(width) / 2, y: baseline)
    context.scaleBy(x: 1, y: -1)
    context.textPosition = .zero
    CTLineDraw(line, context)
    context.restoreGState()
}

let display = NSFont.systemFont(ofSize: 66, weight: .heavy, width: .condensed)
let reasonDescriptor = NSFont.systemFont(ofSize: 42, weight: .semibold).fontDescriptor.withDesign(.serif)!
    .withSymbolicTraits(.italic)
let reason = NSFont(descriptor: reasonDescriptor, size: 42)!

draw("RIDE", font: display, color: ink, baseline: 137, tracking: -1)
draw("or", font: reason, color: accent, baseline: 165)
draw("NAH", font: display, color: nah, baseline: 213, tracking: -1)

guard let image = context.makeImage() else { fatalError("Couldn't render the icon") }
let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!

let root = URL(filePath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
for catalog in ["RideOrNah/Assets.xcassets", "Watch/App/Assets.xcassets"] {
    let url = root.appending(path: "\(catalog)/AppIcon.appiconset/AppIcon.png")
    try png.write(to: url)
    print("Wrote \(url.path(percentEncoded: false))")
}
