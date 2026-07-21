import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Coffee, CornerDownLeft, Heart, HeartHandshake } from "lucide-react"

/*
 * 投げ銭の受け皿リンク。アカウント開設後にURLを入れて ready を true にする。
 * ready=false の間は「準備中」表示になる。
 */
const channels = [
  {
    icon: Coffee,
    name: "Buy Me a Coffee",
    description: "コーヒー1杯分から、単発で応援できます。",
    url: "",
    ready: false,
  },
  {
    icon: HeartHandshake,
    name: "GitHub Sponsors",
    description: "GitHubアカウントで、単発・月額どちらでも。手数料0%で全額届きます。",
    url: "",
    ready: false,
  },
]

export default function SupportPage() {
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

      <main className="mx-auto max-w-xl px-6 py-16">
        <div className="text-center">
          <Heart className="mx-auto mb-4 size-8 text-[#d44c47]" />
          <h1 className="text-3xl font-bold">開発を支援する</h1>
          <p className="mt-4 text-muted-foreground">
            UniEnterは無料で、広告もありません。
            <br />
            役に立ったら、コーヒー1杯分の投げ銭で応援してもらえるとうれしいです。
          </p>
        </div>

        <div className="mt-10 space-y-4">
          {channels.map(({ icon: Icon, name, description, url, ready }) => (
            <Card key={name} className="shadow-sm">
              <CardContent className="flex items-center gap-4 py-5">
                <Icon className="size-6 shrink-0 text-muted-foreground" />
                <div className="min-w-0 flex-1">
                  <p className="font-semibold">{name}</p>
                  <p className="text-sm text-muted-foreground">{description}</p>
                </div>
                {ready ? (
                  <Button asChild>
                    <a href={url} target="_blank" rel="noopener noreferrer">
                      支援する
                    </a>
                  </Button>
                ) : (
                  <Badge variant="secondary" className="shrink-0 text-muted-foreground">
                    準備中
                  </Badge>
                )}
              </CardContent>
            </Card>
          ))}
        </div>

        <div className="mt-10 rounded-xl border bg-muted p-6 text-sm text-muted-foreground">
          <p className="mb-2 font-semibold text-foreground">支援金の使い道</p>
          <ul className="list-inside list-disc space-y-1">
            <li>Apple Developer Program 年会費(アプリの公証 = 警告なしで開けるようにする費用)</li>
            <li>対応アプリ・対応ブラウザの拡充と検証</li>
          </ul>
          <p className="mt-4 text-xs">
            支援は任意の寄付であり、ソフトウェアやサポートの対価ではありません。
            支援の有無にかかわらず、すべての機能を無料で利用できます。
          </p>
        </div>
      </main>

      <footer className="border-t px-6 py-10 text-center text-xs text-muted-foreground">
        <p>
          © 2026 octo — お問い合わせ:{" "}
          <a className="underline" href="mailto:info@oc-to.com">
            info@oc-to.com
          </a>
        </p>
      </footer>
    </div>
  )
}
