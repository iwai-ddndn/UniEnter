# ライセンス自動発行 Worker(Paddle → Cloudflare Workers)

Paddleの `transaction.completed` Webhookを受けて、`issue.swift` と同一形式の
ライセンスキー(`UNIENTER-base64url(payload).base64url(signature)`)を自動発行する。

- `POST /paddle/webhook` — Webhook受信。キーを発行してKVへ保存(Resend設定時はメール送信も)
- `GET /license?txn=txn_...` — キー表示ページ。Paddleチェックアウトの完了後リダイレクト先に使う

手動運用(`swift license-signing/issue.swift メール`)はいつでも併用可能。

## デプロイ手順(Paddleアカウント作成後)

```bash
cd license-signing/worker
npm i -g wrangler        # 未導入なら
wrangler login

# KV作成 → 出力されたIDを wrangler.toml の TODO_KV_NAMESPACE_ID に反映
wrangler kv namespace create LICENSES

# シークレット登録
wrangler secret put LICENSE_PRIVATE_KEY   # ../keys.txt の PRIVATE: 以降のbase64
wrangler secret put PADDLE_API_KEY        # Paddle Dashboard → Developer tools → Authentication
wrangler secret put PADDLE_WEBHOOK_SECRET # 下記のNotification destination作成時に表示される
wrangler secret put RESEND_API_KEY        # 任意(メール送信する場合のみ)

wrangler deploy
```

## Paddle側の設定

1. Developer tools → Notifications → New destination
   - URL: `https://unienter-license.<your>.workers.dev/paddle/webhook`
   - イベント: `transaction.completed` のみ
   - 表示される secret を `PADDLE_WEBHOOK_SECRET` に登録
2. Checkout settings → 完了後のリダイレクト先(success URL)に
   `https://unienter-license.<your>.workers.dev/license?txn={transaction_id}`
   を設定できる場合は設定(できない場合もWebhook+メールで届く)

## 動作確認

- サンドボックス: `PADDLE_API_BASE = "https://sandbox-api.paddle.com"` に変えてテスト購入
- 発行されたキーがアプリで通ることを確認(ライセンス画面に貼り付け)
- 互換性テスト(署名がアプリの公開鍵で検証できるか)はローカルで:
  `node compat-test.mjs`(要Node 20+。../keys.txt を読む)

## 注意

- `keys.txt`(秘密鍵)は今後 **Cloudflareのシークレットにも存在する** ことになる。
  漏洩時は鍵ペア再生成+アプリの公開鍵差し替え+全キー再発行が必要。
- Workerを止めても販売は継続できる(Paddleの購入通知メールを見て手動発行に戻すだけ)。
