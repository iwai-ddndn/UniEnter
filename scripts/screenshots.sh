#!/bin/bash
# アプリの全画面スクリーンショットを screenshots/app/ に生成する。
#
#   ./scripts/screenshots.sh
#
# 出力はライト/ダーク各10枚のPNGと INDEX.md。ファイル名は固定なので毎回上書きされ、
# screenshots/app/ は常に最新のUIを表す。
#
# 実体は UniEnter/Debug/ScreenshotMode.swift(DEBUGビルド限定)。
# 撮影対象を増やすときはそちらの allShots() に追記する。
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR="$PWD/screenshots/app"
APP="build/Build/Products/Debug/UniEnter.app/Contents/MacOS/UniEnter"

echo "==> プロジェクト生成"
xcodegen generate >/dev/null

echo "==> Debugビルド"
xcodebuild -project UniEnter.xcodeproj -scheme UniEnter -configuration Debug \
  -derivedDataPath build build >/dev/null

echo "==> 画面書き出し -> $OUT_DIR"
rm -rf "$OUT_DIR"
"$APP" --screenshot-mode "$OUT_DIR"

echo "==> 完了"
ls -1 "$OUT_DIR"
