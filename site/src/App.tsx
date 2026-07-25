import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { CornerDownLeft } from "lucide-react"
import { useEffect } from "react"
import { observeSections, track } from "@/lib/analytics"
import { ServiceTile, services } from "./brands"
import HeroDemo from "./HeroDemo"

/* 改行=グリーン / 送信=ブルー(Notion系の落ち着いた色) */

// (対応アプリのロゴ/名称は brands.tsx に集約)

/*
 * 質問はすべてユーザー側の言葉・疑問文で書く。専門用語(フェイルセーフ、書き換え、
 * 〜側に倒す)は使わない。順番は「不安 → つまずき → 契約」の順。
 */
const faqs = [
  {
    q: "変換のときのEnterで、誤って送信されない?",
    a: "されません。日本語を変換しているあいだのEnterには、UniEnterは一切手を出しません。判断に迷ったときも何もしない側に寄せてあるので、変換の確定が送信になることはありません。",
  },
  {
    q: "アプリ側の設定と、どちらが優先される?",
    a: "UniEnterが優先されます。LINEやSlackが「Enterで送信」の設定でも、チェックを入れたアプリでは Enter=改行 / ⌘Enter=送信 になります。各アプリの設定画面を開いて確認する必要はありません(1つだけ例外があります → 次の項目)。",
  },
  {
    q: "⌘Enterを押しても送信できない",
    a: "そのアプリ自身の設定で、送信キーをすでに「⌘Enter」に変更している場合に起こります。UniEnterの切り替えと二重にかかるためです。UniEnterの設定を開き、一番下の「⌘Enterを押しても送信できないときは」から、そのアプリにチェックを入れてください。UniEnterがそのアプリに手を出さなくなり、元どおり送信できます。",
  },
  {
    q: "入力した文章が、どこかに送られない?",
    a: "送られません。UniEnterはインターネット通信を一切行いません。見ているのは、EnterキーとCommandキーが押されたかどうかと、最前面のアプリが何かだけです。入力した文章そのものは読みません。",
  },
  {
    q: "必要な権限は?",
    a: "アクセシビリティのみです。初回起動時に画面の案内に沿って許可してください。",
  },
  {
    q: "開こうとすると「開発元を確認できません」と出る",
    a: "現在Appleの公証を準備中のため、初回だけmacOSに止められます。上の「インストール手順」の3ステップで開けます。2回目以降は、警告なしで開けます。",
  },
  {
    q: "インストール方法は?",
    a: "ダウンロードした UniEnter.pkg をダブルクリックし、インストーラに沿って進めてください(アプリケーションフォルダに入ります)。zip版は、お好みの場所に解凍して使えます。初回はmacOSに止められるので、上の「インストール手順」もあわせてご覧ください。",
  },
  {
    q: "容量やCPUはどのくらい使う?",
    a: "アプリ本体は約3MBです。常駐しますが、キーを押したときだけ動くためCPUはほぼ0%。メニューバーにアイコンが1つ増えるほかは、何も表示しません。",
  },
  {
    q: "無料トライアルが終わるとどうなる?",
    a: "Enterキーの切り替えが止まり、各アプリ本来の動きに戻ります(アプリの邪魔をすることはありません)。期限が切れるとUniEnterがライセンス画面を開いてお知らせしますので、続けて使うならライセンスを購入、使わないならアプリを削除してください。",
  },
  {
    q: "複数台のMacで使える?",
    a: "使えます。ご本人が使うMacであれば、台数の制限はありません。各Macで同じライセンスキーを入力してください。",
  },
  {
    q: "支払い方法と領収書は?",
    a: "決済代行のPaddle経由で、クレジットカード等が使えます。領収書・インボイスはPaddleから発行されます。",
  },
]

export default function App() {
  useEffect(() => observeSections(), [])

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
      <header data-track-section="hero" className="px-6 pt-16 pb-20 text-center">
        <Badge variant="secondary" className="mb-6 font-normal text-muted-foreground">
          macOS用メニューバーアプリ・14日間無料トライアル
        </Badge>
        <h1 className="text-3xl leading-snug font-bold sm:text-5xl sm:leading-snug">
          改行と送信、
          <br />
          もう間違えない。
        </h1>
        <p className="mx-auto mt-5 max-w-lg text-muted-foreground">
          書きかけのメッセージが、Enterひとつで飛んでいく。
          <br />
          あの「うっかり送信」を、Macから無くします。
        </p>
        <div className="mt-10">
          <HeroDemo />
        </div>

        <p className="mx-auto mt-10 max-w-lg text-muted-foreground">
          どのアプリでも Enterは改行、送信は⌘Enter。
          <br />
          SlackもTeamsも、ChatGPTもClaudeも、同じ操作に揃います。
        </p>

        <div className="mt-12 flex flex-wrap items-center justify-center gap-3">
          <Button size="lg" asChild>
            <a
              href="https://github.com/iwai-ddndn/UniEnter/releases/latest/download/UniEnter.pkg"
              onClick={() => track("download_click", { file_type: "pkg", location: "hero" })}
            >
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
            onClick={() => track("download_click", { file_type: "zip", location: "hero" })}
          >
            zip版
          </a>{" "}
          /{" "}
          <a className="underline" href="https://github.com/iwai-ddndn/UniEnter/releases">
            リリース一覧
          </a>
        </p>
        <p className="mt-3 text-xs text-muted-foreground">
          初回は「開発元を確認できません」と表示されます →{" "}
          <a className="font-medium underline" href="#install">
            インストール手順
          </a>
        </p>
      </header>

      {/* Before / After — 「今どのくらいダルくて、入れるとどう楽になるか」を先に示す */}
      <section data-track-section="before-after" className="border-t px-6 py-20">
        <div className="mx-auto max-w-4xl">
          <h2 className="mb-3 text-center text-2xl font-bold sm:text-3xl">
            アプリごとの「Enter問題」を、まとめて終わらせる。
          </h2>
          <p className="mx-auto mb-12 max-w-lg text-center text-muted-foreground">
            各アプリの設定画面を開いて回る必要はありません。
            起動しておくだけで、対象アプリがすべて同じ操作になります。
          </p>

          <div className="grid gap-5 sm:grid-cols-2">
            <Card className="shadow-sm">
              <CardContent className="pt-2">
                <p className="mb-5 text-xs font-semibold tracking-widest text-muted-foreground">
                  これまで
                </p>
                <ul className="space-y-3 text-sm">
                  <li>アプリごとに、Enterの意味が違う</li>
                  <li>設定を変えられるアプリと、変えられないアプリがある</li>
                  <li>どのアプリをどう設定したか、覚えていられない</li>
                </ul>
                <p className="mt-6 border-t pt-4 text-sm text-muted-foreground">
                  → 書きかけのまま送信してしまう。送ったつもりが、改行だった。
                </p>
              </CardContent>
            </Card>

            <Card className="shadow-sm">
              <CardContent className="pt-2">
                <p className="mb-5 text-xs font-semibold tracking-widest text-muted-foreground">
                  UniEnterを入れると
                </p>
                <div className="space-y-3">
                  <div className="flex items-center gap-3">
                    <kbd className="rounded-md border bg-muted px-2.5 py-1 text-sm font-semibold">Enter</kbd>
                    <span className="text-sm font-medium" style={{ color: "#0f7b6c" }}>
                      → 改行
                    </span>
                  </div>
                  <div className="flex items-center gap-3">
                    <kbd className="rounded-md border bg-muted px-2.5 py-1 text-sm font-semibold">⌘</kbd>
                    <kbd className="rounded-md border bg-muted px-2.5 py-1 text-sm font-semibold">Enter</kbd>
                    <span className="text-sm font-medium" style={{ color: "#2383e2" }}>
                      → 送信
                    </span>
                  </div>
                </div>
                <p className="mt-5 text-sm">対象アプリすべてで、例外なくこの2つだけ。</p>
                <p className="mt-6 border-t pt-4 text-sm text-muted-foreground">
                  → 各アプリの設定画面は、もう開かなくていい。
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* Apps */}
      <section data-track-section="apps" className="border-t bg-muted/50 px-6 py-20">
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
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
            {services.map((service) => (
              <ServiceTile key={service.name} service={service} />
            ))}
          </div>
          <p className="mt-6 text-center text-xs text-muted-foreground">
            「ブラウザ」は Safari / Chrome / Edge / Arc などで各サービスのWeb版を開いたタブが対象。
            設定でサービスごと・アプリ/ブラウザごとにオン/オフできます。
          </p>
        </div>
      </section>

      {/* Features */}
      <section data-track-section="features" className="px-6 py-20">
        <div className="mx-auto grid max-w-5xl gap-5 sm:grid-cols-3">
          <Card className="shadow-sm">
            <CardContent className="pt-2">
              <img
                src="./assets/feature-ime.png"
                alt="「あ」と刻印されたキーキャップ"
                className="mb-5 aspect-[3/2] w-full rounded-lg border object-cover"
              />
              <h3 className="mb-2 font-semibold">変換中のEnterには、触れません</h3>
              <p className="text-sm text-muted-foreground">
                日本語を変換しているあいだのEnterは、そのまま通します。変換の確定が、誤って送信になることはありません。
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
                使っているアプリにチェックを入れるだけ。あとは覚えることも、操作することもありません。
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
              <h3 className="mb-2 font-semibold">入れていることを、忘れる軽さ</h3>
              <p className="text-sm text-muted-foreground">
                常駐していてもCPUはほぼ0%。メニューバーのアイコン以外、何も邪魔をしません。
              </p>
            </CardContent>
          </Card>
        </div>

        {/* プライバシーは「軽さ」と同居させず、独立して読めるようにする */}
        <div className="mx-auto mt-12 max-w-2xl rounded-xl border bg-muted/50 px-6 py-6 text-center">
          <h3 className="mb-2 font-semibold">入力した文章は、どこにも送りません</h3>
          <p className="text-sm text-muted-foreground">
            インターネット通信は一切行いません。UniEnterが見ているのは、
            <strong className="font-medium text-foreground">
              EnterキーとCommandキーが押されたかどうか
            </strong>
            と、
            <strong className="font-medium text-foreground">どのアプリが最前面か</strong>
            だけです。入力した文章そのものは読みません。
          </p>
        </div>
      </section>

      {/* インストール手順 — 現状ここが最大の離脱ポイント(未公証のためmacOSに止められる) */}
      <section id="install" data-track-section="install" className="border-t bg-muted/50 px-6 py-20">
        <div className="mx-auto max-w-2xl">
          <h2 className="mb-3 text-center text-2xl font-bold sm:text-3xl">インストール手順</h2>
          <p className="mx-auto mb-10 max-w-lg text-center text-muted-foreground">
            現在Appleの公証を準備中のため、初回だけmacOSに止められます。
            <br />
            下の手順で開けます(2回目からは、この操作は不要です)。
          </p>

          <Card className="shadow-sm">
            <CardContent className="py-7">
              <ol className="space-y-5 text-sm">
                <li>
                  <p className="font-semibold">1. UniEnter.pkg をダブルクリックする</p>
                  <p className="mt-1 text-muted-foreground">
                    「Appleは…マルウェアが含まれていないことを確認できませんでした」と出ます。
                    ここで<strong className="font-semibold text-foreground">「完了」</strong>
                    を押してください(「ゴミ箱に入れる」は押さないでください)。
                  </p>
                </li>
                <li>
                  <p className="font-semibold">
                    2. システム設定 → プライバシーとセキュリティ を開く
                  </p>
                  <p className="mt-1 text-muted-foreground">
                    画面を下までスクロールすると「セキュリティ」の項目に
                    「"UniEnter.pkg"は開発元を確認できないため、使用がブロックされました」
                    と表示されています。
                  </p>
                </li>
                <li>
                  <p className="font-semibold">3.「このまま開く」を押す</p>
                  <p className="mt-1 text-muted-foreground">
                    Touch IDまたはパスワードで認証すると、インストーラが始まります。
                  </p>
                </li>
              </ol>

              <div className="mt-7 space-y-3 border-t pt-6 text-sm text-muted-foreground">
                <p>
                  <strong className="font-semibold text-foreground">
                    手順2で該当の表示が見つからないときは、
                  </strong>
                  手順1をやり直してください。この項目は、開こうとした直後にだけ表示されます。
                </p>
                <p>
                  <strong className="font-semibold text-foreground">
                    macOS 15以降では、Finderで右クリック →「開く」の回避策は使えません。
                  </strong>
                  上の手順が唯一の方法です。
                </p>
                <p>
                  zip版も同じ手順です。うまくいかない場合は{" "}
                  <a className="underline" href="mailto:info@oc-to.com">
                    info@oc-to.com
                  </a>{" "}
                  までご連絡ください(お使いのmacOSのバージョンを添えていただけると助かります)。
                </p>
              </div>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" data-track-section="pricing" className="border-t px-6 py-20">
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
                <li>✓ ご本人が使うMacなら、台数の制限なし</li>
              </ul>
              <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
                <Button size="lg" asChild>
                  <a
                    href="https://github.com/iwai-ddndn/UniEnter/releases/latest/download/UniEnter.pkg"
                    onClick={() => track("download_click", { file_type: "pkg", location: "pricing" })}
                  >
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
      <section id="faq" data-track-section="faq" className="border-t bg-muted/50 px-6 py-20">
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
          <a className="underline" href="./terms.html">利用規約</a>
          <a className="underline" href="./privacy.html">プライバシーポリシー</a>
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
        <p className="mx-auto mt-2 max-w-lg">
          記載の製品名は各社の商標です。本アプリは各社と無関係の個人開発ソフトウェアです。
        </p>
      </footer>
    </div>
  )
}
