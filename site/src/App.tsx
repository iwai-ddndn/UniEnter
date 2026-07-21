import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Check, CornerDownLeft, Lock } from "lucide-react"

function Kbd({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-flex items-center rounded-md border border-[#3a4a63] bg-gradient-to-b from-[#232c3b] to-[#1a2230] px-2 py-0.5 text-xs font-semibold">
      {children}
    </span>
  )
}

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

/* macOSウィンドウ風モックアップの枠 */
function WindowMock({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="overflow-hidden rounded-xl border border-border/60 bg-background text-left shadow-lg">
      <div className="flex items-center gap-1.5 border-b border-border/60 bg-secondary/60 px-4 py-2.5">
        <span className="size-2.5 rounded-full bg-[#ff5f57]" />
        <span className="size-2.5 rounded-full bg-[#febc2e]" />
        <span className="size-2.5 rounded-full bg-[#28c840]" />
        <span className="ml-2 truncate text-xs text-muted-foreground">{title}</span>
      </div>
      <div className="p-5">{children}</div>
    </div>
  )
}

function UrlRow({ url, active }: { url: string; active: boolean }) {
  return (
    <div className="flex items-center justify-between gap-2 rounded-lg border border-border/60 bg-secondary/40 px-3 py-2">
      <span className="flex min-w-0 items-center gap-2 text-sm">
        <Lock className="size-3.5 shrink-0 text-muted-foreground" />
        <span className="truncate">{url}</span>
      </span>
      {active ? (
        <Badge className="shrink-0 border-transparent bg-[#7ee2a8]/15 text-[#7ee2a8]">統一</Badge>
      ) : (
        <Badge variant="outline" className="shrink-0 text-muted-foreground">
          干渉しない
        </Badge>
      )}
    </div>
  )
}

function CheckRow({ label }: { label: string }) {
  return (
    <div className="flex items-center gap-2.5 rounded-lg border border-border/60 bg-secondary/40 px-3 py-2 text-sm">
      <span className="flex size-4 items-center justify-center rounded border border-primary bg-primary">
        <Check className="size-3 text-primary-foreground" />
      </span>
      {label}
    </div>
  )
}

function StatRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between rounded-lg border border-border/60 bg-secondary/40 px-3 py-2 text-sm">
      <span className="text-muted-foreground">{label}</span>
      <span className="font-semibold text-[#7ee2a8]">{value}</span>
    </div>
  )
}

const desktopApps = ["Slack", "Microsoft Teams", "Discord", "LINE", "Chatwork"]

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
        <h1 className="text-3xl leading-snug font-bold sm:text-5xl sm:leading-snug">
          どんなメッセージアプリでも、
          <br />
          改行と送信を統一。
        </h1>
        <p className="mx-auto mt-5 max-w-lg text-muted-foreground">
          Enterはいつでも改行、送信は⌘Enter。
          <br />
          アプリごとにバラバラな挙動が生む「うっかり送信」をなくします。
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
      <section className="px-6 py-20">
        <div className="mx-auto max-w-4xl">
          <h2 className="mb-3 text-center text-2xl font-bold sm:text-3xl">
            アプリでも、ブラウザでも。
          </h2>
          <p className="mx-auto mb-10 max-w-md text-center text-muted-foreground">
            対象のアプリやタブが前面のときだけ働きます。それ以外には一切干渉しません。
          </p>
          <div className="grid gap-5 sm:grid-cols-2">
            <WindowMock title="デスクトップアプリ">
              <div className="flex flex-wrap gap-2">
                {desktopApps.map((app) => (
                  <Badge key={app} variant="secondary" className="px-3 py-1.5 text-sm">
                    {app}
                  </Badge>
                ))}
              </div>
              <p className="mt-4 text-xs text-muted-foreground">
                設定のチェックボックスでアプリごとにオン/オフできます
              </p>
            </WindowMock>
            <WindowMock title="ブラウザ — Safari / Chrome / Edge / Arc など">
              <div className="space-y-2">
                <UrlRow url="app.slack.com" active />
                <UrlRow url="teams.cloud.microsoft" active />
                <UrlRow url="discord.com/channels/…" active />
                <UrlRow url="example.com" active={false} />
              </div>
            </WindowMock>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="bg-secondary/40 px-6 py-20">
        <div className="mx-auto grid max-w-5xl gap-5 sm:grid-cols-3">
          <Card className="border-border/60">
            <CardContent className="pt-2">
              <div className="mb-5 rounded-lg border border-border/60 bg-background p-4">
                <p className="text-lg">
                  <span className="border-b-2 border-dotted border-foreground/60 pb-0.5">
                    こんにちは
                  </span>
                </p>
                <div className="mt-3 flex flex-wrap items-center gap-2 text-sm">
                  <Kbd>Enter</Kbd>
                  <span className="text-muted-foreground">→</span>
                  <span className="font-medium text-[#7ee2a8]">確定のみ。送信されない</span>
                </div>
              </div>
              <h3 className="mb-2 font-semibold">日本語入力に、とことん安全</h3>
              <p className="text-sm text-muted-foreground">
                変換中のEnterには触れません。判定に迷ったら「何もしない」設計。
              </p>
            </CardContent>
          </Card>

          <Card className="border-border/60">
            <CardContent className="pt-2">
              <div className="mb-5 space-y-2 rounded-lg border border-border/60 bg-background p-4">
                <CheckRow label="Slack" />
                <CheckRow label="Microsoft Teams" />
                <CheckRow label="LINE" />
              </div>
              <h3 className="mb-2 font-semibold">設定は、チェックを入れるだけ</h3>
              <p className="text-sm text-muted-foreground">
                インストールして対象アプリを選ぶだけ。覚えることはありません。
              </p>
            </CardContent>
          </Card>

          <Card className="border-border/60">
            <CardContent className="pt-2">
              <div className="mb-5 space-y-2 rounded-lg border border-border/60 bg-background p-4">
                <StatRow label="アイドル時CPU" value="≈ 0%" />
                <StatRow label="ネットワーク通信" value="なし" />
                <StatRow label="入力内容の読み取り" value="なし" />
              </div>
              <h3 className="mb-2 font-semibold">軽くて、何も送らない</h3>
              <p className="text-sm text-muted-foreground">
                判定するのはEnter関連のキーだけ。文章は読まず、外部にも送りません。
              </p>
            </CardContent>
          </Card>
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

      <footer className="border-t px-6 py-10 text-center text-xs text-muted-foreground">
        <p>© 2026 UniEnter</p>
        <p className="mx-auto mt-2 max-w-lg">
          記載の製品名は各社の商標です。本アプリは各社と無関係の個人開発ソフトウェアです。
        </p>
      </footer>
    </div>
  )
}
