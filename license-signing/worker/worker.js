// UniEnter ライセンス自動発行 Worker(Polar.sh Webhook)
//
// エンドポイント:
//   POST /polar/webhook           Polarの order.paid を受けてキーを発行しKVへ保存
//                                 (RESEND_API_KEY 設定時は購入者へメール送信)
//   GET  /license?checkout_id=ID  チェックアウト完了ページ向け。キーを表示。
//                                 ?order=ID でも同様に引ける(エイリアス)。
//                                 未発行かつWebhook未着の場合は自動更新ページを返し、
//                                 POLAR_ACCESS_TOKEN があればチェックアウトAPIで
//                                 その場発行も試みる(Webhookとのレース対策)
//
// シークレット(wrangler secret put):
//   POLAR_WEBHOOK_SECRET   Polar Webhookエンドポイント作成時に発行される secret(whsec_...)
//   POLAR_ACCESS_TOKEN     Polar Organization access token(customers/checkouts読み取り、任意)
//   LICENSE_PRIVATE_KEY    keys.txt の PRIVATE: 行のbase64(Ed25519シード32byte)
//   RESEND_API_KEY         任意。設定するとメール送信も行う
// 変数(wrangler.toml [vars]):
//   POLAR_API_BASE         https://api.polar.sh(sandboxは https://sandbox-api.polar.sh)
//   LICENSE_PUBLIC_KEY     公開鍵base64(LicenseManager.publicKeyBase64と同値)
//   MAIL_FROM              メール送信元(例: "UniEnter <license@oc-to.com>")
// KV: LICENSES(キーは order:<order_id> と checkout:<checkout_id> の2本立てで同じレコードを保存)

const encoder = new TextEncoder()

function bytesToB64url(bytes) {
  let bin = ""
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "")
}

function b64ToB64url(b64) {
  return b64.replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "")
}

function b64ToBytes(b64) {
  const bin = atob(b64)
  const bytes = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i)
  return bytes
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

async function hmacSha256(keyBytes, messageBytes) {
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"])
  return new Uint8Array(await crypto.subtle.sign("HMAC", key, messageBytes))
}

// 長さ一致+全桁比較(早期returnしない)
function constantTimeEqual(a, b) {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i]
  return diff === 0
}

// Standard Webhooks形式の署名検証
// ヘッダ: webhook-id / webhook-timestamp(unix秒) / webhook-signature("v1,<base64>"のスペース区切り、複数可)
// 署名対象: `${webhook-id}.${webhook-timestamp}.${rawBody}` のHMAC-SHA256
// secretは2種類の解釈を両方試す(Polar SDKと同じ振る舞い):
//   新形式: "whsec_"以降をbase64デコードしたバイト列をHMACキーにする(2026-09-08以降に発行された secret)
//   旧形式: "whsec_"込みの文字列全体をUTF-8バイト列としてHMACキーにする(それ以前の secret)
async function verifyPolarSignature(env, rawBody, headers) {
  const id = headers.get("webhook-id")
  const timestamp = headers.get("webhook-timestamp")
  const signatureHeader = headers.get("webhook-signature")
  if (!id || !timestamp || !signatureHeader) return false

  const now = Math.floor(Date.now() / 1000)
  if (!Number.isFinite(Number(timestamp)) || Math.abs(now - Number(timestamp)) > 300) return false

  const secret = env.POLAR_WEBHOOK_SECRET ?? ""
  if (!secret.startsWith("whsec_")) return false
  const secretBody = secret.slice("whsec_".length)

  const candidateKeys = []
  try {
    candidateKeys.push(b64ToBytes(secretBody)) // 新形式
  } catch {
    // secretBodyがbase64として不正なら新形式の候補はスキップ
  }
  candidateKeys.push(encoder.encode(secret)) // 旧形式(whsec_込み全体)

  const message = encoder.encode(`${id}.${timestamp}.${rawBody}`)
  const providedSigs = signatureHeader
    .split(" ")
    .map((entry) => entry.split(",")[1])
    .filter(Boolean)

  for (const keyBytes of candidateKeys) {
    const mac = await hmacSha256(keyBytes, message)
    for (const sigB64 of providedSigs) {
      let sigBytes
      try {
        sigBytes = b64ToBytes(sigB64)
      } catch {
        continue
      }
      if (constantTimeEqual(mac, sigBytes)) return true
    }
  }
  return false
}

async function polarGet(env, path) {
  const res = await fetch(`${env.POLAR_API_BASE}${path}`, {
    headers: { Authorization: `Bearer ${env.POLAR_ACCESS_TOKEN}` },
  })
  if (!res.ok) throw new Error(`Polar API ${path} -> ${res.status}`)
  return res.json()
}

async function customerEmail(env, customerId) {
  const customer = await polarGet(env, `/v1/customers/${customerId}`)
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

// KVからレコードを引く。checkout_id優先、無ければorder_idとしても引く(?order=エイリアス対応)
async function lookupRecord(env, id) {
  if (!id) return null
  const byCheckout = await env.LICENSES.get(`checkout:${id}`, "json")
  if (byCheckout) return byCheckout
  return env.LICENSES.get(`order:${id}`, "json")
}

// Webhookがまだ届いていない場合のレース対策。POLAR_ACCESS_TOKENがあれば
// チェックアウトAPIを直接確認し、支払い済みならその場でキーを発行する
async function tryIssueFromCheckout(env, checkoutId) {
  if (!checkoutId || !env.POLAR_ACCESS_TOKEN) return null
  let checkout
  try {
    checkout = await polarGet(env, `/v1/checkouts/${checkoutId}`)
  } catch {
    return null
  }
  if (checkout.status !== "succeeded") return null
  const email = checkout.customer_email
  if (!email) return null

  const licenseKey = await issueLicenseKey(env, email)
  const record = { email, key: licenseKey, issuedAt: new Date().toISOString() }
  await env.LICENSES.put(`checkout:${checkoutId}`, JSON.stringify(record))
  if (checkout.order_id) {
    await env.LICENSES.put(`order:${checkout.order_id}`, JSON.stringify(record))
  }
  return record
}

function escapeHtml(s) {
  return s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
}

function htmlPage(body, refreshUrl) {
  const refreshTag = refreshUrl
    ? `<meta http-equiv="refresh" content="5;url=${escapeHtml(refreshUrl)}">`
    : ""
  return new Response(
    `<!doctype html><html lang="ja"><head><meta charset="utf-8">
     <meta name="viewport" content="width=device-width, initial-scale=1">
     ${refreshTag}
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

function licensePage(record) {
  return htmlPage(`<h1>ご購入ありがとうございます</h1>
       <p>あなたのライセンスキー(<strong>${escapeHtml(record.email)}</strong> 宛に発行):</p>
       <pre>${escapeHtml(record.key)}</pre>
       <p>メニューバーの UniEnter → ライセンス にキーを貼り付けて有効化してください。<br>
       このページのURLを保存しておけば、あとからキーを再表示できます。</p>`)
}

// 発行中(Webhook未着)ページ。?n=で再読み込み回数を持ち回り、最大12回(約1分)で諦める
function pendingPage(checkoutId, n) {
  if (n < 12) {
    const nextUrl = `/license?checkout_id=${encodeURIComponent(checkoutId)}&n=${n + 1}`
    return htmlPage(
      `<h1>発行中です</h1>
       <p>決済の確認とキーの発行に数秒かかることがあります。<br>
       このページは自動的に再読み込みされます(数秒後に再読み込みしてください)。</p>`,
      nextUrl,
    )
  }
  return htmlPage(
    `<h1>ライセンスキーを表示できません</h1>
     <p>決済が確認できませんでした。お手数ですが info@oc-to.com まで
     ご購入時のメールアドレスとあわせてお問い合わせください。</p>`,
  )
}

function notFoundPage() {
  return htmlPage(
    `<h1>ライセンスキーを表示できません</h1>
     <p>URLに誤りがある可能性があります。info@oc-to.com までお問い合わせください。</p>`,
  )
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url)

    if (request.method === "POST" && url.pathname === "/polar/webhook") {
      const rawBody = await request.text()
      const ok = await verifyPolarSignature(env, rawBody, request.headers)
      if (!ok) return new Response("invalid signature", { status: 401 })

      const event = JSON.parse(rawBody)
      if (event.type !== "order.paid") {
        // order.created / checkout.* 等は無視(200で返し再送を止める)
        return new Response("ignored")
      }

      const order = event.data
      const orderId = order.id
      const existing = await env.LICENSES.get(`order:${orderId}`)
      if (!existing) {
        let email = order.customer?.email ?? null
        if (!email && order.customer_id && env.POLAR_ACCESS_TOKEN) {
          email = await customerEmail(env, order.customer_id)
        }
        if (!email) {
          // メールが取れない場合は発行できない。Polarの再送(最大10回)に賭けて非200を返す
          return new Response("email unresolved", { status: 500 })
        }

        const licenseKey = await issueLicenseKey(env, email)
        const record = { email, key: licenseKey, issuedAt: new Date().toISOString() }
        await env.LICENSES.put(`order:${orderId}`, JSON.stringify(record))
        if (order.checkout_id) {
          await env.LICENSES.put(`checkout:${order.checkout_id}`, JSON.stringify(record))
        }
        await sendLicenseMail(env, email, licenseKey)
      }
      // 既発行(リトライ配送)でも200を返して冪等に扱う
      return new Response("ok")
    }

    if (request.method === "GET" && url.pathname === "/license") {
      const id = url.searchParams.get("checkout_id") ?? url.searchParams.get("order") ?? ""
      const n = Number(url.searchParams.get("n") ?? "0")
      if (!id) return notFoundPage()

      let record = await lookupRecord(env, id)
      if (!record) {
        try {
          record = await tryIssueFromCheckout(env, id)
        } catch {
          record = null
        }
      }
      return record ? licensePage(record) : pendingPage(id, n)
    }

    return new Response("not found", { status: 404 })
  },
}
