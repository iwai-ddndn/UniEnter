---
name: gen-image
description: OpenAI APIで画像を生成してsite/public/assets/に保存し、必要ならLPへ組み込む。ブラウザ操作なしでClaude Code内で完結する。引数: 生成したい画像の説明(と保存名)。
---

# 画像生成(Claude Code内で完結)

ChatGPTのWeb UIをブラウザ操作する方式は、生成待ち・ダウンロード制約・セッション不安定のため使わない。
代わりにOpenAI Images API(gpt-image-1)をcurlで直接叩く。

## 前提

環境変数 `OPENAI_API_KEY` が必要。未設定なら作業を始める前にユーザーへ次を案内する:
1. https://platform.openai.com/api-keys でAPIキーを発行(ChatGPT Plusとは別の従量課金。画像1枚あたり数円〜数十円)
2. `~/.zshrc` に `export OPENAI_API_KEY="sk-..."` を追記して新しいターミナルで再起動、またはこのセッション限りなら実行時に渡す

## 手順

1. トンマナを揃える。このプロジェクトのLPはライトモード・Notion風。プロンプトには必ず
   「白〜ライトグレー基調、自然光、ソフトな影、ミニマル、余白広め、ネオンや光る演出は無し、文字は入れない」
   を含める(過去の採用画像: ライトグレーのキーキャップ写真、白背景の3Dオブジェクト)。
2. 生成(sizeは用途で選ぶ: LPカード=1536x1024、正方形アイコン=1024x1024):

```bash
curl -sS https://api.openai.com/v1/images/generations \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-image-1", "prompt": "<プロンプト>", "size": "1536x1024", "quality": "high"}' \
  | python3 -c "import sys, json, base64; d=json.load(sys.stdin); open('/tmp/gen.png','wb').write(base64.b64decode(d['data'][0]['b64_json']))"
```

   エラー時はレスポンスのerrorをそのまま確認する(キー未設定/残高不足が典型)。
3. Readツールで/tmp/gen.pngを表示して品質確認。トンマナが合わなければプロンプトを直して再生成(1〜2回まで。無限リトライしない)。
4. `site/public/assets/<用途名>.png` に配置し、`cd site && npm run build` でdocs/へ反映。
5. LPへの組み込みが必要なら `site/src/App.tsx` を編集し、ブラウザペインで表示確認してからコミット。

## 備考

- アプリアイコン用の角丸マスクと全サイズ生成は、過去に作ったツールを再利用:
  スクラッチパッドの `mask.swift`(角丸透過)+ `sips -z <size> <size>` で
  `UniEnter/Assets.xcassets/AppIcon.appiconset/` を更新 → `xcodegen generate` → ビルド。
- OGP画像はHTML(1200x630)を書いて `render.swift`(WKWebViewスナップショット)でPNG化する方式が既に確立している。
