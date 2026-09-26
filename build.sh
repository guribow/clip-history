#!/bin/bash
# ClipHistory.app（macOS 13 以降、Apple シリコンと Intel の両対応）をビルドし、~/Applications に入れる。
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

APP=build/ClipHistory.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp app/Info.plist "$APP/Contents/"
[ -f icon/AppIcon.icns ] && cp icon/AppIcon.icns "$APP/Contents/Resources/"
cp -R app/ja.lproj app/en.lproj "$APP/Contents/Resources/"   # 日本語・英語の文字列（Mac の言語設定で自動で切り替わる）
# macOS 13 以降で動く、Apple シリコンと Intel の両方に対応したユニバーサル形式にする
MIN_OS=13.0
for ARCH in arm64 x86_64; do
    swiftc -O -target "$ARCH-apple-macos$MIN_OS" -o "build/ClipHistory-$ARCH" app/*.swift
done
lipo -create -output "$APP/Contents/MacOS/ClipHistory" build/ClipHistory-arm64 build/ClipHistory-x86_64
codesign --force --sign - "$APP"

mkdir -p ~/Applications
pkill -x ClipHistory 2>/dev/null && sleep 1 || true
rm -rf ~/Applications/ClipHistory.app
cp -R "$APP" ~/Applications/
echo "built: ~/Applications/ClipHistory.app"
