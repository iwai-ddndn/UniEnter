# Paddle導入手順(ご本人作業)

UniEnterの課金はオフライン検証ライセンス+Paddle決済で動く。アプリ側とキー発行の仕組みは実装済み。
残るのはPaddle側の設定のみ。

## いま動いている仕組み

- アプリは初回起動から**14日間**全機能で動作し、以降はライセンスキー入力まで書き換えを停止する
- ライセンスキーはEd25519署名付きのオフライン検証(認証サーバ不要)
- 発行: `swift license-signing/issue.swift 購入者メール` → 出力されたキーを購入者へメールするだけ
  - 秘密鍵は `license-signing/keys.txt`(**git管理外・要バックアップ**。漏れたら全キー再発行になるので厳重に)

## Paddle側でやること

1. https://www.paddle.com/ でアカウント作成(個人事業主でOK。サイトURL・事業情報の審査が数日かかることがある)
   - 審査にはLPの公開が必要になる場合が多い(「公開して」のタイミングと合わせるのが吉)
2. Catalog → Product作成: 「UniEnter」/ one-time(単発)price を作成: **¥1,480**(価格はLP `site/src/App.tsx` の表記と揃えること)
   - 税設定: 「Standard digital goods」/ 価格は税込(inclusive)推奨
3. Checkout → 「Buy now」リンク(hosted checkout)を作成
4. できたチェックアウトURLを教えてもらえれば、以下を差し替える:
   - LP価格セクションの「ライセンスを購入(準備中)」ボタン
   - アプリ内 `UniEnter/UI/LicenseView.swift` の `purchaseURL`

## 購入→キー発行の運用

- **当面(手動)**: Paddleの購入通知メールを受けたら `issue.swift` でキーを発行し、購入者へ返信(1件30秒)
- **自動化(次フェーズ)**: Paddle Webhook(transaction.completed)→ Cloudflare Worker等でissue.swift相当の署名を実行し、
  Paddleの「custom fulfillment」でキーを購入完了画面・メールに自動表示する。希望があれば実装する

## 補足

- Paddleは Merchant of Record(販売者はPaddle)なので、消費税・インボイス・特商法表記の負担が大幅に軽くなる
- 返金対応もPaddle経由。ポリシーは Paddle Dashboard → Checkout settings で設定できる
