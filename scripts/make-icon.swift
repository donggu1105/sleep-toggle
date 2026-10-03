import AppKit

// 메뉴 막대의 달 모티프를 앱 아이콘에도 사용한다. 시스템 심벌과 벡터만으로
// 모든 해상도를 직접 그려 추가 이미지 의존성과 흐릿한 확대를 피한다.
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func render(pixels: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 205, yRadius: 205)
    NSGradient(colors: [
        NSColor(srgbRed: 0.10, green: 0.15, blue: 0.33, alpha: 1),
        NSColor(srgbRed: 0.30, green: 0.38, blue: 0.75, alpha: 1),
    ])!.draw(in: tile, angle: 60)
    let moon = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(paletteColors: [.white]))!
    moon.draw(in: NSRect(x: 202, y: 282, width: 590, height: 590))
    let track = NSBezierPath(roundedRect: NSRect(x: 405, y: 178, width: 414, height: 206), xRadius: 103, yRadius: 103)
    NSColor(srgbRed: 0.43, green: 0.87, blue: 0.77, alpha: 1).setFill()
    track.fill()
    NSColor.white.withAlphaComponent(0.32).setStroke()
    track.lineWidth = 8
    track.stroke()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 628, y: 202, width: 158, height: 158)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(pixels: size).write(to: destination.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(pixels: size * 2).write(to: destination.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
print("앱 아이콘 생성 완료")
