import SwiftUI

/// 購入ページのURL。Paddleで商品を作成したらチェックアウトリンクに差し替える。
let purchaseURL = URL(string: "https://unienter.oc-to.com/#pricing")!

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
            switch model.state {
            case .licensed(let email):
                Label("ライセンス認証済み", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundColor(.green)
                Text(email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .trial(let daysLeft):
                Label("無料トライアル中 — 残り \(daysLeft) 日", systemImage: "clock")
                    .font(.headline)
                Text("トライアル終了後はキーの書き換えが停止します。ライセンスを購入すると引き続き利用できます(買い切り)。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .expired:
                Label("無料トライアルが終了しました", systemImage: "exclamationmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text("現在、キーの書き換えは停止しています。ライセンスを購入すると再開されます(買い切り)。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if case .licensed = model.state {} else {
                Button("ライセンスを購入") {
                    NSWorkspace.shared.open(purchaseURL)
                }
                .keyboardShortcut(.defaultAction)

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
                    .foregroundColor(model.messageIsError ? .red : .green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
