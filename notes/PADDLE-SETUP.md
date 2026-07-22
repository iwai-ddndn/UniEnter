# Paddle導入手順(ご本人作業)

UniEnterの課金はオフライン検証ライセンス+Paddle決済で動く。アプリ側・キー発行・
自動発行Worker(`license-signing/worker/`)まで実装済み。残るのはPaddle側の設定のみ。

## いま動いている仕組み

- アプリは初回起動から**14日間**全機能で動作し、以降はライセンスキー入力まで書き換えを停止する
- ライセンスキーはEd25519署名付きのオフライン検証(認証サーバ不要)
- 手動発行: `swift license-signing/issue.swift 購入者メール` → キーを購入者へメール(1件30秒)
- 自動発行: `license-signing/worker/`(Cloudflare Worker、署名互換テスト済み・未デプロイ)
- 秘密鍵は `license-signing/keys.txt`(**git管理外・要バックアップ**。漏れたら全キー再発行)

## 事前準備(完了済み)

- LP公開済み: https://iwai-ddndn.github.io/UniEnter/
- 利用規約: https://iwai-ddndn.github.io/UniEnter/terms.html
- プライバシーポリシー: https://iwai-ddndn.github.io/UniEnter/privacy.html
- 価格表記: ¥1,480(税込・買い切り)

## Step 1: アカウント作成(約10分)

1. https://www.paddle.com/ → Get started でサインアップ(個人事業主OK)
2. メール認証・2FA設定
3. 事業情報: 個人(sole trader / individual)を選択、氏名・住所(日本)
4. ウェブサイト: `https://iwai-ddndn.github.io/UniEnter/` を申告

> 併せて**サンドボックスアカウント**も作っておくと安全にテスト購入できる
> (https://sandbox-login.paddle.com/signup — 本番とは別アカウント)。

## Step 2: 審査(数日かかることがある)

2つの審査がある。ダッシュボードの指示に従って両方進める:

1. **ドメイン審査(Website approval)**: Checkout → Website approval で
   `https://iwai-ddndn.github.io/UniEnter/` を申請。
   審査観点は「何を売っているか明確」「利用規約・プライバシーポリシーがある」
   「価格が明示されている」— すべて対応済み。
   - **注意**: github.io のような共有ドメインで通りにくい場合は、
     GitHub Pagesにカスタムドメイン(例: `unienter.oc-to.com`)を設定して再申請する
     (Pages側はCNAME追加のみ。必要になったらClaudeに依頼)
2. **事業者確認(Business verification)**: 本人確認書類と、売上受取先
   (銀行口座等)の登録

税カテゴリは既定の **Standard digital goods** のままでよい(Catalog → Taxable categories)。

## Step 3: 商品と価格の作成

1. Catalog → Products → **New product**
   - Name: `UniEnter` / Tax category: Standard digital goods
   - Description: 「macOSのチャットアプリでEnter=改行、⌘Enter=送信に統一するユーティリティ」等
2. その商品に **Price** を追加:
   - Type: **One-time**(単発)
   - Amount: **JPY 1,480**
   - 税設定: **税込(include tax in price / inclusive)** を選択
     (LPの「¥1,480(税込)」表記と一致させる。変更時はLPも揃える)

## Step 4: チェックアウトリンク(Buy nowリンク)の作成

1. Checkout → **Checkout links**(または価格の「…」メニューから Share/Copy checkout link)
2. 上で作った ¥1,480 の価格を選んでリンクを生成(`https://pay.paddle.io/...` 形式)
3. Checkout settings で Default payment link にLPのURLを設定しておく

**→ このURLをClaudeに渡す。** LP購入ボタンと `UniEnter/UI/LicenseView.swift` の
`purchaseURL` を差し替えて購入導線を有効化する。

## Step 5: キー発行の運用開始

- **当面(手動)**: Paddleの購入通知メールを受けたら `issue.swift` でキー発行→購入者へ返信
- **自動化**: `license-signing/worker/README.md` の手順でWorkerをデプロイし、
  Developer tools → Notifications で `transaction.completed` のWebhookを
  `https://<worker>/paddle/webhook` に向ける(secretをWorkerに登録)。
  発行キーはKV保存+`/license?txn=…`ページで表示、Resend設定時はメール自動送信

## Step 6: テスト

1. サンドボックスで同じ商品・価格・チェックアウトリンクを作り、テストカード
   (`4242 4242 4242 4242`)で購入 → Webhook→キー発行→アプリで有効化まで通す
2. 本番リンクでも1件実購入して確認(自分で購入→Paddleダッシュボードから返金でよい)

## 補足

- Paddleは Merchant of Record(販売者はPaddle)なので、消費税・インボイス・
  特商法表記の負担が大幅に軽くなる。領収書もPaddleが発行する
- 返金対応もPaddle経由。ポリシーは Dashboard → Checkout settings で設定できる
- 売上の受け取り(payout)は月次。受取通貨・口座はダッシュボードで設定
