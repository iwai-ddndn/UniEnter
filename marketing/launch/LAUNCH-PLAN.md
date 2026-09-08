# UniEnter リリース宣伝プラン

作成日: 2026-07-22  
主戦場: 制作者本人のXアカウント  
公開予定URL: <https://iwai-ddndn.github.io/UniEnter/>

## 結論

UniEnterは機能一覧から説明するより、最初の1秒で次の2行を理解してもらうのが強い。

- Enter → 改行
- ⌘Enter → 送信

Xでは画像と投稿冒頭をLPの「改行と送信、もう間違えない。」に揃え、投稿からLPへ移ったときに同じ製品だと一瞬で認識できるようにする。「改行のつもりで途中の文章を送ってしまう」という共感フックは、翌日の引用投稿や制作ストーリーで使う。リンク・価格・対応環境は直後のセルフリプライに分ける。これはアルゴリズム対策を断定するものではなく、主投稿を読みやすくし、参考投稿と同じく画像の第一印象を強くするための構成。

本公開の前提は、Paddleの購入導線、公開LP、ダウンロード、Developer ID署名と公証がすべて動くこと。アクセシビリティ権限を使うアプリなので、公証前の警告が出る状態で大きく宣伝すると信頼とインストール完了率を落としやすい。公証前に出す場合は「正式リリース」ではなく、人数を絞った「先行テスト」として扱う。

## 参考投稿から採用した型

- 本文は「何を公開したか」「何ができるか」「安全性」の3段に絞る
- 画像は1枚の中を3面に分け、物理キー、操作ルール、製品名を同時に見せる
- メイン投稿は画像とストーリーに集中し、URLは直後のセルフリプライでリンクカードとして見せる
- 参考投稿のダークで力強いルックはコピーせず、UniEnterの白・墨色・改行グリーン・送信ブルーに置き換える

## ポジショニング

### 一言で

Macのチャットアプリ全部で、Enterを改行、⌘Enterを送信に統一するアプリ。

### 最初に届けたい人

1. ChatGPT / ClaudeとSlack / Teamsを毎日行き来するMacユーザー
2. 日本語変換の確定Enterと送信Enterが混ざることに不安がある人
3. 「アプリごとの設定を覚えたくない」人

### 伝える順番

1. 誤送信がなくなる
2. どのアプリでも同じ操作になる
3. 日本語変換中のEnterは壊さない
4. 入力内容を読まず、外部送信もしない
5. 14日無料、¥1,480（税込・買い切り）

## 公開判定（GO / NO-GO）

### GOに必要

- GitHub PagesのLPが公開され、スマホでも購入・ダウンロードまで辿れる
- PaddleチェックアウトURLがLPとアプリの両方で有効
- `.pkg` と `.zip` をクリーンなMacユーザー環境で確認済み
- Developer ID署名・公証済みで、初回起動が通常の導線で通る
- Xリンクカードのタイトル・画像・説明が本番URLで表示される
- 問い合わせ先 `info@oc-to.com` と利用規約・プライバシーポリシーが到達可能
- 価格、対応OS、14日トライアルの表記がLP・アプリ・Xで一致

### NO-GOなら

- 購入不能: 「先行テスト」または「公開予告」に変更し、正式リリースとは言わない
- 公証前: 不特定多数への投稿は保留し、既知の協力者に限定
- LPやダウンロード不調: X投稿を止め、先に導線を直す

## 7日間の実行プラン

| 時点 | 実行内容 | 目的 |
| --- | --- | --- |
| T-7〜T-4 | GO条件を完了。Macを多用する知人5〜10人に先行テストを依頼 | 致命的な導線と初回権限の問題を潰す |
| T-3 | Xで予告を1回。「Enter誤送信、困っている人いますか？」ではなく、15秒程度の実デモか `x-launch-how` を見せる | 問題への共感を作る |
| T-1 | 本番URL、OG、UTM、画像のスマホ表示を確認。プロフィールのリンクをLPに変更 | 投稿直後の離脱を防ぐ |
| T0 20:30 JST | メイン投稿＋1〜2分以内にリンク返信＋安全性返信。メイン投稿を固定 | 最初の到達と変換を同時に取る |
| T0〜90分 | 返信には具体的に回答。対応アプリ要望はメモ。引用・再投稿を強要しない | 会話と信頼を作る |
| T+1 | メイン投稿を引用し、ChatGPT/Claude利用者向けの具体例を1つ追加 | 別の利用文脈で再到達 |
| T+3 | noteまたはZennで「日本語IMEを壊さない設計」を公開 | 技術的な信頼を補強 |
| T+7 | 初週の数字、反応、改善内容を投稿。許可を得た利用者の短い感想を掲載 | 社会的証明と第2波を作る |

投稿時刻20:30は日本のMacユーザー向けの初期仮説。Xのアカウント分析でフォロワーの活動時間が分かる場合は、そちらを優先する。

## X投稿セット

### メイン投稿（推奨）

添付: `assets/x-launch-main-1600x900.png` を1枚

```text
改行と送信、もう間違えない。
macOSアプリ「UniEnter」を公開しました。

Enterはいつでも改行、送信は⌘Enter。

SlackもTeamsも、ChatGPTもClaudeも同じ操作に。改行と送信、もう間違えない。

日本語変換中のEnterは、そのままです。
#Mac #個人開発
```

### 1件目のセルフリプライ（URL）

リンクカードを出す場合は画像を添付しない。サイト側のOG画像に `og-link-card-1200x630.png` を採用してから本番表示を確認する。

```text
14日間、すべての機能を無料で試せます。
¥1,480（税込・買い切り／サブスクなし）

ダウンロードはこちら👇
https://iwai-ddndn.github.io/UniEnter/?utm_source=x&utm_medium=social&utm_campaign=launch_v020&utm_content=reply1

macOS 13以降
```

### 2件目のセルフリプライ（安全性）

添付: `assets/x-launch-safety-1600x900.png`

```text
UniEnterは入力内容を読みません。

判定に使うのは、Enter関連のキー・前面のアプリ・日本語入力中かどうかだけ。外部送信もありません。

変換確定のEnterはそのまま。判定に迷うときは「何もしない」設計です。
```

### T+1の引用投稿

添付なし。メイン投稿を引用する。

```text
ChatGPTでは改行できたのに、Slackでは途中で送信してしまう。

UniEnterは、そういう「アプリごとの差」をMac側でなくします。ChatGPTからSlackへ移っても、Enterはいつでも改行、送信は⌘Enterのままです。

14日間無料で試せます。
```

### 予告投稿（T-3）

添付: `assets/x-launch-how-1600x900.png`

```text
改行と送信、もう間違えない。
そんなmacOSアプリを作っています。

Enterはいつでも改行、送信は⌘Enter。

SlackもChatGPTもClaudeも、もうアプリごとに覚え直さなくていい。近日公開します。
```

### 代替: URLをメイン投稿に入れる版

セルフリプライを見ない人にも確実にURLを届けたい場合はこちら。メイン画像は同じ。

```text
改行と送信、もう間違えない。
macOSアプリ「UniEnter」を公開しました。

Enterはいつでも改行、送信は⌘Enter。
SlackもChatGPTもClaudeも同じ操作に。改行と送信、もう間違えない。

14日間無料
https://iwai-ddndn.github.io/UniEnter/?utm_source=x&utm_medium=social&utm_campaign=launch_v020&utm_content=main

#Mac #個人開発
```

### 画像の代替テキスト

`x-launch-main-1600x900.png`:

```text
白いMacキーボードの文字キー領域右端にあるReturnキーとUniEnterのアイコン。「改行と送信、もう間違えない。」という見出し。右側に「Enterは改行」「⌘Enterは送信」、Slack・Teams・ChatGPT・Claudeなどで同じ操作になることを図解している。
```

`x-launch-safety-1600x900.png`:

```text
「あ」と刻印された白いキーキャップと、「日本語入力に、とことん安全。」という見出し。変換中のEnterはそのまま、迷ったら何もしない、入力内容を読まず外部送信しない、という3点を説明している。
```

## 画像の使い分け

| ファイル | 用途 |
| --- | --- |
| `assets/x-launch-main-1600x900.png` | 公開日のメイン投稿。1枚で課題・操作・対応範囲を完結 |
| `assets/x-launch-how-1600x900.png` | 予告、機能説明、引用投稿 |
| `assets/x-launch-safety-1600x900.png` | 2件目の返信、IME・プライバシー質問への回答 |
| `assets/x-launch-square-1200x1200.png` | Xの正方形版、Instagram、noteのSNS告知 |
| `assets/og-link-card-1200x630.png` | LPのOG候補。レビュー後に `site/public/assets/og.png` と差し替える |

X公式は画像・動画に16:9または1:1を使い、モバイルでも文字を読める大きさにすることを勧めている。本セットはその2比率で用意した。参考: [X Creative Best Practices](https://business.x.com/en/advertising/creative-best-practices)、[X Ads Creative Specs](https://business.x.com/en/help/campaign-setup/creative-ad-specifications)

## X以外の優先順位

### 1. note / Zenn（T+3）

タイトル案:

> 「Enterで誤送信」をMacからなくすアプリを作った — 日本語IMEを壊さないための設計

内容は、制作理由、アプリごとに違う送信キー、日本語変換中のEnterを安全に扱う難しさ、入力内容を読まない設計、14日トライアルの順。技術詳細は信頼の裏付けとして使い、冒頭は利用者の困りごとから始める。

### 2. 既存の知人・利用者への個別連絡

一斉DMではなく、実際にMacでチャットを多用している5〜10人へ短く送る。「拡散してください」ではなく「初回導線で困った点を教えてください」と依頼する。許可が取れた感想だけをT+7で使う。

### 3. GitHub Release / README

リポジトリ公開後、Release本文の先頭にも `Enter → 改行 / ⌘Enter → 送信` を置く。XからGitHub Releasesへ直接飛ばさず、まずLPで安全性と導入方法を説明する。

### 4. Product Hunt（英語LPができてから）

日本語だけの初回リリースと同日に無理に行わない。英語LP、短いデモ、英語の安全性説明を用意した第2波として使う。Product Hunt公式ガイドでは、制作者本人の投稿、製品の直接URL、最初のコメント、12:01 AM Pacificでの予約が案内され、アップボートを直接依頼しないよう求めている。参考: [Product Hunt Launch Guide](https://www.producthunt.com/launch)、[How to post a product](https://help.producthunt.com/en/articles/479557-how-to-post-a-product)

## 計測

最低限、次を初日・3日・7日で記録する。

- X: 表示、詳細クリック、プロフィール遷移、リンククリック、保存、返信
- LP: Xからの訪問（UTM別）
- GitHub: `.pkg` / `.zip` のダウンロード数
- Paddle: チェックアウト開始、購入完了
- サポート: 初回権限、インストール、公証警告、IMEに関する問い合わせ件数

投稿の成功を表示数だけで判断しない。最優先は `X → LP → ダウンロード`、次に `トライアル → 購入` の落ち方を見ること。初週は広告を出さず、どの訴求に自発的な反応が集まるかを確認してから画像や文面を増やす。

## imagegen生成元

`keyboard-enter-source.png` は組版前の背景素材。画像内の日本語や商品説明はimagegenに描かせず、`render_assets.swift` で正確に配置している。

使用モード: built-in imagegen  
分類: 生成 `ads-marketing` / 配置修正 `precise-object-edit`

最終プロンプト:

```text
Use case: ads-marketing
Asset type: X launch-post background panel for a macOS utility app
Primary request: Create a premium editorial macro photograph inspired by the supplied UniEnter app icon’s soft white keycap material language, showing a modern low-profile computer keyboard from a close diagonal angle with one large Enter key as the unmistakable focal point.
Input images: Image 1 is a visual/material reference for the white sculpted keycap look; do not copy it as a floating app icon.
Scene/backdrop: Minimal warm off-white studio surface, subtle shallow depth of field, quiet Notion-like restraint.
Subject: A realistic white Enter key integrated into a modern aluminum laptop keyboard; surrounding keys understated and partly out of focus.
Style/medium: Photorealistic premium product photography, tactile polymer texture, believable aluminum, refined but not glossy.
Composition/framing: Wide 16:9 landscape, Enter key occupying the right-center, generous clean negative space on the left for later typography; crop-safe edges.
Lighting/mood: Soft window light, calm, practical, intelligent; gentle natural shadow.
Color palette: warm white, ink gray, tiny restrained reflections of teal #0f7b6c and blue #2383e2 only.
Constraints: no hands, no screen, no product logo, no brand marks, no watermark, no floating icon, no added copy. If any key legend appears, only a simple return-arrow symbol on the focal key; keep other legends unobtrusive and physically plausible.
Avoid: dark cyberpunk style, neon, gaming keyboard, dramatic black background, distorted key geometry, gibberish text, oversaturated colors.
```

Returnキー配置の修正プロンプト:

```text
Use case: precise-object-edit
Asset type: X launch-post background panel for UniEnter
Primary request: Correct only the keyboard layout so the focal Return/Enter key is in the physically accurate position on a standard Mac laptop ANSI keyboard.
Input images: Image 1 is the edit target.
Keyboard geometry: The focal Return key must be a horizontal rectangular key at the far right edge of the main alphabetic typing area. It must be directly below the backslash key, directly to the right of the apostrophe key, and directly above the long right Shift key. The computer chassis must end immediately to the right of Return. It must NOT be in the arrow-key cluster, bottom row, numeric keypad, or an isolated navigation cluster.
Focal key legend: one simple engraved bent return-arrow symbol, physically plausible.
Composition/framing: Keep the wide 16:9 composition, close diagonal macro viewpoint, keyboard on the right half, and generous clean negative space on the left for typography.
Invariants: Change only the keyboard layout/geometry needed to put Return in the correct location. Preserve the warm off-white studio background, soft window lighting, shallow depth of field, white key material, aluminum texture, calm premium product-photo mood, and overall right-weighted framing.
Constraints: no hands, no screen, no brand logo, no watermark, no floating keycap, no extra copy. Surrounding key legends may be blank or understated; no gibberish.
Avoid: Return key beside arrow keys; Return key in bottom-right corner; numeric keypad; gaming keyboard; black keyboard; distorted key sizes; impossible gaps.
```

## 再生成

リポジトリルートで実行:

```bash
swift marketing/launch/render_assets.swift
```
