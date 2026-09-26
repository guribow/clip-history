#!/bin/bash
# 中身のしくみ（Store・クリップボードの読み書き）を確かめ、英訳の抜けを調べる。
# 一時フォルダと専用の名前のクリップボードを使うので、ユーザーの履歴やクリップボードには触れない。
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

# app/main.swift（アプリの入口）以外と、テストをまとめてビルドする
SOURCES=$(ls app/*.swift | grep -v '/main\.swift$')
swiftc -o build/tests $SOURCES tests/*.swift
build/tests

# 英訳の抜け：コード中の L("…") のキーが en.lproj にあるか
missing=0
while IFS= read -r key; do
    [ -z "$key" ] && continue
    grep -qF "\"$key\" = " app/en.lproj/Localizable.strings || { echo "英訳なし: $key"; missing=1; }
done < <(grep -oh 'L("[^"]*")' app/*.swift | sed -E 's/^L\("(.*)"\)$/\1/' | sort -u)
[ $missing -eq 0 ] && echo "英訳の抜けなし" || exit 1
