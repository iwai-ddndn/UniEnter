import Foundation

/// アプリ側の送信キー設定の検出結果
enum SendKeyDetection {
    /// アプリ自身の設定で「⌘Enter=送信」になっている(UniEnterは素通しすべき)
    case cmdEnterSend
    /// 「Enter=送信」になっている(書き換えてよい)
    case standard
    /// 設定ファイルが読めない・キーが無い等で判定不能。手動宣言(cmdEnterSendApps)にフォールバック
    case unknown
}

/// LINEの設定ファイル(LINE.ini、Qt QSettings形式)から送信方法を判定する純粋ロジック。
///
/// キーはアカウントmid由来のプレフィックス付き(例: `p6…%3A2\chat_sendkey=1`)なので
/// 「`\chat_sendkey=` を含む行」で探す。1=⌘Enter送信、0=Enter送信。
/// デフォルトのまま一度も変更していないとキー自体が書かれないため、キー不在は
/// 「Enter送信」ではなく unknown として扱う(不在を判定に使わない)。
enum LineSendKeyParser {
    static func parse(iniContent: String) -> SendKeyDetection {
        var sawStandard = false
        for line in iniContent.split(separator: "\n") {
            guard let range = line.range(of: "\\chat_sendkey=") else { continue }
            let value = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            // 複数アカウントのキーが残っている場合、どれかが⌘Enter送信なら安全側(素通し)に倒す
            if value == "1" { return .cmdEnterSend }
            if value == "0" { sawStandard = true }
        }
        return sawStandard ? .standard : .unknown
    }
}

/// raw Snappy(フレームなし)の伸長。ChromiumがIndexedDBの大きな値をblobファイルへ
/// 外部化するときの圧縮形式で、Slackの設定読み取りに使う。失敗時はnil。
enum Snappy {
    static func decompress(_ data: Data) -> Data? {
        let bytes = [UInt8](data)
        var i = 0

        // 先頭は展開後サイズのvarint
        var length = 0
        var shift = 0
        while true {
            guard i < bytes.count, shift < 35 else { return nil }
            let b = bytes[i]
            i += 1
            length |= Int(b & 0x7F) << shift
            if b & 0x80 == 0 { break }
            shift += 7
        }
        // 壊れたデータでの暴走防止(実測のbootDataは1.5MB程度)
        guard length <= 32 * 1024 * 1024 else { return nil }

        var out = [UInt8]()
        out.reserveCapacity(length)
        while i < bytes.count {
            guard out.count <= length else { return nil }
            let tag = bytes[i]
            i += 1
            let kind = tag & 3
            if kind == 0 {
                // リテラル。長さ61以上は後続1〜4バイトに(長さ-1)がリトルエンディアンで入る
                var len = Int(tag >> 2) + 1
                if len > 60 {
                    let extra = len - 60
                    guard i + extra <= bytes.count else { return nil }
                    len = 0
                    for k in 0..<extra { len |= Int(bytes[i + k]) << (8 * k) }
                    len += 1
                    i += extra
                }
                guard i + len <= bytes.count else { return nil }
                out.append(contentsOf: bytes[i..<(i + len)])
                i += len
            } else {
                // 既出力からのコピー(自己参照コピーで反復展開されるためバイト単位で写す)
                let len: Int
                let offset: Int
                switch kind {
                case 1:
                    guard i < bytes.count else { return nil }
                    len = Int((tag >> 2) & 7) + 4
                    offset = Int(tag >> 5) << 8 | Int(bytes[i])
                    i += 1
                case 2:
                    guard i + 2 <= bytes.count else { return nil }
                    len = Int(tag >> 2) + 1
                    offset = Int(bytes[i]) | Int(bytes[i + 1]) << 8
                    i += 2
                default:
                    guard i + 4 <= bytes.count else { return nil }
                    len = Int(tag >> 2) + 1
                    offset = Int(bytes[i]) | Int(bytes[i + 1]) << 8
                        | Int(bytes[i + 2]) << 16 | Int(bytes[i + 3]) << 24
                    i += 4
                }
                guard offset > 0, offset <= out.count else { return nil }
                for _ in 0..<len { out.append(out[out.count - offset]) }
            }
        }
        guard out.count == length else { return nil }
        return Data(out)
    }
}

/// SlackのIndexedDB blob(reduxPersistenceのbootData)から
/// 「メッセージ入力時のEnterキーの動作」設定を判定する純粋ロジック。
///
/// blobは先頭3バイト `FF 11 02`(Blink IDB value wrapper)+ raw Snappy圧縮。
/// 展開するとV8構造化クローンで、one-byte文字列は `0x22 <長さ> <ASCII>`、直後の
/// 1バイトが値タグ(T=true / F=false)。長さバイト0x12(=18)まで一致させることで
/// 別キー `msg_input_send_btn_auto_set` を除外する。
/// true = 「Enterで改行・⌘Enterで送信」= UniEnterは素通しすべき状態。
enum SlackSendKeyParser {
    private static let blobHeader: [UInt8] = [0xFF, 0x11, 0x02]
    private static let pattern: [UInt8] = [0x22, 0x12] + Array("msg_input_send_btn".utf8)

    static func parse(blob: Data) -> SendKeyDetection {
        guard blob.count > blobHeader.count,
              [UInt8](blob.prefix(blobHeader.count)) == blobHeader,
              let payload = Snappy.decompress(blob.dropFirst(blobHeader.count))
        else { return .unknown }
        return parse(payload: payload)
    }

    static func parse(payload: Data) -> SendKeyDetection {
        let bytes = [UInt8](payload)
        guard bytes.count > pattern.count else { return .unknown }
        var sawStandard = false
        var i = 0
        while i + pattern.count < bytes.count {
            guard bytes[i] == pattern[0], Array(bytes[i..<(i + pattern.count)]) == pattern else {
                i += 1
                continue
            }
            switch bytes[i + pattern.count] {
            case UInt8(ascii: "T"): return .cmdEnterSend
            case UInt8(ascii: "F"): sawStandard = true
            default: break
            }
            i += pattern.count
        }
        return sawStandard ? .standard : .unknown
    }
}

/// LINE / Slack の設定ファイルを読んで、アプリ側の送信キー設定を推定する(ベストエフォート)。
///
/// どちらも非公開の内部実装への依存なので、読めない・形式が変わった場合はすべて
/// unknown に倒し、既存の手動宣言(SettingsStore.cmdEnterSendApps)にフォールバックする。
/// macOS 14以降は他アプリのコンテナへの初回アクセスで許可ダイアログが出ることがあり、
/// 拒否されると読み取りが失敗する(= unknown になるだけで誤動作はしない)。
/// ファイルI/Oを伴うためCGEventTapコールバックからは呼ばないこと。
final class SendKeyDetector {
    static let lineBundleID = "jp.naver.line.mac"
    static let slackBundleID = "com.tinyspeck.slackmacgap"
    static let supportedBundleIDs: Set<String> = [lineBundleID, slackBundleID]

    private let home = FileManager.default.homeDirectoryForCurrentUser

    func detect(bundleID: String) -> SendKeyDetection {
        switch bundleID {
        case Self.lineBundleID: return detectLine()
        case Self.slackBundleID: return detectSlack()
        default: return .unknown
        }
    }

    private func detectLine() -> SendKeyDetection {
        // App Store版コンテナの中に旧bundle ID名のディレクトリが入れ子になった特殊構造
        let ini = home.appendingPathComponent(
            "Library/Containers/jp.naver.line.mac/Data/Library/Containers/jp.naver.line/Data/LINE.ini")
        guard let data = try? Data(contentsOf: ini),
              let content = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        else { return .unknown }
        return LineSendKeyParser.parse(iniContent: content)
    }

    private func detectSlack() -> SendKeyDetection {
        let candidates = [
            // App Store版 / 直接配布版
            "Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack",
            "Library/Application Support/Slack",
        ]
        var sawStandard = false
        for base in candidates {
            let blobDir = home.appendingPathComponent(base)
                .appendingPathComponent("IndexedDB/https_app.slack.com_0.indexeddb.blob")
            guard let enumerator = FileManager.default.enumerator(
                at: blobDir,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            // blobはワークスペースごと。設定はワークスペース単位なので、どれかが
            // ⌘Enter送信なら安全側(素通し)に倒す。件数・サイズは暴走防止で上限を切る
            var parsed = 0
            for case let url as URL in enumerator {
                guard parsed < 64 else { break }
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true,
                      let size = values.fileSize, size > 3, size <= 8 * 1024 * 1024,
                      let blob = try? Data(contentsOf: url)
                else { continue }
                parsed += 1
                switch SlackSendKeyParser.parse(blob: blob) {
                case .cmdEnterSend: return .cmdEnterSend
                case .standard: sawStandard = true
                case .unknown: break
                }
            }
        }
        return sawStandard ? .standard : .unknown
    }
}
