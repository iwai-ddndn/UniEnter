import CryptoKit
import Foundation

enum LicenseState: Equatable {
    case licensed(email: String)
    case trial(daysLeft: Int)
    case expired
}

enum LicenseError: LocalizedError {
    case malformed
    case badSignature

    var errorDescription: String? {
        switch self {
        case .malformed: return "ライセンスキーの形式が正しくありません。"
        case .badSignature: return "ライセンスキーを検証できませんでした。入力内容をご確認ください。"
        }
    }
}

/// 買い切りライセンスと14日間トライアルの管理。
///
/// - ライセンスはオフライン検証: `base64url(payload).base64url(signature)` 形式のキーを
///   埋め込みEd25519公開鍵で検証する(サーバ通信なし)。発行は license-signing/issue.swift。
/// - トライアル開始日時はUserDefaultsとApplication Support配下のマーカーに二重記録し、
///   早い方を採用する(単純な再インストールでのリセットを防ぐ。厳密な保護はしない)。
final class LicenseManager {
    static let trialDays = 14
    static let publicKeyBase64 = "GnuD4CdMgZHXooBnItp7HxOZUQD7Ai/fURl0oqidhXk="
    static let keyPrefix = "UNIENTER-"

    private static let licenseKeyKey = "licenseKey"
    private static let trialStartKey = "trialStartedAt"

    private let defaults: UserDefaults
    private let markerURL: URL
    private let now: () -> Date
    private let publicKeyBase64Value: String

    init(defaults: UserDefaults = .standard,
         markerURL: URL? = nil,
         publicKeyBase64: String = LicenseManager.publicKeyBase64,
         now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        self.publicKeyBase64Value = publicKeyBase64
        if let markerURL {
            self.markerURL = markerURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.markerURL = support.appendingPathComponent("UniEnter/.trial", isDirectory: false)
        }
    }

    // MARK: - 状態

    var state: LicenseState {
        if let key = defaults.string(forKey: Self.licenseKeyKey),
           let email = Self.verify(key: key, publicKeyBase64: publicKeyBase64Value) {
            return .licensed(email: email)
        }
        let start = trialStart()
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: now()).day ?? 0
        let left = Self.trialDays - elapsed
        return left > 0 ? .trial(daysLeft: left) : .expired
    }

    /// 書き換え機能を有効にしてよいか
    var isEntitled: Bool {
        if case .expired = state { return false }
        return true
    }

    // MARK: - 認証

    /// キーを検証して保存する。成功時は購入者メールアドレスを返す。
    @discardableResult
    func activate(key rawKey: String) throws -> String {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let email = Self.verify(key: key, publicKeyBase64: publicKeyBase64Value) else {
            throw key.hasPrefix(Self.keyPrefix) ? LicenseError.badSignature : LicenseError.malformed
        }
        defaults.set(key, forKey: Self.licenseKeyKey)
        return email
    }

    /// キー本体の検証(状態を持たない)。妥当なら購入者メールアドレスを返す。
    static func verify(key: String, publicKeyBase64: String) -> String? {
        guard key.hasPrefix(keyPrefix) else { return nil }
        let body = String(key.dropFirst(keyPrefix.count))
        let parts = body.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let payload = Data(base64urlEncoded: parts[0]),
              let signature = Data(base64urlEncoded: parts[1]),
              let keyData = Data(base64Encoded: publicKeyBase64),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              publicKey.isValidSignature(signature, for: payload),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let email = json["email"] as? String else {
            return nil
        }
        return email
    }

    // MARK: - トライアル

    /// トライアル開始日時。未記録なら現在時刻で開始し、両方の保存先に記録する。
    private func trialStart() -> Date {
        let fromDefaults = (defaults.object(forKey: Self.trialStartKey) as? Double).map(Date.init(timeIntervalSince1970:))
        let fromMarker = (try? String(contentsOf: markerURL, encoding: .utf8))
            .flatMap(Double.init)
            .map(Date.init(timeIntervalSince1970:))

        let start: Date
        switch (fromDefaults, fromMarker) {
        case let (d?, m?): start = min(d, m)
        case let (d?, nil): start = d
        case let (nil, m?): start = m
        case (nil, nil): start = now()
        }

        if fromDefaults != start {
            defaults.set(start.timeIntervalSince1970, forKey: Self.trialStartKey)
        }
        if fromMarker != start {
            try? FileManager.default.createDirectory(
                at: markerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? String(start.timeIntervalSince1970).write(to: markerURL, atomically: true, encoding: .utf8)
        }
        return start
    }
}

extension Data {
    init?(base64urlEncoded input: String) {
        var base64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        self.init(base64Encoded: base64)
    }

    func base64urlEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
