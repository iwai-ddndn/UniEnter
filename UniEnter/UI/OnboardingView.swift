import SwiftUI

/// アクセシビリティ許可の誘導画面。許可はシステム設定でユーザー自身が行う。
struct OnboardingView: View {
    var openSystemSettings: () -> Void
    /// 許可プロンプトを再表示する(リストから削除して登録し直すケース用)
    var requestPrompt: () -> Void

    @State private var showTroubleshooting = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "return")
                .font(.system(size: 40))
            Text("UniEnterへようこそ")
                .font(.title2.bold())
            Text("""
            チャットアプリのEnterキー挙動を「Enter=改行、⌘Enter=送信」に統一します。
            キー入力を書き換えるため、アクセシビリティの許可が必要です。

            1. 下のボタンでシステム設定を開く
            2. リストの UniEnter をオンにする

            許可されると自動でこの画面は閉じ、動作を開始します。
            """)
            .font(.callout)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            Button("システム設定を開く") {
                openSystemSettings()
            }
            .keyboardShortcut(.defaultAction)

            Label("許可を待っています…", systemImage: "hourglass")
                .font(.caption)
                .foregroundColor(.secondary)

            if showTroubleshooting {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("オンにしても進まない場合")
                        .font(.subheadline.bold())
                    Text("""
                    リストにある UniEnter が古いビルドを指している可能性があります(再ビルド後に起こります)。
                    1. システム設定のアクセシビリティで UniEnter を選び「−」で削除
                    2. 下の「許可をやり直す」を押して登録し直し、あらためてオンにする
                    """)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    Button("許可をやり直す") {
                        requestPrompt()
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 400)
        .task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            showTroubleshooting = true
        }
    }
}
