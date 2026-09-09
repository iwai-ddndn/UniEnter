// worker.js の fetch ハンドラを直接呼び出すローカルテスト(Cloudflareにデプロイせず検証)
// 実行: node webhook-test.mjs(要Node 20+、../keys.txt が必要)
//
// 検証内容:
//   1. 正しいStandard Webhooks署名の order.paid → 200、UNIENTER-形式のキーが
//      order:<id> と checkout:<id> の両方に保存される
//   2. 改ざんされたボディ → 401
//   3. 同一Webhookの再送(重複配信) → 200 だが再発行されない(冪等)
//   4. GET /license?checkout_id=... でキーが表示される
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import assert from "node:assert/strict"
import worker from "./worker.js"

const here = dirname(fileURLToPath(import.meta.url))
const keysTxt = readFileSync(join(here, "..", "keys.txt"), "utf8")
const privateB64 = keysTxt.split("\n").find((l) => l.startsWith("PRIVATE:")).slice("PRIVATE:".length).trim()
const PUBLIC_KEY_B64 = "GnuD4CdMgZHXooBnItp7HxOZUQD7Ai/fURl0oqidhXk=" // LicenseManager.publicKeyBase64

// --- KVスタブ(インメモリ) ---
function createKvStub() {
  const store = new Map()
  const putCalls = []
  return {
    async get(key, type) {
      const v = store.get(key)
      if (v === undefined) return null
      return type === "json" ? JSON.parse(v) : v
    },
    async put(key, value) {
      putCalls.push(key)
      store.set(key, value)
    },
    store,
    putCalls,
  }
}

const kv = createKvStub()

// Standard Webhooks形式のsecret(新形式: whsec_ + base64バイト列)
const secretBytes = crypto.getRandomValues(new Uint8Array(24))
const secretB64 = Buffer.from(secretBytes).toString("base64")
const POLAR_WEBHOOK_SECRET = `whsec_${secretB64}`

const env = {
  LICENSE_PRIVATE_KEY: privateB64,
  LICENSE_PUBLIC_KEY: PUBLIC_KEY_B64,
  POLAR_WEBHOOK_SECRET,
  POLAR_API_BASE: "https://api.polar.sh",
  MAIL_FROM: "UniEnter <license@oc-to.com>",
  LICENSES: kv,
}

async function hmacSha256Base64(keyBytes, message) {
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"])
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message)))
  return Buffer.from(mac).toString("base64")
}

async function signedHeaders(id, timestamp, rawBody) {
  const signedContent = `${id}.${timestamp}.${rawBody}`
  const sigB64 = await hmacSha256Base64(secretBytes, signedContent)
  return {
    "webhook-id": id,
    "webhook-timestamp": String(timestamp),
    "webhook-signature": `v1,${sigB64}`,
    "content-type": "application/json",
  }
}

const ORDER_ID = "11111111-1111-1111-1111-111111111111"
const CHECKOUT_ID = "22222222-2222-2222-2222-222222222222"

function sampleOrderPaidBody() {
  return JSON.stringify({
    type: "order.paid",
    timestamp: new Date().toISOString(),
    data: {
      id: ORDER_ID,
      status: "paid",
      paid: true,
      billing_reason: "purchase",
      currency: "jpy",
      total_amount: 1480,
      customer_id: "cus_test",
      product_id: "prod_test",
      checkout_id: CHECKOUT_ID,
      customer: { id: "cus_test", email: "buyer@example.com", public_name: "Test Buyer" },
      product: null,
      metadata: {},
      custom_field_data: {},
    },
  })
}

let passed = 0
function ok(label) {
  passed++
  console.log(`OK: ${label}`)
}

// --- 1. 正しい署名 → 200、キーがorder:とcheckout:両方に保存 ---
{
  const id = "msg_1"
  const timestamp = Math.floor(Date.now() / 1000)
  const rawBody = sampleOrderPaidBody()
  const headers = await signedHeaders(id, timestamp, rawBody)
  const req = new Request("https://worker.example/polar/webhook", { method: "POST", headers, body: rawBody })
  const res = await worker.fetch(req, env)
  assert.equal(res.status, 200)
  ok("正しい署名のorder.paid → 200")

  const byOrder = await kv.get(`order:${ORDER_ID}`, "json")
  const byCheckout = await kv.get(`checkout:${CHECKOUT_ID}`, "json")
  assert.ok(byOrder, "order:<id> にレコードが保存されている")
  assert.ok(byCheckout, "checkout:<id> にレコードが保存されている")
  assert.equal(byOrder.key, byCheckout.key)
  assert.match(byOrder.key, /^UNIENTER-[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/)
  assert.equal(byOrder.email, "buyer@example.com")
  ok("UNIENTER-形式のキーがorder:とcheckout:の両方に保存される")
}

// --- 2. 改ざんされたボディ → 401 ---
{
  const id = "msg_2"
  const timestamp = Math.floor(Date.now() / 1000)
  const rawBody = sampleOrderPaidBody()
  const headers = await signedHeaders(id, timestamp, rawBody) // 正しい署名(元のボディに対して)
  const tamperedBody = rawBody.replace('"total_amount":1480', '"total_amount":1')
  const req = new Request("https://worker.example/polar/webhook", { method: "POST", headers, body: tamperedBody })
  const res = await worker.fetch(req, env)
  assert.equal(res.status, 401)
  ok("改ざんされたボディ → 401")
}

// --- 3. 重複配信(再送) → 200だが再発行しない ---
{
  const putCountBefore = kv.putCalls.length
  const id = "msg_1_retry" // Polarは再送時に別のwebhook-idを付けることがあるが、注文IDで冪等判定する
  const timestamp = Math.floor(Date.now() / 1000)
  const rawBody = sampleOrderPaidBody() // 同一order.id
  const headers = await signedHeaders(id, timestamp, rawBody)
  const req = new Request("https://worker.example/polar/webhook", { method: "POST", headers, body: rawBody })
  const res = await worker.fetch(req, env)
  assert.equal(res.status, 200)
  assert.equal(kv.putCalls.length, putCountBefore, "重複配信ではKVへの書き込みが発生しない")
  ok("重複配信 → 200、再発行なし(KV書き込みなし)")
}

// --- 4. GET /license?checkout_id=... でキーが表示される ---
{
  const req = new Request(`https://worker.example/license?checkout_id=${CHECKOUT_ID}`)
  const res = await worker.fetch(req, env)
  assert.equal(res.status, 200)
  const text = await res.text()
  const record = await kv.get(`checkout:${CHECKOUT_ID}`, "json")
  assert.ok(text.includes(record.key), "レスポンスHTMLにライセンスキーが含まれる")
  ok("GET /license?checkout_id=... がキーを表示する")
}

console.log(`\n${passed}件のテストに合格`)
