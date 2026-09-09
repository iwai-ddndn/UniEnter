# Polar.sh導入手順(ご本人作業)

UniEnterの課金はオフライン検証ライセンス+Polar.sh決済で動く。Paddleのドメイン審査が7週間以上
pendingのまま進まなかったため、Merchant of RecordをPolar.shに切替えた(旧手順は
`notes/PADDLE-SETUP.md` に経緯として残してある)。アプリ側・キー発行・自動発行Worker
(`license-signing/worker/`)まで実装済み。残るのはPolar側の設定のみ。

## いま動いている仕組み

- アプリは初回起動から**14日間**全機能で動作し、以降はライセンスキー入力まで書き換えを停止する
- ライセンスキーはEd25519署名付きのオフライン検証(認証サーバ不要)
- 手動発行: `swift license-signing/issue.swift 購入者メール` → キーを購入者へメール(1件30秒)
- 自動発行: `license-signing/worker/`(Cloudflare Worker、Polarの `order.paid` Webhookを受信。
  署名検証・冪等性のローカルテスト済み・未デプロイ)
- 秘密鍵は `license-signing/keys.txt`(**git管理外・要バックアップ**。漏れたら全キー再発行)

## 事前準備(完了済み)

- LP公開済み: https://unienter.oc-to.com/
- 利用規約: https://unienter.oc-to.com/terms.html
- プライバシーポリシー: https://unienter.oc-to.com/privacy.html
- 価格表記: ¥1,480(税込・買い切り)

## Step 1: アカウント作成(本番 + サンドボックス)

1. https://polar.sh/ → Sign up でサインアップ
2. 事業情報(個人事業主でも可)を入力。組織(Organization)を作成
3. 併せて**サンドボックスアカウント**も作る(https://sandbox.polar.sh/ — 本番とは別アカウント)。
   まずサンドボックスで一通り確認してから本番に切替えるのが安全

## Step 2: 商品作成(買い切り ¥1,480)

1. Products → **New Product**
   - Name: `UniEnter`
   - Description: 「macOSのチャットアプリでEnter=改行、⌘Enter=送信に統一するユーティリティ」等
   - Pricing: **One-time purchase**(買い切り)
2. 価格を **JPY 1,480** で設定
   - Organizationのdefault currencyがJPY以外の場合、JPYを価格通貨として追加できるか確認する
     (default currencyの変更が必要なケースがある)
   - 表示は税込(inclusive)にして、LPの「¥1,480(税込)」表記と一致させる。
     変更時はLP(`site/`)側の表記も揃える(この作業自体は別途Claudeが行う)

## Step 3: Webhook設定

1. Organization Settings → **Webhooks** → **Add Endpoint**
   - URL: `https://unienter-license.<subdomain>.workers.dev/polar/webhook`
   - Format: **Raw**(JSON)
   - Events: **`order.paid`** のみ購読(他のイベントは受信してもWorker側で無視される)
2. 作成すると secret(`whsec_...`)が表示されるので、Workerに登録する:
   ```bash
   cd license-signing/worker
   wrangler secret put POLAR_WEBHOOK_SECRET
   ```
3. サンドボックスと本番は別々にWebhookエンドポイントを作る必要がある
   (secretも別々になる。サンドボックスで試すあいだは `POLAR_API_BASE` も
   `https://sandbox-api.polar.sh` に変えておく)

## Step 4: Organization access tokenの発行

`POLAR_ACCESS_TOKEN` は必須ではないが、以下の2用途で強く推奨:
- Webhookの `customer.email` が null のときに顧客情報をAPIで補完する
- チェックアウト完了直後、Webhookがまだ届いていない場合に `/license` ページが
  チェックアウトAPIを直接確認してその場でキーを発行する(レース対策)

1. Organization Settings → Developers → **Organization access tokens** → New token
2. 読み取り権限(customers, checkouts)があるスコープで発行
3. Workerに登録:
   ```bash
   wrangler secret put POLAR_ACCESS_TOKEN
   ```

## Step 5: Checkout Link作成

1. Checkout Links → **New Link** → Step 2で作った ¥1,480 の商品を選択
2. Success URLに以下を設定(`{CHECKOUT_ID}` はPolarが実際のIDに置換する):
   ```
   https://unienter-license.<subdomain>.workers.dev/license?checkout_id={CHECKOUT_ID}
   ```
3. 生成された長期利用可能なURL(Checkout Link)を控えておく

## Step 6: Workerデプロイ

```bash
cd license-signing/worker
npm i -g wrangler        # 未導入なら
wrangler login

# KV作成 → 出力されたIDを wrangler.toml の TODO_KV_NAMESPACE_ID に反映(初回のみ)
wrangler kv namespace create LICENSES

# シークレット登録(Step 3, 4で取得した値)
wrangler secret put LICENSE_PRIVATE_KEY   # ../keys.txt の PRIVATE: 以降のbase64(初回のみ)
wrangler secret put POLAR_WEBHOOK_SECRET
wrangler secret put POLAR_ACCESS_TOKEN
wrangler secret put RESEND_API_KEY        # 任意(メール送信する場合のみ)

wrangler deploy
```

## Step 7: サンドボックスでテスト購入

1. `POLAR_API_BASE = "https://sandbox-api.polar.sh"` にしてデプロイ、
   サンドボックスのWebhook secret/access tokenを使う
2. https://sandbox.polar.sh/ でサンドボックス用のCheckout Linkから購入
   (テストカード `4242 4242 4242 4242`)
3. 購入完了 → success URLで `/license` ページが表示され、キーが発行されるか確認
4. 発行されたキーをアプリのライセンス画面に貼り付けて有効化できるか確認
5. 確認できたら `POLAR_API_BASE` を本番(`https://api.polar.sh`)・本番のsecret/tokenに戻して再デプロイ

## Step 8: 本番切替

Step 5で作った本番のCheckout Link URLを控えて共有してください。以下の2箇所の
差し替えは別途Claudeが行います:
- LP(`site/src/App.tsx`)の価格セクションの購入ボタン
- `UniEnter/UI/LicenseView.swift` の `purchaseURL`

## アカウント審査

初回payout前に審査が入る(最長14日程度)。必要になるもの:
- 事業内容の説明
- Stripe Identityによる本人確認(身分証+セルフィー)
- Stripe Connect Express経由の受取口座登録(日本の口座に対応)

審査中でも決済自体は受け付けられる(Webhook→キー発行のフローは審査と独立して動く)ので、
Step 1〜7は審査完了を待たずに進めてよい。

## 注意

- `keys.txt`(秘密鍵)は今後 **Cloudflareのシークレットにも存在する** ことになる。
  漏洩時は鍵ペア再生成+アプリの公開鍵差し替え+全キー再発行が必要
- Workerを止めても販売は継続できる(Polarの購入通知メールを見て手動発行に戻すだけ)
- 手数料は **5% + 50セント/取引**(Polarの標準MoR手数料。Paddle同様、消費税・インボイス・
  特商法表記の負担はPolar側が負う)
- 返金対応もPolarのダッシュボードから行う
- Webhookは最大10回・指数バックオフで再送される。Workerは注文ID単位で冪等に処理するため、
  再送されてもキーが二重発行されることはない
