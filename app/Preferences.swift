// 設定の値（UserDefaults に保存）と設定のウインドウ
import AppKit
import ServiceManagement

enum Settings {
    /// 残す件数
    static var limit: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "limit")
            return Store.limitChoices.contains(v) ? v : 200
        }
        set { UserDefaults.standard.set(newValue, forKey: "limit") }
    }

    /// ショートカットキー（Hotkey.choices の何番目か）
    static var hotkeyIndex: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "hotkey")
            return Hotkey.choices.indices.contains(v) ? v : 0
        }
        set { UserDefaults.standard.set(newValue, forKey: "hotkey") }
    }
}

final class PreferencesWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let onHotkeyChange: () -> Void
    private let onLimitChange: () -> Void
    private let hotkeyPopup = NSPopUpButton()
    private let limitPopup = NSPopUpButton()
    private let loginCheckbox = NSButton(checkboxWithTitle: L("ログイン時に起動する"), target: nil, action: nil)
    private let axLabel = NSTextField(labelWithString: "")

    init(onHotkeyChange: @escaping () -> Void, onLimitChange: @escaping () -> Void) {
        self.onHotkeyChange = onHotkeyChange
        self.onLimitChange = onLimitChange
    }

    func show() {
        if window == nil { build() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// システム設定から戻ってきたときに、許可の状態を読み直す
    func windowDidBecomeKey(_ notification: Notification) { refresh() }

    private func refresh() {
        hotkeyPopup.selectItem(at: Settings.hotkeyIndex)
        limitPopup.selectItem(at: Store.limitChoices.firstIndex(of: Settings.limit) ?? 2)
        loginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        axLabel.stringValue = AXIsProcessTrusted()
            ? L("許可されています（選ぶだけで貼れます）")
            : L("許可されていません（クリップボードに入れるだけになります）")
    }

    private func build() {
        hotkeyPopup.addItems(withTitles: Hotkey.choices.map(\.title))
        hotkeyPopup.target = self
        hotkeyPopup.action = #selector(hotkeyChanged)
        limitPopup.addItems(withTitles: Store.limitChoices.map { String(format: L("%d 件"), $0) })
        limitPopup.target = self
        limitPopup.action = #selector(limitChanged)
        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginChanged)
        let openButton = NSButton(title: L("システム設定を開く"), target: self, action: #selector(openAccessibility))

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: L("ショートカットキー：")), hotkeyPopup],
            [NSTextField(labelWithString: L("残す件数：")), limitPopup],
            [NSGridCell.emptyContentView, loginCheckbox],
            [NSTextField(labelWithString: L("デバイスの制御：")), axLabel],
            [NSGridCell.emptyContentView, openButton],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.rowSpacing = 12
        grid.columnSpacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 220),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = L("ClipHistory の設定")
        w.isReleasedWhenClosed = false
        w.delegate = self
        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
        ])
        w.contentView = content
        w.center()
        window = w
    }

    @objc private func hotkeyChanged() {
        Settings.hotkeyIndex = hotkeyPopup.indexOfSelectedItem
        onHotkeyChange()
    }

    @objc private func limitChanged() {
        Settings.limit = Store.limitChoices[limitPopup.indexOfSelectedItem]
        onLimitChange()
    }

    @objc private func loginChanged() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "ClipHistory"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refresh()
    }

    @objc private func openAccessibility() { Paster.openAccessibilitySettings() }
}
