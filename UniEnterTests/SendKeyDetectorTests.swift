import XCTest
@testable import UniEnter

final class SendKeyDetectorTests: XCTestCase {

    // MARK: - LINE (LINE.ini)

    func testLineCmdEnterSend() {
        let ini = """
        [global]
        language=ja-JP
        [oHCeppe24V]
        p6rgyFbL\\ZWRYSdnPsBRjRgk4aVzOCdaoa9YT%2B1ObRzETMWyhHqla%3A2\\chat_sendkey=1
        p6rgyFbL\\ZWRYSdnPsBRjRgk4aVzOCdaoa9YT%2B1ObRzETMWyhHqla%3A2\\alarm_popup=false
        """
        XCTAssertEqual(LineSendKeyParser.parse(iniContent: ini), .cmdEnterSend)
    }

    func testLineStandardSend() {
        let ini = "prefix%3A2\\chat_sendkey=0\n"
        XCTAssertEqual(LineSendKeyParser.parse(iniContent: ini), .standard)
    }

    func testLineKeyAbsentIsUnknown() {
        // デフォルトのまま(未変更)だとキー自体が書かれない。Enter送信とは断定しない
        let ini = "[global]\nlanguage=ja-JP\napp_theme=2\n"
        XCTAssertEqual(LineSendKeyParser.parse(iniContent: ini), .unknown)
    }

    func testLineMultipleAccountsPrefersCmdEnter() {
        // 複数アカウントのキーが混在したら安全側(素通し)に倒す
        let ini = "a%3A2\\chat_sendkey=0\nb%3A2\\chat_sendkey=1\n"
        XCTAssertEqual(LineSendKeyParser.parse(iniContent: ini), .cmdEnterSend)
    }

    func testLineUnexpectedValueIsUnknown() {
        // 将来値が暗号化された場合など。誤検出しない
        let ini = "a%3A2\\chat_sendkey=@ByteArray(xyz)\n"
        XCTAssertEqual(LineSendKeyParser.parse(iniContent: ini), .unknown)
    }

    // MARK: - Snappy

    /// リテラルのみのraw Snappyエンコード(テスト用)
    private func snappyLiteral(_ payload: [UInt8]) -> Data {
        var out = [UInt8]()
        // 展開後サイズのvarint
        var n = payload.count
        while n >= 0x80 {
            out.append(UInt8(n & 0x7F) | 0x80)
            n >>= 7
        }
        out.append(UInt8(n))
        // 60バイト以下のチャンクに割ってリテラルタグを吐く
        var rest = payload[...]
        while !rest.isEmpty {
            let chunk = rest.prefix(60)
            out.append(UInt8((chunk.count - 1) << 2))
            out.append(contentsOf: chunk)
            rest = rest.dropFirst(chunk.count)
        }
        return Data(out)
    }

    func testSnappyLiteralRoundTrip() {
        let payload = [UInt8]("hello snappy world — 日本語もOK".utf8)
        XCTAssertEqual(Snappy.decompress(snappyLiteral(payload)), Data(payload))
    }

    func testSnappyLongLiteral() {
        // 61バイト以上のリテラル(長さが後続バイトに入る形式)
        let payload = [UInt8](repeating: 0x41, count: 300)
        var data = [UInt8]()
        data.append(0xAC); data.append(0x02) // varint 300
        data.append(60 << 2) // リテラル、長さ-1は後続1バイト
        data.append(255)     // 256バイト
        data.append(contentsOf: payload.prefix(256))
        // 残り44バイトは通常リテラル
        data.append(UInt8((44 - 1) << 2))
        data.append(contentsOf: payload.prefix(44))
        XCTAssertEqual(Snappy.decompress(Data(data)), Data(payload))
    }

    func testSnappyCopyOperation() {
        // "abcabcabc": リテラル"abc" + 1バイトオフセットコピー(offset=3, len=6)
        var data = [UInt8]()
        data.append(9) // varint 9
        data.append(UInt8((3 - 1) << 2))
        data.append(contentsOf: Array("abc".utf8))
        data.append(UInt8((6 - 4) << 2 | 1)) // copy1: len=6, offsetの上位3bit=0
        data.append(3)
        XCTAssertEqual(Snappy.decompress(Data(data)), Data("abcabcabc".utf8))
    }

    func testSnappyMalformedReturnsNil() {
        XCTAssertNil(Snappy.decompress(Data()))
        // 宣言サイズと実際の展開結果が食い違う
        var data = [UInt8]()
        data.append(10)
        data.append(UInt8((3 - 1) << 2))
        data.append(contentsOf: Array("abc".utf8))
        XCTAssertNil(Snappy.decompress(Data(data)))
        // 出力より大きいオフセットのコピー
        XCTAssertNil(Snappy.decompress(Data([4, 0b0000_0101, 9])))
    }

    // MARK: - Slack (IndexedDB blob)

    /// V8構造化クローン風に `0x22 <長さ> <キー> <値タグ>` を並べたペイロードを作る
    private func v8Entry(_ key: String, _ value: Character) -> [UInt8] {
        var bytes: [UInt8] = [0x22, UInt8(key.utf8.count)]
        bytes += Array(key.utf8)
        bytes += Array(String(value).utf8)
        return bytes
    }

    func testSlackCmdEnterSendDetected() {
        let payload = v8Entry("some_other_pref", "F") + v8Entry("msg_input_send_btn", "T")
        XCTAssertEqual(SlackSendKeyParser.parse(payload: Data(payload)), .cmdEnterSend)
    }

    func testSlackStandardSend() {
        let payload = v8Entry("msg_input_send_btn", "F")
        XCTAssertEqual(SlackSendKeyParser.parse(payload: Data(payload)), .standard)
    }

    func testSlackAutoSetKeyIsNotConfused() {
        // 長さバイトが違うため、別キー msg_input_send_btn_auto_set には反応しない
        let payload = v8Entry("msg_input_send_btn_auto_set", "T")
        XCTAssertEqual(SlackSendKeyParser.parse(payload: Data(payload)), .unknown)
    }

    func testSlackKeyAbsentIsUnknown() {
        let payload = v8Entry("enter_is_special_in_tbt", "F")
        XCTAssertEqual(SlackSendKeyParser.parse(payload: Data(payload)), .unknown)
    }

    func testSlackFullBlobWithHeaderAndCompression() {
        // 実ファイルと同じ構造: FF 11 02 + raw Snappy圧縮ペイロード
        let payload = v8Entry("msg_input_send_btn", "T") + v8Entry("msg_input_send_btn_auto_set", "F")
        let blob = Data([0xFF, 0x11, 0x02]) + snappyLiteral(payload)
        XCTAssertEqual(SlackSendKeyParser.parse(blob: blob), .cmdEnterSend)
    }

    func testSlackWrongHeaderIsUnknown() {
        let blob = Data([0x00, 0x11, 0x02]) + snappyLiteral(v8Entry("msg_input_send_btn", "T"))
        XCTAssertEqual(SlackSendKeyParser.parse(blob: blob), .unknown)
    }

    func testSlackCorruptCompressionIsUnknown() {
        let blob = Data([0xFF, 0x11, 0x02, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00])
        XCTAssertEqual(SlackSendKeyParser.parse(blob: blob), .unknown)
    }
}
