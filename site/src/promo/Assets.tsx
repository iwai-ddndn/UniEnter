import { Code, CornerDownLeft, Languages, WifiOff } from "lucide-react"
import type { CSSProperties, ReactNode } from "react"
import { createRoot } from "react-dom/client"
import { services, type Service } from "../brands"
import "../index.css"
import "../landing.css"
import "./promo.css"

/*
 * SNS用の静止画アセット(sns-assets.html?a=<名前>)。ビルド対象外・dev server専用。
 * 撮影: marketing/sns/render-assets.mjs。見た目はLP(紙の生成り地 × 墨 × ティール1色)に揃える。
 */

export const ASSETS: Record<string, { w: number; h: number }> = {
  "profile-icon": { w: 540, h: 540 }, // → 1080×1080
  "x-header": { w: 750, h: 250 }, // → 1500×500
  "x-post-main": { w: 800, h: 450 }, // → 1600×900
  "x-post-rule": { w: 800, h: 450 },
  "x-post-safety": { w: 800, h: 450 },
  "ig-01-hook": { w: 540, h: 675 }, // → 1080×1350
  "ig-02-before": { w: 540, h: 675 },
  "ig-03-rule": { w: 540, h: 675 },
  "ig-04-apps": { w: 540, h: 675 },
  "ig-05-safety": { w: 540, h: 675 },
  "ig-06-cta": { w: 540, h: 675 },
  "reel-cover": { w: 540, h: 960 }, // → 1080×1920
}

const INK = "var(--ink)"
const shown = services.filter((s) => !s.hideInLogoRow)

function Mark({ size }: { size: number }) {
  return (
    <span className="flex shrink-0 items-center justify-center text-white" style={{ width: size, height: size, borderRadius: size * 0.24, background: "var(--teal)" }}>
      <CornerDownLeft size={size * 0.56} strokeWidth={2.6} />
    </span>
  )
}

function Brand({ size = 18, dark }: { size?: number; dark?: boolean }) {
  return (
    <span className="flex items-center gap-2 font-extrabold" style={{ fontSize: size, color: dark ? "#f3f1ea" : INK }}>
      <Mark size={size * 1.35} /> UniEnter
    </span>
  )
}

function Key({ children, style }: { children: ReactNode; style?: CSSProperties }) {
  return (
    <span className="kc" style={style}>
      {children}
    </span>
  )
}

/* 「Enter → 改行 / ⌘ Enter → 送信」の2行ルール */
function Rule({ scale = 1 }: { scale?: number }) {
  const k = { height: 44 * scale, padding: `0 ${14 * scale}px`, fontSize: 17 * scale, borderRadius: 10 * scale }
  return (
    <div className="flex flex-col gap-4" style={{ gap: 16 * scale }}>
      <p className="flex items-center" style={{ gap: 12 * scale }}>
        <Key style={k}>
          return <CornerDownLeft size={16 * scale} />
        </Key>
        <span className="font-extrabold" style={{ fontSize: 24 * scale, color: "var(--teal)" }}>
          → 改行
        </span>
      </p>
      <p className="flex items-center" style={{ gap: 12 * scale }}>
        <Key style={{ ...k, width: 48 * scale, padding: 0 }}>⌘</Key>
        <Key style={k}>
          return <CornerDownLeft size={16 * scale} />
        </Key>
        <span className="font-extrabold" style={{ fontSize: 24 * scale }}>
          → 送信
        </span>
      </p>
    </div>
  )
}

function Logo({ s, size }: { s: Service; size: number }) {
  return (
    <span className="flex items-center justify-center" style={{ width: size, height: size, borderRadius: size * 0.28, background: `#${s.hex}`, boxShadow: "0 10px 18px -10px rgba(29,28,25,.45)" }}>
      {s.path && (
        <svg viewBox={s.viewBox ?? "0 0 24 24"} style={{ width: size * 0.52, height: size * 0.52, fill: "#fff" }}>
          <path d={s.path} />
        </svg>
      )}
    </span>
  )
}

function Bubble({ children, mine = true, muted }: { children: ReactNode; mine?: boolean; muted?: boolean }) {
  return (
    <div className={`flex ${mine ? "justify-end" : ""}`}>
      <p
        className="max-w-[85%] rounded-2xl px-3.5 py-2 text-[14px] leading-relaxed whitespace-pre-wrap"
        style={mine ? { background: muted ? "#6b6963" : INK, color: "#fff", borderBottomRightRadius: 6 } : { background: "var(--paper-2)", borderBottomLeftRadius: 6 }}
      >
        {children}
      </p>
    </div>
  )
}

function Win({ title, on, children, width = 400 }: { title: string; on?: boolean; children: ReactNode; width?: number }) {
  return (
    <div className="overflow-hidden rounded-[18px] border bg-white text-left" style={{ width, borderColor: "var(--line)", boxShadow: "0 30px 60px -30px rgba(29,28,25,.4)" }}>
      <div className="flex items-center gap-2 border-b px-4 py-2.5" style={{ borderColor: "var(--line)" }}>
        {[0, 1, 2].map((i) => (
          <i key={i} className="size-2.5 rounded-full" style={{ background: "#e6e3db" }} />
        ))}
        <span className="ml-1.5 text-[12px] font-bold" style={{ color: "var(--ink-2)" }}>
          {title}
        </span>
        <span
          className="ml-auto rounded-full px-2 py-0.5 text-[10px] font-bold"
          style={on ? { background: "var(--teal-tint)", color: "var(--teal-ink)" } : { background: "var(--paper-2)", color: "var(--ink-3)" }}
        >
          UniEnter {on ? "ON" : "なし"}
        </span>
      </div>
      <div className="flex flex-col gap-2 px-4 py-4">{children}</div>
    </div>
  )
}

function Frame({ w, h, dark, children, className = "" }: { w: number; h: number; dark?: boolean; children: ReactNode; className?: string }) {
  return (
    <div className={`lpn promo relative overflow-hidden ${className}`} style={{ width: w, height: h, background: dark ? "var(--night)" : "var(--paper)", fontFamily: '"Hiragino Sans", sans-serif' }}>
      {!dark && <div className="dotgrid absolute inset-0" style={{ opacity: 0.8 }} />}
      <div className="relative h-full w-full">{children}</div>
    </div>
  )
}

const H = ({ children, size, dark, className = "" }: { children: ReactNode; size: number; dark?: boolean; className?: string }) => (
  <p className={`font-extrabold tracking-tight ${className}`} style={{ fontSize: size, lineHeight: 1.3, color: dark ? "#f3f1ea" : INK }}>
    {children}
  </p>
)

const Sub = ({ children, size = 15, dark }: { children: ReactNode; size?: number; dark?: boolean }) => (
  <p className="font-bold" style={{ fontSize: size, lineHeight: 1.6, color: dark ? "rgba(255,255,255,.6)" : "var(--ink-2)" }}>
    {children}
  </p>
)

const SAFETY = [
  { I: WifiOff, h: "通信しない", b: "インターネット通信を一切しません。打った文字の記録も保存もしません。" },
  { I: Languages, h: "変換中は触れない", b: "日本語の変換を確定するEnterは、そのまま通します。" },
  { I: Code, h: "中身は公開", b: "ソースコードはすべてGitHubで読めます。" },
]

function SafetyCards({ vertical }: { vertical?: boolean }) {
  return (
    <div className={vertical ? "flex flex-col gap-3" : "grid grid-cols-3 gap-3"} style={vertical ? {} : { display: "grid", gridTemplateColumns: "repeat(3, 1fr)" }}>
      {SAFETY.map(({ I, h, b }) => (
        <div key={h} className={`rounded-2xl border p-4 ${vertical ? "flex items-start gap-4" : ""}`} style={{ borderColor: "rgba(255,255,255,.12)", background: "rgba(255,255,255,.04)", color: "#f3f1ea" }}>
          <span className="flex size-10 shrink-0 items-center justify-center rounded-xl" style={{ background: "rgba(255,255,255,.08)", color: "#e8f3f0" }}>
            <I size={20} />
          </span>
          <div className={vertical ? "" : "mt-3"}>
            <p className="text-[16px] font-bold">{h}</p>
            <p className="mt-1 text-[12px] leading-relaxed" style={{ color: "rgba(255,255,255,.6)" }}>
              {b}
            </p>
          </div>
        </div>
      ))}
    </div>
  )
}

function Page({ n }: { n: string }) {
  return (
    <span className="absolute top-6 right-6 text-[12px] font-bold tabular-nums" style={{ color: "var(--ink-3)" }}>
      {n} / 6
    </span>
  )
}

function Asset({ name }: { name: string }) {
  const { w, h } = ASSETS[name]
  switch (name) {
    case "profile-icon":
      // 丸く切り抜かれても↵が欠けないよう、全面ティール+中央に大きめの記号
      return (
        <div className="flex items-center justify-center text-white" style={{ width: w, height: h, background: "#0f7b6c" }}>
          <CornerDownLeft size={250} strokeWidth={2.4} />
        </div>
      )
    case "x-header":
      // 左下はアイコンが重なるので、要素は中央〜右に寄せる
      return (
        <Frame w={w} h={h}>
          <div className="absolute inset-y-0 right-10 flex items-center gap-9" style={{ paddingBottom: 24 }}>
            <div>
              <H size={26}>Enterでのうっかり送信を防ぎます</H>
              <div className="mt-2">
                <Sub size={13}>チャットアプリ/AIアプリで、Enterは改行・送信は⌘Enterに統一(Mac)</Sub>
              </div>
            </div>
            <Rule scale={0.72} />
          </div>
        </Frame>
      )
    case "x-post-main":
      return (
        <Frame w={w} h={h}>
          <div className="flex h-full items-center gap-10 px-14">
            <div className="flex-1">
              <Brand size={16} />
              <div className="mt-5">
                <H size={40}>
                  Enterでの
                  <br />
                  うっかり送信を
                  <br />
                  防ぎます
                </H>
              </div>
              <div className="mt-4">
                <Sub>Enterは改行、送信は⌘Enter。Macのチャット、ぜんぶで。</Sub>
              </div>
            </div>
            <Win title="# 企画チーム" on width={330}>
              <Bubble mine={false}>明日の件、どうなりました?</Bubble>
              <Bubble>{"明日の打ち合わせですが、\n15時からに変更できますか?\n資料は前日にお送りします。"}</Bubble>
              <div className="mt-1 rounded-xl border px-3 py-2 text-[13px]" style={{ borderColor: "var(--line)", color: "var(--ink-3)" }}>
                Enterで改行、⌘Enterで送信
              </div>
            </Win>
          </div>
        </Frame>
      )
    case "x-post-rule":
      return (
        <Frame w={w} h={h}>
          <div className="flex h-full items-center justify-center gap-14 px-14">
            <div>
              <H size={34}>
                どのアプリでも、
                <br />
                ルールは2つだけ。
              </H>
              <div className="mt-8">
                <Rule scale={1} />
              </div>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(4, auto)", gap: 14 }}>
              {shown.slice(0, 12).map((s) => (
                <Logo key={s.name} s={s} size={52} />
              ))}
            </div>
          </div>
          <span className="absolute right-6 bottom-5">
            <Brand size={13} />
          </span>
        </Frame>
      )
    case "x-post-safety":
      return (
        <Frame w={w} h={h} dark>
          <div className="flex h-full flex-col justify-center px-14">
            <H size={36} dark>
              入力した文章は、どこにも送りません。
            </H>
            <div className="mt-8">
              <SafetyCards />
            </div>
          </div>
          <span className="absolute right-6 bottom-5">
            <Brand size={13} dark />
          </span>
        </Frame>
      )
    case "ig-01-hook":
      return (
        <Frame w={w} h={h}>
          <Page n="1" />
          <div className="flex h-full flex-col justify-center px-10">
            <H size={40}>
              改行したかった
              <br />
              だけなのに、
              <br />
              送ってしまった。
            </H>
            <div className="mt-8">
              <Win title="# 企画チーム" width={460}>
                <Bubble mine={false}>明日の件、どうなりました?</Bubble>
                <Bubble>明日の打ち合わせですが、</Bubble>
                <p className="text-right text-[11px] font-bold" style={{ color: "var(--ink-3)" }}>
                  送信済み ― 書きかけのまま
                </p>
              </Win>
            </div>
            <p className="mt-8 text-[14px] font-bold" style={{ color: "var(--ink-3)" }}>
              → スワイプ
            </p>
          </div>
        </Frame>
      )
    case "ig-02-before":
      return (
        <Frame w={w} h={h} className="">
          <div className="absolute inset-0" style={{ background: "radial-gradient(ellipse 70% 65% at 50% 50%, transparent 35%, rgba(29,28,25,.22) 75%, rgba(29,28,25,.45) 100%)" }} />
          <Page n="2" />
          <div className="relative flex h-full flex-col justify-center px-10">
            <span className="mb-4 self-start rounded-full px-3 py-1 text-[12px] font-bold text-white" style={{ background: INK }}>
              これまで
            </span>
            <H size={30}>
              AIへの長い指示も、
              <br />
              1行目だけで送信。
            </H>
            <div className="mt-7" style={{ filter: "grayscale(.6)" }}>
              <Win title="AIアシスタント" width={460}>
                <Bubble>以下の条件で旅程を組んで:</Bubble>
                <Bubble mine={false}>承知しました。どのような条件でしょうか?</Bubble>
              </Win>
            </div>
            <div className="mt-7">
              <Sub size={16}>取り消して、謝って、書き直す。</Sub>
            </div>
          </div>
        </Frame>
      )
    case "ig-03-rule":
      return (
        <Frame w={w} h={h}>
          <Page n="3" />
          <div className="flex h-full flex-col justify-center px-10">
            <span className="mb-4 self-start rounded-full px-3 py-1 text-[12px] font-bold" style={{ background: "var(--teal-tint)", color: "var(--teal-ink)" }}>
              UniEnterを入れると
            </span>
            <H size={34}>
              Enterは改行。
              <br />
              送信は⌘Enter。
            </H>
            <div className="mt-8">
              <Rule scale={1.05} />
            </div>
            <div className="mt-9">
              <Sub size={16}>
                対象にしたアプリは、この2つだけ。
                <br />
                各アプリの設定画面は、もう開かなくていい。
              </Sub>
            </div>
          </div>
        </Frame>
      )
    case "ig-04-apps":
      return (
        <Frame w={w} h={h}>
          <Page n="4" />
          <div className="flex h-full flex-col justify-center px-10">
            <H size={34}>
              アプリでも、
              <br />
              ブラウザでも。
            </H>
            <div className="mt-8" style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", rowGap: 18, columnGap: 10 }}>
              {shown.slice(0, 12).map((s) => (
                <div key={s.name} className="flex flex-col items-center gap-1.5">
                  <Logo s={s} size={64} />
                  <span className="text-[11px] font-bold whitespace-nowrap" style={{ color: "var(--ink-2)" }}>
                    {s.name}
                  </span>
                </div>
              ))}
            </div>
            <div className="mt-7">
              <Sub size={13}>Safari / Chrome / Edge / Arc で開いたWeb版も対象です。</Sub>
            </div>
          </div>
        </Frame>
      )
    case "ig-05-safety":
      return (
        <Frame w={w} h={h} dark>
          <span className="absolute top-6 right-6 text-[12px] font-bold" style={{ color: "rgba(255,255,255,.45)" }}>
            5 / 6
          </span>
          <div className="flex h-full flex-col justify-center px-10">
            <H size={32} dark>
              入力した文章は、
              <br />
              どこにも送りません。
            </H>
            <div className="mt-8">
              <SafetyCards vertical />
            </div>
          </div>
        </Frame>
      )
    case "ig-06-cta":
      return (
        <Frame w={w} h={h}>
          <Page n="6" />
          <div className="flex h-full flex-col items-center justify-center px-10 text-center">
            <Mark size={84} />
            <p className="mt-5 text-[42px] font-extrabold tracking-tight">UniEnter</p>
            <div className="mt-2">
              <Sub size={17}>Enterでのうっかり送信を防ぎます</Sub>
            </div>
            <div className="mt-7 flex gap-2">
              {["14日間無料", "買い切り ¥1,480", "macOS 13以降"].map((x) => (
                <span key={x} className="rounded-full border bg-white px-3 py-1.5 text-[12px] font-bold" style={{ borderColor: "var(--line)" }}>
                  {x}
                </span>
              ))}
            </div>
            <p className="mt-8 rounded-full px-6 py-3 text-[17px] font-extrabold text-white" style={{ background: "var(--teal)" }}>
              プロフィールのリンクから
            </p>
            <p className="mt-3 text-[13px] font-bold" style={{ color: "var(--ink-3)" }}>
              unienter.oc-to.com
            </p>
          </div>
        </Frame>
      )
    case "reel-cover":
      return (
        <Frame w={w} h={h}>
          <div className="flex h-full flex-col items-center justify-center px-10 text-center">
            <Mark size={96} />
            <div className="mt-8">
              <H size={44}>
                Enterでの
                <br />
                うっかり送信を
                <br />
                防ぎます
              </H>
            </div>
            <div className="mt-5">
              <Sub size={18}>Macのチャット・AIアプリ、ぜんぶで。</Sub>
            </div>
            <div className="mt-10">
              <Rule scale={1} />
            </div>
          </div>
        </Frame>
      )
  }
  return null
}

const name = new URLSearchParams(location.search).get("a") ?? "x-post-main"
createRoot(document.getElementById("root")!).render(<Asset name={name} />)
;(window as unknown as { __ready: boolean }).__ready = true
