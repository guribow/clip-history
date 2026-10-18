// ClipHistory: クリップボードの履歴。
// コピーしたものを自動で残し、ショートカットキーで出すパネルから選ぶと、今のアプリにそのまま貼れる。
import AppKit

/// メニューの項目（選ばれたら handler を呼ぶ）
final class MenuAction: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var store: Store!
    private var watcher: Watcher!
    private var panel: PanelController!
    private var hotkey: Hotkey!
    private var hotkeyOK = true
    private lazy var preferences = PreferencesWindow(
        onHotkeyChange: { [weak self] in self?.applyHotkey() },
        onLimitChange: { [weak self] in self?.store.limit = Settings.limit })

    func applicationDidFinishLaunching(_ notification: Notification) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipHistory")
        store = Store(dir: dir, limit: Settings.limit)
        watcher = Watcher(store: store)
        panel = PanelController(store: store) { [weak self] item in self?.paste(item) }
        store.onChange = { [weak self] in self?.panel.refreshIfVisible() }
        hotkey = Hotkey { [weak self] in self?.panel.toggle() }
        applyHotkey()
        watcher.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        Updater.shared.onChange = { [weak self] in self?.updateIcon() }
        Updater.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) { store.saveNow() }

    private func applyHotkey() {
        hotkeyOK = hotkey.register(Hotkey.choices[Settings.hotkeyIndex])
    }

    private func paste(_ item: ClipItem) { Paster.paste(item, store: store, watcher: watcher) }

    /// 一時停止中はアイコンを変える
    private func updateIcon() {
        let paused = watcher.paused
        let image = NSImage(systemSymbolName: paused ? "pause.circle" : "doc.on.clipboard",
                            accessibilityDescription: paused ? L("ClipHistory（記録を一時停止中）") : "ClipHistory")
        image?.isTemplate = true
        statusItem.button?.image = Updater.shared.badge(image)
    }

    // メニューを開くたびに作り直す
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        Updater.shared.topMenuItems().forEach(menu.addItem)
        let recent = store.items.prefix(10)
        if recent.isEmpty { menu.addItem(disabledItem(L("履歴はまだありません"))) }
        for item in recent {
            let mi = MenuAction(summary(item, max: 40)) { [weak self] in self?.paste(item) }
            if item.kind == .image { mi.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil) }
            menu.addItem(mi)
        }
        menu.addItem(.separator())
        let open = MenuAction(L("履歴を開く"), key: "v") { [weak self] in self?.panel.show() }
        open.keyEquivalentModifierMask = Hotkey.choices[Settings.hotkeyIndex].flags
        menu.addItem(open)
        if !hotkeyOK { menu.addItem(disabledItem(L("ショートカットキーを使えません（設定で変えてください）"))) }
        let pause = MenuAction(L("記録を一時停止")) { [weak self] in self?.togglePause() }
        pause.state = watcher.paused ? .on : .off
        menu.addItem(pause)
        let clear = MenuAction(L("履歴をすべて消去…")) { [weak self] in self?.confirmClear() }
        clear.isEnabled = !store.items.isEmpty
        menu.addItem(clear)
        menu.addItem(.separator())
        menu.addItem(MenuAction(L("設定…"), key: ",") { [weak self] in self?.preferences.show() })
        Updater.shared.settingsMenuItems().forEach(menu.addItem)
        menu.addItem(MenuAction(L("ClipHistory について")) { [weak self] in self?.showAbout() })
        menu.addItem(NSMenuItem(title: L("終了"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func togglePause() {
        watcher.paused.toggle()
        updateIcon()
    }

    private func confirmClear() {
        let alert = NSAlert()
        alert.messageText = L("履歴をすべて消去しますか？")
        alert.informativeText = String(format: L("%d 件をすべて消します。元に戻せません。"), store.items.count)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("消去"))
        alert.addButton(withTitle: L("キャンセル"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.removeAll()
    }

    /// macOS 標準の「このアプリについて」（アイコン・名前・バージョン・著作権は Info.plist から）
    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.version: ""])   // ビルド番号の「(…)」は出さない
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
