// 画面に出す文字
import Foundation

/// 画面に出す文字列。日本語をキーにし、英語は en.lproj/Localizable.strings で訳す（Mac の言語設定で自動で切り替わる）
func L(_ ja: String) -> String { NSLocalizedString(ja, comment: "") }

/// 一覧やメニューに出す 1 行（テキストは空でない最初の行、画像は大きさ）
func summary(_ item: ClipItem, max: Int = 60) -> String {
    switch item.kind {
    case .text:
        let line = (item.text ?? "").split(whereSeparator: \.isNewline)
            .lazy.map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        return line.count > max ? String(line.prefix(max)) + "…" : line
    case .image:
        return String(format: L("画像 %d × %d"), item.imageWidth ?? 0, item.imageHeight ?? 0)
    }
}
