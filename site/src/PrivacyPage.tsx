import LegalLayout, { LegalSection } from "./LegalLayout"

export default function PrivacyPage() {
  return (
    <LegalLayout
      title="プライバシーポリシー"
      established="制定日: 2026年7月22日 / 最終改定日: 2026年7月24日"
    >
      <p className="mt-6 text-sm leading-relaxed text-muted-foreground">
        octo(https://oc-to.com、以下「提供者」)は、macOS用ソフトウェア「UniEnter」(以下「本アプリ」)
        および本ウェブサイトにおける利用者の情報の取り扱いについて、次のとおり定めます。
      </p>

      <LegalSection title="1. 基本方針">
        <p>
          本アプリは、利用者の入力内容や個人情報を収集しません。
          キーボードの入力イベントは、Enterキーの挙動を統一する判定のためにMac内でのみ処理され、
          記録・保存・外部送信は一切行いません。
        </p>
      </LegalSection>

      <LegalSection title="2. アプリが扱う情報">
        <ul className="list-inside list-disc space-y-1">
          <li>判定に使用するのは、Enter関連のキーイベント、前面のアプリ・タブ、日本語入力の状態のみです</li>
          <li>アクセシビリティ権限は、前面のアプリ・ブラウザタブの判定のためだけに使用します</li>
          <li>本アプリは現在、外部との通信を行いません(利用状況の解析・広告も一切ありません)</li>
          <li>設定・ライセンスキー・トライアル開始日は、利用者のMac内にのみ保存されます</li>
        </ul>
        <p>
          将来、アップデート確認などの通信機能を追加する場合は、本ポリシーを改定のうえ告知します。
        </p>
      </LegalSection>

      <LegalSection title="3. ライセンス購入時に取得する情報">
        <p>
          決済は Paddle.com Market Ltd.(以下「Paddle」)が販売者(Merchant of Record)として処理します。
          クレジットカード情報等の決済情報はPaddleが取り扱い、提供者には渡りません。
          Paddleにおける情報の取り扱いは、
          <a className="underline" href="https://www.paddle.com/legal/privacy" target="_blank" rel="noopener noreferrer">
            Paddleのプライバシーポリシー
          </a>
          をご確認ください。
        </p>
        <p>
          提供者は、ライセンスキーの発行および購入者サポートのために、購入者のメールアドレスと購入記録を受け取り、
          これらの目的の範囲でのみ利用・保管します。法令に基づく場合を除き、第三者に提供しません。
        </p>
      </LegalSection>

      <LegalSection title="4. ウェブサイト">
        <p>
          本ウェブサイトでは、サイトの利用状況を把握し改善に役立てるため、Google LLC が提供するアクセス解析ツール
          「Google アナリティクス」を使用しています。Google アナリティクスはCookie等を利用して、
          個人を特定しない形でアクセス情報(閲覧ページ、参照元、おおよその地域、ブラウザ・端末の種類等)を収集し、
          Googleへ送信します。この機能はブラウザの設定でCookieを無効にするか、
          <a
            className="underline"
            href="https://tools.google.com/dlpage/gaoptout?hl=ja"
            target="_blank"
            rel="noopener noreferrer"
          >
            Google アナリティクス オプトアウト アドオン
          </a>
          により収集を拒否できます。収集される情報とその取り扱いについては、
          <a
            className="underline"
            href="https://policies.google.com/technologies/partner-sites?hl=ja"
            target="_blank"
            rel="noopener noreferrer"
          >
            Googleのポリシーと規約
          </a>
          をご確認ください。
        </p>
        <p>
          また、本ウェブサイトは GitHub Pages でホストされており、
          ホスティング事業者であるGitHubがアクセスログ等を取り扱う場合があります。詳細は
          <a
            className="underline"
            href="https://docs.github.com/ja/site-policy/privacy-policies/github-general-privacy-statement"
            target="_blank"
            rel="noopener noreferrer"
          >
            GitHubのプライバシーステートメント
          </a>
          をご確認ください。
        </p>
      </LegalSection>

      <LegalSection title="5. お問い合わせ">
        <p>
          本ポリシーに関するお問い合わせは、info@oc-to.com までお願いします。
        </p>
      </LegalSection>

      <LegalSection title="6. 改定">
        <p>
          本ポリシーは、必要に応じて改定することがあります。重要な変更がある場合は、本ウェブサイトで告知します。
        </p>
      </LegalSection>
    </LegalLayout>
  )
}
