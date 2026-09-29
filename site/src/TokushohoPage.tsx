import type { ReactNode } from "react"
import LegalLayout from "./LegalLayout"

/*
 * 特定商取引法に基づく表記。販売者(MoR)は Polar だが、広告(LP)を運営しているのは本人なので置いておく。
 * 住所・電話番号は「請求があれば遅滞なく開示」で省略(消費者庁の案内に基づく)。返品特約と動作環境は省略不可。
 * 根拠と経緯: notes/PAYMENT-CHECKLIST.md の「D. 特定商取引法に基づく表記」
 */
const rows: [string, ReactNode][] = [
  [
    "販売事業者",
    <>
      Polar Software, Inc.(米国デラウェア州)
      <br />
      本商品の決済・領収書・返金は、Polarが販売者(Merchant of Record)として取り扱います。
    </>,
  ],
  ["運営統括責任者", "岩井 宗一郎(屋号: octo)"],
  ["所在地", "請求があった場合には、遅滞なく電子メールにて開示いたします。"],
  [
    "電話番号",
    <>
      請求があった場合には、遅滞なく電子メールにて開示いたします。
      <br />
      お問い合わせは下記のメールアドレスにお願いいたします。
    </>,
  ],
  [
    "メールアドレス",
    <a className="underline" href="mailto:info@oc-to.com">
      info@oc-to.com
    </a>,
  ],
  [
    "ウェブサイト",
    <a className="underline" href="https://unienter.oc-to.com/">
      https://unienter.oc-to.com/
    </a>,
  ],
  ["販売価格", "1,480円(税込・買い切り)"],
  ["商品代金以外の必要料金", "インターネット接続に必要な通信料等は、お客様のご負担となります。"],
  ["支払方法", "クレジットカード等(Polarの購入画面でご利用いただける方法)"],
  ["支払時期", "ご注文時にお支払いが確定します。"],
  ["商品の引渡時期", "決済完了後、画面上に直ちにライセンスキーを表示します。"],
  [
    "返品・キャンセル",
    <>
      デジタル商品の性質上、購入後のお客様のご都合による返品・キャンセルはお受けしておりません。購入前に14日間の無料トライアルで動作をご確認ください。
      <br />
      不具合により正常に利用できない場合は、info@oc-to.com までご連絡ください。返金はPolarのポリシーに従って処理します。
    </>,
  ],
  [
    "動作環境",
    <>
      macOS 13(Ventura)以降、Appleシリコン / Intel搭載のMac
      <br />
      アクセシビリティの許可が必要です。
    </>,
  ],
  ["ライセンス", "買い切り。ご本人が使用するMacであれば、台数の制限なく利用できます。"],
]

export default function TokushohoPage() {
  return (
    <LegalLayout title="特定商取引法に基づく表記" established="最終更新日: 2026年9月29日">
      <dl className="mt-10 divide-y border-y text-sm">
        {rows.map(([k, v]) => (
          <div key={k} className="grid gap-1 py-4 sm:grid-cols-[10rem_1fr] sm:gap-4">
            <dt className="font-semibold">{k}</dt>
            <dd className="leading-relaxed text-muted-foreground">{v}</dd>
          </div>
        ))}
      </dl>
    </LegalLayout>
  )
}
