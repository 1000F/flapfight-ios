import Foundation

struct ChallengeCode: Equatable {
  let seed: UInt64
  let targetScore: Int

  /// Encodes the challenge code into a short alphanumeric string
  func encode() -> String {
    // Pack seed (8 bytes) + targetScore (2 bytes) = 10 bytes
    // Use base32 encoding for URL-safe, human-readable output

    var bytes: [UInt8] = []

    // Encode seed (8 bytes, big-endian)
    bytes.append(contentsOf: withUnsafeBytes(of: seed.bigEndian) { Array($0) })

    // Encode targetScore as UInt16 (2 bytes, big-endian) - supports scores up to 65535
    let clampedScore = min(UInt16(targetScore), UInt16.max)
    bytes.append(contentsOf: withUnsafeBytes(of: clampedScore.bigEndian) { Array($0) })

    // Base32 encode (results in ~16 chars for 10 bytes)
    return Data(bytes).base32EncodedString()
  }

  /// Decodes a challenge code string back to seed + target score
  static func decode(code: String) -> ChallengeCode? {
    guard let data = Data(base32Encoded: code.uppercased()),
          data.count == 10 else {
      return nil
    }

    let bytes = Array(data)

    // Decode seed (first 8 bytes)
    let seedBytes = bytes[0..<8]
    let seed = seedBytes.withUnsafeBytes { $0.load(as: UInt64.self) }.bigEndian

    // Decode targetScore (last 2 bytes)
    let scoreBytes = bytes[8..<10]
    let targetScore = Int(scoreBytes.withUnsafeBytes { $0.load(as: UInt16.self) }.bigEndian)

    return ChallengeCode(seed: seed, targetScore: targetScore)
  }
}

// MARK: - Base32 Encoding/Decoding

fileprivate extension Data {
  // RFC 4648 base32 alphabet (no padding)
  private static let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

  func base32EncodedString() -> String {
    var result = ""
    var bits = 0
    var buffer = 0

    for byte in self {
      buffer = (buffer << 8) | Int(byte)
      bits += 8

      while bits >= 5 {
        bits -= 5
        let index = (buffer >> bits) & 0x1F
        let char = Data.base32Alphabet[Data.base32Alphabet.index(Data.base32Alphabet.startIndex, offsetBy: index)]
        result.append(char)
      }
    }

    // Handle remaining bits
    if bits > 0 {
      buffer <<= (5 - bits)
      let index = buffer & 0x1F
      let char = Data.base32Alphabet[Data.base32Alphabet.index(Data.base32Alphabet.startIndex, offsetBy: index)]
      result.append(char)
    }

    return result
  }

  init?(base32Encoded string: String) {
    let cleanString = string.uppercased().filter { Data.base32Alphabet.contains($0) }
    guard !cleanString.isEmpty else { return nil }

    var bytes: [UInt8] = []
    var buffer = 0
    var bits = 0

    for char in cleanString {
      guard let index = Data.base32Alphabet.firstIndex(of: char) else {
        return nil
      }
      let value = Data.base32Alphabet.distance(from: Data.base32Alphabet.startIndex, to: index)

      buffer = (buffer << 5) | value
      bits += 5

      if bits >= 8 {
        bits -= 8
        bytes.append(UInt8((buffer >> bits) & 0xFF))
      }
    }

    self.init(bytes)
  }
}
