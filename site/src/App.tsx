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
import { useEffect, useState } from "react"
import { observeSections, track } from "@/lib/analytics"
import { ServiceTile, services } from "./brands"
import HeroDemo from "./HeroDemo"

/*
 * 色は index.css の --primary(ティール #0f7b6c)に一本化。
 * ティールは CTA・リンク・「改行」ラベル・フォーカスだけに使い、面や見出しには使わない。
 * 「送信」は本文色の墨。改行と送信の弁別は⌘キーの有無が担う。
 */
const TEAL = "#0f7b6c"

const PKG_URL = "https://github.com/iwai-ddndn/UniEnter/releases/latest/download/UniEnter.pkg"
const ZIP_URL = "https://github.com/iwai-ddndn/UniEnter/releases/latest/download/UniEnter.zip"
const REPO_URL = "https://github.com/iwai-ddndn/UniEnter"
const RELEASES_URL = "https://github.com/iwai-ddndn/UniEnter/releases"

/*
 * 質問はすべてユーザー側の言葉・疑問文で書く。専門用語(フェイルセーフ、書き換え、
 * 〜側に倒す)は使わない。「安心 → 使い方 → 購入」の3群に分ける。
 */
const faqGroups: { title: string; items: { q: string; a: React.ReactNode }[] }[] = [
  {
    title: "安心のこと",
    items: [
      {
        q: "変換のときのEnterで、誤って送信されない?",
        a: "されません。日本語を変換しているあいだのEnterには、UniEnterは一切手を出しません。判断に迷ったときも何もしない側に寄せてあるので、変換の確定が送信になることはありません。",
      },
      {
        q: "入力した文章が、どこかに送られない?",
        a: "送られません。UniEnterはインターネット通信を一切行いません(通信用のコードがそもそも入っていません)。キーが押されたことは見ますが、Enterと⌘以外は「文字キーが押された」という事実を日本語の変換中かどうかの判断に使うだけで、どの文字かは記録も保存もしません。ほかに見ているのは、前面のアプリと、ブラウザのタブのURL(対象サービスかどうかの判定だけ)です。",
      },
      {
        q: "アクセシビリティの許可は、何に使われる?",
        a: (
          <>
            Enterが押されたことを知って、それを改行に置き換えるには、macOSではこの許可しかありません。
            入力した文章を記録・保存・送信することはありません。通信もしないので、送る先がそもそもありません。
            ソースコードは{" "}
            <a className="underline" href={REPO_URL}>
              GitHub
            </a>{" "}
            で全部公開しています。
          </>
        ),
      },
    ],
  },
  {
    title: "使い方のこと",
    items: [
      {
        q: "アプリ側の設定と、どちらが優先される?",
        a: "UniEnterが優先されます。LINEやSlackが「Enterで送信」の設定でも、チェックを入れたアプリでは Enter=改行 / ⌘Enter=送信 になります。各アプリの設定画面を開いて確認する必要はありません(例外が1つだけあります。この群の最後の項目をご覧ください)。",
      },
      {
        q: "Enterで送信するのに慣れている。元に戻せる?",
        a: "戻せます。設定でアプリごとにチェックを外せば、そのアプリは元の動きに戻ります。全部オフにすることもできます。",
      },
      {
        q: "容量やCPUはどのくらい使う?",
        a: "アプリ本体は約3MBです。常駐しますが、キーを押したときだけ動くためCPUはほぼ0%。画面いちばん上のメニューバー(時計やWi-Fiのアイコンが並ぶ帯)にアイコンが1つ増えるほかは、何も表示しません。",
      },
      {
        q: "インストールで「開発元を確認できません」と出て進めない",
        a: (
          <>
            Appleの公証を申請中のため、初回だけmacOSに止められます。
            <a className="underline" href="#install">
              はじめかた
            </a>
            の②の手順で開けます。2回目以降は、警告なしで開けます。
          </>
        ),
      },
      {
        q: "⌘Enterを押しても送信できない",
        a: "そのアプリ自身の設定で、送信キーをすでに「⌘Enter」に変更している場合に起こります。UniEnterの切り替えと二重にかかるためです。UniEnterの設定を開き、一番下の「⌘Enterを押しても送信できないときは」から、そのアプリにチェックを入れてください。UniEnterがそのアプリに手を出さなくなり、元どおり送信できます。",
      },
    ],
  },
  {
    title: "購入のこと",
    items: [
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
        a: (
          <>
            購入の受付はまだ開始していません。開始しましたら、このページと{" "}
            <a className="underline" href={RELEASES_URL}>
              リリース一覧
            </a>{" "}
            でご案内します。領収書・インボイスは発行できます。
          </>
        ),
      },
    ],
  },
]

/*
 * インストール手順のスクリーンショット。macOSのダイアログ3枚は別途撮影して
 * public/assets/install/ に置く。まだ無いあいだは枠だけを出し、ビルドは通す。
 */
function Shot({ src, alt, caption }: { src: string; alt: string; caption: string }) {
  const [missing, setMissing] = useState(false)
  return (
    <figure className="min-w-0">
      {missing ? null : (
        <img
          src={src}
          alt={alt}
          loading="lazy"
          onError={() => setMissing(true)}
          className="mx-auto max-h-64 w-auto rounded-lg border bg-white object-contain"
        />
      )}
      <figcaption className="mt-2 text-xs text-muted-foreground">{caption}</figcaption>
    </figure>
  )
}

function DownloadButton({ location, label }: { location: string; label: string }) {
  return (
    <Button size="lg" asChild>
      <a href={PKG_URL} onClick={() => track("download_click", { file_type: "pkg", location })}>
        {label}
      </a>
    </Button>
  )
}

export default function App() {
  useEffect(() => observeSections(), [])

  return (
    <div className="min-h-screen">
      {/* Nav — 途中で買う気になった人がいつでも押せるよう sticky にする */}
      <nav className="sticky top-0 z-50 border-b bg-background/90 backdrop-blur">
        <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-3">
          <span className="flex items-center gap-2 font-semibold">
            <CornerDownLeft className="size-4" /> UniEnter
          </span>
          <div className="flex items-center gap-2">
            <Button variant="ghost" size="sm" asChild className="hidden sm:inline-flex">
              <a href={REPO_URL}>ソースコード(GitHub)</a>
            </Button>
            <Button variant="ghost" size="sm" asChild>
              <a href="#pricing">価格</a>
            </Button>
            <Button size="sm" asChild>
              <a
                href={PKG_URL}
                onClick={() => track("download_click", { file_type: "pkg", location: "nav" })}
              >
                無料で試す
              </a>
            </Button>
          </div>
        </div>
      </nav>

      {/* Hero — CTAはデモより前に置き、ファーストビューの中に入れる */}
      <header data-track-section="hero" className="px-6 pt-10 pb-16 text-center sm:pt-14">
        <Badge variant="secondary" className="mb-5 font-normal text-muted-foreground">
          メニューバーに常駐・14日間無料・買い切り
        </Badge>
        <h1 className="text-2xl leading-snug font-bold sm:text-5xl sm:leading-snug">
          Enterは改行、
          {/* 狭い画面では「送信は⌘Enter。」を独立した行に落とす(単語の途中で折れるのを防ぐ) */}
          <br className="sm:hidden" />
          送信は⌘Enter。
          <br />
          Macのチャット、ぜんぶで。
        </h1>
        <p className="mx-auto mt-5 max-w-lg text-muted-foreground">
          アプリごとの設定画面を開いて回る必要はありません。起動しておくだけで、対象アプリがすべて同じ操作に揃います。
        </p>

        <div className="mt-7 flex flex-wrap items-center justify-center gap-3">
          <DownloadButton location="hero" label="14日間、無料で試す" />
          <Button size="lg" variant="outline" asChild>
            <a href="#pricing">価格を見る</a>
          </Button>
        </div>
        <p className="mt-3 text-xs text-muted-foreground">
          macOS 13以降 / Mac用インストーラ(.pkg・約3MB)
        </p>
        <div className="mx-auto mt-5 max-w-md rounded-lg border px-4 py-3 text-left text-sm">
          初回だけ、Macが確認を求めます(Appleの公証を申請中のため)。開き方は2分 →{" "}
          <a className="font-medium underline" href="#install">
            はじめかた
          </a>
        </div>

        <div className="mt-10">
          <HeroDemo />
        </div>

        <p className="mx-auto mt-8 max-w-lg text-lg font-medium">書きかけのまま、送信されない。</p>
      </header>

      {/* Before / After */}
      <section data-track-section="before-after" className="border-t px-6 py-16">
        <div className="mx-auto max-w-4xl">
          <h2 className="mb-10 text-center text-2xl font-bold sm:text-3xl">
            アプリごとに違うEnterを、1つに戻す。
          </h2>

          <div className="grid gap-5 sm:grid-cols-2">
            <Card className="border-transparent bg-muted shadow-none">
              <CardContent className="pt-2">
                <p className="mb-5 text-xs font-semibold tracking-widest text-muted-foreground">
                  これまで
                </p>
                <div className="space-y-3 text-sm text-muted-foreground">
                  <p>Slackは設定で変えられる。LINEは変えられない。Teamsは会社が決めている。</p>
                  <p>で、どれをどう設定したか、もう覚えていない。</p>
                </div>
              </CardContent>
            </Card>

            <Card className="shadow-sm">
              <CardContent className="pt-2">
                <p className="mb-5 text-xs font-semibold tracking-widest text-muted-foreground">
                  UniEnterを入れると
                </p>
                <div className="space-y-3">
                  <div className="flex items-center gap-3">
                    <kbd className="rounded-md border bg-muted px-2.5 py-1 text-sm font-semibold">
                      Enter
                    </kbd>
                    <span className="text-sm font-medium" style={{ color: TEAL }}>
                      → 改行
                    </span>
                  </div>
                  <div className="flex items-center gap-3">
                    <kbd className="rounded-md border bg-muted px-2.5 py-1 text-sm font-semibold">
                      ⌘
                    </kbd>
                    <kbd className="rounded-md border bg-muted px-2.5 py-1 text-sm font-semibold">
                      Enter
                    </kbd>
                    <span className="text-sm font-medium">→ 送信</span>
                  </div>
                </div>
                <p className="mt-5 text-sm">対象にしたアプリは、この2つだけ。</p>
                <p className="mt-6 border-t pt-4 text-sm text-muted-foreground">
                  → 各アプリの設定画面は、もう開かなくていい。
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* 対応サービス */}
      <section data-track-section="apps" className="border-t bg-muted/50 px-6 py-16">
        <div className="mx-auto max-w-4xl">
          <h2 className="mb-3 text-center text-2xl font-bold sm:text-3xl">
            アプリでも、ブラウザでも。
          </h2>
          <p className="mx-auto mb-10 max-w-md text-center text-muted-foreground">
            いま使っているアプリが下のどれかなら、そのまま揃います。ブラウザで開くWeb版も対象です。
          </p>
          <figure className="mx-auto mb-10 max-w-[240px]">
            <img
              src="./assets/install/settings.webp"
              alt="UniEnterの設定画面。対応サービスがチェックリストで並んでいる"
              width={340}
              height={524}
              loading="lazy"
              className="w-full rounded-lg border bg-white shadow-sm"
            />
            <figcaption className="mt-2 text-center text-xs text-muted-foreground">
              実際の設定画面。使うサービスにチェックを入れるだけです。
            </figcaption>
          </figure>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {services.map((service) => (
              <ServiceTile key={service.name} service={service} />
            ))}
          </div>
          <p className="mt-6 text-center text-xs text-muted-foreground">
            「ブラウザ」バッジは、Safari / Chrome / Edge / Arc などでそのサービスのWeb版を開いたタブが対象、という意味です。
          </p>
        </div>
      </section>

      {/* 安心 — Macの警告文を読む「前」に読ませる */}
      <section id="safety" data-track-section="safety" className="border-t px-6 py-16">
        <div className="mx-auto max-w-3xl">
          <h2 className="mb-3 text-center text-2xl font-bold sm:text-3xl">
            キー入力を扱うアプリなので、先に説明します。
          </h2>
          <p className="mx-auto mb-10 max-w-lg text-center text-muted-foreground">
            何を見ていて、何を見ていないか。確かめる方法も書いておきます。
          </p>

          <div className="grid gap-5 sm:grid-cols-2">
            <div className="rounded-xl border px-5 py-5">
              <h3 className="mb-2 font-semibold">入力した文章は、どこにも送りません</h3>
              <p className="text-sm text-muted-foreground">
                インターネット通信を一切行いません。UniEnterが使うのは、
                <strong className="font-medium text-foreground">
                  EnterキーとCommand(⌘)キーが押されたかどうか
                </strong>
                、
                <strong className="font-medium text-foreground">どのアプリ・どのサイトが前面か</strong>
                、そして日本語の変換中かを判断するための「文字キーが押された」という事実だけです。どの文字を打ったかは、記録も保存もしません。
              </p>
            </div>

            <div className="rounded-xl border px-5 py-5">
              <h3 className="mb-2 font-semibold">アクセシビリティの許可が要る理由</h3>
              <p className="text-sm text-muted-foreground">
                Enterが押されたことを知って、それを改行に置き換えるには、macOSではこの許可しかありません。入力した文章を記録・保存・送信することはありません。通信もしないので、送る先がそもそもありません。
              </p>
            </div>

            <div className="rounded-xl border px-5 py-5">
              <h3 className="mb-2 font-semibold">変換中のEnterには、触れません</h3>
              <p className="text-sm text-muted-foreground">
                日本語を変換しているあいだ(まだ確定しておらず、下線が付いた文字が出ている状態)のEnterは、そのまま通します。変換の確定が、誤って送信になることはありません。
              </p>
            </div>

            <div className="rounded-xl border px-5 py-5">
              <h3 className="mb-2 font-semibold">ソースコードは、すべて公開しています</h3>
              <p className="text-sm text-muted-foreground">
                中身は{" "}
                <a className="font-medium text-primary underline" href={REPO_URL}>
                  GitHub
                </a>{" "}
                で全部読めます。通信用のコードが一切無いことも、ソースを検索すれば確かめられます。
                <a className="underline" href="./privacy.html">
                  プライバシーポリシー
                </a>
                もあわせてどうぞ。
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* はじめかた — 全員が必ず通る本流。折りたたむのは例外だけ */}
      <section id="install" data-track-section="install" className="border-t bg-muted/50 px-6 py-16">
        <div className="mx-auto max-w-3xl">
          <h2 className="mb-3 text-center text-2xl font-bold sm:text-3xl">はじめかた(2分)</h2>
          <ol className="mx-auto mb-10 flex max-w-xl flex-wrap items-center justify-center gap-x-2 gap-y-2 text-sm">
            {["ダウンロード", "Macに許可する", "使うアプリにチェック"].map((label, i) => (
              <li key={label} className="flex items-center gap-2">
                <span className="flex size-6 items-center justify-center rounded-full bg-primary text-xs font-semibold text-primary-foreground">
                  {i + 1}
                </span>
                <span className="font-medium">{label}</span>
                {i < 2 && <span className="ml-1 text-muted-foreground">→</span>}
              </li>
            ))}
          </ol>

          <div className="space-y-5">
            {/* ① */}
            <Card className="shadow-sm">
              <CardContent className="py-2">
                <h3 className="mb-2 flex items-center gap-2 font-semibold">
                  <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary text-xs text-primary-foreground">
                    1
                  </span>
                  ダウンロード
                </h3>
                <p className="text-sm text-muted-foreground">
                  UniEnter.pkg をダウンロードして、ダブルクリックします。
                </p>
                <div className="mt-4">
                  <DownloadButton location="install" label="14日間、無料で試す" />
                </div>
              </CardContent>
            </Card>

            {/* ② */}
            <Card className="shadow-sm">
              <CardContent className="py-2">
                <h3 className="mb-2 flex items-center gap-2 font-semibold">
                  <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary text-xs text-primary-foreground">
                    2
                  </span>
                  Macに許可する(初回だけ)
                </h3>

                <div className="mb-4 rounded-lg border bg-muted px-4 py-3 text-sm">
                  <p className="mb-1 font-semibold">なぜMacに止められるの?</p>
                  <p className="text-muted-foreground">
                    Appleの公証(年間の開発者登録が必要です)を申請中だからです。ソフトの中身に問題があるという意味ではありません。UniEnterはソースコードをすべて{" "}
                    <a className="underline" href={REPO_URL}>
                      GitHub
                    </a>{" "}
                    で公開していて、インターネット通信を一切行いません。
                  </p>
                </div>

                <p className="mb-4 text-sm text-muted-foreground">次の3クリックで開けます。</p>

                <div className="grid gap-5 sm:grid-cols-3">
                  <div>
                    <p className="mb-2 text-sm font-medium sm:min-h-16">
                      1.「完了」を押す(「ゴミ箱に入れる」は押さない)
                    </p>
                    <Shot
                      src="./assets/install/gatekeeper.png"
                      alt="pkgを開いたときにmacOSが出す確認ダイアログ"
                      caption="「完了」を押します。ここでゴミ箱に入れないでください。"
                    />
                  </div>
                  <div>
                    <p className="mb-2 text-sm font-medium sm:min-h-16">
                      2. システム設定 →「プライバシーとセキュリティ」→ 下までスクロール →「このまま開く」
                    </p>
                    <Shot
                      src="./assets/install/settings-security.png"
                      alt="システム設定のプライバシーとセキュリティ画面。下部のセキュリティ項目"
                      caption="この項目は、開こうとした直後にだけ表示されます。"
                    />
                  </div>
                  <div>
                    <p className="mb-2 text-sm font-medium sm:min-h-16">
                      3. Touch IDまたはパスワードで確認 → インストーラが始まります
                    </p>
                    <Shot
                      src="./assets/install/auth.png"
                      alt="Touch IDまたはパスワードを求める確認シート"
                      caption="ここまでで、インストールは終わりです。"
                    />
                  </div>
                </div>

                <details className="mt-5 border-t pt-4 text-sm">
                  <summary className="cursor-pointer font-medium">うまくいかないときは</summary>
                  <ul className="mt-3 space-y-2 text-muted-foreground">
                    <li>
                      手順2の表示が見つからない → 手順1をやり直してください。この項目は、開こうとした直後にだけ表示されます。
                    </li>
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
              </CardContent>
            </Card>

            {/* ③ */}
            <Card className="shadow-sm">
              <CardContent className="py-2">
                <h3 className="mb-2 flex items-center gap-2 font-semibold">
                  <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary text-xs text-primary-foreground">
                    3
                  </span>
                  使うアプリにチェック
                </h3>
                <p className="mb-4 text-sm text-muted-foreground">
                  インストールが終わるとUniEnterが起動し、キー入力を扱うための許可(アクセシビリティ)を求めます。許可したら、使っているアプリにチェックを入れて終わりです。
                </p>
                <div className="grid gap-5 sm:grid-cols-2">
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
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" data-track-section="pricing" className="border-t px-6 py-16">
        <div className="mx-auto max-w-xl">
          <h2 className="mb-3 text-center text-2xl font-bold sm:text-3xl">価格</h2>
          <p className="mx-auto mb-10 max-w-md text-center text-muted-foreground">
            買い切りです。サブスクではありません。
          </p>
          <Card className="shadow-sm">
            <CardContent className="py-6 text-center">
              <p className="text-4xl font-bold">
                ¥1,480 <span className="text-base font-normal text-muted-foreground">(税込)</span>
              </p>
              <ul className="mx-auto mt-6 max-w-xs space-y-2 text-left text-sm text-muted-foreground">
                <li>✓ すべての対象アプリと、そのWeb版</li>
                <li>✓ 以後のアップデートは追加費用なし</li>
                <li>✓ ご本人が使うMacなら、台数の制限なし</li>
              </ul>
              <div className="mt-8 flex justify-center">
                <DownloadButton location="pricing" label="14日間、無料で試す" />
              </div>
              <p className="mt-4 text-sm text-muted-foreground">
                購入は準備中です。トライアル期間中に購入できるようになります。
              </p>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" data-track-section="faq" className="border-t bg-muted/50 px-6 py-16">
        <div className="mx-auto max-w-xl">
          <h2 className="mb-8 text-center text-2xl font-bold">よくある質問</h2>
          {faqGroups.map((group) => (
            <div key={group.title} className="mb-8 last:mb-0">
              <h3 className="mb-2 text-xs font-semibold tracking-widest text-muted-foreground">
                {group.title}
              </h3>
              <Accordion type="single" collapsible>
                {group.items.map(({ q, a }) => (
                  <AccordionItem key={q} value={q}>
                    <AccordionTrigger className="text-left">{q}</AccordionTrigger>
                    <AccordionContent className="text-muted-foreground">{a}</AccordionContent>
                  </AccordionItem>
                ))}
              </Accordion>
            </div>
          ))}
        </div>
      </section>

      {/* 最終CTA */}
      <section data-track-section="final-cta" className="border-t px-6 py-16 text-center">
        <h2 className="text-2xl font-bold sm:text-3xl">Enterは改行、送信は⌘Enter。</h2>
        <p className="mx-auto mt-3 max-w-md text-muted-foreground">
          14日間、全機能をそのまま試せます。合わなければ、削除するだけです。
        </p>
        <div className="mt-7 flex flex-wrap items-center justify-center gap-3">
          <DownloadButton location="final" label="14日間、無料で試す" />
          <Button size="lg" variant="outline" asChild>
            <a href="#install">開き方(2分)</a>
          </Button>
        </div>
        <p className="mt-3 text-xs text-muted-foreground">
          macOS 13以降 / Mac用インストーラ(.pkg・約3MB)
        </p>
      </section>

      {/* 作っている人 */}
      <section data-track-section="maker" className="border-t bg-muted/50 px-6 py-12">
        <div className="mx-auto max-w-xl text-sm text-muted-foreground">
          <h2 className="mb-3 font-semibold text-foreground">作っている人</h2>
          <p className="mb-2">
            octo(オクト)という屋号での個人開発です。会社のソフトではありません。
          </p>
          <p className="mb-2">
            不具合の報告・要望・購入の相談は、直接わたしに届きます。{" "}
            <a className="underline" href="mailto:info@oc-to.com">
              info@oc-to.com
            </a>{" "}
            へ。屋号のサイトは{" "}
            <a className="underline" href="https://oc-to.com" target="_blank" rel="noopener noreferrer">
              oc-to.com
            </a>{" "}
            です。
          </p>
        </div>
      </section>

      <footer className="border-t px-6 py-10 text-center text-xs text-muted-foreground">
        <p className="mb-2 space-x-4">
          <a className="underline" href={REPO_URL}>
            ソースコード(GitHub)
          </a>
          <a
            className="underline"
            href={ZIP_URL}
            onClick={() => track("download_click", { file_type: "zip", location: "footer" })}
          >
            zip版
          </a>
          <a className="underline" href={RELEASES_URL}>
            リリース一覧
          </a>
          <a className="underline" href="#pricing">
            価格
          </a>
          <a className="underline" href="./terms.html">
            利用規約
          </a>
          <a className="underline" href="./privacy.html">
            プライバシーポリシー
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
        <p className="mx-auto mt-2 max-w-lg">
          記載の製品名は各社の商標です。本アプリは各社と無関係の個人開発ソフトウェアです。
        </p>
      </footer>
    </div>
  )
}
