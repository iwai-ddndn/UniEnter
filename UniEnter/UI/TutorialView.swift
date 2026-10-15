import SwiftUI

/// 権限付与後に表示する基本操作の案内。任意の送信キー設定は設定画面にまとめる。
struct TutorialView: View {
    var finish: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            stepKeys
            Text("困ったときは、メニューバーの ⏎ →「設定…」から\n「⌘Enterを押しても送信できないときは」を開けます。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("さっそく使う", action: finish)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func key(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 18, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.4)))
    }

    private var stepKeys: some View {
        VStack(spacing: 14) {
            Text("覚えるのは、2つだけ")
                .font(.title3.bold())
            HStack(spacing: 10) {
                key("Enter")
                Text("→ 改行")
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            HStack(spacing: 10) {
                key("⌘")
                key("Enter")
                Text("→ 送信")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            Text("SlackやLINE、ChatGPTなどの対象アプリすべてで、\nこの操作に統一されます。Enterでのうっかり送信を防ぎます。")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}
