# SNS(Instagram / X)用アセットとプロフィール

2026-09-29 作成。LPの全面リニューアル(紙の生成り地 × 墨 × ティール1色)に合わせた一式。
旧素材 `marketing/launch/assets/`(青 #2383e2・AI生成のキーボード写真)は現行のLPと見た目が合わないので、**今後はこちらを正とする**。

> ⚠️ **投稿の前に**: `LAUNCH-PLAN.md` のGO条件(特に **Developer ID 公証** と **購入の受付開始**)が揃うまで、広く告知しない。
> 公証前はmacOS 15でインストールが難しく、先行テストでも脱落が出ている(CLAUDE.md「残タスク」参照)。
> 素材に「買い切り ¥1,480」とあるので、購入受付の開始前に出す場合はそこを文面で「購入は近日開始」と補う。

2026-10-06: メインコピー修正版は [copy-20261006](../copy-20261006/README.md) を使用。旧書き出しは履歴として保全。

## ファイル

| ファイル | サイズ | 用途 |
| --- | --- | --- |
| `video/unienter-story.mp4` | 1080×1920・28秒・無音 | **IG リール / ストーリーズ**(Xにも縦動画として投稿可) |
| `video/unienter-square.mp4` | 1080×1080・28秒・無音 | **X のタイムライン**、IG フィード |
| `assets/reel-cover.png` | 1080×1920 | リールのカバー画像(グリッドでは中央1080×1350が見える) |
| `assets/profile-icon.png` | 1080×1080 | X・IG 共通のプロフィール画像(丸く切り抜かれても↵が欠けない) |
| `assets/x-header.png` | 1500×500 | X のヘッダー(左下はアイコンが重なるので要素は右寄せ) |
| `assets/x-post-main.png` | 1600×900 | X 告知投稿の画像 |
| `assets/x-post-rule.png` | 1600×900 | X 使い方投稿(Enter→改行 / ⌘Enter→送信+対応サービス) |
| `assets/x-post-safety.png` | 1600×900 | X 安心の説明(リプライ・質問への回答用) |
| `assets/ig-01-hook.png` 〜 `ig-06-cta.png` | 1080×1350 ×6 | IG カルーセル投稿(1枚目フック → 6枚目CTA) |

動画の構成(28秒): あるある(Enterで書きかけ送信)→ AIに1行目だけ送信 → 製品名 → Enterは改行・⌘Enterで送信の実演 → 対応サービス → 勝手に通信しない等の3点(夜色)→ 14日間無料・URL。
**音は入れていない**(ライセンスの問題を避けるため)。IG で音を付けるなら、投稿時にアプリ内の音源ライブラリから選ぶ。字幕が画面に入っているので無音でも伝わる。

### 作り直し方

見た目はすべて `site/src/promo/`(`Promo.tsx` = 動画、`Assets.tsx` = 静止画)。本番ビルドには含まれない。

```bash
cd site && npx vite --port 5188     # dev server
cd marketing/sns && npm i --no-save puppeteer-core && node render-video.mjs && node render-assets.mjs
```

確認だけなら `http://localhost:5188/promo.html?format=story&play`(リアルタイム再生)/ `?t=12.3`(その時刻で静止)/ `sns-assets.html?a=x-post-main`。

---

## プロフィール

### X

- **名前**(50字以内): `UniEnter|Enterのうっかり送信を防ぐMacアプリ`
- **ユーザー名の候補**: `@unienter_app` → `@unienter_mac` → `@uni_enter`(空いているものを取得)
- **自己紹介**(160字以内・現在 約120字):

```text
Enterでのうっかり送信を防ぐMacアプリ。Slack・Teams・LINE・ChatGPT・Claudeなど、チャット/AIアプリのEnterは改行、送信は⌘Enterに統一します。勝手に通信しない・日本語の変換中は触れない設計。14日間無料・買い切り。制作: octo
```

- **場所**: `macOS 13以降`
- **ウェブサイト**: `https://unienter.oc-to.com/?utm_source=x&utm_medium=social&utm_campaign=profile`
- **固定ポスト**: 下の「X 告知投稿」(動画付き)

### Instagram

- **ユーザーネーム候補**: `unienter.app` → `unienter_mac`
- **名前**(検索にかかる欄): `UniEnter|Macのうっかり送信防止`
- **自己紹介**(150字以内・現在 約90字):

```text
Enterでのうっかり送信を防ぐMacアプリ
Enterは改行、送信は⌘Enter
Slack・LINE・ChatGPT・Claudeなど
勝手に通信しない/14日間無料・買い切り
↓ダウンロード・使い方
```

- **リンク**: `https://unienter.oc-to.com/?utm_source=instagram&utm_medium=social&utm_campaign=profile`
- **カテゴリ**: 「アプリページ」または「ソフトウェア」(プロアカウントに切り替えると選べる。インサイトも見られるので切替推奨)
- **ハイライト**(任意): 「使い方」= `ig-03-rule`、「安心」= `ig-05-safety`、「対応アプリ」= `ig-04-apps` をストーリーズに上げてからハイライト化

---

## 投稿文

### X 告知投稿(動画: `unienter-square.mp4`)

```text
改行したかっただけなのに、送ってしまった。

Macのチャット/AIアプリで、Enterでのうっかり送信を防ぐアプリ「UniEnter」を作りました。

Enterは改行、送信は⌘Enter。
Slack・Teams・LINE・ChatGPT・Claudeなど、アプリでもブラウザでも同じルールに。

14日間無料で試せます。
```

セルフリプライ(画像なし=リンクカードを出す):

```text
ダウンロードはこちら(macOS 13以降・約3MB)
https://unienter.oc-to.com/?utm_source=x&utm_medium=social&utm_campaign=launch&utm_content=reply1

買い切り ¥1,480(税込)。入力した文章をどこにも送らない設計です(勝手に通信しない・ソースコード公開)。
```

### X 使い方投稿(画像: `x-post-rule.png`)

```text
覚えることは2つだけ。

Enter → 改行
⌘ + Enter → 送信

アプリごとに「このアプリはEnterで送信だっけ?」と考えなくてよくなります。
```

### X 安心の説明(画像: `x-post-safety.png`、「キー入力を見るアプリって大丈夫?」系の反応への返信にも使う)

```text
UniEnterは、入力した文章をどこにも送りません。

・勝手に通信しない(通信は「アップデートを確認」を押したときだけ)
・日本語の変換を確定するEnterには触れない
・ソースコードはGitHubで全部公開
```

### IG リール(動画: `unienter-story.mp4`、カバー: `reel-cover.png`)

```text
改行したかっただけなのに、送ってしまった…を、なくすMacアプリを作りました。

UniEnterを入れると、チャット/AIアプリで
Enter → 改行
⌘ + Enter → 送信
に揃います。

Slack・Teams・LINE・ChatGPT・Claude・Discordなど、アプリ版もブラウザ版も対象。
入力した文章はどこにも送りません(勝手に通信しない)。

14日間無料・買い切り。プロフィールのリンクからどうぞ。

#Mac #Macアプリ #仕事効率化 #Slack #ChatGPT #個人開発 #リモートワーク #ショートカットキー
```

### IG カルーセル(画像: `ig-01` 〜 `ig-06` の順)

```text
Enterでのうっかり送信、ありませんか?

書きかけのメッセージ、AIへの長い指示の1行目だけ…
UniEnterは、Macのチャット/AIアプリで「Enterは改行、送信は⌘Enter」に揃えます。

▶ 詳しくはスワイプ
▶ ダウンロードはプロフィールのリンクから(14日間無料)

#Mac #Macアプリ #仕事効率化 #Slack #ChatGPT #Claude #個人開発 #便利ツール
```

### 代替テキスト(アクセシビリティ)

- 動画: 「チャットアプリでEnterを押すと書きかけのメッセージが送られてしまう場面と、UniEnterを入れるとEnterで改行でき、⌘Enterで送信される場面の比較。対応サービスのロゴと、勝手に通信しない・変換中は触れない・ソースコード公開の3点、最後に14日間無料とURL」
- `x-post-main`: 「UniEnterのロゴと『Enterでのうっかり送信を防ぐ』の文字。右にチャット画面で3行のメッセージが1通で送られている例」
- `x-post-rule`: 「returnキーで改行、⌘とreturnキーで送信、という2つのルール。右に対応サービスのロゴ12個」
- `x-post-safety`: 「入力した文章はどこにも送りません。勝手に通信しない・変換中は触れない・中身は公開、の3項目」

## 投稿のコツ(既存の LAUNCH-PLAN.md の判断を踏襲)

- 告知の時刻は火曜 21:05 JST。X は動画を本文に、URLはセルフリプライへ(本文にURLを入れると表示が落ちやすい)。
- IG は最初にリール → 翌日カルーセル。リールはカバーを必ず設定する(グリッドの見た目が揃う)。
- ロゴは各社の商標。投稿本文に「各社と無関係の個人開発」まで書く必要はないが、質問が来たらLPのフッター表記どおりに答える。
