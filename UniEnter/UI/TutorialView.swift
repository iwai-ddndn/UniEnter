import SwiftUI

/// 初回起動時に一度だけ表示する使い方チュートリアル。
///
/// 読むだけの説明ステップは置かず、「操作の説明」と「アプリ側の送信キー確認」の
/// 2ステップだけに絞る(対象アプリは既定ですべてONなので選ばせない)。
struct TutorialView: View {
    @ObservedObject var model: SettingsViewModel
    var finish: () -> Void

    @State private var step: Int
    private let totalSteps = 2

    init(model: SettingsViewModel, finish: @escaping () -> Void, step: Int = 0) {
        self.model = model
        self.finish = finish
        _step = State(initialValue: step)
    }

    var body: some View {
        VStack(spacing: 20) {
            // 送信キー確認ステップだけリストがあるので上詰め、他は中央寄せ
            if step != 1 { Spacer(minLength: 0) }
            Group {
                switch step {
                case 0: stepKeys
                default: stepSendKey
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

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
        .frame(width: 460, height: 400)
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
            Text("SlackやLINE、ChatGPTなどの対象アプリすべてで、\nこの操作に統一されます。うっかり送信は、もう起きません。")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // 実際に最初につまずくのがここ。アプリ側で送信キーを⌘Enterに変えていると
    // UniEnterと二重にかかって送信できなくなるため、使い始める前に確認してもらう
    private var stepSendKey: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("すでに⌘Enterで送信に設定しているアプリを\n選んでください")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text("アプリ自身の設定で送信キーを「⌘Enter」に変えている場合は、チェックを入れてください。そのアプリにはUniEnterは何もしません(二重にかかるのを防ぎます)。LINEとSlackは設定を自動で読み取ります。")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SendKeyAppListView(model: model)

            Spacer(minLength: 0)

            Text("対象アプリはすべてONで始まります。メニューバーの ⏎ からいつでも変更できます。\n14日間はすべての機能を無料で使えます。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}
