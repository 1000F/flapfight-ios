import Foundation

struct ChallengeCode: Equatable {
  let seed: UInt64
  let targetScore: Int
  let tapTimestamps: [TimeInterval]

  /// Encodes the challenge code into a shareable string
  func encode() -> String {
    // Pack: seed (8 bytes) + targetScore (2 bytes) + tap count (1 byte) + delta-encoded taps
    // Delta encoding: store time differences as UInt16 milliseconds

    var bytes: [UInt8] = []

    // Encode seed (8 bytes, big-endian)
    bytes.append(contentsOf: withUnsafeBytes(of: seed.bigEndian) { Array($0) })

    // Encode targetScore as UInt16 (2 bytes, big-endian)
    let clampedScore = min(UInt16(targetScore), UInt16.max)
    bytes.append(contentsOf: withUnsafeBytes(of: clampedScore.bigEndian) { Array($0) })

    // Encode tap count (1 byte, max 255 taps)
    let tapCount = min(UInt8(tapTimestamps.count), UInt8.max)
    bytes.append(tapCount)

    // Delta encode tap timestamps as milliseconds (2 bytes each)
    var lastTime: TimeInterval = 0
    for timestamp in tapTimestamps.prefix(Int(tapCount)) {
      let deltaMs = UInt16(max(0, min(65535, (timestamp - lastTime) * 1000)))
      bytes.append(contentsOf: withUnsafeBytes(of: deltaMs.bigEndian) { Array($0) })
      lastTime = timestamp
    }

    // Base32 encode
    return Data(bytes).base32EncodedString()
  }

  /// Decodes a challenge code string
  static func decode(code: String) -> ChallengeCode? {
    guard let data = Data(base32Encoded: code.uppercased()),
          data.count >= 11 else {
      return nil
    }

    let bytes = Array(data)

    // Decode seed (first 8 bytes)
    let seedBytes = bytes[0..<8]
    let seed = seedBytes.withUnsafeBytes { $0.load(as: UInt64.self) }.bigEndian

    // Decode targetScore (bytes 8-9)
    let scoreBytes = bytes[8..<10]
    let targetScore = Int(scoreBytes.withUnsafeBytes { $0.load(as: UInt16.self) }.bigEndian)

    // Decode tap count (byte 10)
    let tapCount = Int(bytes[10])

    // Decode delta-encoded tap timestamps
    var tapTimestamps: [TimeInterval] = []
    var currentTime: TimeInterval = 0
    var offset = 11

    for _ in 0..<tapCount {
      guard offset + 1 < bytes.count else { break }
      let deltaBytes = bytes[offset..<offset+2]
      let deltaMs = deltaBytes.withUnsafeBytes { $0.load(as: UInt16.self) }.bigEndian
      currentTime += TimeInterval(deltaMs) / 1000.0
      tapTimestamps.append(currentTime)
      offset += 2
    }

    return ChallengeCode(seed: seed, targetScore: targetScore, tapTimestamps: tapTimestamps)
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
