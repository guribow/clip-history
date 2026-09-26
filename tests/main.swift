// ./test.sh で動く。一時フォルダと専用の名前のクリップボードだけを使い、ユーザーの履歴やクリップボードには触れない
import AppKit

var failures = 0

func check(_ ok: Bool, _ name: String, file: String = #fileID, line: Int = #line) {
    if ok {
        print("ok   \(name)")
    } else {
        failures += 1
        print("FAIL \(name)（\(file):\(line)）")
    }
}

/// テストごとの一時フォルダ
func tempDir() -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("cliphistory-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}

/// 本物の画像（透明な w × h）
func testImage(_ w: Int, _ h: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}

storeTests()
watcherTests()
pasterTests()
textTests()

print(failures == 0 ? "すべて成功" : "失敗：\(failures) 件")
exit(failures == 0 ? 0 : 1)
