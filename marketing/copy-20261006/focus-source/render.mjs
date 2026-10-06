// Headless Chrome driver (no deps): Node built-in WebSocket + DevTools Protocol.
//   node focus/render.mjs stills 0.95 1.8 6.3 8.7      → output/keyframes/kf_<t>.png
//   node focus/render.mjs frames [from] [to]           → output/preview_frames/f_00000.jpg …
//   node focus/render.mjs final  [from] [to]           → output/final_frames/f_00000.png …
import { spawn } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = here; // focus/: outputs go to focus/output, profile to focus/.cache
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PORT = 9349;
const profile = join(root, ".cache", "chrome-profile");
mkdirSync(profile, { recursive: true });

const chrome = spawn(CHROME, [
  "--headless=new",
  `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`,
  "--no-first-run",
  "--no-default-browser-check",
  "--hide-scrollbars",
  "--window-size=1080,1920",
  "--ignore-gpu-blocklist",
  "--enable-gpu",
  "--use-angle=metal",
  "about:blank",
], { stdio: ["ignore", "ignore", "pipe"] });
chrome.stderr.on("data", () => {});

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function json(path, method = "GET") {
  for (let i = 0; i < 100; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}${path}`, { method });
      if (r.ok) return await r.json();
    } catch {}
    await sleep(100);
  }
  throw new Error("chrome devtools not reachable");
}

let ws, seq = 0;
const pending = new Map();
function send(method, params = {}) {
  const id = ++seq;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((res, rej) => pending.set(id, { res, rej }));
}
async function evaluate(expr) {
  const r = await send("Runtime.evaluate", { expression: expr, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails, null, 1).slice(0, 3000));
  return r.result.value;
}

async function main() {
  await json("/json/version");
  const url = pathToFileURL(join(here, "index.html")).href;
  const tgt = await json(`/json/new?${encodeURI(url)}`, "PUT");
  ws = new WebSocket(tgt.webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener("open", r, { once: true }));
  ws.addEventListener("message", (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pending.has(m.id)) {
      const p = pending.get(m.id);
      pending.delete(m.id);
      m.error ? p.rej(new Error(m.error.message)) : p.res(m.result);
    } else if (m.method === "Runtime.consoleAPICalled") {
      console.log("[page]", m.params.args.map((a) => a.value ?? a.description).join(" "));
    } else if (m.method === "Runtime.exceptionThrown") {
      console.log("[page exception]", m.params.exceptionDetails.exception?.description ?? m.params.exceptionDetails.text);
    }
  });
  await send("Runtime.enable");
  for (let i = 0; i < 50; i++) {
    if (await evaluate("document.readyState === 'complete' && typeof window.__init === 'function'")) break;
    await sleep(100);
  }
  const info = await evaluate("window.__init().then(r => JSON.stringify(r))");
  console.log("init", info);
  const { duration, fps } = JSON.parse(info);

  const [mode, ...args] = process.argv.slice(2);
  const save = async (t, file) => {
    const t0 = Date.now();
    const r = await evaluate(`window.__render(${t}).then(r => JSON.stringify(r))`);
    const data = await evaluate(file.endsWith(".jpg") ? "window.__grab('image/jpeg')" : "window.__grab()");
    writeFileSync(file, Buffer.from(data.split(",")[1], "base64"));
    console.log(file.replace(root + "/", ""), `t=${t}`, r, `${Date.now() - t0}ms`);
  };

  if (mode === "stills") {
    const dir = join(root, "output", "keyframes");
    mkdirSync(dir, { recursive: true });
    for (const a of args) await save(parseFloat(a), join(dir, `kf_${parseFloat(a).toFixed(2)}.png`));
  } else if (mode === "frames" || mode === "final") {
    const dir = join(root, "output", mode === "final" ? "final_frames" : "preview_frames");
    const ext = mode === "final" ? "png" : "jpg";
    mkdirSync(dir, { recursive: true });
    const total = Math.round(duration * fps);
    const from = args[0] ? parseInt(args[0]) : 0;
    const to = args[1] ? parseInt(args[1]) : total - 1;
    for (let f = from; f <= to; f++) await save(f / fps, join(dir, `f_${String(f).padStart(5, "0")}.${ext}`));
  } else {
    console.log("usage: render.mjs stills <t...> | frames [from] [to] (jpg preview) | final [from] [to] (png)");
  }
}

main()
  .catch((e) => { console.error(e.message ?? e); process.exitCode = 1; })
  .finally(() => { try { ws?.close(); } catch {} chrome.kill(); });
