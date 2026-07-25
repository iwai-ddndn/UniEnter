#!/bin/bash
# UI関連ソースが screenshots/app/ より新しければスクリーンショットを撮り直す。
# .claude/settings.json の Stop フックから呼ばれる(手で実行してもよい)。
#
# 判定は mtime 比較のみ。UIに触っていないセッションでは即座に何もせず終了するので、
# 毎回ビルドが走ることはない。
set -uo pipefail

cd "$(dirname "$0")/.."

# 画面の見た目を左右するソース。ここが変わったら撮り直す
WATCHED=(UniEnter/UI UniEnter/Debug/ScreenshotMode.swift UniEnter/Settings/AppRegistry.swift)
STAMP=screenshots/app/INDEX.md

if [[ -f "$STAMP" ]] && [[ -z "$(find "${WATCHED[@]}" -name '*.swift' -newer "$STAMP" 2>/dev/null)" ]]; then
  exit 0  # 変更なし
fi

if ! OUTPUT=$(./scripts/screenshots.sh 2>&1); then
  printf '%s' "$OUTPUT" | tail -20 >&2
  echo '{"systemMessage": "スクリーンショットの更新に失敗しました。./scripts/screenshots.sh を手で実行して確認してください。"}'
  exit 0
fi

echo '{"systemMessage": "UI変更を検知したため screenshots/app/ を更新しました(INDEX.md に一覧)。", "suppressOutput": true}'
