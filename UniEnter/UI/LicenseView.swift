import SwiftUI

/// 購入ページのURL(LPの価格欄)。購入はLP経由でPolarのチェックアウトに進む。
let purchaseURL = URL(string: "https://unienter.oc-to.com/#pricing")!
/// 購入の受付を始めたら true にする。false の間は「購入」ボタンを出さず、準備中であることを伝える
/// (押した先のLPが「購入は準備中」だと行き止まりになるため)
let purchaseOpen = false

final class LicenseViewModel: ObservableObject {
    @Published var state: LicenseState
    @Published var keyInput = ""
    @Published var message: String?
    @Published var messageIsError = false

    private let manager: LicenseManager
    /// 認証成功時にAppDelegateへ伝える
    var onActivated: (() -> Void)?

    init(manager: LicenseManager) {
        self.manager = manager
        self.state = manager.state
    }

    func activate() {
        do {
            let email = try manager.activate(key: keyInput)
            state = manager.state
            message = "認証しました(\(email))。ありがとうございます!"
            messageIsError = false
            keyInput = ""
            onActivated?()
        } catch {
            message = error.localizedDescription
            messageIsError = true
        }
    }
}

struct LicenseView: View {
    @ObservedObject var model: LicenseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 色はアイコンにだけ付ける(システムの緑・オレンジの文字は白地で読みにくい)
            switch model.state {
            case .licensed(let email):
                Label {
                    Text("ライセンス認証済み")
                } icon: {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.accentColor)
                }
                .font(.headline)
                Text("ありがとうございます。このMacでずっと使えます。")
                    .font(.callout)
                Text(email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .trial(let daysLeft):
                Label("無料トライアル中 — あと \(daysLeft) 日", systemImage: "clock")
                    .font(.headline)
                Text("トライアルが終わるとEnterキーの切り替えが止まり、各アプリ本来の動きに戻ります。続けて使うにはライセンスを購入してください。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .expired:
                Label {
                    Text("無料トライアルが終了しました")
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
                }
                .font(.headline)
                Text("いまEnterキーの切り替えは止まっていて、各アプリ本来の動きに戻っています。ライセンスを購入すると再開します。使わない場合は、アプリを削除してかまいません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if case .licensed = model.state {} else {
                Text("¥1,480(税込・買い切り)")
                    .font(.subheadline.bold())

                if purchaseOpen {
                    Button("ライセンスを購入") {
                        NSWorkspace.shared.open(purchaseURL)
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("購入について(Webサイト)") {
                        NSWorkspace.shared.open(purchaseURL)
                    }
                    Text("購入の受付は準備中です。始まったら、この画面から購入できるようになります。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                Text("購入済みの方: メールで届いたライセンスキーを貼り付けてください")
                    .font(.caption)
                HStack {
                    TextField("UNIENTER-…", text: $model.keyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                    Button("認証") { model.activate() }
                        .disabled(model.keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if let message = model.message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(model.messageIsError ? .red : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            CreditLine()
        }
        .padding(20)
        .frame(width: 380)
    }
}

/// クレジット表記。全画面で同じ形式にそろえる(CLAUDE.md「連絡先・クレジット表記の統一」)
struct CreditLine: View {
    var body: some View {
        Text("制作: [octo(oc-to.com)](https://oc-to.com) / お問い合わせ: [info@oc-to.com](mailto:info@oc-to.com)")
            .font(.caption)
            .foregroundColor(.secondary)
            .tint(.accentColor)
    }
}
