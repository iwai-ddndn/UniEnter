// SNS用静止画のレンダラ。site/sns-assets.html?a=<名前> を2倍解像度で撮る。
// 使い方: site の dev server(5188)を起動した状態で  node render-assets.mjs
// 出力: marketing/sns/assets/<名前>.png
import { mkdirSync } from "node:fs"
import path from "node:path"
import puppeteer from "puppeteer-core"

const BASE = process.env.ASSETS_URL ?? "http://localhost:5188/sns-assets.html"
// CSS px(撮影は deviceScaleFactor 2)。site/src/promo/Assets.tsx の ASSETS と揃える
const ASSETS = {
  "profile-icon": [540, 540],
  "x-header": [750, 250],
  "x-post-main": [800, 450],
  "x-post-rule": [800, 450],
  "x-post-safety": [800, 450],
  "ig-01-hook": [540, 675],
  "ig-02-before": [540, 675],
  "ig-03-rule": [540, 675],
  "ig-04-apps": [540, 675],
  "ig-05-safety": [540, 675],
  "ig-06-cta": [540, 675],
  "reel-cover": [540, 960],
}
const out = path.join(path.dirname(new URL(import.meta.url).pathname), "assets")
mkdirSync(out, { recursive: true })
const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: true })
for (const [name, [w, h]] of Object.entries(ASSETS)) {
  const page = await browser.newPage()
  await page.setViewport({ width: w, height: h, deviceScaleFactor: 2 })
  await page.goto(`${BASE}?a=${name}`, { waitUntil: "networkidle0" })
  await page.waitForFunction("window.__ready === true")
  await page.evaluate(() => document.fonts.ready)
  await page.screenshot({ path: path.join(out, `${name}.png`), clip: { x: 0, y: 0, width: w, height: h } })
  await page.close()
  console.log("wrote", name)
}
await browser.close()
