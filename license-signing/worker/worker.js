// UniEnter ライセンス自動発行 Worker(Paddle Billing Webhook)
//
// エンドポイント:
//   POST /paddle/webhook  Paddleの transaction.completed を受けてキーを発行しKVへ保存
//                         (RESEND_API_KEY 設定時は購入者へメール送信)
//   GET  /license?txn=ID  チェックアウト完了ページ向け。キーを表示(未発行なら
//                         Paddle APIで取引を検証してその場で発行)
//
// シークレット(wrangler secret put):
//   PADDLE_WEBHOOK_SECRET  Paddle通知先(Notification destination)のsecret
//   PADDLE_API_KEY         Paddle APIキー(customers/transactions読み取り)
//   LICENSE_PRIVATE_KEY    keys.txt の PRIVATE: 行のbase64(Ed25519シード32byte)
//   RESEND_API_KEY         任意。設定するとメール送信も行う
// 変数(wrangler.toml [vars]):
//   PADDLE_API_BASE        https://api.paddle.com(sandboxは https://sandbox-api.paddle.com)
//   LICENSE_PUBLIC_KEY     公開鍵base64(LicenseManager.publicKeyBase64と同値)
//   MAIL_FROM              メール送信元(例: "UniEnter <license@oc-to.com>")
// KV: LICENSES

const encoder = new TextEncoder()

function bytesToB64url(bytes) {
  let bin = ""
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "")
}

function b64ToB64url(b64) {
  return b64.replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "")
}

// keys.txtのシードと公開鍵からJWKを組み立ててWebCryptoに読ませる
async function importSigningKey(env) {
  const jwk = {
    kty: "OKP",
    crv: "Ed25519",
    d: b64ToB64url(env.LICENSE_PRIVATE_KEY),
    x: b64ToB64url(env.LICENSE_PUBLIC_KEY),
  }
  return crypto.subtle.importKey("jwk", jwk, { name: "Ed25519" }, false, ["sign"])
}

// issue.swiftと同一形式のキーを生成(payloadはemail,iatのキー順を固定)
async function issueLicenseKey(env, email) {
  const payload = `{"email":${JSON.stringify(email)},"iat":${Math.floor(Date.now() / 1000)}}`
  const key = await importSigningKey(env)
  const payloadBytes = encoder.encode(payload)
  const sig = new Uint8Array(await crypto.subtle.sign("Ed25519", key, payloadBytes))
  return `UNIENTER-${bytesToB64url(payloadBytes)}.${bytesToB64url(sig)}`
}

// Paddle-Signature: "ts=1671552777;h1=..." / 署名対象は `${ts}:${rawBody}`
async function verifyPaddleSignature(env, rawBody, header) {
  if (!header) return false
  const parts = Object.fromEntries(header.split(";").map((p) => p.split("=")))
  const ts = parts.ts
  const h1 = parts.h1
  if (!ts || !h1) return false
  if (Math.abs(Date.now() / 1000 - Number(ts)) > 300) return false

  const hmacKey = await crypto.subtle.importKey(
    "raw", encoder.encode(env.PADDLE_WEBHOOK_SECRET),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  )
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", hmacKey, encoder.encode(`${ts}:${rawBody}`)))
  const hex = [...mac].map((b) => b.toString(16).padStart(2, "0")).join("")
  // 長さ一致+全桁比較(早期returnしない)
  if (hex.length !== h1.length) return false
  let diff = 0
  for (let i = 0; i < hex.length; i++) diff |= hex.charCodeAt(i) ^ h1.charCodeAt(i)
  return diff === 0
}

async function paddleGet(env, path) {
  const res = await fetch(`${env.PADDLE_API_BASE}${path}`, {
    headers: { Authorization: `Bearer ${env.PADDLE_API_KEY}` },
  })
  if (!res.ok) throw new Error(`Paddle API ${path} -> ${res.status}`)
  return (await res.json()).data
}

async function customerEmail(env, customerId) {
  const customer = await paddleGet(env, `/customers/${customerId}`)
  return customer.email
}

async function sendLicenseMail(env, email, licenseKey) {
  if (!env.RESEND_API_KEY || !env.MAIL_FROM) return
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: env.MAIL_FROM,
      to: [email],
      subject: "UniEnter ライセンスキーのお届け",
      text: [
        "UniEnterをご購入いただきありがとうございます。",
        "",
        "以下があなたのライセンスキーです:",
        "",
        licenseKey,
        "",
        "メニューバーのUniEnter → ライセンス からキーを貼り付けて有効化してください。",
        "同一ユーザーのMacであれば複数台でご利用いただけます。",
        "",
        "お困りの際は info@oc-to.com までご連絡ください。",
        "— octo(https://oc-to.com)",
      ].join("\n"),
    }),
  })
}

// 取引IDからキーを取得(未発行ならPaddle APIで確認して発行)
async function licenseForTransaction(env, txnId) {
  if (!/^txn_[a-z0-9]+$/i.test(txnId)) return null
  const cached = await env.LICENSES.get(`txn:${txnId}`, "json")
  if (cached) return cached

  const txn = await paddleGet(env, `/transactions/${txnId}`)
  if (!["completed", "paid"].includes(txn.status)) return null
  const email = await customerEmail(env, txn.customer_id)
  const licenseKey = await issueLicenseKey(env, email)
  const record = { email, key: licenseKey, issuedAt: new Date().toISOString() }
  await env.LICENSES.put(`txn:${txnId}`, JSON.stringify(record))
  return record
}

function licensePage(record) {
  const body = record
    ? `<h1>ご購入ありがとうございます</h1>
       <p>あなたのライセンスキー(<strong>${escapeHtml(record.email)}</strong> 宛に発行):</p>
       <pre>${escapeHtml(record.key)}</pre>
       <p>メニューバーの UniEnter → ライセンス にキーを貼り付けて有効化してください。<br>
       このページのURLを保存しておけば、あとからキーを再表示できます。</p>`
    : `<h1>ライセンスキーを表示できません</h1>
       <p>決済が確認できませんでした。数分おいて再読み込みするか、
       info@oc-to.com までお問い合わせください。</p>`
  return new Response(
    `<!doctype html><html lang="ja"><head><meta charset="utf-8">
     <meta name="viewport" content="width=device-width, initial-scale=1">
     <title>UniEnter ライセンス</title>
     <style>
       body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;color:#37352f;
            max-width:40rem;margin:4rem auto;padding:0 1.5rem;line-height:1.7}
       pre{background:#f6f5f4;border:1px solid #e3e2e0;border-radius:8px;
           padding:1rem;overflow-x:auto;user-select:all}
       h1{font-size:1.4rem}
     </style></head><body>${body}
     <p style="color:#9b9a97;font-size:.8rem">© 2026 octo(oc-to.com)/ info@oc-to.com</p>
     </body></html>`,
    { headers: { "Content-Type": "text/html; charset=utf-8" } },
  )
}

function escapeHtml(s) {
  return s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url)

    if (request.method === "POST" && url.pathname === "/paddle/webhook") {
      const rawBody = await request.text()
      const ok = await verifyPaddleSignature(env, rawBody, request.headers.get("Paddle-Signature"))
      if (!ok) return new Response("invalid signature", { status: 401 })

      const event = JSON.parse(rawBody)
      if (event.event_type === "transaction.completed") {
        const txnId = event.data.id
        const existing = await env.LICENSES.get(`txn:${txnId}`)
        if (!existing) {
          const email = await customerEmail(env, event.data.customer_id)
          const licenseKey = await issueLicenseKey(env, email)
          await env.LICENSES.put(
            `txn:${txnId}`,
            JSON.stringify({ email, key: licenseKey, issuedAt: new Date().toISOString() }),
          )
          await sendLicenseMail(env, email, licenseKey)
        }
      }
      return new Response("ok")
    }

    if (request.method === "GET" && url.pathname === "/license") {
      const txnId = url.searchParams.get("txn") ?? ""
      let record = null
      try {
        record = await licenseForTransaction(env, txnId)
      } catch {
        record = null
      }
      return licensePage(record)
    }

    return new Response("not found", { status: 404 })
  },
}
