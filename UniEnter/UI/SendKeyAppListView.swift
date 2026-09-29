import SwiftUI

/// アプリ側でEnterを「改行」に設定済みのアプリを宣言・確認する共通リスト。
/// チュートリアルと設定画面の両方から使う。
///
/// 既定は自動検出できるLINEとSlackの2行(+すでに宣言・検出済みのアプリ)。
/// その他のアプリは「その他のアプリを追加」メニューで行を増やす。
/// 「確認しにいく」はそのアプリを起動する(LINE/Slackは自動検出も走る)。
struct SendKeyAppListView: View {
    @ObservedObject var model: SettingsViewModel

    /// 行として表示するアプリ
    @State private var shownApps: [String]

    /// アプリ内の送信キー設定がある場所(分かっているものだけ表示)
    private static let sendKeyHints: [String: String] = [
        SendKeyDetector.lineBundleID: "設定 > トーク > 送信方法 が「⌘+Enter」なら該当",
        SendKeyDetector.slackBundleID: "環境設定 > 詳細設定 > 「メッセージ入力時のEnterキー」が「改行を挿入」なら該当",
    ]

    init(model: SettingsViewModel) {
        self.model = model
        let defaults = [SendKeyDetector.lineBundleID, SendKeyDetector.slackBundleID]
        let declared = model.cmdEnterSendApps.union(model.detectedCmdEnterSendApps)
        let extras = AppRegistry.all
            .filter { $0.hasDesktop && !defaults.contains($0.bundleID) && declared.contains($0.bundleID) }
            .map(\.bundleID)
        _shownApps = State(initialValue: defaults + extras)
    }

    /// まだ行に出していない、追加候補のデスクトップアプリ
    private var addableApps: [TargetApp] {
        AppRegistry.all.filter { $0.hasDesktop && !shownApps.contains($0.bundleID) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 行が少ないうちは詰めて表示し、追加で増えたときだけスクロールに切り替える
            if shownApps.count <= 4 {
                rows
            } else {
                ScrollView {
                    rows
                }
                .frame(height: 150)
            }

            if !addableApps.isEmpty {
                Menu("その他のアプリを追加…") {
                    ForEach(addableApps, id: \.bundleID) { app in
                        Button(app.name) { shownApps.append(app.bundleID) }
                    }
                }
                .controlSize(.small)
                .fixedSize()
            }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(shownApps, id: \.self) { bundleID in
                if let app = AppRegistry.all.first(where: { $0.bundleID == bundleID }) {
                    row(app)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ app: TargetApp) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                // 自動で確かめたアプリは、手で上書きできないよう固定する(0fa2bfaの方針)。
                // ただし無効化したトグルはグレーで読めず「選べない」ように見えるので、
                // 名前は通常の文字色のまま、チェック状態を記号で、分かったことをバッジで示す
                if model.detectedCmdEnterSendApps.contains(app.bundleID) {
                    detectedRow(app, checked: true, badge: "自動で確認: Enterで改行 → UniEnterは何もしません")
                } else if model.detectedStandardApps.contains(app.bundleID) {
                    detectedRow(app, checked: false, badge: "自動で確認: Enterで送信(初期設定)")
                } else {
                    Toggle(app.name, isOn: model.alreadyCmdEnter(app))
                }
                Spacer()
                if model.isAppInstalled?(app.bundleID) ?? true {
                    Button("確認しにいく") { model.openApp?(app.bundleID) }
                        .controlSize(.small)
                } else {
                    Text("未インストール")
                        .font(.caption2)
                        .foregroundColor(Color.secondary.opacity(0.7))
                }
            }
            if let hint = Self.sendKeyHints[app.bundleID], !model.detectedSendKeys.keys.contains(app.bundleID) {
                Text(hint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 22)
            }
        }
    }

    private func detectedRow(_ app: TargetApp, checked: Bool, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundColor(.secondary)
                Text(app.name)
                    .fixedSize()
            }
            Text(badge)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15), in: Capsule())
                .padding(.leading, 20)
        }
        .accessibilityElement(children: .combine)
    }
}
