import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { CornerDownLeft, Feather, Globe, Languages } from "lucide-react"

function HeroVisual() {
  return (
    <div className="relative mx-auto mt-12 max-w-3xl overflow-hidden rounded-2xl border border-border/60 shadow-2xl">
      <img
        src="./assets/hero.png"
        alt="Enterキーは改行、⌘Enterキーは送信"
        className="block w-full"
      />
      <div className="absolute inset-x-0 bottom-[7%] flex text-lg font-bold sm:text-2xl">
        <p className="w-1/2 text-center text-[#7ee2a8]">Enter → 改行</p>
        <p className="w-1/2 text-center text-[#6ea8ff]">⌘Enter → 送信</p>
      </div>
    </div>
  )
}

const apps = ["Slack", "Microsoft Teams", "Discord", "LINE", "Chatwork", "各Web版"]

const features = [
  {
    icon: Languages,
    title: "日本語IMEに安全",
    body: "変換確定のEnterには触れません。迷ったら「何もしない」設計。",
  },
  {
    icon: Globe,
    title: "ブラウザ版もそのまま",
    body: "SafariやChromeで開いたSlackやTeamsでも、同じ操作。",
  },
  {
    icon: Feather,
    title: "軽くて、何も送らない",
    body: "CPUほぼ0%。通信・解析・入力内容の読み取りはゼロ。",
  },
]

const faqs = [
  {
    q: "必要な権限は?",
    a: "アクセシビリティのみ。初回起動時に画面の案内に沿って許可するだけです。",
  },
  {
    q: "日本語の変換確定Enterが誤送信されない?",
    a: "されません。変換中のEnterは一切書き換えず、判定に迷ったときも「何もしない」側に倒すフェイルセーフ設計です。",
  },
  {
    q: "アプリ側で「⌘Enterで送信」にしている",
    a: "設定でそのアプリの送信キーを⌘Enterに切り替えると、書き換えを止めてアプリ本来の動作をそのまま使います。",
  },
  {
    q: "入力内容を読まれない?",
    a: "読みません。判定に使うのはEnter関連のキー・前面アプリ・日本語入力かどうかだけ。外部送信も一切ありません。",
  },
]

export default function App() {
  return (
    <div className="min-h-screen">
      {/* Nav */}
      <nav className="mx-auto flex max-w-5xl items-center justify-between px-6 py-5">
        <span className="flex items-center gap-2 font-semibold tracking-wide">
          <CornerDownLeft className="size-4" /> UniEnter
        </span>
        <Button variant="outline" size="sm" asChild>
          <a href="#">GitHub</a>
        </Button>
      </nav>

      {/* Hero */}
      <header className="relative overflow-hidden px-6 pt-16 pb-20 text-center">
        <div
          className="pointer-events-none absolute inset-0 -z-10"
          style={{
            background:
              "radial-gradient(ellipse 70% 55% at 50% -10%, rgba(79,142,247,0.25), transparent)",
          }}
        />
        <Badge variant="secondary" className="mb-6">
          macOS用メニューバーアプリ・無料
        </Badge>
        <h1 className="text-4xl leading-tight font-bold sm:text-6xl">
          Enterは、改行。
          <br />
          送信は、⌘Enter。
        </h1>
        <p className="mx-auto mt-5 max-w-md text-muted-foreground">
          Slack・Teams・Discord・LINE・Chatwork。
          <br />
          バラバラなEnterの挙動を、ぜんぶ同じに。
        </p>

        <HeroVisual />

        <div className="mt-12 flex flex-wrap items-center justify-center gap-3">
          <Button size="lg" asChild>
            <a href="#">ダウンロード</a>
          </Button>
          <Button size="lg" variant="outline" asChild>
            <a href="#faq">よくある質問</a>
          </Button>
        </div>
        <p className="mt-4 text-xs text-muted-foreground">macOS 13以降</p>
      </header>

      {/* Apps */}
      <section className="px-6 pb-20">
        <div className="mx-auto flex max-w-2xl flex-wrap items-center justify-center gap-2">
          {apps.map((app) => (
            <Badge key={app} variant="outline" className="px-4 py-1.5 text-sm">
              {app}
            </Badge>
          ))}
        </div>
      </section>

      {/* Features */}
      <section className="bg-secondary/40 px-6 py-20">
        <div className="mx-auto grid max-w-4xl gap-5 sm:grid-cols-3">
          {features.map(({ icon: Icon, title, body }) => (
            <Card key={title} className="border-border/60">
              <CardContent className="pt-2">
                <Icon className="mb-4 size-6 text-primary" />
                <h3 className="mb-2 font-semibold">{title}</h3>
                <p className="text-sm text-muted-foreground">{body}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="px-6 py-20">
        <div className="mx-auto max-w-xl">
          <h2 className="mb-8 text-center text-2xl font-bold">よくある質問</h2>
          <Accordion type="single" collapsible>
            {faqs.map(({ q, a }) => (
              <AccordionItem key={q} value={q}>
                <AccordionTrigger className="text-left">{q}</AccordionTrigger>
                <AccordionContent className="text-muted-foreground">
                  {a}
                </AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </div>
      </section>

      {/* Support */}
      <section className="px-6 pb-24">
        <Card className="mx-auto max-w-xl text-center">
          <CardContent className="py-10">
            <h2 className="mb-2 text-xl font-bold">無料で使えます</h2>
            <p className="mb-6 text-sm text-muted-foreground">
              役に立ったら、コーヒー1杯分の応援をもらえるとうれしいです。
            </p>
            <Button asChild>
              <a href="#">☕ 開発を支援する</a>
            </Button>
          </CardContent>
        </Card>
      </section>

      <footer className="border-t px-6 py-10 text-center text-xs text-muted-foreground">
        <p>© 2026 UniEnter</p>
        <p className="mx-auto mt-2 max-w-lg">
          記載の製品名は各社の商標です。本アプリは各社と無関係の個人開発ソフトウェアです。
        </p>
      </footer>
    </div>
  )
}
