// 選んだ項目をクリップボードに入れて、今のアプリに ⌘V を送る
// ⌘V を送るにはアクセシビリティの許可が要る。なければクリップボードに入れるだけにする
import AppKit

enum Paster {
    /// 項目をクリップボードに入れる。画像のファイルがなければ false
    @discardableResult
    static func write(_ item: ClipItem, store: Store, to pb: NSPasteboard = .general) -> Bool {
        switch item.kind {
        case .text:
            guard let s = item.text else { return false }
            pb.declareTypes([.string], owner: nil)
            pb.setString(s, forType: .string)
        case .image:
            guard let url = store.imageURL(for: item), let png = try? Data(contentsOf: url) else { return false }
            pb.declareTypes([.png, .tiff], owner: nil)
            pb.setData(png, forType: .png)
            if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
        }
        return true
    }

    /// クリップボードに入れて ⌘V を送る。許可がなければ入れるだけにする
    static func paste(_ item: ClipItem, store: Store, watcher: Watcher) {
        guard write(item, store: store) else { NSSound.beep(); return }
        watcher.skipCurrent()          // 自分で入れたものを新しいコピーとして読まない
        store.moveToTop(id: item.id)   // 使ったものを上へ（コピー元は変えない）
        if AXIsProcessTrusted() {
            // パネルやメニューが閉じて、元のアプリにキー入力が戻るのを待つ
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { sendCommandV() }
        } else {
            explainPermissionOnce()
        }
    }

    static func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 9   // kVK_ANSI_V（キーの位置。JIS 配列でも同じ）
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: down)
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }
    }

    /// 許可がないときの説明（初めての 1 回だけ）
    private static func explainPermissionOnce() {
        let key = "explainedAccessibility"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let alert = NSAlert()
        alert.messageText = L("そのまま貼るには、アクセシビリティの許可が必要です")
        alert.informativeText = L("今はクリップボードに入れただけなので、⌘V で貼ってください。システム設定の「プライバシーとセキュリティ」→「アクセシビリティ」で ClipHistory をオンにすると、選ぶだけで貼れるようになります。")
        alert.addButton(withTitle: L("システム設定を開く"))
        alert.addButton(withTitle: L("あとで"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { openAccessibilitySettings() }
    }
}
