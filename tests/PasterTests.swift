// Paster（クリップボードに入れる）と summary のテスト
import AppKit

func pasterTests() {
    let pb = NSPasteboard(name: .init("com.guribow.cliphistory.test.paster"))
    defer { pb.releaseGlobally() }
    let store = Store(dir: tempDir(), limit: 200)

    store.add(.text("貼る文字"), appName: nil, bundleID: nil)
    check(Paster.write(store.items[0], store: store, to: pb) && pb.string(forType: .string) == "貼る文字",
          "テキストをクリップボードに入れる")

    let png = testImage(3, 2).representation(using: .png, properties: [:])!
    store.add(.image(png: png, width: 3, height: 2), appName: nil, bundleID: nil)
    let image = store.items[0]
    check(Paster.write(image, store: store, to: pb) && pb.data(forType: .png) == png && pb.data(forType: .tiff) != nil,
          "画像は PNG と TIFF で入れる")
    if case .image(let d, _, _)? = Watcher.read(pb) {
        check(Store.hash(d) == image.hash, "貼った画像を読み直しても同じものと見分けられる")
    } else { check(false, "貼った画像を読み直しても同じものと見分けられる") }

    try! FileManager.default.removeItem(at: store.imageURL(for: image)!)
    check(!Paster.write(image, store: store, to: pb), "画像のファイルがなければ入れない")
}

func textTests() {
    func text(_ s: String) -> ClipItem { ClipItem(id: UUID(), kind: .text, date: Date(), text: s, hash: "") }
    check(summary(text("一行目\n二行目")) == "一行目", "テキストは 1 行目を出す")
    check(summary(text("\n  \n  本文  ")) == "本文", "空の行と前後の空白は飛ばす")
    check(summary(text(String(repeating: "あ", count: 50)), max: 10) == String(repeating: "あ", count: 10) + "…",
          "長ければ省略する")
    let image = ClipItem(id: UUID(), kind: .image, date: Date(), imageWidth: 1920, imageHeight: 1080, hash: "")
    check(summary(image) == "画像 1920 × 1080", "画像は大きさを出す")
}
