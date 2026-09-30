#!/bin/bash
# 配布物を作る: Developer ID 署名 → 公証 → ステープル → zip / pkg → Sparkle 用の appcast 更新。
# GitHub へのリリース作成と LP(appcast)の公開はしない(最後に手順を表示する)。
#
# 使い方: scripts/release.sh 0.3.4
#
# 前提(一度だけ):
#   - キーチェーンに「Developer ID Application」「Developer ID Installer」証明書(Xcode → Settings → Accounts)
#   - 公証用の認証情報: xcrun notarytool store-credentials unienter-notary --apple-id ... --team-id ...
#   - Sparkle の署名鍵がキーチェーンにある(generate_keys --account dev.iwai.UniEnter。
#     バックアップは license-signing/sparkle-private-key.txt・git管理外)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?バージョンを指定してください(例: scripts/release.sh 0.3.4)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-unienter-notary}"
APP="build/Build/Products/Release/UniEnter.app"
SPARKLE_BIN="build/SourcePackages/artifacts/sparkle/Sparkle/bin"
APPCAST="site/public/appcast.xml"
DOWNLOAD_BASE="https://github.com/iwai-ddndn/UniEnter/releases/download/v${VERSION}"

# 証明書から署名IDとチームIDを取る
APP_IDENTITY=$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')
PKG_IDENTITY=$(security find-identity -v | grep -o '"Developer ID Installer: [^"]*"' | head -1 | tr -d '"')
[ -n "$APP_IDENTITY" ] || { echo "Developer ID Application 証明書がありません"; exit 1; }
[ -n "$PKG_IDENTITY" ] || { echo "Developer ID Installer 証明書がありません"; exit 1; }
TEAM_ID=$(echo "$APP_IDENTITY" | sed -E 's/.*\(([A-Z0-9]+)\)$/\1/')
PLIST_VERSION=$(grep 'CFBundleShortVersionString' project.yml | grep -o '"[^"]*"' | tr -d '"')
[ "$PLIST_VERSION" = "$VERSION" ] || { echo "project.yml の CFBundleShortVersionString($PLIST_VERSION)を $VERSION にしてください(CFBundleVersion も+1)"; exit 1; }

echo "== ビルド($APP_IDENTITY)"
xcodegen generate -q
xcodebuild -project UniEnter.xcodeproj -scheme UniEnter -configuration Release \
  -derivedDataPath build DEVELOPMENT_TEAM="$TEAM_ID" build | grep -E "(error:|\*\* BUILD)" || true
test -d "$APP"
codesign --verify --deep --strict "$APP"
codesign -dv "$APP" 2>&1 | grep -q "flags=.*runtime" || { echo "Hardened Runtime が有効になっていません"; exit 1; }

mkdir -p dist
rm -f dist/UniEnter.zip dist/UniEnter.pkg dist/notarize.zip

echo "== アプリを公証"
ditto -c -k --keepParent "$APP" dist/notarize.zip
xcrun notarytool submit dist/notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
rm -f dist/notarize.zip

# zip(手動インストール派向け・Sparkle の更新ファイルも兼ねる)
ditto -c -k --keepParent "$APP" dist/UniEnter.zip

echo "== pkg を作成・署名・公証"
# --scripts: インストール完了後に postinstall でアプリを自動起動する
pkgbuild --component "$APP" \
  --install-location /Applications \
  --identifier dev.iwai.UniEnter \
  --version "$VERSION" \
  --scripts scripts/pkg-scripts \
  dist/UniEnter-component.pkg
productbuild --synthesize --package dist/UniEnter-component.pkg dist/distribution.xml
sed -i '' 's|<installer-gui-script minSpecVersion="1">|<installer-gui-script minSpecVersion="1"><title>UniEnter</title>|' dist/distribution.xml
productbuild --distribution dist/distribution.xml --package-path dist --sign "$PKG_IDENTITY" dist/UniEnter.pkg
rm -f dist/UniEnter-component.pkg dist/distribution.xml
xcrun notarytool submit dist/UniEnter.pkg --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple dist/UniEnter.pkg

echo "== Gatekeeper で確認"
spctl -a -vv "$APP"
spctl -a -vv -t install dist/UniEnter.pkg

echo "== appcast を更新($APPCAST)"
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$APP/Contents/Info.plist")
SIG_ATTRS=$("$SPARKLE_BIN/sign_update" --account dev.iwai.UniEnter dist/UniEnter.zip)
PUB_DATE=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")
ITEM="    <item>
      <title>UniEnter ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_OS}</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/iwai-ddndn/UniEnter/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <enclosure url=\"${DOWNLOAD_BASE}/UniEnter.zip\" type=\"application/octet-stream\" ${SIG_ATTRS} />
    </item>"
python3 - "$APPCAST" "$ITEM" <<'PY'
import sys, pathlib
path, item = pathlib.Path(sys.argv[1]), sys.argv[2]
marker = "<!-- items -->"
text = path.read_text()
path.write_text(text.replace(marker, marker + "\n" + item, 1))
PY

echo "---"
ls -lh dist/UniEnter.zip dist/UniEnter.pkg
cat <<NEXT
次の手順(公開):
  1. gh release create v${VERSION} dist/UniEnter.pkg dist/UniEnter.zip --title "v${VERSION}" --notes-file <リリースノート>
  2. cd site && npm run build   # appcast.xml を docs/ へ
  3. git add project.yml site/public/appcast.xml docs && git commit && git push
     (appcast は GitHub のリリースを作ってから push する。先に push すると、まだ無い zip を指してしまう)
NEXT
