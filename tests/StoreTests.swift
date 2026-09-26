// Store（履歴のデータと保存）のテスト
import Foundation

func storeTests() {
    let fm = FileManager.default
    // Store は画像の中身を見ないので、区別できれば十分
    func fakePNG(_ n: UInt8) -> Data { Data([0x89, 0x50, 0x4E, 0x47, n]) }

    do {
        let s = Store(dir: tempDir(), limit: 200)
        s.add(.text("a"), appName: "Safari", bundleID: "com.apple.Safari")
        s.add(.text("b"), appName: nil, bundleID: nil)
        check(s.items.map(\.text) == ["b", "a"], "新しいものが上に来る")
        check(s.items[1].sourceAppName == "Safari" && s.items[1].sourceBundleID == "com.apple.Safari"
              && s.items[1].kind == .text, "コピー元と種類を記録する")
    }
    do {
        let s = Store(dir: tempDir(), limit: 200)
        let t0 = Date(timeIntervalSince1970: 1000)
        s.add(.text("a"), appName: "A", bundleID: nil, date: t0)
        s.add(.text("b"), appName: "B", bundleID: nil, date: t0)
        s.add(.text("a"), appName: "C", bundleID: nil, date: t0.addingTimeInterval(60))
        check(s.items.map(\.text) == ["a", "b"], "同じテキストは増えずに上へ移る")
        check(s.items[0].date == t0.addingTimeInterval(60) && s.items[0].sourceAppName == "C",
              "上へ移ると日時とコピー元が新しくなる")
        s.add(.text("a "), appName: nil, bundleID: nil)
        check(s.items.count == 3, "空白が 1 つでも違えば別のもの")
    }
    do {
        let s = Store(dir: tempDir(), limit: 3)
        for i in 1...5 { s.add(.text("t\(i)"), appName: nil, bundleID: nil) }
        check(s.items.map(\.text) == ["t5", "t4", "t3"], "上限を超えると古いものから消える")
    }
    do {
        let s = Store(dir: tempDir(), limit: 2)
        s.add(.image(png: fakePNG(1), width: 30, height: 20), appName: nil, bundleID: nil)
        let img = s.items[0]
        let url = s.imageURL(for: img)!
        check(img.kind == .image && img.imageWidth == 30 && img.imageHeight == 20, "画像の大きさを記録する")
        check((try? Data(contentsOf: url)) == fakePNG(1), "画像の本体を Images に保存する")
        s.add(.image(png: fakePNG(1), width: 30, height: 20), appName: nil, bundleID: nil)
        check(s.items.count == 1, "同じ画像は増えない")
        s.add(.text("x"), appName: nil, bundleID: nil)
        s.add(.text("y"), appName: nil, bundleID: nil)
        check(!fm.fileExists(atPath: url.path), "上限で消えた画像はファイルも消える")
    }
    do {
        let s = Store(dir: tempDir(), limit: 5)
        s.add(.image(png: fakePNG(2), width: 1, height: 1), appName: nil, bundleID: nil)
        let url = s.imageURL(for: s.items[0])!
        s.add(.text("a"), appName: nil, bundleID: nil)
        s.add(.text("b"), appName: nil, bundleID: nil)
        s.limit = 2
        check(s.items.map(\.text) == ["b", "a"], "上限を下げるとその場で古いものが消える")
        check(!fm.fileExists(atPath: url.path), "上限を下げて消えた画像はファイルも消える")
    }
    do {
        let s = Store(dir: tempDir(), limit: 200)
        s.add(.image(png: fakePNG(3), width: 1, height: 1), appName: nil, bundleID: nil)
        let url = s.imageURL(for: s.items[0])!
        s.add(.text("a"), appName: nil, bundleID: nil)
        s.remove(id: s.items[1].id)
        check(s.items.map(\.text) == ["a"] && !fm.fileExists(atPath: url.path), "1 件消すと画像のファイルも消える")
        s.add(.text("b"), appName: nil, bundleID: nil)
        s.removeAll()
        check(s.items.isEmpty, "すべて消せる")
    }
    do {
        let s = Store(dir: tempDir(), limit: 200)
        s.add(.text("a"), appName: "A", bundleID: nil)
        s.add(.text("b"), appName: "B", bundleID: nil)
        s.moveToTop(id: s.items[1].id)
        check(s.items.map(\.text) == ["a", "b"] && s.items[0].sourceAppName == "A",
              "自分で貼ったものは上へ移り、コピー元は変わらない")
    }
    do {
        var calls = 0
        let s = Store(dir: tempDir(), limit: 200)
        s.onChange = { calls += 1 }
        s.add(.text("a"), appName: nil, bundleID: nil)
        s.remove(id: s.items[0].id)
        check(calls == 2, "変わるたびに onChange を呼ぶ")
    }
    do {
        let dir = tempDir()
        let s = Store(dir: dir, limit: 200)
        s.add(.text("日本語と絵文字 🎉\n2 行目"), appName: "メモ", bundleID: "com.apple.Notes")
        s.add(.image(png: fakePNG(4), width: 8, height: 9), appName: nil, bundleID: nil)
        s.add(.text(String(repeating: "長い", count: 1_000_000)), appName: nil, bundleID: nil)   // 約 6 MB
        check(s.saveNow(), "保存できる")
        let s2 = Store(dir: dir, limit: 200)
        check(s2.items == s.items, "読み込むと同じ内容に戻る（長いテキストも）")
    }
    do {
        let dir = tempDir()
        try! Data("{".utf8).write(to: dir.appendingPathComponent("history.json"))
        let s = Store(dir: dir, limit: 200)
        let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        check(s.items.isEmpty, "壊れていたら空で始まる")
        check(names.contains { $0.hasPrefix("history.broken-") && $0.hasSuffix(".json") }
              && !names.contains("history.json"), "壊れたファイルは消さずに名前を変えて控える")
    }
    do {
        let dir = tempDir()
        let s = Store(dir: dir, limit: 200)
        s.add(.image(png: fakePNG(5), width: 1, height: 1), appName: nil, bundleID: nil)
        s.add(.text("a"), appName: nil, bundleID: nil)
        s.saveNow()
        try! fm.removeItem(at: s.imageURL(for: s.items[1])!)
        let stray = s.imagesDir.appendingPathComponent("stray.png")
        try! fakePNG(6).write(to: stray)
        let s2 = Store(dir: dir, limit: 200)
        check(s2.items.map(\.text) == ["a"], "画像ファイルがない項目は外れる")
        check(!fm.fileExists(atPath: stray.path), "どの項目も使っていない画像ファイルは片付ける")
    }
    do {
        let dir = tempDir()
        let s = Store(dir: dir, limit: 200)
        for i in 1...5 { s.add(.text("t\(i)"), appName: nil, bundleID: nil) }
        s.saveNow()
        let s2 = Store(dir: dir, limit: 2)
        check(s2.items.map(\.text) == ["t5", "t4"], "起動したときに上限を超えていれば古いものを消す")
        let s3 = Store(dir: dir, limit: 200)
        check(s3.items.count == 2, "そのときの結果を保存する")
    }
}
