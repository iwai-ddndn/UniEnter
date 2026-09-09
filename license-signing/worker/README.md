# ライセンス自動発行 Worker(Polar.sh → Cloudflare Workers)

Polarの `order.paid` Webhookを受けて、`issue.swift` と同一形式の
ライセンスキー(`UNIENTER-base64url(payload).base64url(signature)`)を自動発行する。

- `POST /polar/webhook` — Webhook受信。キーを発行してKVへ保存(Resend設定時はメール送信も)
- `GET /license?checkout_id=...` — キー表示ページ。Polarチェックアウトの完了後リダイレクト先に使う
  (`?order=...` でも同様に引ける。Webhook未着の場合は数秒おきに自動再読み込みし、
  `POLAR_ACCESS_TOKEN` があればチェックアウトAPIを直接確認してその場発行も試みる)

手動運用(`swift license-signing/issue.swift メール`)はいつでも併用可能。

## デプロイ手順(Polarアカウント作成後)

```bash
cd license-signing/worker
npm i -g wrangler        # 未導入なら
wrangler login

# KV作成 → 出力されたIDを wrangler.toml の TODO_KV_NAMESPACE_ID に反映
wrangler kv namespace create LICENSES

# シークレット登録
wrangler secret put LICENSE_PRIVATE_KEY   # ../keys.txt の PRIVATE: 以降のbase64
wrangler secret put POLAR_WEBHOOK_SECRET  # 下記のWebhookエンドポイント作成時に表示される(whsec_...)
wrangler secret put POLAR_ACCESS_TOKEN    # Polar Dashboard → Settings → Developers → Organization access tokens(任意だが推奨)
wrangler secret put RESEND_API_KEY        # 任意(メール送信する場合のみ)

wrangler deploy
```

## Polar側の設定

1. Organization Settings → Webhooks → **Add Endpoint**
   - URL: `https://unienter-license.<your>.workers.dev/polar/webhook`
   - Format: **Raw**(JSON)
   - Events: `order.paid` のみ購読
   - 表示される secret(`whsec_...`)を `POLAR_WEBHOOK_SECRET` に登録
2. Checkout Links → 該当リンクの success URL に
   `https://unienter-license.<your>.workers.dev/license?checkout_id={CHECKOUT_ID}`
   を設定(Polarが `{CHECKOUT_ID}` を実際のIDに置換してくれる)

## 動作確認

- サンドボックス: `POLAR_API_BASE = "https://sandbox-api.polar.sh"` に変えて
  https://sandbox.polar.sh でテスト購入(テストカード `4242 4242 4242 4242`)
- 発行されたキーがアプリで通ることを確認(ライセンス画面に貼り付け)
- 署名検証・キー発行ロジックのテストはローカルで:
  - `node compat-test.mjs` — 発行したキーがアプリの公開鍵で検証できるか(要Node 20+、../keys.txt)
  - `node webhook-test.mjs` — Standard Webhooks署名の検証・冪等性・`/license`表示までを
    fetchハンドラ単体でシミュレート(要Node 20+、../keys.txt)

## 注意

- `keys.txt`(秘密鍵)は今後 **Cloudflareのシークレットにも存在する** ことになる。
  漏洩時は鍵ペア再生成+アプリの公開鍵差し替え+全キー再発行が必要。
- Workerを止めても販売は継続できる(Polarの購入通知メールを見て手動発行に戻すだけ)。
- Polarは最大10回・指数バックオフでWebhookを再送する。ハンドラは `order:<order_id>` を
  KVで確認してから発行するため、再送されても二重発行はしない(200を返して黙って無視する)。
- Webhookの署名secretは2026-09-08以降に発行されたものはStandard Webhooks形式
  (`webhook-id`/`webhook-timestamp`/`webhook-signature` ヘッダ)。それより前に作成した
  エンドポイントのsecretは旧Polar HMAC形式の場合があり、Workerは両方の鍵解釈を試して検証する。
