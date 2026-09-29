import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion"
import {
  ArrowDown,
  ArrowRight,
  ArrowUp,
  Check,
  ChevronDown,
  Code,
  CornerDownLeft,
  Download,
  Keyboard,
  Hash,
  Languages,
  MessageSquare,
  Plus,
  Sparkles,
  WifiOff,
} from "lucide-react"
import {
  type CSSProperties,
  type ReactNode,
  useCallback,
  useEffect,
  useRef,
  useState,
} from "react"
import { observeSections, track } from "@/lib/analytics"
import { type Service, services } from "./brands"
import { REPO_URL, RELEASES_URL, faqGroups } from "./faq"
import "./landing.css"

/*
 * UniEnter LP。見せ方の骨格:
 *   - ヒーローは「実際に打てる」デモ(チャット → AIエージェントを自動で切替)+ 押し込めるキーキャップ
 *   - Before/After はスクロールに張り付く5場面。説明文が主役、デモは従
 *   - 対応サービスは流れるマーキー、安心は夜のセクションで「壁で止まる文字」
 * キーカラーはティール1色(CTA・改行・番号チップ・フォーカスのみ)。
 */

const PKG_URL = "https://github.com/iwai-ddndn/UniEnter/releases/latest/download/UniEnter.pkg"
/* Polarのチェックアウトリンク(販売者=Polar。購入後は Worker のキー表示ページへ戻る) */
const CHECKOUT_URL = "https://buy.polar.sh/polar_cl_zdFJOA7iIWaUzPThWsIjQKyRW0pImM8vfTuhn1sIQLk"
const ZIP_URL = "https://github.com/iwai-ddndn/UniEnter/releases/latest/download/UniEnter.zip"

const vars = (v: Record<string, string | number>) => v as CSSProperties
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))
const clamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n))
const prefersReducedMotion = () =>
  typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches

/* ─────────────────────────── hooks ─────────────────────────── */

function useInView<T extends Element>(threshold = 0.2, once = true) {
  const ref = useRef<T>(null)
  const [inView, setInView] = useState(false)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true)
          if (once) io.disconnect()
        } else if (!once) {
          setInView(false)
        }
      },
      { threshold },
    )
    io.observe(el)
    return () => io.disconnect()
  }, [threshold, once])
  return [ref, inView] as const
}

/** 要素がビューポートを通過する割合(0→1)。sticky な長いセクションの進行度に使う */
function useScrollProgress<T extends HTMLElement>(mode: "pin" | "pass" = "pin") {
  const ref = useRef<T>(null)
  const [progress, setProgress] = useState(0)
  useEffect(() => {
    let raf = 0
    const update = () => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        const el = ref.current
        if (!el) return
        const r = el.getBoundingClientRect()
        const vh = window.innerHeight
        if (mode === "pin") {
          const total = r.height - vh
          setProgress(total > 0 ? clamp(-r.top / total) : r.top < 0 ? 1 : 0)
        } else {
          setProgress(clamp((vh * 0.75 - r.top) / r.height))
        }
      })
    }
    update()
    window.addEventListener("scroll", update, { passive: true })
    window.addEventListener("resize", update)
    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener("scroll", update)
      window.removeEventListener("resize", update)
    }
  }, [mode])
  return [ref, progress] as const
}

function Reveal({
  children,
  delay = 0,
  className = "",
}: {
  children: ReactNode
  delay?: number
  className?: string
}) {
  const [ref, inView] = useInView<HTMLDivElement>(0.15)
  return (
    <div ref={ref} className={`rv ${inView ? "in" : ""} ${className}`} style={vars({ "--d": `${delay}ms` })}>
      {children}
    </div>
  )
}

/* 見出しを1文字ずつ立ち上げる。本文としては1回だけ出す(検索エンジン・読み上げ用に複製しない) */
function SplitText({ text, base = 0 }: { text: string; base?: number }) {
  return (
    <>
      {[...text].map((c, i) => (
        <span key={i} className="ch" style={vars({ "--i": i, "--base": `${base}ms` })}>
          {c}
        </span>
      ))}
    </>
  )
}

/* ─────────────────────────── 部品 ─────────────────────────── */

function PrimaryCTA({ location, label = "14日間、無料で試す" }: { location: string; label?: string }) {
  return (
    <a
      href={PKG_URL}
      onClick={() => track("download_click", { file_type: "pkg", location })}
      className="group inline-flex h-13 items-center gap-2.5 rounded-full bg-[var(--teal)] pr-2 pl-6 text-[15px] font-bold text-white shadow-[0_10px_30px_-10px_rgba(15,123,108,0.6)] transition-all duration-300 hover:-translate-y-0.5 hover:shadow-[0_16px_36px_-12px_rgba(15,123,108,0.7)] focus-visible:ring-4 focus-visible:ring-[var(--teal)]/30 focus-visible:outline-none"
    >
      {label}
      <span className="flex size-9 items-center justify-center overflow-hidden rounded-full bg-white/15">
        <Download className="size-4 transition-transform duration-300 group-hover:translate-y-0.5" />
      </span>
    </a>
  )
}

function GhostCTA({ href, children }: { href: string; children: ReactNode }) {
  return (
    <a
      href={href}
      className="group inline-flex h-13 items-center gap-2 rounded-full border border-[var(--ink)]/15 bg-white/60 px-6 text-[15px] font-semibold backdrop-blur transition-colors hover:border-[var(--ink)]/40"
    >
      {children}
      <ArrowRight className="size-4 transition-transform duration-300 group-hover:translate-x-1" />
    </a>
  )
}

function Key({
  children,
  down,
  teal,
  className = "",
  style,
}: {
  children: ReactNode
  down?: boolean
  teal?: boolean
  className?: string
  style?: CSSProperties
}) {
  return (
    <span className={`kc ${down ? "down" : ""} ${teal ? "teal" : ""} ${className}`} style={style}>
      {children}
    </span>
  )
}

function LogoGlyph({ service, className }: { service: Service; className: string }) {
  return service.path ? (
    <svg viewBox={service.viewBox ?? "0 0 24 24"} className={`${className} fill-white`} aria-hidden>
      <path d={service.path} />
    </svg>
  ) : (
    <span className="text-base leading-none font-bold text-white">{service.initial}</span>
  )
}

function LogoSquare({ service, size = "size-10", glyph = "size-5", className = "" }: { service: Service; size?: string; glyph?: string; className?: string }) {
  return (
    <span
      className={`flex shrink-0 items-center justify-center rounded-[28%] ${size} ${className}`}
      style={{ backgroundColor: `#${service.hex}` }}
    >
      <LogoGlyph service={service} className={glyph} />
    </span>
  )
}

function Eyebrow({ children, dark }: { children: ReactNode; dark?: boolean }) {
  return (
    <p
      className={`mb-4 inline-flex items-center gap-2 text-xs font-semibold tracking-[0.2em] ${dark ? "text-white/55" : "text-[var(--ink-3)]"}`}
    >
      <span className={`h-px w-6 ${dark ? "bg-white/30" : "bg-[var(--ink)]/25"}`} />
      {children}
    </p>
  )
}

/* ─────────────────────── ヒーロー: チャット → AIエージェントの打てるデモ ─────────────────────── */

type AppKind = "chat" | "agent"
type Msg = { id: number; text: string; role: "me" | "other" | "ai" }
type Step =
  | { t: "type"; s: string }
  | { t: "enter" }
  | { t: "send" }
  | { t: "reply"; s: string }
  | { t: "think"; ms: number }
  | { t: "stream"; s: string }
  | { t: "wait"; ms: number }

const INITIAL_MSGS: Record<AppKind, Msg[]> = {
  chat: [{ id: 0, text: "来週の定例、日程どうしましょう?", role: "other" }],
  agent: [],
}

const SCRIPTS: Record<AppKind, Step[]> = {
  chat: [
    { t: "wait", ms: 900 },
    { t: "type", s: "明日の打ち合わせ、" },
    { t: "enter" },
    { t: "type", s: "15時からに変更できますか?" },
    { t: "enter" },
    { t: "type", s: "資料は前日にお送りします。" },
    { t: "wait", ms: 700 },
    { t: "send" },
    { t: "wait", ms: 1000 },
    { t: "reply", s: "大丈夫です!15時で押さえますね。" },
    { t: "wait", ms: 2200 },
  ],
  agent: [
    { t: "wait", ms: 900 },
    { t: "type", s: "次の条件で、京都の旅程を組んで:" },
    { t: "enter" },
    { t: "type", s: "・3泊4日" },
    { t: "enter" },
    { t: "type", s: "・予算は1人10万円" },
    { t: "enter" },
    { t: "type", s: "・朝はゆっくりめで" },
    { t: "wait", ms: 700 },
    { t: "send" },
    { t: "think", ms: 1300 },
    {
      t: "stream",
      s: "承知しました。3つの条件で組みます。\n\n1日目 午後に到着、祇園と八坂神社を散策\n2日目 10時に出発、嵐山と竹林の小径へ\n3日目 朝はホテルでゆっくり、午後に伏見稲荷\n4日目 錦市場で昼食をとってから帰路へ",
    },
    { t: "wait", ms: 3400 },
  ],
}

/* 自分で打ったときのAIの返答(デモ用の固定文) */
const USER_AGENT_REPLY =
  "受け取りました。途中のEnterは改行として入力欄に残り、⌘Enterを押したときに初めて全文が送られました。これがUniEnterの動きです。"

const APP_ORDER: AppKind[] = ["chat", "agent"]

function AppTabs({ app, onPick }: { app: AppKind; onPick: (a: AppKind) => void }) {
  return (
    <div className="relative mx-auto mb-5 inline-grid grid-cols-2 rounded-full border border-[var(--line)] bg-white/70 p-1 text-[13px] font-bold backdrop-blur">
      <span
        aria-hidden
        className="absolute inset-y-1 left-1 w-[calc(50%-4px)] rounded-full bg-[var(--ink)] shadow-[0_6px_16px_-8px_rgba(29,28,25,0.6)] transition-transform duration-500 ease-[cubic-bezier(.2,.9,.25,1.1)]"
        style={{ transform: app === "agent" ? "translateX(100%)" : "none" }}
      />
      {APP_ORDER.map((a) => (
        <button
          key={a}
          type="button"
          onClick={() => onPick(a)}
          aria-pressed={app === a}
          className={`relative z-10 flex items-center justify-center gap-1.5 rounded-full px-4 py-1.5 transition-colors duration-300 ${
            app === a ? "text-white" : "text-[var(--ink-2)] hover:text-[var(--ink)]"
          }`}
        >
          {a === "chat" ? <MessageSquare className="size-3.5" /> : <Sparkles className="size-3.5" />}
          {a === "chat" ? "チャット" : "AIエージェント"}
        </button>
      ))}
    </div>
  )
}

function OnPill() {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full bg-[var(--teal-tint)] px-2.5 py-1 text-[11px] font-bold whitespace-nowrap text-[var(--teal-ink)]">
      <span className="relative flex size-1.5">
        <span className="absolute inline-flex size-full animate-ping rounded-full bg-[var(--teal)] opacity-60" />
        <span className="relative inline-flex size-1.5 rounded-full bg-[var(--teal)]" />
      </span>
      UniEnter ON
    </span>
  )
}

function Dots() {
  return (
    <span className="inline-flex items-center gap-1 py-1">
      {[0, 1, 2].map((i) => (
        <span key={i} className="size-1.5 animate-bounce rounded-full bg-[var(--ink-3)]" style={{ animationDelay: `${i * 120}ms` }} />
      ))}
    </span>
  )
}

function ChatPlayground() {
  const [wrapRef, inView] = useInView<HTMLDivElement>(0.3, false)
  const [app, setApp] = useState<AppKind>("chat")
  const [startApp, setStartApp] = useState<AppKind>("chat")
  const [msgs, setMsgs] = useState<Msg[]>(INITIAL_MSGS.chat)
  const [thinking, setThinking] = useState(false)
  const [draft, _setDraft] = useState("")
  const draftRef = useRef("")
  const setDraft = useCallback((next: string | ((d: string) => string)) => {
    draftRef.current = typeof next === "function" ? next(draftRef.current) : next
    _setDraft(draftRef.current)
  }, [])
  const [mode, setMode] = useState<"auto" | "user">("auto")
  const [cmd, setCmd] = useState(false)
  const [ret, setRet] = useState(false)
  const [pop, setPop] = useState<{ kind: "newline" | "send"; id: number } | null>(null)
  const idRef = useRef(1)
  const backTimer = useRef<number | undefined>(undefined)
  const inputRef = useRef<HTMLTextAreaElement>(null)
  const replyToken = useRef(0)

  const push = useCallback((text: string, role: Msg["role"]) => {
    setMsgs((m) => [...m.slice(-5), { id: idRef.current++, text, role }])
  }, [])

  const send = useCallback(() => {
    const text = draftRef.current.replace(/\s+$/, "")
    if (!text) return false
    push(text, "me")
    setDraft("")
    setPop({ kind: "send", id: Date.now() })
    return true
  }, [push, setDraft])

  /* AIの返答を1文字ずつ流す。isCancelled が true になったら途中で止める */
  const stream = useCallback(async (text: string, isCancelled: () => boolean) => {
    const id = idRef.current++
    setMsgs((m) => [...m.slice(-5), { id, text: "", role: "ai" }])
    for (let i = 0; i < text.length; i += 2) {
      if (isCancelled()) return
      const part = text.slice(0, i + 2)
      setMsgs((m) => m.map((x) => (x.id === id ? { ...x, text: part } : x)))
      await sleep(22)
    }
  }, [])

  const switchApp = useCallback(
    (a: AppKind) => {
      replyToken.current++
      setApp(a)
      setMsgs(INITIAL_MSGS[a])
      setThinking(false)
      setDraft("")
    },
    [setDraft],
  )

  // 自動デモ: チャット → AIエージェント → … を繰り返す。画面外・ユーザー操作中は止める
  useEffect(() => {
    if (mode !== "auto" || !inView) return
    if (prefersReducedMotion()) {
      switchApp(startApp)
      setDraft("明日の打ち合わせ、\n15時からに変更できますか?")
      return
    }
    let cancelled = false
    const isCancelled = () => cancelled
    ;(async () => {
      let idx = APP_ORDER.indexOf(startApp)
      while (!cancelled) {
        const a = APP_ORDER[idx % APP_ORDER.length]
        switchApp(a)
        for (const step of SCRIPTS[a]) {
          if (cancelled) return
          if (step.t === "wait") await sleep(step.ms)
          else if (step.t === "type") {
            for (const c of step.s) {
              if (cancelled) return
              setDraft((d) => d + c)
              await sleep(40 + Math.random() * 55)
            }
          } else if (step.t === "enter") {
            setRet(true)
            setDraft((d) => d + "\n")
            setPop({ kind: "newline", id: Date.now() })
            await sleep(170)
            setRet(false)
            await sleep(260)
          } else if (step.t === "send") {
            setCmd(true)
            await sleep(220)
            setRet(true)
            send()
            await sleep(170)
            setRet(false)
            await sleep(120)
            setCmd(false)
          } else if (step.t === "reply") {
            push(step.s, "other")
          } else if (step.t === "think") {
            setThinking(true)
            await sleep(step.ms)
            setThinking(false)
          } else if (step.t === "stream") {
            await stream(step.s, isCancelled)
          }
        }
        idx++
      }
    })()
    return () => {
      cancelled = true
      setCmd(false)
      setRet(false)
      setThinking(false)
    }
  }, [mode, inView, startApp, send, push, stream, switchApp, setDraft])

  const pickApp = (a: AppKind) => {
    track("playground_tab", { app: a })
    if (mode === "auto") setStartApp(a)
    switchApp(a)
  }

  const takeOver = () => {
    window.clearTimeout(backTimer.current)
    if (mode === "auto") {
      setMode("user")
      setStartApp(app)
      setMsgs(INITIAL_MSGS[app])
      setThinking(false)
      setDraft("")
      track("playground_focus", { location: "hero", app })
    }
  }

  const userSend = async () => {
    if (!send() || app !== "agent") return
    const token = ++replyToken.current
    const isCancelled = () => token !== replyToken.current
    setThinking(true)
    await sleep(900)
    setThinking(false)
    if (!isCancelled()) await stream(USER_AGENT_REPLY, isCancelled)
  }

  const onKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Meta" || e.key === "Control") setCmd(true)
    if (e.key !== "Enter") return
    // 日本語変換中のEnterは触らない(UniEnter本体と同じ約束)
    if (e.nativeEvent.isComposing || e.keyCode === 229) return
    setRet(true)
    // macOSでは⌘押下中のEnterのkeyupが来ないことがあるので時間で戻す
    window.setTimeout(() => setRet(false), 160)
    if (e.metaKey || e.ctrlKey) {
      e.preventDefault()
      void userSend()
    } else {
      setPop({ kind: "newline", id: Date.now() })
    }
  }
  const onKeyUp = (e: React.KeyboardEvent) => {
    if (e.key === "Meta" || e.key === "Control") setCmd(false)
  }
  const onBlur = () => {
    setCmd(false)
    if (!draftRef.current) {
      backTimer.current = window.setTimeout(() => setMode("auto"), 4000)
    }
  }

  const lines = draft.split("\n")
  const placeholder =
    app === "chat" ? "# 企画チーム へのメッセージ" : "何でも聞いてください"

  /* 入力欄の中身(自動デモ中は↵マーク付きの表示、操作中は本物のtextarea) */
  const field =
    mode === "user" ? (
      <textarea
        ref={inputRef}
        autoFocus
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onKeyDown={onKeyDown}
        onKeyUp={onKeyUp}
        onFocus={() => window.clearTimeout(backTimer.current)}
        onBlur={onBlur}
        rows={3}
        aria-label="メッセージを入力(Enterで改行、⌘Enterで送信)"
        placeholder="ここに打ってみてください。Enterで改行、⌘Enterで送信。"
        className="block w-full resize-none bg-transparent outline-none placeholder:text-[var(--ink-3)]"
      />
    ) : (
      <button
        type="button"
        onClick={takeOver}
        className="block w-full cursor-text text-left"
        aria-label="デモの入力欄。クリックすると自分で入力できます"
      >
        {draft === "" ? (
          <span className="block min-h-[1.6em] text-[var(--ink-3)]">
            <span className="caret !ml-0 mr-1" />
            {placeholder}
          </span>
        ) : (
          lines.map((line, i) => (
            <span key={i} className="block min-h-[1.6em]">
              {line}
              {i < lines.length - 1 && <span className="nl-mark">↵</span>}
              {i === lines.length - 1 && <span className="caret" />}
            </span>
          ))
        )}
      </button>
    )

  return (
    <div ref={wrapRef} className="relative mx-auto w-full max-w-[680px]">
      <AppTabs app={app} onPick={pickApp} />

      <div key={app} className="app-in">
        {app === "chat" ? (
          /* ── チャットアプリ風: 左にチャンネル一覧、吹き出し ── */
          <div className="flex h-[440px] overflow-hidden rounded-[22px] border border-[var(--line)] bg-white text-left shadow-[0_40px_80px_-30px_rgba(29,28,25,0.35),0_2px_6px_rgba(29,28,25,0.05)] sm:h-[420px]">
            <aside className="hidden w-44 shrink-0 flex-col border-r border-[var(--line)] bg-[var(--paper)] px-3 py-3 sm:flex">
              <span className="mb-4 flex gap-1.5 px-1">
                <i className="size-3 rounded-full bg-[#e6e3db]" />
                <i className="size-3 rounded-full bg-[#e6e3db]" />
                <i className="size-3 rounded-full bg-[#e6e3db]" />
              </span>
              <p className="mb-1.5 px-2 text-[10px] font-bold tracking-[0.15em] text-[var(--ink-3)]">チャンネル</p>
              {["企画チーム", "営業", "雑談"].map((c, i) => (
                <p
                  key={c}
                  className={`flex items-center gap-1.5 rounded-md px-2 py-1.5 text-[13px] ${
                    i === 0 ? "bg-white font-bold shadow-[0_1px_2px_rgba(29,28,25,0.08)]" : "text-[var(--ink-2)]"
                  }`}
                >
                  <Hash className="size-3.5 opacity-60" />
                  {c}
                </p>
              ))}
              <p className="mt-4 mb-1.5 px-2 text-[10px] font-bold tracking-[0.15em] text-[var(--ink-3)]">ダイレクト</p>
              {["佐藤", "田中"].map((n) => (
                <p key={n} className="flex items-center gap-2 px-2 py-1.5 text-[13px] text-[var(--ink-2)]">
                  <span className="flex size-5 items-center justify-center rounded-md bg-[var(--paper-2)] text-[10px] font-bold">
                    {n[0]}
                  </span>
                  {n}
                </p>
              ))}
            </aside>
            <div className="flex min-w-0 flex-1 flex-col">
              <div className="flex items-center gap-2 border-b border-[var(--line)] px-4 py-3">
                <span className="flex gap-1.5 sm:hidden">
                  <i className="size-3 rounded-full bg-[#e6e3db]" />
                  <i className="size-3 rounded-full bg-[#e6e3db]" />
                  <i className="size-3 rounded-full bg-[#e6e3db]" />
                </span>
                <span className="flex items-center gap-1 text-[14px] font-bold">
                  <Hash className="size-4 text-[var(--ink-3)]" />
                  企画チーム
                </span>
                <span className="ml-auto">
                  <OnPill />
                </span>
              </div>
              <div className="flex min-h-0 flex-1 flex-col justify-end gap-2.5 overflow-hidden px-4 pt-4 pb-3">
                {msgs.map((m) => (
                  <div key={m.id} className={`flex items-end gap-2 ${m.role === "me" ? "justify-end" : ""}`}>
                    {m.role !== "me" && (
                      <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-[var(--paper-2)] text-[11px] font-bold text-[var(--ink-2)]">
                        佐
                      </span>
                    )}
                    <p
                      className={`bubble-in max-w-[80%] rounded-2xl px-3.5 py-2 text-[14px] leading-relaxed whitespace-pre-wrap ${
                        m.role === "me"
                          ? "rounded-br-md bg-[var(--ink)] text-white"
                          : "other rounded-bl-md bg-[var(--paper-2)] text-[var(--ink)]"
                      }`}
                    >
                      {m.text}
                    </p>
                  </div>
                ))}
              </div>
              <div className="px-4 pb-4">
                <div
                  className={`min-h-[84px] rounded-xl border px-3.5 py-2.5 text-[14px] leading-relaxed transition-colors ${
                    mode === "user" ? "border-[var(--teal)] ring-4 ring-[var(--teal)]/10" : "border-[var(--line)]"
                  }`}
                >
                  {field}
                </div>
              </div>
            </div>
          </div>
        ) : (
          /* ── AIエージェント風: 中央寄せの会話、太いプロンプト欄、送信ボタン ── */
          <div className="flex h-[440px] flex-col overflow-hidden rounded-[22px] border border-[var(--line)] bg-[#fcfbf9] text-left shadow-[0_40px_80px_-30px_rgba(29,28,25,0.35),0_2px_6px_rgba(29,28,25,0.05)] sm:h-[420px]">
            <div className="flex items-center gap-2 px-4 py-3">
              <span className="flex gap-1.5">
                <i className="size-3 rounded-full bg-[#e6e3db]" />
                <i className="size-3 rounded-full bg-[#e6e3db]" />
                <i className="size-3 rounded-full bg-[#e6e3db]" />
              </span>
              <span className="ml-1 inline-flex items-center gap-1.5 rounded-lg px-2 py-1 text-[13px] font-bold whitespace-nowrap">
                <Sparkles className="size-4" />
                AIエージェント
                <ChevronDown className="hidden size-3.5 text-[var(--ink-3)] sm:block" />
              </span>
              <span className="ml-auto">
                <OnPill />
              </span>
            </div>
            <div className="mx-auto flex min-h-0 w-full max-w-[560px] flex-1 flex-col justify-end gap-4 overflow-hidden px-5 pt-2 pb-3">
              {msgs.length === 0 && !thinking && (
                <div className="app-in m-auto text-center">
                  <span className="mx-auto mb-3 flex size-10 items-center justify-center rounded-2xl bg-[var(--ink)] text-white">
                    <Sparkles className="size-5" />
                  </span>
                  <p className="text-xl font-bold tracking-tight">何をお手伝いしましょう?</p>
                </div>
              )}
              {msgs.map((m) =>
                m.role === "me" ? (
                  <div key={m.id} className="flex justify-end">
                    <p className="bubble-in max-w-[85%] rounded-2xl rounded-br-md bg-[var(--paper-2)] px-4 py-2.5 text-[14px] leading-relaxed whitespace-pre-wrap">
                      {m.text}
                    </p>
                  </div>
                ) : (
                  <div key={m.id} className="flex gap-3">
                    <span className="flex size-7 shrink-0 items-center justify-center rounded-lg bg-[var(--ink)] text-white">
                      <Sparkles className="size-3.5" />
                    </span>
                    <p className="pt-0.5 text-[14px] leading-relaxed whitespace-pre-wrap">{m.text}</p>
                  </div>
                ),
              )}
              {thinking && (
                <div className="flex items-center gap-3">
                  <span className="flex size-7 shrink-0 items-center justify-center rounded-lg bg-[var(--ink)] text-white">
                    <Sparkles className="size-3.5 animate-pulse" />
                  </span>
                  <span className="text-[13px] text-[var(--ink-3)]">考えています</span>
                  <Dots />
                </div>
              )}
            </div>
            <div className="mx-auto w-full max-w-[580px] px-4 pb-10">
              <div
                className={`rounded-[20px] border bg-white px-4 pt-3 pb-2.5 text-[14px] leading-relaxed shadow-[0_10px_30px_-18px_rgba(29,28,25,0.45)] transition-colors ${
                  mode === "user" ? "border-[var(--teal)] ring-4 ring-[var(--teal)]/10" : "border-[var(--line)]"
                }`}
              >
                <div className="max-h-[112px] min-h-[48px] overflow-hidden">{field}</div>
                <div className="mt-2 flex items-center gap-2">
                  <span className="flex size-7 items-center justify-center rounded-full border border-[var(--line)] text-[var(--ink-3)]">
                    <Plus className="size-4" />
                  </span>
                  <span className="rounded-full border border-[var(--line)] px-2.5 py-1 text-[11px] font-semibold text-[var(--ink-3)]">
                    ツール
                  </span>
                  <span className="ml-auto text-[11px] font-semibold text-[var(--ink-3)]">⌘ ↵ で送信</span>
                  <span
                    className={`flex size-8 items-center justify-center rounded-full text-white transition-colors ${
                      draft.trim() ? "bg-[var(--ink)]" : "bg-[#d6d3cb]"
                    }`}
                  >
                    <ArrowUp className="size-4" strokeWidth={2.5} />
                  </span>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* キーキャップ */}
      <div className="relative z-10 -mt-7 flex items-end justify-center gap-3">
        <Key down={cmd} className="h-16 w-20 flex-col !gap-0 text-[22px] sm:h-[72px] sm:w-24">
          ⌘<span className="text-[10px] font-semibold tracking-wide text-[var(--ink-3)]">command</span>
        </Key>
        <span className="relative">
          <Key down={ret} teal={ret && !cmd} className="h-16 w-36 text-lg sm:h-[72px] sm:w-44">
            return <CornerDownLeft className="size-5" />
          </Key>
          {pop && (
            <span
              key={pop.id}
              className={`pop pointer-events-none absolute -top-10 left-1/2 rounded-full px-3 py-1 text-xs font-bold whitespace-nowrap ${
                pop.kind === "newline" ? "bg-[var(--teal)] text-white" : "bg-[var(--ink)] text-white"
              }`}
            >
              {pop.kind === "newline" ? "↵ 改行" : "⌘ + Enter → 送信"}
            </span>
          )}
        </span>
      </div>
      <p className="mt-5 text-center text-xs text-[var(--ink-3)]">
        {mode === "user" ? (
          <>Enter で改行 / ⌘ + Enter で送信(日本語の変換中のEnterはそのまま確定)</>
        ) : (
          <>入力欄をクリックすると、実際に打って試せます</>
        )}
      </p>
    </div>
  )
}

const FLOATERS: { name: string; cls: string; style: Record<string, string> }[] = [
  { name: "Slack", cls: "left-[4%] top-[18%]", style: { "--dur": "8s", "--r0": "-10deg", "--r1": "-2deg" } },
  { name: "LINE", cls: "left-[11%] top-[52%]", style: { "--dur": "10s", "--delay": "-3s", "--r0": "6deg", "--r1": "-4deg" } },
  { name: "ChatGPT", cls: "left-[6%] top-[80%]", style: { "--dur": "9s", "--delay": "-5s" } },
  { name: "Microsoft Teams", cls: "right-[5%] top-[20%]", style: { "--dur": "11s", "--r0": "8deg", "--r1": "2deg" } },
  { name: "Claude", cls: "right-[12%] top-[50%]", style: { "--dur": "9s", "--delay": "-2s" } },
  { name: "Discord", cls: "right-[5%] top-[78%]", style: { "--dur": "10s", "--delay": "-6s", "--r0": "-4deg", "--r1": "6deg" } },
]

function Hero() {
  const ref = useRef<HTMLElement>(null)
  const onMove = (e: React.PointerEvent) => {
    const r = ref.current?.getBoundingClientRect()
    if (!r) return
    ref.current!.style.setProperty("--mx", `${e.clientX - r.left}px`)
    ref.current!.style.setProperty("--my", `${e.clientY - r.top}px`)
  }
  return (
    <header
      ref={ref}
      onPointerMove={onMove}
      data-track-section="hero"
      className="relative px-5 pt-32 pb-20 text-center sm:pt-40"
    >
      <div className="dotgrid pointer-events-none absolute inset-0" />
      <div className="spot pointer-events-none absolute inset-0" />
      {FLOATERS.map((f) => {
        const s = services.find((x) => x.name === f.name)!
        return (
          <span key={f.name} className={`float pointer-events-none absolute hidden lg:block ${f.cls}`} style={vars(f.style)}>
            <LogoSquare service={s} size="size-14" glyph="size-7" className="shadow-[0_18px_30px_-12px_rgba(29,28,25,0.35)]" />
          </span>
        )
      })}

      <div className="relative">
        <Reveal>
          <p className="mb-7 inline-flex items-center gap-2 rounded-full border border-[var(--line)] bg-white/70 px-4 py-1.5 text-[13px] font-semibold text-[var(--ink-2)] backdrop-blur">
            <span className="size-1.5 rounded-full bg-[var(--teal)]" />
            14日間無料・買い切り
          </p>
        </Reveal>
        <h1 className="text-[40px] leading-[1.15] font-extrabold tracking-[-0.02em] sm:text-7xl sm:leading-[1.1] lg:text-[88px]">
          <span className="block">
            <SplitText text="Enterでの" base={150} />
          </span>
          <span className="block">
            <SplitText text="うっかり送信を" base={400} />
            <br className="sm:hidden" />
            <SplitText text="防ぎます" base={700} />
          </span>
        </h1>
        <Reveal delay={900}>
          <p className="mx-auto mt-7 max-w-xl text-lg font-medium text-[var(--ink-2)] sm:text-xl">
            <span className="font-bold text-[var(--teal-ink)]">Enterは改行</span>、送信は⌘Enter。
            <br className="sm:hidden" />
            Macのチャット、ぜんぶで。
          </p>
        </Reveal>
        <Reveal delay={1050}>
          <div className="mt-9 flex flex-wrap items-center justify-center gap-3">
            <PrimaryCTA location="hero" />
            <GhostCTA href="#pricing">価格を見る</GhostCTA>
          </div>
          <p className="mt-4 text-xs text-[var(--ink-3)]">macOS 13以降 / Mac用インストーラ(.pkg・約3MB)</p>
        </Reveal>
        <Reveal delay={1250} className="mt-16">
          <ChatPlayground />
        </Reveal>
      </div>
    </header>
  )
}

/* ─────────────────────── Before / After ストーリー ─────────────────────── */

const STORY: { before: boolean; text: ReactNode }[] = [
  {
    before: true,
    text: (
      <>
        改行のつもりで押したEnterで、<em className="mark not-italic">書きかけのメッセージが送られてしまう。</em>
      </>
    ),
  },
  {
    before: true,
    text: (
      <>
        AIへの長い指示も、<em className="mark not-italic">1行目だけで送信されてしまう。</em>
      </>
    ),
  },
  {
    before: true,
    text: <em className="mark not-italic">取り消して、謝って、書き直す。</em>,
  },
  {
    before: false,
    text: (
      <>
        <span className="text-[var(--teal)]">Enter → 改行</span>、
        <br />
        ⌘ Enter → 送信。
        <span className="mt-3 block text-[0.55em] leading-relaxed font-bold text-[var(--ink-2)]">
          対象にしたアプリは、この2つだけ。
        </span>
      </>
    ),
  },
  { before: false, text: "各アプリの設定画面は、もう開かなくていい。" },
]

const at = (s: number, extra: Record<string, string | number> = {}) => vars({ "--at": `${s}s`, ...extra })
const typeVars = (s: number, n: number, t = n * 0.07) => at(s, { "--n": n, "--t": `${t}s` })

function Annot({ children, time, teal }: { children: ReactNode; time: number; teal?: boolean }) {
  return (
    <span
      className={`scene-in absolute top-12 right-4 z-10 rounded-full px-3 py-1 text-[11px] font-bold ${
        teal ? "bg-[var(--teal-tint)] text-[var(--teal-ink)]" : "bg-[var(--ink)] text-white"
      }`}
      style={at(time)}
    >
      {children}
    </span>
  )
}

function Bubble({ children, mine = true, style, className = "" }: { children: ReactNode; mine?: boolean; style?: CSSProperties; className?: string }) {
  return (
    <div className={`flex ${mine ? "justify-end" : ""}`}>
      <p
        className={`max-w-[82%] rounded-2xl px-3.5 py-2 text-[13px] leading-relaxed sm:text-[14px] ${
          mine ? "rounded-br-md bg-[var(--ink)] text-white" : "rounded-bl-md bg-[var(--paper-2)]"
        } ${className}`}
        style={style}
      >
        {children}
      </p>
    </div>
  )
}

function SceneWindow({ title, on, children, composer, keys }: { title: string; on?: boolean; children: ReactNode; composer: ReactNode; keys: ReactNode }) {
  return (
    <div className="relative">
      <div className="relative overflow-hidden rounded-[20px] border border-[var(--line)] bg-white shadow-[0_30px_60px_-30px_rgba(29,28,25,0.35)]">
        <div className="flex items-center gap-2 border-b border-[var(--line)] px-4 py-2.5">
          <span className="flex gap-1.5">
            <i className="size-2.5 rounded-full bg-[#e6e3db]" />
            <i className="size-2.5 rounded-full bg-[#e6e3db]" />
            <i className="size-2.5 rounded-full bg-[#e6e3db]" />
          </span>
          <span className="ml-1.5 text-[12px] font-semibold text-[var(--ink-2)]">{title}</span>
          <span
            className={`ml-auto rounded-full px-2 py-0.5 text-[10px] font-bold ${
              on ? "bg-[var(--teal-tint)] text-[var(--teal-ink)]" : "bg-[var(--paper-2)] text-[var(--ink-3)]"
            }`}
          >
            UniEnter {on ? "ON" : "なし"}
          </span>
        </div>
        <div className="flex h-[150px] flex-col justify-end gap-2 overflow-hidden px-4 py-3 sm:h-[220px]">{children}</div>
        <div className="border-t border-[var(--line)] px-4 py-2.5">
          <div className="min-h-[58px] rounded-xl border border-[var(--line)] bg-[var(--paper)]/60 px-3 py-2 text-[13px] leading-relaxed sm:text-[14px]">
            {composer}
          </div>
        </div>
      </div>
      <div className="relative z-10 -mt-5 flex justify-center gap-2.5">{keys}</div>
    </div>
  )
}

function SceneKeys({ enterAt = [], cmdAt = [], teal }: { enterAt?: number[]; cmdAt?: number[]; teal?: boolean }) {
  // 同じキーの複数回押下は要素を重ねて表現できないため、各キー1回までに限定する
  return (
    <>
      <Key className={`h-12 w-16 text-lg ${cmdAt.length ? "scene-press" : ""}`} style={cmdAt.length ? at(cmdAt[0], { animationDuration: "0.5s" }) : undefined}>
        ⌘
      </Key>
      <Key
        teal={teal}
        className={`h-12 w-28 text-sm ${enterAt.length ? "scene-press" : ""}`}
        style={enterAt.length ? at(enterAt[0]) : undefined}
      >
        return <CornerDownLeft className="size-4" />
      </Key>
    </>
  )
}

function Scene({ step }: { step: number }) {
  if (step === 0)
    return (
      <SceneWindow
        title="# 企画チーム"
        keys={<SceneKeys enterAt={[1.3]} />}
        composer={
          <span className="scene-out" style={at(1.35)}>
            <span className="scene-type" style={typeVars(0.2, 12, 0.9)}>
              明日の打ち合わせですが、
            </span>
          </span>
        }
      >
        <Annot time={2.2}>書きかけのまま送信</Annot>
        <Bubble mine={false}>明日の件、どうなりました?</Bubble>
        <div className="scene-in" style={at(1.45)}>
          <div className="shake" style={at(1.95)}>
            <Bubble>明日の打ち合わせですが、</Bubble>
          </div>
          <p className="mt-1 text-right text-[10px] text-[var(--ink-3)]">送信済み</p>
        </div>
      </SceneWindow>
    )
  if (step === 1)
    return (
      <SceneWindow
        title="AIアシスタント"
        keys={<SceneKeys enterAt={[1.3]} />}
        composer={
          <span className="scene-out" style={at(1.35)}>
            <span className="scene-type" style={typeVars(0.2, 13, 0.9)}>
              以下の条件で旅程を組んで:
            </span>
          </span>
        }
      >
        <Annot time={2.5}>1行目だけで送信</Annot>
        <div className="scene-in" style={at(1.45)}>
          <Bubble>以下の条件で旅程を組んで:</Bubble>
        </div>
        <div className="scene-in" style={at(2.1)}>
          <Bubble mine={false}>承知しました。どのような条件でしょうか?</Bubble>
        </div>
      </SceneWindow>
    )
  if (step === 2)
    return (
      <SceneWindow
        title="# 企画チーム"
        keys={<SceneKeys />}
        composer={
          <span className="scene-type" style={typeVars(2.4, 12, 0.9)}>
            明日の打ち合わせですが、
          </span>
        }
      >
        <Annot time={2.3}>取り消して、謝って、書き直す</Annot>
        <div className="scene-out" style={at(0.9)}>
          <Bubble>
            <span className="strike" style={at(0.3)}>
              明日の打ち合わせですが、
            </span>
          </Bubble>
        </div>
        <p className="scene-in text-center text-[11px] text-[var(--ink-3)]" style={at(1.1)}>
          メッセージの送信を取り消しました
        </p>
        <div className="scene-in" style={at(1.6)}>
          <Bubble>すみません、途中で送ってしまいました🙏</Bubble>
        </div>
      </SceneWindow>
    )
  if (step === 3)
    return (
      <SceneWindow
        title="# 企画チーム"
        on
        keys={
          <>
            <Key className="scene-press h-12 w-16 text-lg" style={at(2.7, { animationDuration: "0.5s" })}>
              ⌘
            </Key>
            <span className="relative">
              <Key
                className="h-12 w-28 text-sm"
                style={{ animation: "lpn-press 0.28s ease-out 1.2s both, lpn-press 0.28s ease-out 2.85s both" }}
              >
                return <CornerDownLeft className="size-4" />
              </Key>
              <span className="pop absolute -top-9 left-1/2 rounded-full bg-[var(--teal)] px-2.5 py-0.5 text-[11px] font-bold whitespace-nowrap text-white" style={{ animationDelay: "1.2s", animationFillMode: "both" }}>
                ↵ 改行
              </span>
              <span className="pop absolute -top-9 left-1/2 rounded-full bg-[var(--ink)] px-2.5 py-0.5 text-[11px] font-bold whitespace-nowrap text-white" style={{ animationDelay: "2.85s", animationFillMode: "both" }}>
                ⌘ + Enter → 送信
              </span>
            </span>
          </>
        }
        composer={
          <span className="scene-out block" style={at(2.95)}>
            <span className="block">
              <span className="scene-type" style={typeVars(0.2, 12, 0.9)}>
                明日の打ち合わせですが、
              </span>
              <span className="nl-mark scene-in" style={at(1.2)}>
                ↵
              </span>
            </span>
            <span className="block">
              <span className="scene-type" style={typeVars(1.4, 14, 1)}>
                15時からに変更できますか?
              </span>
            </span>
          </span>
        }
      >
        <Annot time={3.3} teal>
          Enter=改行 / ⌘Enter=送信
        </Annot>
        <Bubble mine={false}>明日の件、どうなりました?</Bubble>
        <div className="scene-in" style={at(3.05)}>
          <Bubble>
            明日の打ち合わせですが、
            <br />
            15時からに変更できますか?
          </Bubble>
        </div>
      </SceneWindow>
    )
  // step 4: どのアプリでも同じルール
  const shown = services.filter((s) => !s.hideInLogoRow)
  return (
    <div className="relative flex h-[270px] items-center justify-center sm:h-[360px]">
      {shown.map((s, i) => {
        const angle = (i / shown.length) * Math.PI * 2 - Math.PI / 2
        return (
          <span
            key={s.name}
            className="scene-in absolute"
            style={{
              ...at(0.08 * i),
              left: `calc(50% + ${Math.cos(angle) * 41}% - 22px)`,
              top: `calc(50% + ${Math.sin(angle) * 40}% - 22px)`,
            }}
          >
            <LogoSquare service={s} size="size-11" glyph="size-6" className="shadow-[0_12px_20px_-10px_rgba(29,28,25,0.4)]" />
          </span>
        )
      })}
      <div className="scene-in rounded-2xl border border-[var(--line)] bg-white px-5 py-4 shadow-[0_24px_50px_-24px_rgba(29,28,25,0.4)]" style={at(0.9)}>
        <p className="mb-3 text-center text-[10px] font-bold tracking-[0.2em] text-[var(--ink-3)]">どのアプリでも</p>
        <div className="space-y-2 text-sm">
          <p className="flex items-center gap-2">
            <Key className="h-8 px-2.5 text-xs !rounded-lg">Enter</Key>
            <span className="font-bold text-[var(--teal)]">→ 改行</span>
          </p>
          <p className="flex items-center gap-2">
            <Key className="h-8 w-8 text-xs !rounded-lg">⌘</Key>
            <Key className="h-8 px-2.5 text-xs !rounded-lg">Enter</Key>
            <span className="font-bold">→ 送信</span>
          </p>
        </div>
      </div>
    </div>
  )
}

function BeforeAfter() {
  const [ref, progress] = useScrollProgress<HTMLElement>("pin")
  const step = Math.min(STORY.length - 1, Math.floor(progress * STORY.length))
  const cur = STORY[step]
  return (
    <section
      ref={ref}
      data-track-section="before-after"
      className="relative"
      style={{ height: `${STORY.length * 75 + 100}svh` }}
    >
      <div className="sticky top-0 flex h-svh items-center overflow-hidden">
        {/* 背景: 「これまで」は周囲がぼんやり暗く沈んだ曇天、「UniEnterを入れると」で一気に晴れる */}
        <div
          className="absolute inset-0 transition-colors duration-1000"
          style={{ backgroundColor: cur.before ? "#e4e1d9" : "#ffffff" }}
        />
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 transition-opacity duration-1000"
          style={{
            opacity: cur.before ? 1 : 0,
            background:
              "radial-gradient(ellipse 70% 65% at 50% 50%, transparent 35%, rgba(29,28,25,0.22) 75%, rgba(29,28,25,0.5) 100%)",
          }}
        />
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 transition-opacity duration-1000"
          style={{
            opacity: cur.before ? 0 : 1,
            background: "radial-gradient(ellipse 55% 50% at 70% 50%, rgba(232,243,240,0.9), transparent 70%)",
          }}
        />
        <div className="relative mx-auto grid w-full max-w-6xl items-center gap-5 px-5 pt-14 lg:grid-cols-[1.2fr_0.8fr] lg:gap-14 lg:pt-0">
          <div>
            <Eyebrow>BEFORE / AFTER</Eyebrow>
            <h2 className="text-[15px] leading-relaxed font-bold text-[var(--ink-2)] sm:text-lg">
              チャットアプリ/AIアプリでEnter送信を防ぎ、
              <br className="hidden sm:block" />
              全て⌘+Enterで送信に統一します。
            </h2>

            {/* 主役: いま起きていることを大きく1文で */}
            <div className="mt-5 min-h-[9.5rem] sm:mt-10 sm:min-h-[15rem]">
              <div key={step} className="swap-in">
                <p className="mb-3 flex items-center gap-3 sm:mb-5">
                  <span
                    className={`rounded-full px-3 py-1 text-[11px] font-bold tracking-[0.12em] sm:text-xs ${
                      cur.before ? "bg-[var(--ink)] text-white" : "bg-[var(--teal-tint)] text-[var(--teal-ink)]"
                    }`}
                  >
                    {cur.before ? "これまで" : "UniEnterを入れると"}
                  </span>
                  <span className="text-xs font-semibold text-[var(--ink-3)] tabular-nums">
                    {String(step + 1).padStart(2, "0")} / {String(STORY.length).padStart(2, "0")}
                  </span>
                </p>
                <p className="text-[24px] leading-[1.4] font-extrabold tracking-tight sm:text-[38px] lg:text-[44px]">
                  {cur.text}
                </p>
              </div>
            </div>

            {/* 進行バー: Before 3つ / After 2つ */}
            <div className="mt-4 flex max-w-sm gap-1.5 sm:mt-8">
              {STORY.map((s, i) => (
                <span key={i} className="h-1 flex-1 overflow-hidden rounded-full bg-[var(--ink)]/10">
                  <span
                    className={`block h-full origin-left rounded-full transition-transform duration-500 ${
                      s.before ? "bg-[var(--ink)]" : "bg-[var(--teal)]"
                    }`}
                    style={{ transform: `scaleX(${i <= step ? 1 : 0})` }}
                  />
                </span>
              ))}
            </div>
          </div>

          <div
            className="mx-auto w-full max-w-[400px] transition-[filter,opacity] duration-1000 lg:max-w-[440px]"
            style={{ filter: cur.before ? "grayscale(0.6) contrast(0.95)" : "none", opacity: cur.before ? 0.92 : 1 }}
          >
            <Scene key={step} step={step} />
          </div>
        </div>
      </div>
    </section>
  )
}

/* ─────────────────────── 対応サービス ─────────────────────── */

function ServiceChip({ service }: { service: Service }) {
  return (
    <div className="mx-2 flex items-center gap-3 rounded-2xl border border-[var(--line)] bg-white py-2.5 pr-4 pl-2.5 shadow-[0_8px_20px_-14px_rgba(29,28,25,0.3)] transition-transform duration-300 hover:-translate-y-1">
      <LogoSquare service={service} />
      <div>
        <p className="text-[14px] font-bold whitespace-nowrap">{service.name}</p>
        <p className="mt-0.5 flex gap-1">
          {service.desktop && (
            <span className="rounded-full bg-[var(--paper-2)] px-1.5 py-px text-[10px] text-[var(--ink-2)]">アプリ</span>
          )}
          {service.web && (
            <span className="rounded-full bg-[var(--paper-2)] px-1.5 py-px text-[10px] text-[var(--ink-2)]">ブラウザ</span>
          )}
        </p>
      </div>
    </div>
  )
}

function Services() {
  const rows = [services.slice(0, 6), services.slice(6)]
  return (
    <section data-track-section="apps" className="relative overflow-hidden bg-[var(--paper)] py-28 sm:py-36">
      <div className="relative mx-auto max-w-3xl px-5 text-center">
        <Reveal>
          <Eyebrow>SUPPORTED</Eyebrow>
          <h2 className="text-3xl font-extrabold tracking-tight sm:text-5xl">アプリでも、ブラウザでも。</h2>
        </Reveal>
        <Reveal delay={120}>
          <p className="mx-auto mt-5 max-w-md text-[var(--ink-2)]">
            いま使っているアプリが下のどれかなら、そのまま揃います。ブラウザで開くWeb版も対象です。
          </p>
        </Reveal>
      </div>

      <ul className="sr-only">
        {services.map((s) => (
          <li key={s.name}>
            {s.name}({[s.desktop && "アプリ", s.web && "ブラウザ"].filter(Boolean).join("・")})
          </li>
        ))}
      </ul>
      <div aria-hidden className="relative mt-14 space-y-4">
        {rows.map((row, i) => (
          <div key={i} className="marquee overflow-hidden">
            <div className={`marquee-track ${i === 1 ? "rev" : ""}`} style={vars({ "--speed": `${38 + i * 6}s` })}>
              {[...row, ...row, ...row, ...row].map((s, j) => (
                <ServiceChip key={j} service={s} />
              ))}
            </div>
          </div>
        ))}
      </div>
      <Reveal className="relative mx-auto mt-10 max-w-xl px-5 text-center">
        <p className="text-xs leading-relaxed text-[var(--ink-3)]">
          「ブラウザ」バッジは、Safari / Chrome / Edge / Arc などでそのサービスのWeb版を開いたタブが対象、という意味です。
        </p>
      </Reveal>
    </section>
  )
}

/* ─────────────────────── 安心(夜) ─────────────────────── */

const FLOW_CHARS = ["明", "日", "の", "件", "E", "n", "t", "e", "r", "了", "解", "⌘"]

function Safety() {
  return (
    <section
      id="safety"
      data-track-section="safety"
      className="relative overflow-hidden bg-[var(--night)] px-5 py-28 text-[#f3f1ea] sm:py-36"
    >
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.07]"
        style={{
          backgroundImage: "linear-gradient(#fff 1px, transparent 1px), linear-gradient(90deg, #fff 1px, transparent 1px)",
          backgroundSize: "56px 56px",
          maskImage: "radial-gradient(ellipse 60% 50% at 50% 30%, #000, transparent)",
        }}
      />
      <div className="relative mx-auto max-w-5xl">
        <div className="text-center">
          <Reveal>
            <Eyebrow dark>PRIVACY</Eyebrow>
            <h2 className="text-3xl leading-tight font-extrabold tracking-tight sm:text-6xl sm:leading-tight">
              入力した文章は、
              <br />
              どこにも送りません。
            </h2>
          </Reveal>
        </div>

        {/* 文字は UniEnter の壁で止まり、インターネットには届かない */}
        <Reveal delay={150} className="mx-auto mt-16 max-w-3xl">
          <div aria-hidden className="relative h-36 sm:h-40">
            <div className="absolute top-1/2 left-0 flex -translate-y-1/2 flex-col items-center gap-1 text-white/45">
              <Keyboard className="size-7" strokeWidth={1.5} />
              <span className="hidden text-[11px] sm:inline">あなたのMac</span>
            </div>
            {FLOW_CHARS.map((c, i) => (
              <span
                key={i}
                className="flow-char font-mono text-base font-bold text-white/85"
                style={vars({ "--delay": `${(i * 3.2) / FLOW_CHARS.length}s`, "--dy": `${((i * 37) % 60) - 30}px` })}
              >
                {c}
              </span>
            ))}
            {/* 壁 = UniEnter */}
            <div className="wall-pulse absolute top-1/2 left-1/2 flex h-14 w-32 -translate-x-1/2 -translate-y-1/2 items-center justify-center gap-2 rounded-2xl bg-[var(--teal)] text-sm font-bold text-white">
              <CornerDownLeft className="size-4" /> UniEnter
            </div>
            {/* 途切れた通信線 */}
            <div className="absolute top-1/2 right-[12%] left-[calc(50%+72px)] -translate-y-1/2 border-t border-dashed border-white/15" />
            <span className="absolute top-1/2 left-[calc(50%+72px+(50%-72px-12%)/2)] flex size-6 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full bg-[var(--night)] text-xs text-white/50">
              ×
            </span>
            <div className="absolute top-1/2 right-0 flex -translate-y-1/2 flex-col items-center gap-1 text-white/30">
              <WifiOff className="size-7" strokeWidth={1.5} />
              <span className="hidden text-[11px] sm:inline">インターネット</span>
            </div>
          </div>
          <p className="mt-2 text-center font-mono text-xs tracking-widest text-white/40">送信量 0 バイト</p>
        </Reveal>

        <div className="mt-16 grid gap-4 sm:grid-cols-3">
          {[
            { icon: WifiOff, title: "通信しない", body: <>インターネット通信を一切行いません。打った文字の記録も保存もしません。</> },
            { icon: Languages, title: "変換中は触れない", body: <>日本語の変換を確定するEnterは、そのまま通します。</> },
            {
              icon: Code,
              title: "中身は公開",
              body: (
                <>
                  ソースコードはすべて{" "}
                  <a className="font-semibold text-white underline underline-offset-4" href={REPO_URL}>
                    GitHub
                  </a>{" "}
                  で読めます。
                </>
              ),
            },
          ].map(({ icon: Icon, title, body }, i) => (
            <Reveal key={title} delay={i * 120}>
              <div className="group h-full rounded-2xl border border-white/10 bg-white/[0.03] p-6 transition-colors duration-300 hover:border-white/25 hover:bg-white/[0.06]">
                <span className="mb-5 flex size-11 items-center justify-center rounded-xl bg-white/[0.07] text-[#e8f3f0] transition-transform duration-300 group-hover:-rotate-6">
                  <Icon className="size-5" />
                </span>
                <h3 className="mb-2 text-lg font-bold">{title}</h3>
                <p className="text-sm leading-relaxed text-white/60">{body}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ─────────────────────── はじめかた ─────────────────────── */

function Shot({ src, alt, caption }: { src: string; alt: string; caption: string }) {
  const [missing, setMissing] = useState(false)
  return (
    <figure className="min-w-0">
      {missing ? (
        <div className="flex h-40 items-center justify-center rounded-lg border-2 border-dashed border-[var(--line)] px-4 text-center text-xs text-[var(--ink-3)]">
          {alt}
        </div>
      ) : (
        <img
          src={src}
          alt={alt}
          loading="lazy"
          onError={() => setMissing(true)}
          className="mx-auto max-h-64 w-auto rounded-lg border border-[var(--line)] bg-white object-contain"
        />
      )}
      <figcaption className="mt-2 text-xs text-[var(--ink-3)]">{caption}</figcaption>
    </figure>
  )
}

function StepBlock({ n, title, children }: { n: number; title: string; children: ReactNode }) {
  return (
    <Reveal className="relative pl-16 sm:pl-24">
      <span className="absolute top-0 left-0 flex size-11 items-center justify-center rounded-full bg-[var(--teal)] text-lg font-extrabold text-white shadow-[0_0_0_8px_var(--paper)] sm:left-3">
        {n}
      </span>
      <h3 className="pt-1.5 text-xl font-extrabold sm:text-2xl">{title}</h3>
      <div className="mt-4">{children}</div>
    </Reveal>
  )
}

function Install() {
  const [ref, progress] = useScrollProgress<HTMLDivElement>("pass")
  return (
    <section id="install" data-track-section="install" className="bg-[var(--paper)] px-5 py-28 sm:py-36">
      <div className="mx-auto max-w-3xl">
        <Reveal className="mb-16 text-center">
          <Eyebrow>HOW TO START</Eyebrow>
          <h2 className="text-3xl font-extrabold tracking-tight sm:text-5xl">
            はじめかた<span className="ml-2 align-middle text-xl font-bold text-[var(--ink-3)] sm:text-2xl">(2分)</span>
          </h2>
        </Reveal>

        <div ref={ref} className="relative space-y-16">
          {/* レール: スクロールに合わせて墨が伸びる */}
          <div className="absolute top-2 bottom-2 left-[21px] w-0.5 bg-[var(--line)] sm:left-[33px]">
            <div
              className="h-full w-full origin-top bg-[var(--ink)]"
              style={{ transform: `scaleY(${progress})` }}
            />
          </div>

          <StepBlock n={1} title="ダウンロード">
            <p className="text-[var(--ink-2)]">UniEnter.pkg をダウンロードして、ダブルクリックします。</p>
            <div className="mt-5">
              <PrimaryCTA location="install" />
            </div>
          </StepBlock>

          <StepBlock n={2} title="Macに許可する(初回だけ)">
            <div className="mb-6 rounded-2xl bg-white p-5 text-sm shadow-[0_10px_30px_-20px_rgba(29,28,25,0.35)]">
              <p className="mb-1.5 font-bold">なぜMacに止められるの?</p>
              <p className="leading-relaxed text-[var(--ink-2)]">
                Appleの公証(年間の開発者登録が必要です)を申請中だからです。ソフトの中身に問題があるという意味ではありません。UniEnterはソースコードをすべて{" "}
                <a className="underline" href={REPO_URL}>
                  GitHub
                </a>{" "}
                で公開していて、インターネット通信を一切行いません。
              </p>
            </div>
            <p className="mb-5 text-sm text-[var(--ink-2)]">次の3クリックで開けます。</p>
            <div className="grid gap-6 sm:grid-cols-3">
              {[
                {
                  t: "1.「完了」を押す(「ゴミ箱に入れる」は押さない)",
                  src: "./assets/install/gatekeeper.png",
                  alt: "pkgを開いたときにmacOSが出す確認ダイアログ",
                  cap: "「完了」を押します。ここでゴミ箱に入れないでください。",
                },
                {
                  t: "2. システム設定 →「プライバシーとセキュリティ」→ 下までスクロール →「このまま開く」",
                  src: "./assets/install/settings-security.png",
                  alt: "システム設定のプライバシーとセキュリティ画面。下部のセキュリティ項目",
                  cap: "この項目は、開こうとした直後にだけ表示されます。",
                },
                {
                  t: "3. Touch IDまたはパスワードで確認 → インストーラが始まります",
                  src: "./assets/install/auth.png",
                  alt: "Touch IDまたはパスワードを求める確認シート",
                  cap: "ここまでで、インストールは終わりです。",
                },
              ].map((c, i) => (
                <Reveal key={c.src} delay={i * 110}>
                  <p className="mb-2 text-sm font-semibold sm:min-h-20">{c.t}</p>
                  <Shot src={c.src} alt={c.alt} caption={c.cap} />
                </Reveal>
              ))}
            </div>
            <details className="group mt-6 rounded-xl border border-[var(--line)] bg-white/60 px-4 py-3 text-sm">
              <summary className="cursor-pointer font-semibold marker:text-[var(--ink-3)]">うまくいかないときは</summary>
              <ul className="mt-3 space-y-2 text-[var(--ink-2)]">
                <li>手順2の表示が見つからない → 手順1をやり直してください。この項目は、開こうとした直後にだけ表示されます。</li>
                <li>macOS 15以降では、Finderで右クリック →「開く」は使えません。</li>
                <li>zip版も同じ手順です。</li>
                <li>
                  それでも開けないときは{" "}
                  <a className="underline" href="mailto:info@oc-to.com">
                    info@oc-to.com
                  </a>{" "}
                  まで(お使いのmacOSのバージョンを添えてください)。
                </li>
              </ul>
            </details>
          </StepBlock>

          <StepBlock n={3} title="使うアプリにチェック">
            <p className="mb-6 leading-relaxed text-[var(--ink-2)]">
              インストールが終わるとUniEnterが起動し、キー入力を扱うための許可(アクセシビリティ)を求めます。許可したら、使っているアプリにチェックを入れて終わりです。
            </p>
            <div className="grid gap-6 sm:grid-cols-2">
              <Shot
                src="./assets/install/accessibility.webp"
                alt="UniEnterが表示するアクセシビリティ許可の案内画面"
                caption="起動直後の案内。ボタンからシステム設定を開けます。"
              />
              <Shot
                src="./assets/install/settings.webp"
                alt="UniEnterの設定画面。使うアプリにチェックを入れる"
                caption="あとは、使うアプリにチェックを入れるだけです。"
              />
            </div>
          </StepBlock>
        </div>
      </div>
    </section>
  )
}

/* ─────────────────────── 価格 ─────────────────────── */

function CountUp({ to, run }: { to: number; run: boolean }) {
  const [n, setN] = useState(0)
  useEffect(() => {
    if (!run) return
    if (prefersReducedMotion()) {
      setN(to)
      return
    }
    let raf = 0
    const start = performance.now()
    const tick = (now: number) => {
      const t = clamp((now - start) / 1400)
      setN(Math.round(to * (1 - Math.pow(1 - t, 4))))
      if (t < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [run, to])
  return <>{n.toLocaleString("ja-JP")}</>
}

function Pricing() {
  const [ref, inView] = useInView<HTMLDivElement>(0.35)
  const cardRef = useRef<HTMLDivElement>(null)
  const onMove = (e: React.PointerEvent) => {
    const el = cardRef.current
    if (!el || e.pointerType !== "mouse") return
    const r = el.getBoundingClientRect()
    const x = (e.clientX - r.left) / r.width - 0.5
    const y = (e.clientY - r.top) / r.height - 0.5
    el.style.setProperty("--ry", `${x * 6}deg`)
    el.style.setProperty("--rx", `${-y * 6}deg`)
  }
  const onLeave = () => {
    cardRef.current?.style.setProperty("--ry", "0deg")
    cardRef.current?.style.setProperty("--rx", "0deg")
  }
  return (
    <section id="pricing" data-track-section="pricing" className="bg-white px-5 py-28 sm:py-36">
      <div className="mx-auto max-w-4xl">
        <Reveal className="mb-14 text-center">
          <Eyebrow>PRICING</Eyebrow>
          <h2 className="text-3xl font-extrabold tracking-tight sm:text-5xl">価格</h2>
        </Reveal>
        <div ref={ref} className={inView ? "in" : ""}>
          <div
            ref={cardRef}
            onPointerMove={onMove}
            onPointerLeave={onLeave}
            className="tilt grid overflow-hidden rounded-[28px] border border-[var(--line)] bg-[var(--paper)] shadow-[0_50px_90px_-50px_rgba(29,28,25,0.45)] md:grid-cols-[1.1fr_1fr]"
          >
            <div className="flex flex-col justify-center p-8 sm:p-12">
              <p className="text-sm font-bold text-[var(--ink-2)]">買い切り</p>
              <p className="mt-2 flex items-baseline gap-2 font-extrabold tracking-tight">
                <span className="text-5xl tabular-nums sm:text-7xl">
                  ¥<CountUp to={1480} run={inView} />
                </span>
                <span className="text-base font-medium whitespace-nowrap text-[var(--ink-3)]">(税込)</span>
              </p>
              <div className="mt-8">
                <p className="mb-2.5 text-xs font-bold tracking-[0.15em] text-[var(--ink-3)]">まずは 14日間、全機能を無料で</p>
                <div className="grid grid-cols-7 gap-1.5">
                  {Array.from({ length: 14 }, (_, i) => (
                    <span
                      key={i}
                      className="day flex aspect-square items-center justify-center rounded-md bg-white text-[10px] font-bold text-[var(--ink-3)] shadow-[inset_0_0_0_1px_var(--line)]"
                      style={vars({ "--i": i })}
                    >
                      {i + 1}
                    </span>
                  ))}
                </div>
              </div>
            </div>
            <div className="flex flex-col justify-center border-t border-[var(--line)] bg-white p-8 sm:p-12 md:border-t-0 md:border-l">
              <ul className="space-y-4 text-[15px]">
                {[
                  "すべての対象アプリと、そのWeb版",
                  "以後のアップデートは追加費用なし",
                  "ご本人が使うMacなら、台数の制限なし",
                ].map((t, i) => (
                  <li key={t} className="rv-child flex gap-3" style={vars({ "--d": `${400 + i * 120}ms` })}>
                    <span className="mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full bg-[var(--teal-tint)] text-[var(--teal-ink)]">
                      <Check className="size-3" strokeWidth={3} />
                    </span>
                    {t}
                  </li>
                ))}
              </ul>
              <div className="mt-9 flex flex-wrap items-center gap-3">
                <PrimaryCTA location="pricing" />
                <a
                  href={CHECKOUT_URL}
                  onClick={() => track("purchase_click", { location: "pricing" })}
                  className="group inline-flex h-13 items-center gap-2 rounded-full border border-[var(--ink)]/15 bg-white px-6 text-[15px] font-bold transition-colors hover:border-[var(--ink)]/40"
                >
                  購入する
                  <ArrowRight className="size-4 transition-transform duration-300 group-hover:translate-x-1" />
                </a>
              </div>
              <p className="mt-4 text-sm leading-relaxed text-[var(--ink-3)]">
                購入後すぐ、画面にライセンスキーが表示されます。決済はPolar(販売代理)が行います。{" "}
                <a className="underline" href="./tokushoho.html">
                  特定商取引法に基づく表記
                </a>
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ─────────────────────── FAQ ─────────────────────── */

function Faq() {
  return (
    <section id="faq" data-track-section="faq" className="bg-[var(--paper)] px-5 py-28 sm:py-36">
      <div className="mx-auto grid max-w-5xl gap-12 lg:grid-cols-[280px_1fr]">
        <div>
          <div className="lg:sticky lg:top-28">
            <Reveal>
              <Eyebrow>FAQ</Eyebrow>
              <h2 className="text-3xl font-extrabold tracking-tight sm:text-4xl">よくある質問</h2>
            </Reveal>
            <nav className="mt-8 hidden flex-col gap-1 lg:flex">
              {faqGroups.map((g, i) => (
                <a
                  key={g.title}
                  href={`#faq-${i}`}
                  className="group flex items-center gap-3 py-1.5 text-sm font-semibold text-[var(--ink-2)] hover:text-[var(--ink)]"
                >
                  <span className="h-px w-4 bg-[var(--ink)]/25 transition-all duration-300 group-hover:w-8 group-hover:bg-[var(--ink)]" />
                  {g.title}
                </a>
              ))}
            </nav>
          </div>
        </div>
        <div className="faq space-y-12">
          {faqGroups.map((group, i) => (
            <Reveal key={group.title}>
              <div id={`faq-${i}`} className="scroll-mt-28">
                <h3 className="mb-2 text-xs font-bold tracking-[0.2em] text-[var(--ink-3)]">{group.title}</h3>
                <Accordion type="single" collapsible className="rounded-2xl border border-[var(--line)] bg-white px-5 sm:px-6">
                  {group.items.map(({ q, a }) => (
                    <AccordionItem key={q} value={q} className="border-[var(--line)]">
                      <AccordionTrigger className="text-left font-bold">{q}</AccordionTrigger>
                      <AccordionContent className="leading-relaxed text-[var(--ink-2)]">{a}</AccordionContent>
                    </AccordionItem>
                  ))}
                </Accordion>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ─────────────────────── 最終CTA: ⌘+Enterを押せる ─────────────────────── */

function FinalCTA() {
  const [cmd, setCmd] = useState(false)
  const [ret, setRet] = useState(false)
  const [sent, setSent] = useState<number | null>(null)
  const ctaRef = useRef<HTMLDivElement>(null)
  const [ref, inView] = useInView<HTMLElement>(0.4, false)

  const fire = useCallback(() => {
    setSent(Date.now())
    ctaRef.current?.animate(
      [{ transform: "scale(1)" }, { transform: "scale(1.06)" }, { transform: "scale(1)" }],
      { duration: 500, easing: "cubic-bezier(.2,.9,.25,1.3)" },
    )
  }, [])

  // このセクションが見えている間だけ、ページ上の ⌘+Enter に反応する(入力欄では無効)
  useEffect(() => {
    if (!inView) return
    const down = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement).tagName
      if (tag === "TEXTAREA" || tag === "INPUT") return
      if (e.key === "Meta" || e.key === "Control") setCmd(true)
      if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        setRet(true)
        window.setTimeout(() => setRet(false), 160)
        fire()
      }
    }
    const up = (e: KeyboardEvent) => {
      if (e.key === "Meta" || e.key === "Control") setCmd(false)
    }
    window.addEventListener("keydown", down)
    window.addEventListener("keyup", up)
    return () => {
      window.removeEventListener("keydown", down)
      window.removeEventListener("keyup", up)
    }
  }, [inView, fire])

  const clickKeys = async () => {
    setCmd(true)
    await sleep(140)
    setRet(true)
    fire()
    await sleep(160)
    setRet(false)
    setCmd(false)
  }

  return (
    <section ref={ref} data-track-section="final-cta" className="relative overflow-hidden bg-white px-5 py-28 text-center sm:py-40">
      <div className="dotgrid pointer-events-none absolute inset-0 opacity-70" />
      <div className="relative">
        <Reveal>
          <button
            type="button"
            onClick={clickKeys}
            aria-label="⌘とEnterのキー(押すと送信のアニメーション)"
            className="relative mx-auto mb-14 flex items-end justify-center gap-3 outline-none"
          >
            {sent && (
              <span
                key={sent}
                className="sent-fly pointer-events-none absolute -top-12 left-1/2 -ml-16 w-32 rounded-2xl rounded-br-md bg-[var(--ink)] px-3 py-1.5 text-xs font-bold text-white"
              >
                送信しました ✓
              </span>
            )}
            <Key down={cmd} className="h-20 w-24 text-3xl sm:h-24 sm:w-28">
              ⌘
            </Key>
            <span className="pb-6 text-2xl font-light text-[var(--ink-3)]">+</span>
            <Key down={ret} className="h-20 w-40 text-xl sm:h-24 sm:w-52">
              return <CornerDownLeft className="size-6" />
            </Key>
          </button>
          <p className="-mt-8 mb-10 text-xs text-[var(--ink-3)]">押してみてください<span className="hidden sm:inline">(キーボードの ⌘ + Enter でも)</span></p>
        </Reveal>
        <Reveal delay={100}>
          <h2 className="text-3xl leading-tight font-extrabold tracking-tight sm:text-6xl sm:leading-tight">
            Enterでの
            <br className="sm:hidden" />
            うっかり送信を防ぎます
          </h2>
        </Reveal>
        <Reveal delay={200}>
          <p className="mx-auto mt-5 max-w-lg text-[var(--ink-2)]">
            14日間、全機能をそのまま試せます。合わなければ、削除するだけです。
          </p>
        </Reveal>
        <Reveal delay={300}>
          <div className="mt-9 flex flex-wrap items-center justify-center gap-3">
            <div ref={ctaRef}>
              <PrimaryCTA location="final" />
            </div>
            <GhostCTA href="#install">開き方(2分)</GhostCTA>
          </div>
          <p className="mt-4 text-xs text-[var(--ink-3)]">macOS 13以降 / Mac用インストーラ(.pkg・約3MB)</p>
        </Reveal>
      </div>
    </section>
  )
}

/* ─────────────────────── Nav / Footer ─────────────────────── */

function Nav() {
  const [scrolled, setScrolled] = useState(false)
  const [p, setP] = useState(0)
  useEffect(() => {
    const on = () => {
      setScrolled(window.scrollY > 24)
      const max = document.documentElement.scrollHeight - window.innerHeight
      setP(max > 0 ? window.scrollY / max : 0)
    }
    on()
    window.addEventListener("scroll", on, { passive: true })
    return () => window.removeEventListener("scroll", on)
  }, [])
  return (
    <>
      <div className="fixed inset-x-0 top-0 z-[60] h-0.5 origin-left bg-[var(--teal)]" style={{ transform: `scaleX(${p})` }} />
      <nav className="fixed inset-x-0 top-3 z-50 flex justify-center px-3">
        <div
          className={`flex w-full max-w-3xl items-center justify-between rounded-full border py-1.5 pr-1.5 pl-4 transition-all duration-500 ${
            scrolled
              ? "border-[var(--line)] bg-white/80 shadow-[0_10px_30px_-18px_rgba(29,28,25,0.4)] backdrop-blur-xl"
              : "border-transparent bg-transparent"
          }`}
        >
          <a href="#" className="flex items-center gap-2 font-extrabold">
            <span className="flex size-7 items-center justify-center rounded-lg bg-[var(--teal)] text-white">
              <CornerDownLeft className="size-4" strokeWidth={2.5} />
            </span>
            UniEnter
          </a>
          <div className="flex items-center gap-1 text-sm font-semibold">
            <a href={REPO_URL} className="hidden rounded-full px-3 py-2 text-[var(--ink-2)] hover:text-[var(--ink)] sm:block">
              ソースコード(GitHub)
            </a>
            <a href="#pricing" className="rounded-full px-3 py-2 text-[var(--ink-2)] hover:text-[var(--ink)]">
              価格
            </a>
            <a
              href={PKG_URL}
              onClick={() => track("download_click", { file_type: "pkg", location: "nav" })}
              className="rounded-full bg-[var(--teal)] px-4 py-2 text-white transition-transform hover:-translate-y-px"
            >
              無料で試す
            </a>
          </div>
        </div>
      </nav>
    </>
  )
}

function Footer() {
  return (
    <footer className="border-t border-[var(--line)] bg-[var(--paper)] px-5 py-14 text-center text-xs text-[var(--ink-3)]">
      <p className="mb-6 flex items-center justify-center gap-2 text-base font-extrabold text-[var(--ink)]">
        <span className="flex size-7 items-center justify-center rounded-lg bg-[var(--teal)] text-white">
          <CornerDownLeft className="size-4" strokeWidth={2.5} />
        </span>
        UniEnter
      </p>
      <p className="mb-3 flex flex-wrap justify-center gap-x-5 gap-y-2">
        <a className="hover:text-[var(--ink)]" href={REPO_URL}>
          ソースコード(GitHub)
        </a>
        <a className="hover:text-[var(--ink)]" href={ZIP_URL} onClick={() => track("download_click", { file_type: "zip", location: "footer" })}>
          zip版
        </a>
        <a className="hover:text-[var(--ink)]" href={RELEASES_URL}>
          リリース一覧
        </a>
        <a className="hover:text-[var(--ink)]" href="#pricing">
          価格
        </a>
        <a className="hover:text-[var(--ink)]" href="./terms.html">
          利用規約
        </a>
        <a className="hover:text-[var(--ink)]" href="./privacy.html">
          プライバシーポリシー
        </a>
        <a className="hover:text-[var(--ink)]" href="./tokushoho.html">
          特定商取引法に基づく表記
        </a>
      </p>
      <p>
        © 2026{" "}
        <a className="underline" href="https://oc-to.com" target="_blank" rel="noopener noreferrer">
          octo
        </a>{" "}
        — お問い合わせ:{" "}
        <a className="underline" href="mailto:info@oc-to.com">
          info@oc-to.com
        </a>
      </p>
      <p className="mx-auto mt-2 max-w-lg">記載の製品名は各社の商標です。本アプリは各社と無関係の個人開発ソフトウェアです。</p>
    </footer>
  )
}

export default function App() {
  useEffect(() => observeSections(), [])
  return (
    <div className="lpn min-h-screen">
      <Nav />
      <Hero />
      <div className="flex justify-center pb-6">
        <ArrowDown className="size-5 animate-bounce text-[var(--ink-3)]" aria-hidden />
      </div>
      <BeforeAfter />
      <Services />
      <Safety />
      <Install />
      <Pricing />
      <Faq />
      <FinalCTA />
      <Footer />
    </div>
  )
}
