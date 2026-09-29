> **進捗(2026-09-29)**: Apple Developer Program 申請済み(承認待ち)。Polar 組織 `oc-to`(表示名 octo)作成・審査承認・
> 本人確認・Stripe入金口座 接続済み。Checkout Link 作成済み(`https://buy.polar.sh/polar_cl_zdFJOA7iIWaUzPThWsIjQKyRW0pImM8vfTuhn1sIQLk`、
> Success URL は Worker の `/license?checkout_id={CHECKOUT_ID}`)。Worker `https://unienter-license.oc-to.workers.dev` を公開し、
> Webhook(order.paid)と秘密鍵を登録。100%割引コードでの¥0テスト購入で、キー発行→表示→公開鍵での署名検証まで通った。
> 残り: 特商法表記ページ(氏名待ち)→ LP購入ボタン公開、公証(Apple承認待ち)、POLAR_ACCESS_TOKEN(任意)、Resend(任意)。

# 課金開始チェックリスト(2026-09-29調査)

UniEnter(¥1,480税込・買い切り・14日トライアル・Ed25519オフラインキー)の販売を始めるまでに
**ご本人がやること / Claudeがやること** を順番に並べたもの。詳細手順は `notes/POLAR-SETUP.md`。
各記述の根拠は末尾「出典」の番号 [n] を参照。**【要確認】** は調査で確定できなかった点。

---

## 結論: Polar.sh を継続する

- 日本は Polar の payout 対応国(Stripe Connect Express 経由)[1]。JPY は提示通貨として全組織で利用可 [2][3]。
  日本の顧客には税込表示がデフォルト(米・加・印以外は inclusive)[3]
- ソフトウェア+ライセンスキー販売は Polar の許容範囲 [4]。Webhook の `{CHECKOUT_ID}` 置換・
  Standard Webhooks 署名(2026-09-08以降発行のsecret)も既存Worker実装と一致 [5][6]
- Polar 組み込みのライセンスキー機能は UUID 形式の自動生成+オンライン検証API で、
  外部生成キーの持ち込みは不可 [7]。**UniEnter はオフラインEd25519検証なので、自前Worker(署名者)は引き続き必要**
- 他の選択肢を検討したが、乗り換える強い理由はない:

| 候補 | 状況(2026-09時点) | 判断 |
|---|---|---|
| **Polar** | 新規組織は Starter 5%+50¢(2026-05-27以降作成)、非米カード+1.5% [8][9] | **継続** |
| Paddle | 5%+50¢。ドメイン審査が7週間以上pendingで停滞(本リポジトリの経緯) | 見送り(再開理由なし) |
| Lemon Squeezy | Stripe傘下。2026-01に「サポートは遅く更新も少ない、Stripe Managed Paymentsへの移行を促す」と公表 [10] | 新規採用は非推奨 |
| Stripe Managed Payments | 日本は対象国だが [11]、**日本拠点の事業者は日本国内向け売上の消費税を自分で申告納付**(MoRの恩恵が国内販売で消える)[12] | 国内中心のUniEnterには不向き |
| Gumroad | 2025年からMoR。10%+50¢+決済手数料で実質約13%+80¢(記事ベース)[13] | 手数料が高い |
| Stripe直(非MoR) | 国内カード3.6% [14]。販売者=本人となり特商法表記・海外VAT等を自分で負う | 手間とリスクが増える |

### 1本あたりの手取り目安【要確認: 為替 $1=¥150 と仮定した概算】

- 売価 ¥1,480(税込)。Polarが日本の消費税を徴収する場合、税抜 ¥1,345【要確認: 後述】
- Polar手数料: 5% ≒ ¥74 + $0.50 ≒ ¥75 + 非米カード1.5% ≒ ¥22 → **約 ¥171(約11.6%)** [8]
- 別途 payout 時: 月$2(payoutがあった月)+ 1回ごと 0.25%+$0.25、通貨換算 最大1% [8]
- → **1本あたり概ね ¥1,150〜1,300 前後**(税の扱い次第)

---

## A. ご本人の作業(順番どおり)

### A-0. 先に決めておくこと(5分)
- [ ] 特商法表記に載せる **氏名(戸籍上の氏名)** を確認。屋号「octo」だけでは不可 [15]
- [ ] 住所・電話番号を LP に載せるか、「請求があれば遅滞なく開示」方式にするか決める(→ セクション D)
- [ ] `license-signing/keys.txt` を **パスワードマネージャ等にバックアップ**(Cloudflareにも置くことになるため)

### A-1. Apple Developer Program 加入(**最優先。公証の前提**)— 30分+承認最大48時間程度
- [ ] 2ファクタ認証が有効な Apple Account で https://developer.apple.com/jp/programs/enroll/ から個人として登録 [16]
  - 姓名は**正式な個人名を半角ローマ字**で(ニックネーム・屋号不可)、私書箱不可 [16]
- [ ] 年会費 **$99(日本では登録時に円表示。¥12,980前後との報告多数)【要確認: 登録画面の表示額】** [16][17]
- [ ] 購入後24時間以内に確認メールが届く [18]
- [ ] 届いたら Claude に連絡 → Developer ID 証明書作成・公証の手順に進む(Xcodeでのサインインだけご本人)

> 公証が済むまで広く告知しない方針(CLAUDE.md)は変わらない。Polar の準備は並行して進めてよい。

### A-2. Polar アカウント作成(15分)
- [ ] https://polar.sh/ でサインアップ → Organization 作成(個人でも可)
- [ ] **サンドボックス**も別途作成: https://sandbox.polar.sh/
- [ ] 2FA を有効化
- [ ] Organization settings にサイト `https://unienter.oc-to.com/` と SNS リンク(X等)を登録(審査で不正防止確認に使われる)[19]
- 注: 2026-05-27以降に作った組織は 4%+40¢ の旧料金(Early Member)対象外 [9]。
  **もし既にそれ以前に組織を作っていたら、それを使う方が安い**(有料プランへ上げると旧料金は消える)

### A-3. 商品作成(10分)— 本番・サンドボックス両方
- [ ] Products → New Product: `UniEnter` / **One-time purchase**
- [ ] 価格を **JPY 1,480** で設定。デフォルト通貨の価格は必須(空だと無料扱い)[3]
  - 確認済み(2026-09-29): 組織作成時にデフォルト通貨として Japanese Yen を選べる
- [ ] Settings の税表示で、日本向けが **税込(inclusive)** になっていることを確認 [3]
- [ ] Benefits(特典)は付けない(キーは自前Workerが発行するため Polar のライセンスキー特典は不要)

### A-4. Cloudflare アカウント(10分、無料)
- [ ] https://dash.cloudflare.com/sign-up で作成(Workers Free: 1日10万リクエスト、KV書込1日1,000回で十分)[20]
- [ ] ターミナルで `wrangler login` のブラウザ認可(**ご本人がクリック**)
- [ ] workers.dev サブドメイン名を控える(→ Webhook URL に使う: `https://unienter-license.<サブドメイン>.workers.dev`)

### A-5. Webhook・トークン(10分)— 本番・サンドボックス別々
- [ ] Organization Settings → Webhooks → Add Endpoint
  - URL: `https://unienter-license.<サブドメイン>.workers.dev/polar/webhook`
  - Format: **Raw** / Events: **`order.paid`** のみ [6]
  - 表示される secret を **ご本人が** `wrangler secret put POLAR_WEBHOOK_SECRET` に貼る
- [ ] Settings → Developers → Organization access token 発行(customers・checkouts 読み取り)
  → `wrangler secret put POLAR_ACCESS_TOKEN` に貼る
- **secret/トークンはチャットに貼らない**。Claude はコマンドを用意するだけで、値の入力はご本人が行う

### A-6. メール送信(任意・30分)— 購入者にキーをメールで送る場合
- Worker は Resend API を使う(`RESEND_API_KEY` 未設定ならメール送信せず、購入完了ページにキーを表示するだけ)
- [ ] https://resend.com でアカウント作成。無料枠は月3,000通・1日100通・ドメイン1つ [21]
- [ ] `oc-to.com` をドメイン登録し、表示された DNS レコード(SPF/DKIM)を oc-to.com の DNS に追加
  【要確認】oc-to.com の DNS 管理先(レジストラ/Cloudflare等)
- [ ] API キー発行 → `wrangler secret put RESEND_API_KEY`
- [ ] 送信元 `license@oc-to.com`(wrangler.toml の MAIL_FROM)で良いか確認。返信は info@oc-to.com 宛に届くか確認
- メールを後回しにする場合も、Polar の購入通知メールを見て `issue.swift` で手動送付すれば運用できる

### A-7. Checkout Link 作成(5分)
- [ ] Checkout Links → New Link → UniEnter を選択
- [ ] Success URL: `https://unienter-license.<サブドメイン>.workers.dev/license?checkout_id={CHECKOUT_ID}` [5]
- [ ] Return URL: `https://unienter.oc-to.com/`
- [ ] 生成された URL を Claude に共有(本番・サンドボックス両方)

### A-8. サンドボックスでテスト購入(15分)
- [ ] テストカード `4242 4242 4242 4242` で購入 → `/license` ページにキー表示 → アプリに貼って有効化
  (Claude がブラウザで確認を手伝える。カード入力はテストカードでもご本人が行う)

### A-9. 審査・本人確認・受取口座(作業30分、審査最大14日)[19]
- [ ] 事業内容の説明を提出(下の文例を使用可)
- [ ] **Stripe Identity**: 運転免許証/マイナンバーカード/パスポート+セルフィー
- [ ] **Stripe Connect Express** で日本の銀行口座を登録(payout先)
- [ ] 商品確認用に **100%割引コード** を発行して審査担当に渡す、または未購入→購入→有効化の**画面録画**を提出 [19]
- 審査中も決済は受け付けられ、payout要求は「Held for review」で保留→承認後に自動送金 [19]
- 購入者からの問い合わせには **48時間以内に返信** が求められる [19]

事業内容の文例:
> UniEnter is a macOS menu-bar utility that remaps Enter to newline and Cmd+Enter to send in chat apps.
> Sold as a one-time license (JPY 1,480). 14-day free trial; license keys are delivered instantly after purchase.
> Website: https://unienter.oc-to.com/ — Support: info@oc-to.com

### A-10. 税務(時期を見て)
- [ ] **開業届**(個人事業の開業届出書): 事業開始の年分の確定申告期限まで [22]
- [ ] **青色申告**にするなら承認申請書: 原則その年の3月15日まで(1/16以降に開業した場合は開業から2か月以内)[22]
- [ ] 確定申告: Polar からの payout(円換算)を事業収入として計上。Polar/Stripeの手数料・Apple年会費・Cloudflare/Resend費用は経費
- 消費税【要確認・税理士に確認推奨】:
  - 販売者(MoR)は Polar(米国法人)で、本人は Polar に対してライセンスを提供している構造。
    電気通信利用役務の内外判定は「役務の提供を受ける者の住所等」で行うため [23]、
    Polar 向け提供は **国外取引(不課税)** と整理されるのが一般的な見解 [24]
  - この整理なら本人側で消費税の申告・インボイス登録は不要。ただし契約上の取引形態(再販か代理か)で結論が変わりうる
  - Polar が日本の購入者から消費税を徴収・納付しているか(日本の登録国外事業者か)は公式ドキュメントで確認できなかった【要確認: Polarサポートへ問い合わせ】[25]

---

## B. Claude がやること(ご本人の作業後)

| # | 作業 | 前提 | 目安 |
|---|---|---|---|
| B-1 | `wrangler kv namespace create LICENSES` → `wrangler.toml` の ID 差し替え、`wrangler deploy`(サンドボックス設定で) | A-4 のログイン済み | 10分 |
| B-2 | `node compat-test.mjs` / `node webhook-test.mjs` の再実行、デプロイ後の `/license` 疎通確認 | B-1 | 10分 |
| B-3 | 本番切替: `POLAR_API_BASE` を `https://api.polar.sh` に戻して再デプロイ | A-8 完了 | 5分 |
| B-4 | LP(`site/src/App.tsx` の Pricing)の「購入は準備中」を購入ボタン(Checkout Link)に差し替え、FAQ(`site/src/faq.tsx`)の「購入の受付はまだ開始していません」を更新 → `npm run build` | A-7 のURL | 20分 |
| B-5 | **特商法表記ページを新設**(`site/tokushoho.html` + `TokushohoPage.tsx`、フッター・価格欄からリンク) | セクションDの placeholder 埋め | 30分 |
| B-6 | **利用規約・プライバシーポリシーの Paddle 記述を Polar に更新**(`TermsPage.tsx` 第2条、`PrivacyPage.tsx` の決済の項。現状まだ Paddle.com Market Ltd. と書かれている) | — | 15分 |
| B-7 | `UniEnter/UI/LicenseView.swift` の `purchaseURL`: 現状 `https://unienter.oc-to.com/#pricing`。**LP経由のままを推奨**(価格・特商法表記を見てから決済に進める/URL変更でアプリ再リリース不要)。直リンクにする場合は次回リリースに同梱 | — | 5分 |
| B-8 | CLAUDE.md・README の Paddle 記述を Polar に更新 | — | 10分 |
| B-9 | Apple加入後: Developer ID 署名+`notarytool` 公証を `scripts/release.sh` に組み込み | A-1 | 1〜2時間 |

---

## C. 費用まとめ

| 項目 | 費用 | 出典 |
|---|---|---|
| Apple Developer Program | $99/年(円表示は登録時。¥12,980前後との報告)【要確認】 | [16][17] |
| Polar | 月額0円(Starter)。1取引 5%+50¢、非米カード+1.5%、payout月$2+0.25%+25¢、換算最大1%、チャージバック$15 | [8] |
| Cloudflare Workers/KV | 0円(Free枠内) | [20] |
| Resend | 0円(月3,000通まで) | [21] |
| 合計(固定費) | **Apple年会費のみ** | |

---

## D. 特定商取引法に基づく表記(草案・未公開)

### 前提となる法的整理
- 通信販売の広告には、事業者の氏名・住所・電話番号、価格、支払時期・方法、引渡時期、申込みの撤回(返品)、
  ソフトウェアの動作環境などの表示が必要 [15][26]
- 個人事業者は**戸籍上の氏名**(または商業登記簿の商号)が必要。通称・屋号のみは不可 [15]
- 「消費者からの請求があれば書面または電子メールで遅滞なく提供する」旨を表示し、実際に遅滞なく提供できる措置を
  とっていれば、**住所・電話番号等の一部事項は省略できる** [26][27]
  - ただし **返品特約(可否・条件)とソフトウェアの動作環境は省略不可** [26]
  - 「遅滞なく」= 申込みの意思決定に先立って十分な時間的余裕をもって提供すること [26]
- MoR(Polar)が契約上の販売者になる場合に本人の表記義務がどうなるかは、消費者庁の資料で明示的な記載を
  見つけられなかった【要確認・グレー】。**LP(広告)を運営しているのは本人なので、表記ページを置くのが安全側**。
  下の草案は「販売事業者=Polar/運営・開発=本人」を併記する形にしてある
- 参考: 申込みの最終確認画面の表示義務(2022年改正)は決済画面側(Polar)の問題になる。
  Polar のチェックアウト画面の表示内容で足りるかは【要確認】[28]

### 草案本文(`{{ }}` を埋める)

```
特定商取引法に基づく表記

販売事業者
  Polar Software, Inc.(Merchant of Record / 決済代行・販売者。米国デラウェア州。polar.sh/legal/privacy で確認済み)
  ※ 本商品の決済・領収書・返金はPolarが販売者として取り扱います

運営統括責任者(開発・提供者)
  {{戸籍上の氏名}}(屋号: octo)

所在地
  請求があった場合には、遅滞なく電子メールにて開示いたします。
  (または: {{住所}} / バーチャルオフィス等を使う場合は、その運営会社との合意等の条件あり[27])

電話番号
  請求があった場合には、遅滞なく電子メールにて開示いたします。
  お問い合わせは下記メールアドレスにお願いいたします。

メールアドレス
  info@oc-to.com

ウェブサイト
  https://unienter.oc-to.com/

販売価格
  1,480円(税込)

商品代金以外の必要料金
  インターネット接続に必要な通信料等はお客様のご負担となります。

支払方法
  クレジットカード等(Polarのチェックアウト画面で利用可能な方法)

支払時期
  ご注文時にお支払いが確定します。

商品の引渡時期
  決済完了後、画面上に直ちにライセンスキーを表示します
  (メール送信を有効にしている場合は、同じキーをメールでもお送りします)。

返品・キャンセル(返品特約)
  デジタル商品の性質上、購入後のお客様都合による返品・キャンセルはお受けしておりません。
  購入前に14日間の無料試用で動作をご確認ください。
  ただし、不具合により正常に利用できない場合等は、info@oc-to.com までご連絡ください。
  返金はPolarのポリシーに従って処理します。
  【要確認: 返金方針を「購入後○日以内は理由を問わず返金」にするか。規約第2条と揃える】

動作環境
  macOS 13 Ventura 以降(project.yml の deploymentTarget = 13.0)
  (Apple シリコン / Intel)【要確認: 対応CPU】
  アクセシビリティ権限の許可が必要です。

ライセンス
  買い切り。購入者本人が使用する複数のMacで利用できます(利用規約第1条)。
```

---

## 出典

1. Polar — Supported countries(Japan 掲載): https://polar.sh/docs/merchant-of-record/supported-countries
2. Polar(X)— 提示通貨にJPY追加の告知: https://x.com/polar_sh/status/2026979022962401441
3. Polar — Products(デフォルト通貨必須・複数通貨・税込/税抜の既定): https://polar.sh/docs/features/products
4. Polar — Acceptable Use Policy: https://polar.sh/legal/acceptable-use-policy
5. Polar — Checkout Links(`checkout_id={CHECKOUT_ID}`): https://polar.sh/docs/features/checkout/links
6. Polar — Webhook endpoints(Raw形式、2026-09-08以降のsecretはStandard Webhooks): https://polar.sh/docs/integrate/webhooks/endpoints
7. Polar — License Keys(プレフィックス+自動生成UUID、検証API): https://polar.sh/docs/features/benefits/license-keys
8. Polar — Fees: https://polar.sh/docs/merchant-of-record/fees
9. Polar — Introducing Polar Plans(2026-05-20発表、05-27以降の新組織に新料金): https://polar.sh/blog/introducing-polar-plans
10. Lemon Squeezy — 2026 Update: https://www.lemonsqueezy.com/blog/2026-update
11. Stripe — Managed Payments 利用資格(JP掲載): https://docs.stripe.com/payments/managed-payments/eligibility
12. Stripe — Managed Payments 税務対応範囲(日本・メキシコ・シンガポール拠点は国内分を自己負担): https://docs.stripe.com/payments/managed-payments/tax-coverage
13. Gumroad Fees 2026(第三者記事): https://roo.beehiiv.com/p/gumroad-fees-2026
14. Stripe 料金: https://stripe.com/pricing
15. 消費者庁 通信販売広告Q&A(個人事業者の氏名、住所・電話、プラットフォーム/バーチャルオフィス): https://www.no-trouble.caa.go.jp/qa/advertising.html
16. Apple — Apple Developer Program 登録: https://developer.apple.com/jp/programs/enroll/
17. Apple Developer Program 費用(日本円、第三者記事): https://www.tekural.com/blog/apple-developer-program-cost
18. Apple — 購入と有効化: https://developer.apple.com/jp/support/purchase-activation/
19. Polar — Account reviews: https://polar.sh/docs/merchant-of-record/account-reviews
20. Cloudflare Workers 料金: https://developers.cloudflare.com/workers/platform/pricing/
21. Resend — Account quotas and limits: https://resend.com/docs/knowledge-base/account-quotas-and-limits
22. 国税庁 No.2090 新たに事業を始めたときの届出など: https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/2090.htm
23. 国税庁 No.6210 国外取引: https://www.nta.go.jp/taxes/shiraberu/taxanswer/shohi/6210.htm
24. 弥生 — 海外取引の消費税(国外取引は不課税・インボイス不要): https://www.yayoi-kk.co.jp/seikyusho/oyakudachi/kaigaitorihiki-shohizei/
25. Polar — Merchant of Record 概要(US Sales Tax, EU VAT, Canadian GST etc. と記載、日本の記載なし): https://polar.sh/docs/merchant-of-record/introduction
26. 消費者庁 通信販売(広告表示事項・省略の条件・省略不可事項): https://www.no-trouble.caa.go.jp/what/mailorder/
27. 消費者庁 通信販売広告について: https://www.no-trouble.caa.go.jp/what/mailorder/advertising.html
28. 消費者庁 通信販売ガイドライン: https://www.no-trouble.caa.go.jp/what/mailorder/guidelines.html
