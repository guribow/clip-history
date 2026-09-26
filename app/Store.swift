// 履歴のデータと保存。画面や AppKit には頼らない（test.sh で単体で確かめる）
import Foundation
import CryptoKit

/// クリップボードから読んだ中身
enum Clip {
    case text(String)
    case image(png: Data, width: Int, height: Int)
}

/// 履歴の 1 件
struct ClipItem: Codable, Equatable {
    enum Kind: String, Codable { case text, image }
    var id: UUID
    var kind: Kind
    var date: Date                     // コピーした日時（上へ移したときは、その日時）
    var text: String? = nil
    var imageFile: String? = nil       // Images/ の中のファイル名
    var imageWidth: Int? = nil
    var imageHeight: Int? = nil
    var sourceAppName: String? = nil   // コピー元のアプリ
    var sourceBundleID: String? = nil
    var hash: String                   // 中身の SHA-256。重複を見分けるのに使う
}

final class Store {
    static let limitChoices = [50, 100, 200, 500, 1000]

    let dir: URL
    private(set) var items: [ClipItem] = []   // 新しい順
    /// 残す件数。下げたときは、その場で古いものを消す
    var limit: Int { didSet { if trim() { changed() } } }
    /// 中身が変わったとき（パネルを作り直す）
    var onChange: (() -> Void)?
    private var saveScheduled = false

    var historyURL: URL { dir.appendingPathComponent("history.json") }
    var imagesDir: URL { dir.appendingPathComponent("Images") }

    init(dir: URL, limit: Int) {
        self.dir = dir
        self.limit = limit
        load()
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func imageURL(for item: ClipItem) -> URL? {
        item.imageFile.map { imagesDir.appendingPathComponent($0) }
    }

    /// 追加する。同じ中身がすでにあれば、新しく足さずに一番上へ移す
    func add(_ clip: Clip, appName: String?, bundleID: String?, date: Date = Date()) {
        let h: String
        switch clip {
        case .text(let s): h = Self.hash(Data(s.utf8))
        case .image(let png, _, _): h = Self.hash(png)
        }
        if let i = items.firstIndex(where: { $0.hash == h }) {
            var item = items.remove(at: i)
            item.date = date
            item.sourceAppName = appName
            item.sourceBundleID = bundleID
            items.insert(item, at: 0)
            changed()
            return
        }
        let id = UUID()
        var item = ClipItem(id: id, kind: .text, date: date, sourceAppName: appName, sourceBundleID: bundleID, hash: h)
        switch clip {
        case .text(let s):
            item.text = s
        case .image(let png, let w, let hh):
            let name = "\(id.uuidString).png"
            do {
                try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
                try png.write(to: imagesDir.appendingPathComponent(name), options: .atomic)
            } catch {
                NSLog("ClipHistory: 画像を保存できません: \(error)")
                return   // 画像の本体がなければ項目にできない
            }
            item.kind = .image
            item.imageFile = name
            item.imageWidth = w
            item.imageHeight = hh
        }
        items.insert(item, at: 0)
        trim()
        changed()
    }

    /// 自分で貼ったものを一番上へ移す（日時だけ新しくし、コピー元はそのまま）
    func moveToTop(id: UUID, date: Date = Date()) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: i)
        item.date = date
        items.insert(item, at: 0)
        changed()
    }

    func remove(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        deleteImage(items.remove(at: i))
        changed()
    }

    func removeAll() {
        items.forEach(deleteImage)
        items.removeAll()
        changed()
    }

    /// 上限を超えた古い項目を消す。消したら true
    @discardableResult
    private func trim() -> Bool {
        guard items.count > limit else { return false }
        items[limit...].forEach(deleteImage)
        items.removeSubrange(limit...)
        return true
    }

    private func deleteImage(_ item: ClipItem) {
        if let url = imageURL(for: item) { try? FileManager.default.removeItem(at: url) }
    }

    private func changed() {
        onChange?()
        scheduleSave()
    }

    /// 1 秒待ってからまとめて書き込む
    private func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.saveScheduled = false
            self?.saveNow()
        }
    }

    /// すぐに書き込む。失敗したら false（メモリの履歴はそのまま。次の変更のときにまた書き込む）
    @discardableResult
    func saveNow() -> Bool {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try JSONEncoder().encode(items).write(to: historyURL, options: .atomic)
            return true
        } catch {
            NSLog("ClipHistory: 履歴を保存できません: \(error)")
            return false
        }
    }

    private func load() {
        let fm = FileManager.default
        guard let data = try? Data(contentsOf: historyURL) else { return }   // 初めて起動したとき
        guard let loaded = try? JSONDecoder().decode([ClipItem].self, from: data) else {
            // 壊れていたら消さずに名前を変えて控え、空の履歴で始める
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyyMMdd-HHmmss"
            let backup = dir.appendingPathComponent("history.broken-\(f.string(from: Date())).json")
            try? fm.moveItem(at: historyURL, to: backup)
            NSLog("ClipHistory: history.json が読めないので \(backup.lastPathComponent) に控えました")
            return
        }
        // 画像ファイルがなくなっている項目は外す
        items = loaded.filter { item in
            guard item.kind == .image else { return true }
            guard let url = imageURL(for: item) else { return false }
            return fm.fileExists(atPath: url.path)
        }
        // どの項目も使っていない画像ファイルを片付ける
        let used = Set(items.compactMap(\.imageFile))
        for name in (try? fm.contentsOfDirectory(atPath: imagesDir.path)) ?? [] where !used.contains(name) {
            try? fm.removeItem(at: imagesDir.appendingPathComponent(name))
        }
        let trimmed = trim()
        if trimmed || items.count != loaded.count { saveNow() }
    }
}
