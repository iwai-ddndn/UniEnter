#!/bin/bash
# 「公開して」の一発実行用。これを実行するまで、リポジトリ・LP・リリースは非公開のまま。
# やること: リポジトリをpublic化 → GitHub Pages有効化 → リリースへ最新成果物を添付
# 使い方: scripts/publish.sh [バージョン]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"

echo "==> リポジトリをpublicに"
gh repo edit iwai-ddndn/UniEnter --visibility public --accept-visibility-change-consequences

echo "==> GitHub Pages有効化(main /docs)"
gh api -X POST repos/iwai-ddndn/UniEnter/pages \
  -f "source[branch]=main" -f "source[path]=/docs" 2>/dev/null || echo "(既に有効)"

echo "==> リリース v$VERSION に成果物を添付"
test -f dist/UniEnter.zip && gh release upload "v$VERSION" dist/UniEnter.zip --clobber
test -f dist/UniEnter.pkg && gh release upload "v$VERSION" dist/UniEnter.pkg --clobber

echo "==> 完了"
echo "リポジトリ: https://github.com/iwai-ddndn/UniEnter"
echo "LP:        https://iwai-ddndn.github.io/UniEnter/ (反映まで数分)"
echo "DL:        https://github.com/iwai-ddndn/UniEnter/releases/latest"
