import CryptoKit
import XCTest
@testable import UniEnter

final class LicenseManagerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var markerURL: URL!
    private var privateKey: Curve25519.Signing.PrivateKey!
    private var publicKeyBase64: String!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "LicenseManagerTests-\(UUID().uuidString)")
        markerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("unienter-tests-\(UUID().uuidString)/.trial")
        privateKey = Curve25519.Signing.PrivateKey()
        publicKeyBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()
    }

    private func manager(now: Date = Date()) -> LicenseManager {
        LicenseManager(defaults: defaults, markerURL: markerURL,
                       publicKeyBase64: publicKeyBase64, now: { now })
    }

    private func makeKey(email: String, privateKey: Curve25519.Signing.PrivateKey? = nil) throws -> String {
        let key = privateKey ?? self.privateKey!
        let payload = try JSONSerialization.data(
            withJSONObject: ["email": email, "iat": 0], options: [.sortedKeys])
        let signature = try key.signature(for: payload)
        return "UNIENTER-\(payload.base64urlEncodedString()).\(signature.base64urlEncodedString())"
    }

    // MARK: - トライアル

    func testFreshInstallStartsTrialWithFullDays() {
        guard case .trial(let daysLeft) = manager().state else {
            return XCTFail("トライアル状態になるべき")
        }
        XCTAssertEqual(daysLeft, LicenseManager.trialDays)
        XCTAssertTrue(manager().isEntitled)
    }

    func testTrialCountsDown() {
        let start = Date()
        _ = manager(now: start).state // 開始日時を記録させる
        // ちょうど5.000日は浮動小数の丸めで4日扱いになり得るため、1時間ずらして判定する
        let later = start.addingTimeInterval(60 * 60 * 24 * 5 + 60 * 60)
        guard case .trial(let daysLeft) = manager(now: later).state else {
            return XCTFail("トライアル継続中のはず")
        }
        XCTAssertEqual(daysLeft, LicenseManager.trialDays - 5)
    }

    func testTrialExpiresAfter14Days() {
        let start = Date()
        _ = manager(now: start).state
        let later = start.addingTimeInterval(60 * 60 * 24 * 15)
        XCTAssertEqual(manager(now: later).state, .expired)
        XCTAssertFalse(manager(now: later).isEntitled)
    }

    func testTrialStartSurvivesDefaultsReset() {
        // UserDefaultsが消えてもマーカーから復元される(単純リセット対策)
        let start = Date()
        _ = manager(now: start).state
        let freshDefaults = UserDefaults(suiteName: "LicenseManagerTests-fresh-\(UUID().uuidString)")!
        let m = LicenseManager(defaults: freshDefaults, markerURL: markerURL,
                               publicKeyBase64: publicKeyBase64,
                               now: { start.addingTimeInterval(60 * 60 * 24 * 15) })
        XCTAssertEqual(m.state, .expired)
    }

    // MARK: - ライセンス

    func testActivateWithValidKey() throws {
        let key = try makeKey(email: "buyer@example.com")
        let email = try manager().activate(key: " \(key)\n") // 前後空白は許容
        XCTAssertEqual(email, "buyer@example.com")
        XCTAssertEqual(manager().state, .licensed(email: "buyer@example.com"))
    }

    func testLicensedEvenAfterTrialExpiry() throws {
        let start = Date()
        _ = manager(now: start).state
        try manager(now: start).activate(key: makeKey(email: "buyer@example.com"))
        let later = start.addingTimeInterval(60 * 60 * 24 * 100)
        XCTAssertEqual(manager(now: later).state, .licensed(email: "buyer@example.com"))
        XCTAssertTrue(manager(now: later).isEntitled)
    }

    func testRejectsMalformedKey() {
        XCTAssertThrowsError(try manager().activate(key: "そんなキーはない"))
    }

    func testRejectsKeySignedWithWrongKey() throws {
        let otherKey = Curve25519.Signing.PrivateKey()
        let forged = try makeKey(email: "attacker@example.com", privateKey: otherKey)
        XCTAssertThrowsError(try manager().activate(key: forged))
        XCTAssertNotEqual(manager().state, .licensed(email: "attacker@example.com"))
    }

    func testRejectsTamperedPayload() throws {
        let key = try makeKey(email: "buyer@example.com")
        let parts = String(key.dropFirst(LicenseManager.keyPrefix.count)).split(separator: ".")
        let tamperedPayload = try JSONSerialization.data(
            withJSONObject: ["email": "tampered@example.com", "iat": 0], options: [.sortedKeys])
        let tampered = "UNIENTER-\(tamperedPayload.base64urlEncodedString()).\(parts[1])"
        XCTAssertThrowsError(try manager().activate(key: tampered))
    }
}
