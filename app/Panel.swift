// ショートカットキーで出す履歴のパネル
// 今のアプリのフォーカスを奪わずに（アプリを切り替えずに）、キー入力だけを受ける
import AppKit
import ImageIO

/// 枠のないパネルでもキー入力を受け、⌘1〜⌘9 を拾う
private final class KeyPanel: NSPanel {
    var onCommandDigit: ((Int) -> Void)?
    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let c = event.charactersIgnoringModifiers, let n = Int(c), (1...9).contains(n) {
            onCommandDigit?(n)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// パネルがキーを持っていなくても、選んだ行を強い色で見せる
private final class EmphasizedRowView: NSTableRowView {
    override var isEmphasized: Bool { get { true } set {} }
}

/// 1 行：コピー元のアプリのアイコン、縮小画像、中身、時間、⌘数字
private final class RowView: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("row")
    let appIcon = NSImageView()
    let thumb = NSImageView()
    let label = NSTextField(labelWithString: "")
    let time = NSTextField(labelWithString: "")
    let shortcut = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        identifier = Self.id
        textField = label
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for f in [time, shortcut] {
            f.font = .systemFont(ofSize: 11)
            f.textColor = .secondaryLabelColor
            f.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        thumb.imageScaling = .scaleProportionallyUpOrDown
        let stack = NSStackView(views: [appIcon, thumb, label, time, shortcut])
        stack.spacing = 8
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            appIcon.widthAnchor.constraint(equalToConstant: 18),
            appIcon.heightAnchor.constraint(equalToConstant: 18),
            thumb.widthAnchor.constraint(equalToConstant: 28),
            thumb.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class PanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    static let width: CGFloat = 440
    static let rowHeight: CGFloat = 36
    static let visibleRows = 9

    private let store: Store
    private let onPick: (ClipItem) -> Void
    private let panel: KeyPanel
    private let field = NSTextField()
    private let table = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private var shown: [ClipItem] = []
    private var thumbs: [UUID: NSImage] = [:]
    private var appIcons: [String: NSImage] = [:]
    private let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "ja")   // アプリの言語に合わせる
        return f
    }()

    init(store: Store, onPick: @escaping (ClipItem) -> Void) {
        self.store = store
        self.onPick = onPick
        let height = 44 + Self.rowHeight * CGFloat(Self.visibleRows) + 8
        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: height),
                         styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                         backing: .buffered, defer: true)
        super.init()
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        [.closeButton, .miniaturizeButton, .zoomButton].forEach { panel.standardWindowButton($0)?.isHidden = true }
        panel.isMovable = false
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.onCommandDigit = { [weak self] n in self?.pick(row: n - 1) }
        build()
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { panel.isVisible ? close() : show() }

    func show() {
        field.stringValue = ""
        reload()
        position()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }

    func close() { panel.orderOut(nil) }

    /// ほかの場所をクリックしたら閉じる
    func windowDidResignKey(_ notification: Notification) { close() }

    /// 開いている間に履歴が変わったら作り直す
    func refreshIfVisible() {
        if panel.isVisible { reload(keepSelection: true) }
    }

    // MARK: - 画面を作る

    private func build() {
        let bg = NSVisualEffectView()
        bg.material = .menu
        bg.state = .active
        bg.blendingMode = .behindWindow
        panel.contentView = bg

        field.placeholderString = L("絞り込み")
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 16)
        field.delegate = self
        field.setAccessibilityIdentifier("filter")

        let column = NSTableColumn(identifier: .init("item"))
        column.width = Self.width
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .plain
        table.rowHeight = Self.rowHeight
        table.intercellSpacing = .zero
        table.backgroundColor = .clear
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.refusesFirstResponder = true   // キー入力はいつも絞り込み欄で受ける
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(doubleClicked)
        table.setAccessibilityIdentifier("history")

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false

        let separator = NSBox()
        separator.boxType = .separator
        emptyLabel.textColor = .secondaryLabelColor

        for v in [field, separator, scroll, emptyLabel] {
            v.translatesAutoresizingMaskIntoConstraints = false
            bg.addSubview(v)
        }
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: bg.topAnchor, constant: 12),
            field.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 14),
            field.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -14),
            separator.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 8),
            separator.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -4),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
        ])
    }

    /// マウスのある画面の、マウスの右下に出す。入らなければ上に出し、画面の中に収める
    private func position() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return }
        let vf = screen.visibleFrame
        let size = panel.frame.size
        var x = mouse.x - 20
        var y = mouse.y - size.height - 8
        if y < vf.minY { y = mouse.y + 8 }
        x = min(max(x, vf.minX + 4), vf.maxX - size.width - 4)
        y = min(max(y, vf.minY + 4), vf.maxY - size.height - 4)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - 一覧

    private func reload(keepSelection: Bool = false) {
        let row = table.selectedRow
        let selectedID = keepSelection && shown.indices.contains(row) ? shown[row].id : nil
        let q = field.stringValue.trimmingCharacters(in: .whitespaces)
        shown = q.isEmpty ? store.items : store.items.filter {
            $0.kind == .text && ($0.text ?? "").localizedCaseInsensitiveContains(q)
        }
        table.reloadData()
        select(selectedID.flatMap { id in shown.firstIndex { $0.id == id } } ?? 0)
        emptyLabel.stringValue = store.items.isEmpty ? L("履歴はまだありません") : L("見つかりません")
        emptyLabel.isHidden = !shown.isEmpty
        let ids = Set(store.items.map(\.id))
        thumbs = thumbs.filter { ids.contains($0.key) }
    }

    private func select(_ row: Int) {
        guard shown.indices.contains(row) else { table.deselectAll(nil); return }
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    private func pick(row: Int) {
        guard shown.indices.contains(row) else { NSSound.beep(); return }
        let item = shown[row]
        close()
        onPick(item)
    }

    @objc private func doubleClicked() { pick(row: table.clickedRow) }

    private func deleteSelected() {
        let row = table.selectedRow
        guard shown.indices.contains(row) else { NSSound.beep(); return }
        store.remove(id: shown[row].id)
        reload()
        select(min(row, shown.count - 1))   // 消した行の位置に留まる
    }

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { EmphasizedRowView() }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: RowView.id, owner: nil) as? RowView ?? RowView()
        let item = shown[row]
        cell.appIcon.image = appIcon(item.sourceBundleID)
        cell.thumb.isHidden = item.kind != .image
        cell.thumb.image = item.kind == .image ? thumbnail(item) : nil
        cell.label.stringValue = summary(item, max: 200)
        cell.time.stringValue = timeFormatter.localizedString(for: item.date, relativeTo: Date())
        cell.shortcut.stringValue = row < 9 ? "⌘\(row + 1)" : ""
        return cell
    }

    private func appIcon(_ bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let icon = appIcons[bundleID] { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        appIcons[bundleID] = icon
        return icon
    }

    /// 縮小画像（大きな画像でも速いように ImageIO で小さく読む）
    private func thumbnail(_ item: ClipItem) -> NSImage? {
        if let t = thumbs[item.id] { return t }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceThumbnailMaxPixelSize: 64] as CFDictionary
        guard let url = store.imageURL(for: item),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else { return nil }
        let t = NSImage(cgImage: cg, size: .zero)
        thumbs[item.id] = t
        return t
    }

    // MARK: - キー操作（絞り込み欄で受ける）

    func controlTextDidChange(_ obj: Notification) { reload() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            select(max(table.selectedRow - 1, 0))
        case #selector(NSResponder.moveDown(_:)):
            select(min(table.selectedRow + 1, shown.count - 1))
        case #selector(NSResponder.insertNewline(_:)):
            pick(row: table.selectedRow)
        case #selector(NSResponder.cancelOperation(_:)):
            if field.stringValue.isEmpty { close() } else { field.stringValue = ""; reload() }
        case #selector(NSResponder.deleteBackward(_:)) where field.stringValue.isEmpty:
            deleteSelected()
        default:
            return false
        }
        return true
    }
}
