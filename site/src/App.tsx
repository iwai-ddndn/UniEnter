import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { CornerDownLeft, Lock } from "lucide-react"

/* 改行=グリーン / 送信=ブルー(Notion系の落ち着いた色) */
const NEWLINE = "#0f7b6c"
const SEND = "#2383e2"

function HeroVisual() {
  return (
    <div className="relative mx-auto mt-12 max-w-3xl overflow-hidden rounded-xl border shadow-sm">
      <img
        src="./assets/hero.png"
        alt="Enterキーは改行、⌘Enterキーは送信"
        className="block w-full"
      />
      <div className="absolute inset-x-0 bottom-[9%] flex text-lg font-bold sm:text-2xl">
        <p className="w-1/2 text-center" style={{ color: NEWLINE }}>
          Enter → 改行
        </p>
        <p className="w-1/2 text-center" style={{ color: SEND }}>
          ⌘Enter → 送信
        </p>
      </div>
    </div>
  )
}

/* macOSウィンドウ風モックアップの枠 */
function WindowMock({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="overflow-hidden rounded-xl border bg-card text-left shadow-sm">
      <div className="flex items-center gap-1.5 border-b bg-muted px-4 py-2.5">
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
    <div className="flex items-center justify-between gap-2 rounded-lg border bg-background px-3 py-2">
      <span className="flex min-w-0 items-center gap-2 text-sm">
        <Lock className="size-3.5 shrink-0 text-muted-foreground" />
        <span className="truncate">{url}</span>
      </span>
      {active ? (
        <Badge className="shrink-0 border-transparent bg-[#dbeddb] text-[#1c3829]">
          統一
        </Badge>
      ) : (
        <Badge variant="secondary" className="shrink-0 text-muted-foreground">
          干渉しない
        </Badge>
      )}
    </div>
  )
}

const desktopApps = [
  "Slack",
  "Microsoft Teams",
  "Discord",
  "LINE",
  "ChatGPT",
  "Claude",
  "Messenger",
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
  {
    q: "無料トライアルが終わるとどうなる?",
    a: "キーの書き換えが停止します(アプリの動作を邪魔することはありません)。ライセンスを購入してキーを入力すると再開されます。",
  },
  {
    q: "支払い方法と領収書は?",
    a: "決済代行のPaddle経由で、クレジットカード等が使えます。領収書・インボイスはPaddleから発行されます。",
  },
  {
    q: "何台のMacで使える?",
    a: "ご本人が使うMacであれば複数台で利用できます。ライセンスキーを各Macで入力してください。",
  },
  {
    q: "インストール方法は?",
    a: "ダウンロードした UniEnter.pkg をダブルクリックし、インストーラに沿って進めるだけです(アプリケーションフォルダに入ります)。zip版はお好みの場所に解凍して使えます。",
  },
  {
    q: "開こうとすると「開発元を確認できない」と警告が出る",
    a: "現在はApple公証の準備中のため、初回のみ システム設定 → プライバシーとセキュリティ → 下部の「このまま開く」から進めてください。2回目以降は普通に開けます。",
  },
]

export default function App() {
  return (
    <div className="min-h-screen">
      {/* Nav */}
      <nav className="mx-auto flex max-w-5xl items-center justify-between px-6 py-5">
        <span className="flex items-center gap-2 font-semibold">
          <CornerDownLeft className="size-4" /> UniEnter
        </span>
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="sm" asChild>
            <a href="#pricing">価格</a>
          </Button>
          <Button variant="outline" size="sm" asChild>
            <a href="https://github.com/iwai-ddndn/UniEnter">GitHub</a>
          </Button>
        </div>
      </nav>

      {/* Hero */}
      <header className="px-6 pt-16 pb-20 text-center">
        <Badge variant="secondary" className="mb-6 font-normal text-muted-foreground">
          macOS用メニューバーアプリ・14日間無料トライアル
        </Badge>
        <h1 className="text-3xl leading-snug font-bold sm:text-5xl sm:leading-snug">
          どのアプリでも、
          <br />
          改行と送信を統一。
        </h1>
        <p className="mx-auto mt-5 max-w-lg text-muted-foreground">
          Enterはいつでも改行、送信は⌘Enter。
          <br />
          SlackもTeamsも、ChatGPTもClaudeも — 「うっかり送信」をなくします。
        </p>

        <HeroVisual />

        <div className="mt-12 flex flex-wrap items-center justify-center gap-3">
          <Button size="lg" asChild>
            <a href="https://github.com/iwai-ddndn/UniEnter/releases/latest/download/UniEnter.pkg">
              無料で試す(.pkg)
            </a>
          </Button>
          <Button size="lg" variant="outline" asChild>
            <a href="#pricing">価格を見る</a>
          </Button>
        </div>
        <p className="mt-4 text-xs text-muted-foreground">
          macOS 13以降・14日間は全機能無料 /{" "}
          <a
            className="underline"
            href="https://github.com/iwai-ddndn/UniEnter/releases/latest/download/UniEnter.zip"
          >
            zip版
          </a>{" "}
          /{" "}
          <a className="underline" href="https://github.com/iwai-ddndn/UniEnter/releases">
            リリース一覧
          </a>
        </p>
      </header>

      {/* Apps */}
      <section className="border-t bg-muted/50 px-6 py-20">
        <div className="mx-auto max-w-4xl">
          <h2 className="mb-3 text-center text-2xl font-bold sm:text-3xl">
            アプリでも、ブラウザでも。
          </h2>
          <p className="mx-auto mb-10 max-w-md text-center text-muted-foreground">
            対象のアプリやタブが前面のときだけ働きます。それ以外には一切干渉しません。
          </p>
          <img
            src="./assets/macbook.png"
            alt="MacBookでチャットアプリを使っている様子"
            className="mb-10 w-full rounded-xl border shadow-sm"
          />
          <div className="grid gap-5 sm:grid-cols-2">
            <WindowMock title="デスクトップアプリ">
              <div className="flex flex-wrap gap-2">
                {desktopApps.map((app) => (
                  <Badge key={app} variant="secondary" className="px-3 py-1.5 text-sm font-normal">
                    {app}
                  </Badge>
                ))}
              </div>
              <p className="mt-4 text-xs text-muted-foreground">
                設定のチェックボックスでアプリごとにオン/オフできます。
                XとInstagramのDM・GeminiはWeb版で対応。
              </p>
            </WindowMock>
            <WindowMock title="ブラウザ — Safari / Chrome / Edge / Arc など">
              <div className="space-y-2">
                <UrlRow url="app.slack.com" active />
                <UrlRow url="chatgpt.com" active />
                <UrlRow url="x.com/messages(DM)" active />
                <UrlRow url="example.com" active={false} />
              </div>
            </WindowMock>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="px-6 py-20">
        <div className="mx-auto grid max-w-5xl gap-5 sm:grid-cols-3">
          <Card className="shadow-sm">
            <CardContent className="pt-2">
              <img
                src="./assets/feature-ime.png"
                alt="「あ」と刻印されたキーキャップ"
                className="mb-5 aspect-[3/2] w-full rounded-lg border object-cover"
              />
              <h3 className="mb-2 font-semibold">日本語入力に、とことん安全</h3>
              <p className="text-sm text-muted-foreground">
                変換中のEnterには触れず、確定はそのまま。判定に迷ったら「何もしない」設計。
              </p>
            </CardContent>
          </Card>

          <Card className="shadow-sm">
            <CardContent className="pt-2">
              <img
                src="./assets/feature-config.png"
                alt="チェックボックス"
                className="mb-5 aspect-[3/2] w-full rounded-lg border object-cover"
              />
              <h3 className="mb-2 font-semibold">設定は、チェックを入れるだけ</h3>
              <p className="text-sm text-muted-foreground">
                インストールして対象アプリを選ぶだけ。覚えることはありません。
              </p>
            </CardContent>
          </Card>

          <Card className="shadow-sm">
            <CardContent className="pt-2">
              <img
                src="./assets/feature-light.png"
                alt="羽根"
                className="mb-5 aspect-[3/2] w-full rounded-lg border object-cover"
              />
              <h3 className="mb-2 font-semibold">軽くて、何も送らない</h3>
              <p className="text-sm text-muted-foreground">
                CPUほぼ0%。通信・解析ゼロ。判定するのはEnter関連のキーだけで、文章は読みません。
              </p>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="border-t px-6 py-20">
        <div className="mx-auto max-w-xl">
          <h2 className="mb-3 text-center text-2xl font-bold sm:text-3xl">価格</h2>
          <p className="mx-auto mb-10 max-w-md text-center text-muted-foreground">
            まずは14日間、全機能を無料で。気に入ったら買い切りで、ずっと。
          </p>
          <Card className="shadow-sm">
            <CardContent className="py-8 text-center">
              <p className="text-4xl font-bold">
                ¥1,480 <span className="text-base font-normal text-muted-foreground">(税込)</span>
              </p>
              <p className="mt-1 text-sm text-muted-foreground">買い切り・サブスクなし</p>
              <ul className="mx-auto mt-6 max-w-xs space-y-2 text-left text-sm text-muted-foreground">
                <li>✓ 14日間の無料トライアル付き(全機能)</li>
                <li>✓ すべての対象アプリ・ブラウザWeb版</li>
                <li>✓ アップデート込み</li>
                <li>✓ 同一ユーザーのMac複数台で利用OK</li>
              </ul>
              <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
                <Button size="lg" asChild>
                  <a href="https://github.com/iwai-ddndn/UniEnter/releases/latest/download/UniEnter.pkg">
                    無料で試す
                  </a>
                </Button>
                <Button size="lg" variant="outline" disabled>
                  ライセンスを購入(準備中)
                </Button>
              </div>
              <p className="mt-4 text-xs text-muted-foreground">
                決済は Paddle(海外製アプリで標準の決済代行)経由。カード情報が開発者に渡ることはありません。
              </p>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="border-t bg-muted/50 px-6 py-20">
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
        <p className="mb-2 space-x-4">
          <a className="underline" href="https://github.com/iwai-ddndn/UniEnter">GitHub</a>
          <a className="underline" href="https://github.com/iwai-ddndn/UniEnter/releases">ダウンロード</a>
          <a className="underline" href="#pricing">価格</a>
        </p>
        <p>
          © 2026 octo — お問い合わせ:{" "}
          <a className="underline" href="mailto:info@oc-to.com">
            info@oc-to.com
          </a>
        </p>
        <p className="mx-auto mt-2 max-w-lg">
          記載の製品名は各社の商標です。本アプリは各社と無関係の個人開発ソフトウェアです。
        </p>
      </footer>
    </div>
  )
}
