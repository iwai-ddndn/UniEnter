import SwiftUI

/// アクセシビリティ許可の誘導画面。許可はシステム設定でユーザー自身が行う。
struct OnboardingView: View {
    var openSystemSettings: () -> Void

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
        }
        .padding(24)
        .frame(width: 380)
    }
}
