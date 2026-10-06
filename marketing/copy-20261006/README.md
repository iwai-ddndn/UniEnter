# メインコピー更新 — 2026-10-06

指定コピー: **Enterでのうっかり送信を防ぐ**

既存履歴・比較案・元動画は保全。新規SNS投稿は行っていません。

| 元素材 | 修正版 | 変更箇所 |
| --- | --- | --- |
| site/public/assets/og.png (site/og.html) | assets/og-copy-20261006.png | メイン見出し。サイト掲載画像も更新 |
| sns/assets/x-header.png | assets/x-header-copy-20261006.png | メインコピー |
| sns/assets/x-post-main.png | assets/x-post-main-copy-20261006.png | メインコピー |
| sns/assets/ig-06-cta.png | assets/ig-06-cta-copy-20261006.png | 製品コピー |
| sns/assets/reel-cover.png | assets/reel-cover-copy-20261006.png | メインコピー |
| sns/video/unienter-story.mp4 | unienter-story-copy-20261006.mp4 | 約9秒の製品紹介コピー |
| sns/video/unienter-square.mp4 | unienter-square-copy-20261006.mp4 | 約9秒の製品紹介コピー |
| 2026-10-05作業フォルダの focus/output/UniEnter-FOCUS-Opus55-12s.mp4 | UniEnter-FOCUS-copy-20261006.mp4 | 冒頭コピー。80pxを維持し2行化 |
| FOCUS冒頭フレーム | assets/focus-opening-copy-20261006.png | 修正版動画の静止画 |

SNSの正規ソースは `site/src/promo/{Assets,Promo}.tsx`。既存 `marketing/sns/render-assets.mjs` と `render-video.mjs` を別出力ディレクトリにコピーして生成。OGは `site/og.html` を1200×630で描画。
FOCUS修正版ソースは `focus-source/`。`node focus-source/render.mjs final` → `zsh focus-source/encode.sh final` で再生成できます。構成・時間・アニメーション・配色は変更せず、冒頭文字列と改行位置のみ変更。

未変更: 旧 launch / launch-monochrome、比較用RETURN / SCHEMA、SNSの説明場面、プロフィール画像、その他カルーセル。コピーの対象がないため保全。

検証: LP build成功。lintエラー0（既存警告18）。1440/390pxで冒頭・末尾を目視、横はみ出しなし。動画全編をffmpegでデコード成功、各場面と変更コピーを目視。FOCUS 1080×1920/12秒/360フレーム、SNS縦1080×1920・正方形1080×1080/各28秒/840フレーム、すべて30fps/H.264/元と同じ無音（音声ストリームなし）。
