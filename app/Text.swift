// 画面に出す文字
import Foundation

/// 画面に出す文字列。日本語をキーにし、英語は en.lproj/Localizable.strings で訳す（Mac の言語設定で自動で切り替わる）
func L(_ ja: String) -> String { NSLocalizedString(ja, comment: "") }
