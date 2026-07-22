import SwiftUI

/// 初回起動時に一度だけ表示する使い方チュートリアル。
struct TutorialView: View {
    var openSettings: () -> Void
    var finish: () -> Void

    @State private var step = 0
    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 20) {
            Group {
                switch step {
                case 0: stepKeys
                case 1: stepApps
                default: stepSafety
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }

            HStack {
                if step > 0 {
                    Button("戻る") { step -= 1 }
                }
                Spacer()
                if step < totalSteps - 1 {
                    Button("次へ") { step += 1 }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("さっそく使う") { finish() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 420, height: 320)
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
                    .foregroundColor(.green)
            }
            HStack(spacing: 10) {
                key("⌘")
                key("Enter")
                Text("→ 送信")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            Text("対象のアプリすべてで、この操作に統一されます。\nうっかり送信は、もう起きません。")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var stepApps: some View {
        VStack(spacing: 14) {
            Text("対象アプリは、設定で選べます")
                .font(.title3.bold())
            Text("""
            SlackやLINE、ChatGPTなどのデスクトップアプリと、
            そのブラウザ版(Safari / Chrome / Arcなど)に対応しています。
            アプリ版・ブラウザ版を別々にオン/オフできます。
            """)
            .font(.callout)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            Button("設定を開いて確認する") { openSettings() }
        }
    }

    private var stepSafety: some View {
        VStack(spacing: 14) {
            Text("日本語入力も、安心")
                .font(.title3.bold())
            Text("""
            変換確定のEnterには触れないフェイルセーフ設計です。
            対象外のアプリには一切干渉しません。

            14日間はすべての機能を無料で使えます。
            メニューバーの ⏎ からいつでも設定・確認できます。
            """)
            .font(.callout)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
    }
}
