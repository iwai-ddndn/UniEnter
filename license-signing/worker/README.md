# ライセンス自動発行 Worker(Polar.sh → Cloudflare Workers)

Polarの `order.paid` Webhookを受けて、`issue.swift` と同一形式の
ライセンスキー(`UNIENTER-base64url(payload).base64url(signature)`)を自動発行する。

- `POST /polar/webhook` — Webhook受信。キーを発行してKVへ保存(明示有効化後の新規発行分はResendでキーと使い方をメール送信)
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
wrangler secret put RESEND_API_KEY        # メール送信の承認後、既存の送信権限を持つキーを登録

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
    fetchハンドラ単体でシミュレート(使い捨て鍵・外部通信なし)
  - `node mail-test.mjs` — 送信有効/無効、API失敗・再試行・重複・過去注文・完了ページ先行発行を
    モックで検証(使い捨て鍵・外部通信なし)

## 注意

- `keys.txt`(秘密鍵)は今後 **Cloudflareのシークレットにも存在する** ことになる。
  漏洩時は鍵ペア再生成+アプリの公開鍵差し替え+全キー再発行が必要。
- Workerを止めても販売は継続できる(Polarの購入通知メールを見て手動発行に戻すだけ)。
- Polarは最大10回・指数バックオフでWebhookを再送する。ハンドラは `order:<order_id>` を
  KVで確認してから発行するため、再送時は同じキーを使う。メールが未受付なら再試行し、
  失敗時は503を返す。メール受付済みなら送信せず200を返す。
- Webhookの署名secretは2026-09-08以降に発行されたものはStandard Webhooks形式
  (`webhook-id`/`webhook-timestamp`/`webhook-signature` ヘッダ)。それより前に作成した
  エンドポイントのsecretは旧Polar HMAC形式の場合があり、Workerは両方の鍵解釈を試して検証する。


## 購入キーのメール通知(本番有効化前の準備)

`LICENSE_EMAIL_ENABLED` は既定で `"false"`。コードのデプロイだけでは送信を始めない。
送信先は **UniEnter購入時のメールアドレス**、件名は「UniEnter ライセンスキーのお届け」。
内容は既に発行した購入キー、アプリへの入力手順、利用範囲、サポート連絡先。

有効化前に必要な確認:

1. 上記送信先・内容で新規購入者へ通知する承認。
2. 既存Resendアカウント/APIキーの利用可否と、`MAIL_FROM` のドメイン認証。
   新規キー、DNS変更、課金が必要なら別途承認を得る。
3. `RESEND_API_KEY` と認証済み `MAIL_FROM` を設定し、モックテストと許可された宛先への送信検証後、
   `LICENSE_EMAIL_ENABLED = "true"` でデプロイする。

有効化後に作成したレコードだけ `mail.status=pending` を付ける。過去レコードへの
自動送信・一斉再送は行わない。過去注文への個別送信は別途承認と作業が必要。
完了ページが先にキーを発行した場合も、そのキーを後続Webhookが再利用して送信する。
GETによるページ表示だけではメールを送らない。

ResendのHTTP成功とmessage IDを確認した後だけ `mail.status=accepted` とID/受付日時を保存する。
これは **API受付** の記録であり、受信箱への配達・開封を意味しない。配達確認はResend側の履歴で行う。
API失敗・通信エラー・ID欠落は503とし、Webhook再試行時にも同じキーと同じメール本文を使用する。

注文IDを使うResendのIdempotency-Keyで重複を抑止する。有効期間は24時間のため、
API受付直後にKV書き込みが失敗し、そのまま24時間を超えた再試行では二重送信の余地がある。
KVは強整合なロックではない。長時間障害後の手動再送では先にResendの受付履歴を確認する。
参照: https://resend.com/docs/dashboard/emails/idempotency-keys

秘密鍵・購入キー・メール本文・API応答本文はログへ出力しない。
