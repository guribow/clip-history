// 履歴の中身を大きめに見せる部品
// 行にマウスを置いたときにパネルの横に出す窓と、右クリックのメニューの一番上で使う
import AppKit
import ImageIO

enum Preview {
    static let maxWidth: CGFloat = 380
    static let maxLines = 30
    static let imageSize: CGFloat = 320
    static let inset: CGFloat = 10

    /// item の中身（テキストは全文を折り返して最大 maxLines 行、画像は大きめ）を、余白込みの大きさで作る
    static func content(_ item: ClipItem, store: Store) -> NSView? {
        let inner: NSView
        switch item.kind {
        case .text:
            let label = NSTextField(wrappingLabelWithString: fullText(item))
            label.font = .systemFont(ofSize: 12)
            label.textColor = .labelColor
            label.maximumNumberOfLines = maxLines
            label.cell?.truncatesLastVisibleLine = true
            label.preferredMaxLayoutWidth = maxWidth - inset * 2
            let fit = label.fittingSize
            label.frame.size = NSSize(width: min(fit.width, maxWidth - inset * 2), height: fit.height)
            inner = label
        case .image:
            guard let image = loadImage(item, store: store) else { return nil }
            let view = NSImageView(image: image)
            view.imageScaling = .scaleProportionallyUpOrDown
            let s = image.size
            let scale = min(1, imageSize / max(s.width, s.height, 1))
            view.frame.size = NSSize(width: max(s.width * scale, 40), height: max(s.height * scale, 40))
            inner = view
        }
        let box = NSView(frame: NSRect(x: 0, y: 0, width: inner.frame.width + inset * 2,
                                       height: inner.frame.height + inset * 2))
        inner.frame.origin = NSPoint(x: inset, y: inset)
        box.addSubview(inner)
        return box
    }

    /// 大きな画像でも速いように ImageIO で縮めて読む
    private static func loadImage(_ item: ClipItem, store: Store) -> NSImage? {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: imageSize * 2] as CFDictionary
        guard let url = store.imageURL(for: item),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else { return nil }
        // Retina で細かく見えるよう、点の大きさは画素の半分にする
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / 2, height: CGFloat(cg.height) / 2))
    }
}

/// 行にマウスを置いたときに、パネルの横に出す窓。クリックは受けない
final class PreviewWindow {
    private let window: NSPanel
    private let bg = NSVisualEffectView()
    private var shownID: UUID?

    init() {
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: true)
        window.level = NSWindow.Level(NSWindow.Level.popUpMenu.rawValue + 1)   // メニューより手前
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        bg.material = .menu
        bg.state = .active
        bg.blendingMode = .behindWindow
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 8
        bg.layer?.masksToBounds = true
        window.contentView = bg
    }

    var isVisible: Bool { window.isVisible }

    /// anchor は行の位置、beside はパネルの枠（どちらも画面の座標）。パネルの右に出し、入らなければ左に出す
    func show(_ item: ClipItem, store: Store, anchor: NSRect, beside: NSRect) {
        if shownID != item.id {
            guard let content = Preview.content(item, store: store) else { hide(); return }
            bg.subviews.forEach { $0.removeFromSuperview() }
            bg.addSubview(content)
            window.setContentSize(content.frame.size)
            shownID = item.id
        }
        let size = window.frame.size
        let screen = NSScreen.screens.first { $0.frame.intersects(beside) } ?? NSScreen.main
        let vf = screen?.visibleFrame ?? beside
        var x = beside.maxX + 6
        if x + size.width > vf.maxX - 4 { x = beside.minX - 6 - size.width }
        var y = anchor.maxY - size.height   // 上端を行にそろえる
        y = min(max(y, vf.minY + 4), vf.maxY - size.height - 4)
        window.setFrameOrigin(NSPoint(x: x, y: y))
        window.orderFront(nil)
    }

    func hide() {
        window.orderOut(nil)
        shownID = nil
    }
}
