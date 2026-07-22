// ライセンスキー発行スクリプト(購入者ごとに実行)
// 使い方: swift license-signing/issue.swift buyer@example.com
// 前提: 同じディレクトリの keys.txt に PRIVATE:<base64> 行があること(git管理外)
import CryptoKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    print("使い方: swift issue.swift <購入者メールアドレス>")
    exit(1)
}
let email = CommandLine.arguments[1]

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let keysURL = scriptDir.appendingPathComponent("keys.txt")
guard let keysText = try? String(contentsOf: keysURL, encoding: .utf8),
      let privateLine = keysText.split(separator: "\n").first(where: { $0.hasPrefix("PRIVATE:") }),
      let privateData = Data(base64Encoded: String(privateLine.dropFirst("PRIVATE:".count))),
      let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privateData) else {
    print("エラー: keys.txt から秘密鍵を読めませんでした")
    exit(1)
}

let payload: [String: Any] = [
    "email": email,
    "iat": Int(Date().timeIntervalSince1970),
]
let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
let signature = try privateKey.signature(for: payloadData)

func base64url(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

print("UNIENTER-\(base64url(payloadData)).\(base64url(signature))")
