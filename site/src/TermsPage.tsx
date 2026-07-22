import LegalLayout, { LegalSection } from "./LegalLayout"

export default function TermsPage() {
  return (
    <LegalLayout title="利用規約" established="制定日: 2026年7月22日">
      <p className="mt-6 text-sm leading-relaxed text-muted-foreground">
        本規約は、octo(https://oc-to.com、以下「提供者」)が提供するmacOS用ソフトウェア
        「UniEnter」(以下「本アプリ」)の利用条件を定めるものです。
        本アプリをダウンロード、インストールまたは利用した時点で、本規約に同意したものとみなします。
      </p>

      <LegalSection title="第1条(ライセンス)">
        <p>
          本アプリは、初回起動から14日間、すべての機能を無料で試用できます。
          試用期間の終了後に継続して利用するには、ライセンスの購入が必要です。
        </p>
        <p>
          ライセンスは買い切り型で、購入者本人が使用するMacであれば複数台で利用できます。
          ライセンスキーを第三者に譲渡・貸与・共有・公開すること、および再販売することはできません。
        </p>
      </LegalSection>

      <LegalSection title="第2条(購入・支払い・返金)">
        <p>
          ライセンスの販売は、決済代行事業者 Paddle.com Market Ltd.(以下「Paddle」)が
          販売者(Merchant of Record)として行います。支払い・領収書・返金は、
          Paddleの規約およびポリシーに従って処理されます。
        </p>
        <p>返金をご希望の場合は、購入時のメールに記載のPaddleの窓口、または提供者(info@oc-to.com)までご連絡ください。</p>
      </LegalSection>

      <LegalSection title="第3条(禁止事項)">
        <p>利用者は、次の行為をしてはなりません。</p>
        <ul className="list-inside list-disc space-y-1">
          <li>ライセンスキーの共有・公開・転売、その他不正な利用</li>
          <li>ライセンス認証の回避・改ざんを目的とする行為</li>
          <li>法令または公序良俗に違反する目的での利用</li>
        </ul>
      </LegalSection>

      <LegalSection title="第4条(知的財産)">
        <p>
          本アプリおよび関連するソースコード・ウェブサイト等の著作権その他の知的財産権は、提供者に帰属します。
          ソースコードは透明性のためにGitHub上で公開していますが、別途明示のない限り、
          再配布、改変版の配布、商用利用を許諾するものではありません。
        </p>
        <p>記載されている各サービス名・製品名は、各社の商標または登録商標です。本アプリは各社と提携・承認関係にありません。</p>
      </LegalSection>

      <LegalSection title="第5条(免責)">
        <p>
          本アプリは現状有姿で提供されます。提供者は、すべての環境・アプリケーションでの動作、
          および意図しない送信(誤送信)が完全に防止されることを保証しません。
          対象アプリケーション側の仕様変更等により、機能の一部が動作しなくなる場合があります。
        </p>
        <p>
          本アプリの利用に関連して利用者に損害が生じた場合、提供者の故意または重過失による場合を除き、
          提供者の賠償責任はライセンス購入代金を上限とします。
        </p>
      </LegalSection>

      <LegalSection title="第6条(規約の変更)">
        <p>
          提供者は、必要に応じて本規約を変更することがあります。
          変更後の規約は、本ウェブサイトに掲示した時点から効力を生じます。
        </p>
      </LegalSection>

      <LegalSection title="第7条(準拠法・裁判管轄)">
        <p>
          本規約は日本法に準拠します。本アプリに関連して紛争が生じた場合、
          提供者の所在地を管轄する裁判所を第一審の専属的合意管轄裁判所とします。
        </p>
      </LegalSection>
    </LegalLayout>
  )
}
