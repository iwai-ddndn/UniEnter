import { CornerDownLeft, Code, Languages, Sparkles, WifiOff } from "lucide-react"
import { type CSSProperties, type ReactNode, useEffect, useState } from "react"
import { flushSync } from "react-dom"
import { services, type Service } from "../brands"

/*
 * SNS用プロダクト紹介動画のコマ描画ページ(promo.html。ビルド対象外・dev server専用)。
 * すべての見た目は時刻 t(秒)だけから決まる。CSSアニメーション・transitionは使わない
 * (1コマずつ撮るので、実時間で動くものがあるとコマがずれる)。
 * 撮影: marketing/sns/render-video.mjs が window.__setT(t) を呼んでは撮る。
 *   ?format=story  → 1080×1920(IG リール / ストーリーズ)
 *   ?format=square → 1080×1080(X / IG フィード)
 *   ?t=12.3        → その時刻で静止(確認用)
 */

export const DURATION = 28

const clamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n))
const prog = (t: number, a: number, b: number) => clamp((t - a) / (b - a))
const easeOut = (x: number) => 1 - Math.pow(1 - x, 3)
const easeBack = (x: number) => {
  const c = 1.7
  return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2)
}
const typed = (s: string, t: number, a: number, b: number) => {
  const chars = [...s]
  return chars.slice(0, Math.round(chars.length * prog(t, a, b))).join("")
}
const pressed = (t: number, at: number, dur = 0.2) => t >= at && t < at + dur

/* 時刻 at から出てくる(下から・少し拡大・ぼかし解除) */
function appear(t: number, at: number, d = 0.45, dist = 24): CSSProperties {
  const p = prog(t, at, at + d)
  const e = easeBack(p)
  return {
    opacity: clamp(p * 1.6),
    transform: `translateY(${(1 - e) * dist}px) scale(${0.94 + 0.06 * e})`,
    filter: `blur(${(1 - clamp(p * 1.4)) * 6}px)`,
  }
}

type Fmt = "story" | "square"

/* ─────────── 部品 ─────────── */

function Key({ children, down, teal, style }: { children: ReactNode; down?: boolean; teal?: boolean; style?: CSSProperties }) {
  return (
    <span className={`kc ${down ? "down" : ""} ${teal && down ? "teal" : ""}`} style={style}>
      {children}
    </span>
  )
}

function Keys({ t, cmdAt = [], retAt = [], newlineAt = [], sendAt = [], oopsAt = [] }: { t: number; cmdAt?: [number, number][]; retAt?: number[]; newlineAt?: number[]; sendAt?: number[]; oopsAt?: number[] }) {
  const cmdDown = cmdAt.some(([a, b]) => t >= a && t < b)
  const retDown = retAt.some((a) => pressed(t, a))
  const pop = [...newlineAt.map((a) => ({ a, kind: "nl" as const })), ...sendAt.map((a) => ({ a, kind: "send" as const })), ...oopsAt.map((a) => ({ a, kind: "oops" as const }))]
    .filter(({ a }) => t >= a && t < a + 0.9)
    .at(-1)
  const popP = pop ? prog(t, pop.a, pop.a + 0.9) : 0
  return (
    <div className="relative z-10 -mt-6 flex items-end justify-center gap-3">
      <Key down={cmdDown} style={{ height: 64, width: 80, fontSize: 24, flexDirection: "column", gap: 0 }}>
        ⌘<span style={{ fontSize: 10, color: "var(--ink-3)", fontWeight: 600 }}>command</span>
      </Key>
      <span className="relative">
        <Key down={retDown} teal={pop?.kind === "nl"} style={{ height: 64, width: 150, fontSize: 19 }}>
          return <CornerDownLeft size={20} />
        </Key>
        {pop && (
          <span
            className="absolute left-1/2 rounded-full px-3 py-1 text-[13px] font-bold whitespace-nowrap text-white"
            style={{
              top: -40,
              background: pop.kind === "nl" ? "var(--teal)" : "var(--ink)",
              opacity: popP < 0.15 ? popP / 0.15 : popP > 0.75 ? (1 - popP) / 0.25 : 1,
              transform: `translate(-50%, ${-popP * 16}px)`,
            }}
          >
            {pop.kind === "nl" ? "↵ 改行" : pop.kind === "oops" ? "Enter → 送信されてしまう" : "⌘ + Enter → 送信"}
          </span>
        )}
      </span>
    </div>
  )
}

type M = { at: number; text: string; role: "me" | "other" | "ai"; shakeAt?: number; stamp?: string }

function Window({
  t,
  kind,
  on,
  msgs,
  composer,
  height = 300,
}: {
  t: number
  kind: "chat" | "agent"
  on?: boolean
  msgs: M[]
  composer: string
  height?: number
}) {
  const lines = composer.split("\n")
  return (
    <div
      className="overflow-hidden rounded-[22px] border bg-white text-left"
      style={{ borderColor: "var(--line)", boxShadow: "0 40px 80px -30px rgba(29,28,25,0.35)", background: kind === "agent" ? "#fcfbf9" : "#fff" }}
    >
      <div className="flex items-center gap-2 px-4 py-3" style={{ borderBottom: kind === "chat" ? "1px solid var(--line)" : undefined }}>
        <span className="flex gap-1.5">
          {[0, 1, 2].map((i) => (
            <i key={i} className="size-3 rounded-full" style={{ background: "#e6e3db" }} />
          ))}
        </span>
        <span className="ml-2 flex items-center gap-1.5 text-[14px] font-bold">
          {kind === "agent" && <Sparkles size={15} />}
          {kind === "chat" ? "# 企画チーム" : "AIエージェント"}
        </span>
        <span
          className="ml-auto rounded-full px-2.5 py-1 text-[11px] font-bold whitespace-nowrap"
          style={on ? { background: "var(--teal-tint)", color: "var(--teal-ink)" } : { background: "var(--paper-2)", color: "var(--ink-3)" }}
        >
          UniEnter {on ? "ON" : "なし"}
        </span>
      </div>
      <div className="flex flex-col justify-end gap-2.5 overflow-hidden px-4 pt-3 pb-3" style={{ height }}>
        {msgs
          .filter((m) => t >= m.at)
          .map((m, i) => {
            const shake = m.shakeAt !== undefined && t >= m.shakeAt && t < m.shakeAt + 0.45
            const sx = shake ? Math.sin((t - m.shakeAt!) * 55) * 7 * (1 - (t - m.shakeAt!) / 0.45) : 0
            if (m.role === "ai")
              return (
                <div key={i} className="flex gap-2.5" style={appear(t, m.at)}>
                  <span className="flex size-7 shrink-0 items-center justify-center rounded-lg text-white" style={{ background: "var(--ink)" }}>
                    <Sparkles size={14} />
                  </span>
                  <p className="pt-0.5 text-[15px] leading-relaxed">{m.text}</p>
                </div>
              )
            return (
              <div key={i} style={appear(t, m.at, 0.45, 40)}>
                <div className={`flex ${m.role === "me" ? "justify-end" : "items-end gap-2"}`} style={{ transform: `translateX(${sx}px)` }}>
                  {m.role === "other" && (
                    <span className="flex size-7 shrink-0 items-center justify-center rounded-full text-[11px] font-bold" style={{ background: "var(--paper-2)", color: "var(--ink-2)" }}>
                      佐
                    </span>
                  )}
                  <p
                    className="max-w-[82%] rounded-2xl px-3.5 py-2 text-[15px] leading-relaxed whitespace-pre-wrap"
                    style={
                      m.role === "me"
                        ? kind === "agent"
                          ? { background: "var(--paper-2)", borderBottomRightRadius: 6 }
                          : { background: "var(--ink)", color: "#fff", borderBottomRightRadius: 6 }
                        : { background: "var(--paper-2)", borderBottomLeftRadius: 6 }
                    }
                  >
                    {m.text}
                  </p>
                </div>
                {m.stamp && t >= m.at + 0.5 && (
                  <p className="mt-1 text-right text-[11px] font-bold" style={{ ...appear(t, m.at + 0.5, 0.3, 8), color: "var(--ink-3)" }}>
                    {m.stamp}
                  </p>
                )}
              </div>
            )
          })}
      </div>
      <div className="px-4 pb-9">
        <div
          className="min-h-[72px] border px-3.5 py-2.5 text-[15px] leading-relaxed"
          style={{ borderColor: "var(--line)", borderRadius: kind === "agent" ? 18 : 12, background: kind === "agent" ? "#fff" : "rgba(247,246,242,.6)" }}
        >
          {composer === "" ? (
            <span style={{ color: "var(--ink-3)" }}>{kind === "agent" ? "何でも聞いてください" : "メッセージを入力"}</span>
          ) : (
            lines.map((line, i) => (
              <span key={i} className="block min-h-[1.6em]">
                {line}
                {i < lines.length - 1 && <span className="nl-mark">↵</span>}
                {i === lines.length - 1 && <span className="caret" style={{ animation: "none" }} />}
              </span>
            ))
          )}
        </div>
      </div>
    </div>
  )
}

function Caption({ t, at, children, size, dark }: { t: number; at: number; children: ReactNode; size: number; dark?: boolean }) {
  return (
    <p
      className="text-center font-extrabold tracking-tight"
      style={{ ...appear(t, at, 0.55, 20), fontSize: size, lineHeight: 1.35, color: dark ? "#f3f1ea" : "var(--ink)" }}
    >
      {children}
    </p>
  )
}

function LogoSquare({ s, size }: { s: Service; size: number }) {
  return (
    <span
      className="flex items-center justify-center"
      style={{ width: size, height: size, borderRadius: size * 0.28, background: `#${s.hex}`, boxShadow: "0 14px 24px -12px rgba(29,28,25,.45)" }}
    >
      {s.path ? (
        <svg viewBox={s.viewBox ?? "0 0 24 24"} style={{ width: size * 0.52, height: size * 0.52, fill: "#fff" }}>
          <path d={s.path} />
        </svg>
      ) : (
        <b className="text-white">{s.initial}</b>
      )}
    </span>
  )
}

function AppMark({ size }: { size: number }) {
  return (
    <span className="flex items-center justify-center text-white" style={{ width: size, height: size, borderRadius: size * 0.24, background: "var(--teal)" }}>
      <CornerDownLeft size={size * 0.55} strokeWidth={2.6} />
    </span>
  )
}

/* シーンの出入り(フェード+わずかなズーム) */
function Scene({ t, a, b, children, last }: { t: number; a: number; b: number; children: ReactNode; last?: boolean }) {
  if (t < a - 0.001 || t > b + 0.001) return null
  const fin = prog(t, a, a + 0.35)
  const fout = last ? 0 : prog(t, b - 0.35, b)
  return (
    <div
      className="absolute inset-0 flex flex-col items-center justify-center"
      style={{
        opacity: easeOut(fin) * (1 - fout),
        transform: `scale(${1 + 0.03 * (1 - easeOut(fin)) - 0.02 * fout})`,
        filter: `blur(${fout * 8}px)`,
      }}
    >
      {children}
    </div>
  )
}

/* ─────────── 本体 ─────────── */

const L1 = "明日の打ち合わせですが、"
const AI1 = "以下の条件で旅程を組んで:"
const D1 = "明日の打ち合わせですが、"
const D2 = "15時からに変更できますか?"
const D3 = "資料は前日にお送りします。"

export function Frame({ t, fmt }: { t: number; fmt: Fmt }) {
  const story = fmt === "story"
  const W = 540
  const H = story ? 960 : 540
  const cap = story ? 40 : 30
  const stageScale = story ? 1 : 0.8
  const gap = story ? 44 : 18
  const night = t >= 20.8 && t < 24

  const stage = (node: ReactNode) => (
    <div style={{ width: 460, transform: `scale(${stageScale})`, transformOrigin: "top center", marginBottom: story ? 0 : -(1 - stageScale) * 430 }}>{node}</div>
  )

  return (
    <div
      className="lpn promo relative overflow-hidden"
      style={{ width: W, height: H, background: night ? "var(--night)" : "var(--paper)", fontFamily: '"Hiragino Sans", sans-serif' }}
    >
      {/* 背景の点グリッド */}
      <div className="dotgrid absolute inset-0" style={{ opacity: night ? 0 : 0.8 }} />

      {/* A: うっかり送信 */}
      <Scene t={t} a={0} b={4.6}>
        <Caption t={t} at={0.1} size={cap}>
          改行したかった
          <br />
          だけなのに。
        </Caption>
        <div style={{ height: gap }} />
        {stage(
          <>
            <Window
              t={t}
              kind="chat"
              msgs={[
                { at: 0, text: "明日の件、どうなりました?", role: "other" },
                { at: 2.25, text: L1, role: "me", shakeAt: 2.75, stamp: "送信済み" },
              ]}
              composer={t < 2.2 ? typed(L1, t, 0.5, 1.8) : ""}
              height={story ? 250 : 200}
            />
            <Keys t={t} retAt={[2.1]} oopsAt={[2.15]} />
          </>,
        )}
      </Scene>

      {/* B: AIに1行目だけ */}
      <Scene t={t} a={4.6} b={8.3}>
        <Caption t={t} at={4.7} size={cap}>
          AIへの指示も、
          <br />
          1行目だけで送信。
        </Caption>
        <div style={{ height: gap }} />
        {stage(
          <>
            <Window
              t={t}
              kind="agent"
              msgs={[
                { at: 6.55, text: AI1, role: "me" },
                { at: 7.2, text: "承知しました。どのような条件でしょうか?", role: "ai" },
              ]}
              composer={t < 6.5 ? typed(AI1, t, 5.0, 6.2) : ""}
              height={story ? 250 : 200}
            />
            <Keys t={t} retAt={[6.4]} oopsAt={[6.45]} />
          </>,
        )}
      </Scene>

      {/* C: 製品名 */}
      <Scene t={t} a={8.3} b={11.3}>
        <div style={{ ...appear(t, 8.45, 0.6, 30), transform: `${appear(t, 8.45, 0.6, 30).transform} rotate(${(1 - easeBack(prog(t, 8.45, 9.05))) * -12}deg)` }}>
          <AppMark size={story ? 120 : 96} />
        </div>
        <p className="mt-6 font-extrabold tracking-tight" style={{ ...appear(t, 8.8, 0.5), fontSize: story ? 56 : 48 }}>
          UniEnter
        </p>
        <p className="mt-3 text-center font-bold" style={{ ...appear(t, 9.3, 0.5), fontSize: story ? 26 : 22, color: "var(--ink-2)" }}>
          Enterでの
          {story && <br />}
          うっかり送信を防ぎます
        </p>
        <p className="mt-4 text-[14px] font-semibold" style={{ ...appear(t, 9.7, 0.5), color: "var(--ink-3)" }}>
          Mac用 メニューバーアプリ
        </p>
      </Scene>

      {/* D: Enter=改行 / ⌘Enter=送信 */}
      <Scene t={t} a={11.3} b={17.7}>
        <Caption t={t} at={11.4} size={cap}>
          <span style={{ color: "var(--teal)" }}>Enterは改行。</span>
          <br />
          送信は⌘Enter。
        </Caption>
        <div style={{ height: gap }} />
        {stage(
          <>
            <Window
              t={t}
              kind="chat"
              on
              msgs={[
                { at: 0, text: "明日の件、どうなりました?", role: "other" },
                { at: 16.05, text: `${D1}\n${D2}\n${D3}`, role: "me" },
              ]}
              composer={
                t >= 16.0
                  ? ""
                  : t < 12.9
                    ? typed(D1, t, 11.8, 12.8)
                    : t < 14.5
                      ? `${D1}\n${typed(D2, t, 13.1, 14.3)}`
                      : `${D1}\n${D2}\n${typed(D3, t, 14.7, 15.5)}`
              }
              height={story ? 250 : 200}
            />
            <Keys t={t} retAt={[12.9, 14.5, 15.95]} newlineAt={[12.9, 14.5]} cmdAt={[[15.75, 16.25]]} sendAt={[15.95]} />
          </>,
        )}
      </Scene>

      {/* E: 対応サービス */}
      <Scene t={t} a={17.7} b={20.9}>
        <Caption t={t} at={17.8} size={cap * 0.9}>
          アプリでも、
          <br />
          ブラウザでも。
        </Caption>
        <div style={{ height: story ? 40 : 18 }} />
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, auto)", gap: 18, transform: `scale(${story ? 1 : 0.8})` }}>
          {services
            .filter((s) => !s.hideInLogoRow)
            .slice(0, story ? 12 : 8)
            .map((s, i) => (
              <div key={s.name} className="flex flex-col items-center gap-1.5" style={appear(t, 18.1 + i * 0.07, 0.45, 30)}>
                <LogoSquare s={s} size={story ? 72 : 64} />
                <span className="text-[11px] font-bold whitespace-nowrap" style={{ color: "var(--ink-2)" }}>
                  {s.name}
                </span>
              </div>
            ))}
        </div>
        <p className="mt-6 text-[14px] font-semibold" style={{ ...appear(t, 19.2, 0.4), color: "var(--ink-3)" }}>
          Slack・Teams・LINE・ChatGPT・Claude など
        </p>
      </Scene>

      {/* F: 安心(夜) */}
      <Scene t={t} a={20.9} b={24.1}>
        <Caption t={t} at={21.0} size={cap * 0.9} dark>
          入力した文章は、
          <br />
          どこにも送りません。
        </Caption>
        <div style={{ height: story ? 40 : 20 }} />
        <div className={story ? "flex w-[400px] flex-col gap-3" : "grid w-[500px] grid-cols-3 gap-3"}>
          {[
            { I: WifiOff, h: "勝手に通信しない", b: "打った文字はどこにも送りません" },
            { I: Languages, h: "変換中は触れない", b: "日本語の変換の確定は、そのまま" },
            { I: Code, h: "中身は公開", b: "ソースコードはGitHubで公開" },
          ].map(({ I, h, b }, i) => (
            <div
              key={h}
              className={`rounded-2xl border p-4 ${story ? "flex items-center gap-4" : ""}`}
              style={{ ...appear(t, 21.6 + i * 0.25, 0.45, 24), borderColor: "rgba(255,255,255,.12)", background: "rgba(255,255,255,.04)", color: "#f3f1ea" }}
            >
              <span className="flex size-10 shrink-0 items-center justify-center rounded-xl" style={{ background: "rgba(255,255,255,.08)", color: "#e8f3f0" }}>
                <I size={20} />
              </span>
              <div className={story ? "" : "mt-3"}>
                <p className="font-bold" style={{ fontSize: story ? 16 : 14 }}>{h}</p>
                <p className="mt-0.5 text-[12px]" style={{ color: "rgba(255,255,255,.6)" }}>
                  {b}
                </p>
              </div>
            </div>
          ))}
        </div>
      </Scene>

      {/* G: CTA */}
      <Scene t={t} a={24.1} b={DURATION} last>
        <div style={appear(t, 24.2, 0.5)}>
          <AppMark size={story ? 88 : 72} />
        </div>
        <p className="mt-5 font-extrabold tracking-tight" style={{ ...appear(t, 24.4, 0.5), fontSize: story ? 44 : 38 }}>
          UniEnter
        </p>
        <p className="mt-2 text-center font-bold" style={{ ...appear(t, 24.6, 0.5), fontSize: story ? 22 : 19, color: "var(--ink-2)" }}>
          Enterは改行、送信は⌘Enter。
          <br />
          Macのチャット、ぜんぶで。
        </p>
        <div className="mt-7 flex gap-2" style={appear(t, 25.0, 0.5)}>
          {["14日間無料", "買い切り ¥1,480", "macOS 13以降"].map((x) => (
            <span key={x} className="rounded-full border bg-white px-3.5 py-1.5 text-[13px] font-bold" style={{ borderColor: "var(--line)" }}>
              {x}
            </span>
          ))}
        </div>
        <p
          className="mt-8 rounded-full px-6 py-3 text-[18px] font-extrabold text-white"
          style={{ ...appear(t, 25.4, 0.5), background: "var(--teal)", boxShadow: "0 12px 30px -12px rgba(15,123,108,.6)" }}
        >
          unienter.oc-to.com
        </p>
      </Scene>

      {/* 常時: 右下の小さなロゴ(C・Gでは消す) */}
      <div
        className="absolute flex items-center gap-1.5 text-[13px] font-extrabold"
        style={{ right: 20, bottom: story ? 28 : 16, color: night ? "#f3f1ea" : "var(--ink)", opacity: (t > 8.3 && t < 11.3) || t > 24.1 ? 0 : 0.8 }}
      >
        <AppMark size={20} /> UniEnter
      </div>
    </div>
  )
}

export default function Promo() {
  const q = new URLSearchParams(location.search)
  const fmt = (q.get("format") === "square" ? "square" : "story") as Fmt
  const [t, setT] = useState(Number(q.get("t") ?? 0))
  useEffect(() => {
    const w = window as unknown as { __setT: (t: number) => void; __duration: number; __ready: boolean }
    w.__setT = (x) => flushSync(() => setT(x))
    w.__duration = DURATION
    w.__ready = true
    // ?play でリアルタイム再生(確認用)
    if (!q.has("play")) return
    const start = performance.now()
    let raf = 0
    const tick = () => {
      setT(((performance.now() - start) / 1000) % DURATION)
      raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  return <Frame t={t} fmt={fmt} />
}
