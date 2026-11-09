// Renders the app icon to a 1024×1024 PNG.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let red = NSColor(srgbRed: 0.93, green: 0.27, blue: 0.25, alpha: 1)
let green = NSColor(srgbRed: 0.33, green: 0.82, blue: 0.40, alpha: 1)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: 824 pt rounded square centred on a 1024 canvas.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

// Soft drop shadow, then the dark tile with a subtle vertical gradient.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor.black.setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(starting: NSColor(white: 0.16, alpha: 1), ending: NSColor(white: 0.05, alpha: 1))!
    .draw(in: tilePath, angle: -90)

// Timer ring: green "rest" arc and a longer red "work" arc, like a running countdown.
let center = NSPoint(x: tile.midX, y: tile.midY)
let radius: CGFloat = 330
func arc(from start: CGFloat, to end: CGFloat, color: NSColor) {
    let p = NSBezierPath()
    p.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
    p.lineWidth = 38
    p.lineCapStyle = .round
    color.setStroke()
    p.stroke()
}
let track = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
track.lineWidth = 38
NSColor(white: 1, alpha: 0.07).setStroke()
track.stroke()
arc(from: 90, to: -150, color: red)     // clockwise from 12 o'clock, two-thirds of the way round
arc(from: -168, to: -240, color: green) // remaining gap, after a small break

// Two-line wordmark.
func font(_ pointSize: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: pointSize, weight: .heavy)
    let rounded = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
    return NSFont(descriptor: rounded, size: pointSize) ?? base
}
func drawCentered(_ text: String, color: NSColor, pointSize: CGFloat, baselineOffset: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font(pointSize), .foregroundColor: color, .kern: -2]
    let s = NSAttributedString(string: text, attributes: attrs)
    let b = s.size()
    s.draw(at: NSPoint(x: center.x - b.width / 2, y: center.y + baselineOffset - b.height / 2))
}
drawCentered("Workout", color: red, pointSize: 128, baselineOffset: 62)
drawCentered("Timer", color: green, pointSize: 128, baselineOffset: -70)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
