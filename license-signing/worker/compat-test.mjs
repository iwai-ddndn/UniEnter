// Workerと同じJWK+WebCrypto署名が、アプリ埋め込みの公開鍵で検証できるかの互換テスト
// 実行: node compat-test.mjs(../keys.txt が必要)
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const PUBLIC_KEY_B64 = "GnuD4CdMgZHXooBnItp7HxOZUQD7Ai/fURl0oqidhXk=" // LicenseManager.publicKeyBase64

const keysTxt = readFileSync(join(dirname(fileURLToPath(import.meta.url)), "..", "keys.txt"), "utf8")
const privateB64 = keysTxt.split("\n").find((l) => l.startsWith("PRIVATE:")).slice("PRIVATE:".length).trim()

const b64ToB64url = (b64) => b64.replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "")
const bytesToB64url = (bytes) => Buffer.from(bytes).toString("base64url")
const b64urlToBytes = (s) => new Uint8Array(Buffer.from(s, "base64url"))

// --- Workerと同じ署名処理 ---
const jwk = { kty: "OKP", crv: "Ed25519", d: b64ToB64url(privateB64), x: b64ToB64url(PUBLIC_KEY_B64) }
const signKey = await crypto.subtle.importKey("jwk", jwk, { name: "Ed25519" }, false, ["sign"])
const payload = `{"email":"compat-test@example.com","iat":${Math.floor(Date.now() / 1000)}}`
const payloadBytes = new TextEncoder().encode(payload)
const sig = new Uint8Array(await crypto.subtle.sign("Ed25519", signKey, payloadBytes))
const licenseKey = `UNIENTER-${bytesToB64url(payloadBytes)}.${bytesToB64url(sig)}`
console.log("生成キー:", licenseKey)

// --- アプリ(LicenseManager.verify)相当の検証 ---
const verifyKey = await crypto.subtle.importKey(
  "raw", b64urlToBytes(b64ToB64url(PUBLIC_KEY_B64)), { name: "Ed25519" }, false, ["verify"],
)
const body = licenseKey.slice("UNIENTER-".length)
const [p, s] = body.split(".")
const ok = await crypto.subtle.verify("Ed25519", verifyKey, b64urlToBytes(s), b64urlToBytes(p))
const parsed = JSON.parse(Buffer.from(p, "base64url").toString("utf8"))
console.log("公開鍵での検証:", ok ? "OK" : "NG", "/ email:", parsed.email)
if (!ok || parsed.email !== "compat-test@example.com") process.exit(1)
