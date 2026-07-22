import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { CornerDownLeft } from "lucide-react"
import { useEffect, useState } from "react"

const NEWLINE = "#0f7b6c"
const SEND = "#2383e2"
const LINE1 = "今日の件ですが、"
const LINE2 = "資料を添付しました。ご確認ください。"

/* 入力→Enter(改行 or 誤送信)→⌘Enter(送信)を無限ループするデモの状態機械 */
function useChatDemo(sendOnEnter: boolean) {
  const [input, setInput] = useState("")
  const [sent, setSent] = useState<string[]>([])
  const [pressed, setPressed] = useState<"" | "enter" | "cmd">("")

  useEffect(() => {
    let alive = true
    const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))
    ;(async () => {
      await sleep(800)
      while (alive) {
        setSent([])
        setInput("")
        for (let i = 1; i <= LINE1.length; i++) {
          if (!alive) return
          setInput(LINE1.slice(0, i))
          await sleep(80)
        }
        await sleep(400)
        setPressed("enter")
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
        for (let i = 1; i <= LINE2.length; i++) {
          if (!alive) return
          setInput(LINE1 + "\n" + LINE2.slice(0, i))
          await sleep(65)
        }
        await sleep(500)
        setPressed("cmd")
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

  return { input, sent, pressed }
}

function MiniKey({ label, active }: { label: string; active: boolean }) {
  return (
    <span
      className={`inline-flex min-w-9 items-center justify-center rounded-md border px-2 py-1 text-xs font-semibold transition-all duration-150 ${
        active
          ? "translate-y-0.5 border-[#2383e2] bg-[#e7f0fb] shadow-none"
          : "border-[#d9d9d6] bg-[#fbfbfa] shadow-[0_2px_0_#e0e0dd]"
      }`}
    >
      {label}
    </span>
  )
}

function SentBubble({ text, oops }: { text: string; oops?: boolean }) {
  return (
    <div className="flex justify-end">
      <div
        className="max-w-[85%] rounded-2xl rounded-br-sm px-4 py-2 text-left text-sm whitespace-pre-line text-white"
        style={{ backgroundColor: oops ? "#d44c47" : SEND }}
      >
        {text}
        {oops && <span className="mt-1 block text-[11px] opacity-80">← 途中で送信されてしまった…</span>}
      </div>
    </div>
  )
}

function InputMock({ input, compact }: { input: string; compact?: boolean }) {
  return (
    <div
      className={`rounded-lg border bg-background px-3 text-left text-sm whitespace-pre-line ${
        compact ? "min-h-14 py-2" : "min-h-16 py-2.5"
      }`}
    >
      {input}
      <span className="ml-0.5 inline-block h-4 w-px animate-pulse bg-foreground align-middle" />
    </div>
  )
}

function KeyLegend({ pressed }: { pressed: "" | "enter" | "cmd" }) {
  return (
    <div className="mt-3 flex items-center justify-center gap-5 text-xs text-muted-foreground">
      <span className="flex items-center gap-1.5">
        <MiniKey label="Enter" active={pressed === "enter"} />
        <span style={{ color: pressed === "enter" ? NEWLINE : undefined }}>改行</span>
      </span>
      <span className="flex items-center gap-1.5">
        <MiniKey label="⌘" active={pressed === "cmd"} />
        <MiniKey label="Enter" active={pressed === "cmd"} />
        <span style={{ color: pressed === "cmd" ? SEND : undefined }}>送信</span>
      </span>
    </div>
  )
}

/* 案A: ミニマルな自動タイピングデモ */
function VariantA() {
  const { input, sent, pressed } = useChatDemo(false)
  return (
    <div className="mx-auto max-w-md rounded-xl border bg-muted p-5">
      <div className="mb-3 h-24 space-y-2 overflow-hidden">
        {sent.map((m) => (
          <SentBubble key={m} text={m} />
        ))}
      </div>
      <InputMock input={input} />
      <KeyLegend pressed={pressed} />
    </div>
  )
}

/* 案B: 実機風チャットウィンドウ(汎用UI)内での同デモ */
function VariantB() {
  const { input, sent, pressed } = useChatDemo(false)
  return (
    <div className="mx-auto max-w-lg overflow-hidden rounded-xl border bg-card text-left shadow-sm">
      <div className="flex items-center gap-1.5 border-b bg-muted px-4 py-2.5">
        <span className="size-2.5 rounded-full bg-[#ff5f57]" />
        <span className="size-2.5 rounded-full bg-[#febc2e]" />
        <span className="size-2.5 rounded-full bg-[#28c840]" />
        <span className="ml-2 text-xs text-muted-foreground"># プロジェクトA</span>
      </div>
      <div className="space-y-3 px-4 pt-4">
        <div className="flex items-start gap-2">
          <span className="mt-0.5 size-6 shrink-0 rounded-full bg-[#d9c9b8]" />
          <div className="rounded-2xl rounded-tl-sm bg-muted px-3 py-2 text-sm">
            例の資料、今日中にもらえそう?
          </div>
        </div>
        <div className="h-20 space-y-2 overflow-hidden">
          {sent.map((m) => (
            <SentBubble key={m} text={m} />
          ))}
        </div>
      </div>
      <div className="px-4 pb-4">
        <InputMock input={input} compact />
        <KeyLegend pressed={pressed} />
      </div>
    </div>
  )
}

/* 案C: 3Dキー押下アニメ */
function BigKey({ label, active, wide }: { label: string; active: boolean; wide?: boolean }) {
  return (
    <span
      className={`inline-flex items-center justify-center rounded-2xl border-2 text-2xl font-semibold transition-all duration-150 ${
        wide ? "min-w-32 px-8" : "min-w-20 px-5"
      } h-20 ${
        active
          ? "translate-y-1.5 border-[#2383e2] bg-[#e7f0fb] shadow-[0_1px_0_#c9ddf5]"
          : "border-[#d9d9d6] bg-[#fbfbfa] shadow-[0_6px_0_#e0e0dd]"
      }`}
    >
      {label}
    </span>
  )
}

function VariantC() {
  const [phase, setPhase] = useState<"" | "enter" | "cmd">("")
  const [label, setLabel] = useState<"" | "newline" | "send">("")
  useEffect(() => {
    let alive = true
    const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))
    ;(async () => {
      while (alive) {
        await sleep(1200)
        if (!alive) return
        setPhase("enter")
        setLabel("newline")
        await sleep(500)
        setPhase("")
        await sleep(1400)
        setLabel("")
        if (!alive) return
        setPhase("cmd")
        setLabel("send")
        await sleep(500)
        setPhase("")
        await sleep(1400)
        setLabel("")
      }
    })()
    return () => {
      alive = false
    }
  }, [])
  return (
    <div className="mx-auto max-w-md rounded-xl border bg-muted px-5 py-10 text-center">
      <div className="flex items-center justify-center gap-3">
        <BigKey label="⌘" active={phase === "cmd"} />
        <BigKey label="Enter" active={phase === "enter" || phase === "cmd"} wide />
      </div>
      <div className="mt-6 h-8 text-xl font-bold">
        {label === "newline" && <span style={{ color: NEWLINE }}>↵ 改行</span>}
        {label === "send" && <span style={{ color: SEND }}>✈ 送信</span>}
      </div>
    </div>
  )
}

/* 案D: Before / After 対比 */
function VariantD() {
  const before = useChatDemo(true)
  const after = useChatDemo(false)
  return (
    <div className="mx-auto grid max-w-2xl gap-4 sm:grid-cols-2">
      <div className="rounded-xl border bg-muted p-4">
        <p className="mb-3 text-center text-xs font-semibold text-[#d44c47]">UniEnterなし</p>
        <div className="mb-2 h-20 space-y-2 overflow-hidden">
          {before.sent.map((m) => (
            <SentBubble key={m} text={m} oops />
          ))}
        </div>
        <InputMock input={before.input} compact />
        <KeyLegend pressed={before.pressed} />
      </div>
      <div className="rounded-xl border bg-background p-4 shadow-sm">
        <p className="mb-3 text-center text-xs font-semibold" style={{ color: NEWLINE }}>
          UniEnterあり
        </p>
        <div className="mb-2 h-20 space-y-2 overflow-hidden">
          {after.sent.map((m) => (
            <SentBubble key={m} text={m} />
          ))}
        </div>
        <InputMock input={after.input} compact />
        <KeyLegend pressed={after.pressed} />
      </div>
    </div>
  )
}

const variants = [
  { id: "A", title: "自動タイピングデモ(ミニマル)", note: "現ヒーローの枠にそのまま収まる", component: VariantA },
  { id: "B", title: "実機風チャットウィンドウ", note: "利用シーンごと見せる。情報量多め", component: VariantB },
  { id: "C", title: "3Dキー押下アニメ", note: "最小の要素で象徴的に", component: VariantC },
  { id: "D", title: "Before / After 対比", note: "課題→解決が一目。横幅を取る", component: VariantD },
]

export default function HeroLab() {
  return (
    <div className="min-h-screen">
      <nav className="mx-auto flex max-w-5xl items-center justify-between px-6 py-5">
        <a href="./" className="flex items-center gap-2 font-semibold">
          <CornerDownLeft className="size-4" /> UniEnter
        </a>
        <Button variant="outline" size="sm" asChild>
          <a href="./">トップへ戻る</a>
        </Button>
      </nav>
      <main className="mx-auto max-w-4xl px-6 py-10">
        <h1 className="text-center text-2xl font-bold">ヒーロービジュアル比較ラボ</h1>
        <p className="mt-2 mb-12 text-center text-sm text-muted-foreground">
          社内確認用のページです(本番からはリンクされていません)
        </p>
        <div className="space-y-16">
          {variants.map(({ id, title, note, component: Component }) => (
            <section key={id}>
              <div className="mb-5 text-center">
                <Badge variant="secondary" className="mb-2">案{id}</Badge>
                <h2 className="text-lg font-bold">{title}</h2>
                <p className="text-xs text-muted-foreground">{note}</p>
              </div>
              <Component />
            </section>
          ))}
        </div>
      </main>
    </div>
  )
}
