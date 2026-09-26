// アプリアイコン（AppIcon.icns）を作るスクリプト
//   swift icon/make-icon.swift             → icon/AppIcon.icns
//   swift icon/make-icon.swift preview.png → 1024px の PNG だけ書き出す（確認用）
// 緑から青のグラデーションの角丸四角。白いクリップボードの後ろに、履歴を表すカードが 2 枚重なっている。
import AppKit

let dir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // 1024 四方の座標で描く
    let k = CGFloat(px) / 1024
    let t = NSAffineTransform()
    t.scale(by: k)
    t.concat()

    func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
    }
    func withShadow(_ blur: CGFloat, _ dy: CGFloat, _ alpha: CGFloat, _ draw: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        let sh = NSShadow()
        sh.shadowColor = NSColor.black.withAlphaComponent(alpha)
        sh.shadowOffset = NSSize(width: 0, height: dy * k)   // 影はデバイス座標なので倍率をかける
        sh.shadowBlurRadius = blur * k
        sh.set()
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }

    // macOS のアイコンの枠：1024 のうち 824 四方、角の半径 185
    let bg = rr(100, 100, 824, 824, 185)
    withShadow(20, -10, 0.3) { NSColor.black.setFill(); bg.fill() }
    NSGradient(starting: rgb(48, 200, 170), ending: rgb(32, 104, 210))!.draw(in: bg, angle: -90)

    // 後ろに重なった履歴のカード
    rgb(255, 255, 255, 0.35).setFill()
    rr(380, 190, 400, 520, 44).fill()
    rgb(255, 255, 255, 0.6).setFill()
    rr(330, 225, 400, 520, 44).fill()

    // クリップボード本体
    let board = rr(280, 260, 400, 520, 44)
    withShadow(30, -12, 0.3) { NSColor.white.setFill(); board.fill() }
    // 上の留め具
    rgb(40, 60, 95).setFill()
    rr(390, 735, 180, 90, 30).fill()
    rgb(48, 200, 170).setFill()
    rr(445, 775, 70, 24, 12).fill()
    // 文字の行
    rgb(190, 200, 215).setFill()
    for (i, w) in [300, 300, 300, 180].enumerated() {
        rr(330, 640 - CGFloat(i) * 90, CGFloat(w), 34, 17).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

if CommandLine.arguments.count > 1 {
    try! render(1024).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    print("作成: \(CommandLine.arguments[1])")
    exit(0)
}

let iconset = dir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! render(base * scale).write(to: iconset.appendingPathComponent(name))
    }
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", dir.appendingPathComponent("AppIcon.icns").path]
try! p.run()
p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(p.terminationStatus == 0 ? "作成: icon/AppIcon.icns" : "iconutil が失敗しました")
