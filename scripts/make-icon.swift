import AppKit

let destination = CommandLine.arguments.dropFirst().first ?? "dist/Notes-icon.png"
let size = 1024
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
    let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Could not create icon canvas") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
canvas.fill()

let tile = NSBezierPath(roundedRect: NSRect(x: 34, y: 34, width: 956, height: 956), xRadius: 218, yRadius: 218)
NSGradient(starting: NSColor(calibratedRed: 0.17, green: 0.19, blue: 0.22, alpha: 1),
    ending: NSColor(calibratedRed: 0.075, green: 0.105, blue: 0.105, alpha: 1))!.draw(in: tile, angle: -60)

NSGraphicsContext.saveGraphicsState()
tile.addClip()
let glow = NSBezierPath(ovalIn: NSRect(x: 420, y: 390, width: 620, height: 620))
NSGradient(starting: NSColor(calibratedRed: 0.24, green: 0.46, blue: 0.35, alpha: 0.24),
    ending: NSColor(calibratedRed: 0.24, green: 0.46, blue: 0.35, alpha: 0))!.draw(in: glow, relativeCenterPosition: .zero)
NSGraphicsContext.restoreGraphicsState()
NSColor(calibratedWhite: 1, alpha: 0.13).setStroke()
tile.lineWidth = 5
tile.stroke()

let noteRect = NSRect(x: 244, y: 207, width: 536, height: 610)
let note = NSBezierPath(roundedRect: noteRect, xRadius: 85, yRadius: 85)
let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.39)
shadow.shadowBlurRadius = 42
shadow.shadowOffset = NSSize(width: 0, height: -25)
shadow.set()
NSGradient(starting: NSColor(calibratedRed: 0.99, green: 0.99, blue: 0.98, alpha: 1),
    ending: NSColor(calibratedRed: 0.83, green: 0.86, blue: 0.85, alpha: 1))!.draw(in: note, angle: -85)
NSShadow().set()

let spine = NSBezierPath(roundedRect: NSRect(x: 285, y: 260, width: 35, height: 500), xRadius: 17, yRadius: 17)
NSColor(calibratedRed: 0.98, green: 0.37, blue: 0.43, alpha: 1).setFill()
spine.fill()

for (index, width) in [330.0, 285.0, 350.0].enumerated() {
    let line = NSBezierPath(roundedRect: NSRect(x: 368, y: 651 - CGFloat(index) * 105, width: width, height: 31), xRadius: 15, yRadius: 15)
    NSColor(calibratedRed: 0.24, green: 0.29, blue: 0.30, alpha: index == 0 ? 0.76 : 0.47).setFill()
    line.fill()
}

let dot = NSBezierPath(ovalIn: NSRect(x: 368, y: 330, width: 49, height: 49))
NSColor(calibratedRed: 0.98, green: 0.37, blue: 0.43, alpha: 1).setFill()
dot.fill()
let finalLine = NSBezierPath(roundedRect: NSRect(x: 444, y: 339, width: 218, height: 31), xRadius: 15, yRadius: 15)
NSColor(calibratedRed: 0.24, green: 0.29, blue: 0.30, alpha: 0.47).setFill()
finalLine.fill()

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not encode icon PNG") }
try png.write(to: URL(fileURLWithPath: destination), options: .atomic)
