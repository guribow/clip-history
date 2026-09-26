// どこからでも履歴のパネルを出すショートカットキー
// Carbon の RegisterEventHotKey を使う（アクセシビリティの許可は要らない）
import AppKit
import Carbon

final class Hotkey {
    struct Combo {
        let title: String
        let keyCode: UInt32
        let modifiers: UInt32                // Carbon の修飾キー
        let flags: NSEvent.ModifierFlags     // メニューに出すための修飾キー
    }

    static let choices = [
        Combo(title: "⇧⌘V", keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(shiftKey | cmdKey), flags: [.shift, .command]),
        Combo(title: "⌥⌘V", keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey | cmdKey), flags: [.option, .command]),
        Combo(title: "⌃⌘V", keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | cmdKey), flags: [.control, .command]),
        Combo(title: "⌃⌥V", keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey), flags: [.control, .option]),
    ]

    private let handler: () -> Void
    private var ref: EventHotKeyRef?

    init(handler: @escaping () -> Void) {
        self.handler = handler
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // C の関数なので、self は userData で渡す
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            Unmanaged<Hotkey>.fromOpaque(userData!).takeUnretainedValue().handler()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// 登録する（前のものは外す）。ほかのアプリが使っていて登録できなければ false
    @discardableResult
    func register(_ combo: Combo) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x434C_4950), id: 1)   // 'CLIP'
        return RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}
