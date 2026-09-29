// SNS用紹介動画のレンダラ。site/promo.html を1コマずつ撮って ffmpeg で mp4 にする。
// 使い方:
//   (1) cd site && npx vite --port 5188        # dev server を起動(promo.html はビルド対象外)
//   (2) cd marketing/sns && npm i --no-save puppeteer-core && node render-video.mjs [story|square]
// 出力: marketing/sns/video/unienter-{story,square}.mp4(30fps・H.264・無音)
import { execFileSync } from "node:child_process"
import { mkdirSync, rmSync } from "node:fs"
import path from "node:path"
import puppeteer from "puppeteer-core"

const BASE = process.env.PROMO_URL ?? "http://localhost:5188/promo.html"
const FPS = 30
const formats = process.argv[2] ? [process.argv[2]] : ["story", "square"]
const SIZE = { story: [540, 960], square: [540, 540] } // CSS px。deviceScaleFactor 2 で 1080 幅になる
const here = path.dirname(new URL(import.meta.url).pathname)

const browser = await puppeteer.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  headless: true,
  args: ["--hide-scrollbars", "--font-render-hinting=none"],
})
for (const fmt of formats) {
  const [w, h] = SIZE[fmt]
  const page = await browser.newPage()
  await page.setViewport({ width: w, height: h, deviceScaleFactor: 2 })
  await page.goto(`${BASE}?format=${fmt}`, { waitUntil: "networkidle0" })
  await page.waitForFunction("window.__ready === true")
  await page.evaluate(() => document.fonts.ready)
  const duration = await page.evaluate("window.__duration")
  const dir = path.join(here, "video", `frames-${fmt}`)
  rmSync(dir, { recursive: true, force: true })
  mkdirSync(dir, { recursive: true })
  const total = Math.round(duration * FPS)
  for (let i = 0; i < total; i++) {
    await page.evaluate((t) => {
      window.__setT(t)
      return new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)))
    }, i / FPS)
    await page.screenshot({ path: path.join(dir, `${String(i).padStart(5, "0")}.png`), clip: { x: 0, y: 0, width: w, height: h } })
    if (i % 60 === 0) process.stdout.write(`${fmt} ${i}/${total}\n`)
  }
  await page.close()
  const out = path.join(here, "video", `unienter-${fmt}.mp4`)
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-framerate", String(FPS), "-i", path.join(dir, "%05d.png"),
    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "slow", "-movflags", "+faststart", out])
  rmSync(dir, { recursive: true, force: true })
  console.log("wrote", out)
}
await browser.close()
