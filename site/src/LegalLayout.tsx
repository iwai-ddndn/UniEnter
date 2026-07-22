import { Button } from "@/components/ui/button"
import { CornerDownLeft } from "lucide-react"
import type { ReactNode } from "react"

/* 利用規約・プライバシーポリシー共通のレイアウト(ナビ+本文+フッター) */

export function LegalSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="mt-8">
      <h2 className="mb-2 text-lg font-semibold">{title}</h2>
      <div className="space-y-2 text-sm leading-relaxed text-muted-foreground">{children}</div>
    </section>
  )
}

export default function LegalLayout({
  title,
  established,
  children,
}: {
  title: string
  established: string
  children: ReactNode
}) {
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

      <main className="mx-auto max-w-2xl px-6 py-16">
        <h1 className="text-3xl font-bold">{title}</h1>
        <p className="mt-3 text-sm text-muted-foreground">{established}</p>
        {children}
      </main>

      <footer className="border-t px-6 py-10 text-center text-xs text-muted-foreground">
        <p className="mb-2 space-x-4">
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
      </footer>
    </div>
  )
}
