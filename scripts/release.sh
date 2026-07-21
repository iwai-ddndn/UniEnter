#!/bin/bash
# リリース成果物(zip / pkg)を dist/ に作る。公開は行わない。
# 使い方: scripts/release.sh [バージョン]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
APP="build/Build/Products/Release/UniEnter.app"

xcodegen generate
xcodebuild -project UniEnter.xcodeproj -scheme UniEnter -configuration Release \
  -derivedDataPath build build | grep -E "(error:|\*\* BUILD)" || true
test -d "$APP"

mkdir -p dist
rm -f dist/UniEnter.zip dist/UniEnter.pkg

# zip(手動インストール派向け)
ditto -c -k --keepParent "$APP" dist/UniEnter.zip

# pkg(ダブルクリックで/Applicationsへインストール)
pkgbuild --component "$APP" \
  --install-location /Applications \
  --identifier dev.iwai.UniEnter \
  --version "$VERSION" \
  dist/UniEnter-component.pkg
productbuild --synthesize --package dist/UniEnter-component.pkg dist/distribution.xml
# インストーラのタイトルを設定
sed -i '' 's|<installer-gui-script minSpecVersion="1">|<installer-gui-script minSpecVersion="1"><title>UniEnter</title>|' dist/distribution.xml
productbuild --distribution dist/distribution.xml --package-path dist dist/UniEnter.pkg
rm -f dist/UniEnter-component.pkg dist/distribution.xml

echo "---"
ls -lh dist/UniEnter.zip dist/UniEnter.pkg
echo "注意: Developer ID Installer証明書が無いため未署名。公証は Apple Developer Program 加入後に scripts へ追加する。"
