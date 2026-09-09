import { useEffect, useState } from "react"

/* ヒーロー本組み用: 3アプリ同期デモ + キー押下(hero-labの案E) */

/* 「改行」はキーカラーのティール。「送信」は本文色の墨で、対の弁別は⌘キーの有無が担う */
const NEWLINE = "#0f7b6c"
const SEND = "#37352f"
const LINE1 = "今日の件ですが、"
const LINE2 = "資料を添付しました。ご確認ください。"

/* 入力→Enter(改行 or 誤送信)→⌘Enter(送信)を無限ループするデモの状態機械 */
export function useChatDemo(sendOnEnter: boolean) {
  const [input, setInput] = useState("")
  const [sent, setSent] = useState<string[]>([])
  const [pressed, setPressed] = useState<"" | "enter" | "cmd">("")
  const [action, setAction] = useState<"" | "newline" | "send">("")

  useEffect(() => {
    let alive = true
    const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))
    ;(async () => {
      await sleep(800)
      while (alive) {
        setSent([])
        setInput("")
        setAction("")
        for (let i = 1; i <= LINE1.length; i++) {
          if (!alive) return
          setInput(LINE1.slice(0, i))
          await sleep(80)
        }
        await sleep(400)
        setPressed("enter")
        setAction("newline")
        await sleep(450)
        setPressed("")
        if (sendOnEnter) {
          // UniEnterなし: 改行のつもりが途中で送信されてしまう
          setSent([LINE1])
          setInput("")
          await sleep(3400)
          continue
        }
        setInput(LINE1 + "\n")
        await sleep(300)
        setAction("")
        for (let i = 1; i <= LINE2.length; i++) {
          if (!alive) return
          setInput(LINE1 + "\n" + LINE2.slice(0, i))
          await sleep(65)
        }
        await sleep(500)
        setPressed("cmd")
        setAction("send")
        await sleep(450)
        setPressed("")
        setSent([LINE1 + "\n" + LINE2])
        setInput("")
        await sleep(3400)
      }
    })()
    return () => {
      alive = false
    }
  }, [sendOnEnter])

  return { input, sent, pressed, action }
}

export type Demo = ReturnType<typeof useChatDemo>

export function BigKey({ label, active, wide }: { label: string; active: boolean; wide?: boolean }) {
  return (
    <span
      className={`inline-flex items-center justify-center rounded-2xl border-2 text-xl font-semibold transition-all duration-150 sm:text-2xl ${
        wide ? "min-w-28 px-6 sm:min-w-32 sm:px-8" : "min-w-16 px-4 sm:min-w-20 sm:px-5"
      } h-16 sm:h-20 ${
        active
          ? "translate-y-1.5 border-[#0f7b6c] bg-[#e8f3f0] shadow-[0_1px_0_#c3ded7]"
          : "border-[#d9d9d6] bg-[#fbfbfa] shadow-[0_6px_0_#e0e0dd]"
      }`}
    >
      {label}
    </span>
  )
}

function Caret({ light }: { light?: boolean }) {
  return (
    <span
      className={`ml-0.5 inline-block h-3 w-px animate-pulse align-middle ${
        light ? "bg-white" : "bg-foreground"
      }`}
    />
  )
}

/* Slack風: ライト・スレッド型(フラットな行 + アバター + 名前) */
function MiniSlack({ demo }: { demo: Demo }) {
  return (
    <div className="flex aspect-[4/5] flex-col overflow-hidden rounded-lg border bg-white text-left shadow-sm">
      <div className="flex h-7 shrink-0 items-center gap-1.5 border-b px-3" style={{ backgroundColor: "#4A154B" }}>
        <span className="text-[11px] font-semibold text-white"># 進行中プロジェクト</span>
      </div>
      <div className="flex min-h-0 flex-1 flex-col p-2.5">
        <div className="flex min-h-0 flex-1 flex-col gap-2 overflow-hidden">
          <div className="flex items-start gap-1.5">
            <span className="mt-0.5 size-5 shrink-0 rounded bg-[#e0b64f]" />
            <div className="min-w-0">
              <p className="text-[11px] leading-tight font-bold">田中</p>
              <p className="text-[11px]">例の資料、今日もらえそう?</p>
            </div>
          </div>
          {demo.sent.map((m) => (
            <div key={m} className="flex items-start gap-1.5">
              <span className="mt-0.5 size-5 shrink-0 rounded bg-[#7fb4a2]" />
              <div className="min-w-0">
                <p className="text-[11px] leading-tight font-bold">あなた</p>
                <p className="text-[11px] whitespace-pre-line">{m}</p>
              </div>
            </div>
          ))}
        </div>
        <div className="mt-2 h-16 shrink-0 overflow-hidden rounded-md border-2 border-[#0f7b6c]/35 px-2 py-1.5 text-[11px] whitespace-pre-line">
          {demo.input}
          <Caret />
        </div>
      </div>
    </div>
  )
}

/* Discord風: ダークモード・フラットなメッセージリスト */
function MiniDiscord({ demo }: { demo: Demo }) {
  return (
    <div className="hidden aspect-[4/5] flex-col overflow-hidden rounded-lg border border-[#26282c] bg-[#313338] text-left text-white shadow-sm sm:flex">
      <div className="flex h-7 shrink-0 items-center gap-1.5 border-b border-[#26282c] bg-[#2b2d31] px-3">
        <span className="text-[13px] leading-none text-[#80848e]">#</span>
        <span className="truncate text-[11px] font-semibold text-neutral-200">開発</span>
      </div>
      <div className="flex min-h-0 flex-1 flex-col p-2.5">
        <div className="flex min-h-0 flex-1 flex-col gap-2 overflow-hidden">
          <div className="flex items-start gap-1.5">
            <span className="mt-0.5 size-5 shrink-0 rounded-full bg-[#5865F2]" />
            <div className="min-w-0">
              <p className="text-[11px] leading-tight font-semibold text-[#f0b232]">ken</p>
              <p className="text-[11px] text-neutral-200">例の資料、今日もらえそう?</p>
            </div>
          </div>
          {demo.sent.map((m) => (
            <div key={m} className="flex items-start gap-1.5">
              <span className="mt-0.5 size-5 shrink-0 rounded-full bg-[#57F287]" />
              <div className="min-w-0">
                <p className="text-[11px] leading-tight font-semibold text-[#6fb3e0]">あなた</p>
                <p className="text-[11px] whitespace-pre-line text-neutral-200">{m}</p>
              </div>
            </div>
          ))}
        </div>
        <div className="mt-2 h-16 shrink-0 overflow-hidden rounded-lg border-2 border-[#0f7b6c]/45 bg-[#383a40] px-2 py-1.5 text-[11px] whitespace-pre-line text-neutral-100">
          {demo.input}
          <Caret light />
        </div>
      </div>
    </div>
  )
}

/* LINE風: 吹き出し型・青グレー背景に緑バブル */
function MiniLine({ demo }: { demo: Demo }) {
  return (
    <div className="flex aspect-[4/5] flex-col overflow-hidden rounded-lg border text-left shadow-sm">
      <div className="flex h-7 shrink-0 items-center gap-1.5 border-b bg-white px-3">
        <span
          className="flex size-4 shrink-0 items-center justify-center rounded"
          style={{ backgroundColor: "#06C755" }}
        >
          <span className="text-[9px] leading-none font-bold text-white">L</span>
        </span>
        <span className="truncate text-[11px] text-muted-foreground">ゆうこ</span>
      </div>
      <div className="flex min-h-0 flex-1 flex-col bg-[#dce4f0] p-2.5">
        <div className="flex min-h-0 flex-1 flex-col gap-2 overflow-hidden">
          <div className="flex items-start gap-1">
            <span className="size-5 shrink-0 rounded-full bg-[#c9a2d8]" />
            <div className="max-w-[85%] rounded-xl rounded-tl-sm bg-white px-2.5 py-1.5 text-[11px]">
              例の資料、今日もらえそう?
            </div>
          </div>
          {demo.sent.map((m) => (
            <div key={m} className="flex justify-end">
              <div
                className="max-w-[85%] rounded-xl rounded-br-sm px-2.5 py-1.5 text-[11px] whitespace-pre-line text-white"
                style={{ backgroundColor: "#06C755" }}
              >
                {m}
              </div>
            </div>
          ))}
        </div>
        <div className="mt-2 h-16 shrink-0 overflow-hidden rounded-2xl border-2 border-[#0f7b6c]/35 bg-white px-3 py-1.5 text-[11px] whitespace-pre-line">
          {demo.input}
          <Caret />
        </div>
      </div>
    </div>
  )
}

/* 3アプリ同期デモ + キー押下。モバイルではSlack風+LINE風の2窓表示 */
export default function HeroDemo() {
  const demo = useChatDemo(false)
  return (
    <div className="mx-auto max-w-3xl rounded-xl border bg-muted p-4 sm:p-5">
      <div className="mx-auto grid w-full max-w-sm grid-cols-2 gap-3 sm:max-w-none sm:grid-cols-3">
        <MiniSlack demo={demo} />
        <MiniDiscord demo={demo} />
        <MiniLine demo={demo} />
      </div>
      {/* 狭い画面ではキーを中央に置き、結果ラベルはその下へ。
          sm以上は右のラベルと同幅のスペーサーでキー列を正確に中央へ */}
      <div className="mt-5 flex flex-col items-center gap-2 sm:mt-6 sm:flex-row sm:justify-center sm:gap-3">
        <div className="mr-2 hidden w-24 shrink-0 sm:block" aria-hidden />
        <div className="flex items-center gap-3">
          <BigKey label="⌘" active={demo.pressed === "cmd"} />
          <BigKey label="Enter" active={demo.pressed === "enter" || demo.pressed === "cmd"} wide />
        </div>
        <div className="ml-0 h-7 shrink-0 text-lg font-bold sm:ml-2 sm:h-auto sm:w-24 sm:text-left sm:text-xl">
          {demo.action === "newline" && <span style={{ color: NEWLINE }}>↵ 改行</span>}
          {demo.action === "send" && <span style={{ color: SEND }}>✈ 送信</span>}
        </div>
      </div>
      <p className="mt-3 text-center text-sm text-muted-foreground">
        ⌘ は Command キーです。
      </p>
    </div>
  )
}
