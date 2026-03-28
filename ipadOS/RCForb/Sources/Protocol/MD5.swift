import Foundation
import CommonCrypto

func md5(_ input: String) -> String {
    let data = Data(input.utf8)
    var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
    _ = data.withUnsafeBytes {
        CC_MD5($0.baseAddress, CC_LONG(data.count), &digest)
    }
    return digest.map { String(format: "%02x", $0) }.joined()
}

func doubleMD5(_ password: String) -> String {
    md5(md5(password))
}

func validationToken(_ user: String, _ doubleMD5Pass: String) -> String {
    let encodedUser = user.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? user
    return md5(encodedUser + doubleMD5Pass)
}
