import UIKit
import AVFoundation

// MARK: - Haptics

enum Haptics {
  private static let light = UIImpactFeedbackGenerator(style: .light)
  private static let medium = UIImpactFeedbackGenerator(style: .medium)
  private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
  private static let tick = UISelectionFeedbackGenerator()

  static func prepare() {
    light.prepare()
    medium.prepare()
    heavy.prepare()
    tick.prepare()
  }

  static func flap()     { light.impactOccurred() }
  static func score()    { medium.impactOccurred() }
  static func death()    { heavy.impactOccurred() }
  static func nearMiss() { tick.selectionChanged() }
}

// MARK: - Procedural Audio

final class GameAudio {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let format: AVAudioFormat

  private let flapBuffer: AVAudioPCMBuffer
  private let scoreBuffer: AVAudioPCMBuffer
  private let deathBuffer: AVAudioPCMBuffer
  private let nearMissBuffer: AVAudioPCMBuffer

  init() {
    let sr: Double = 44100
    format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!

    flapBuffer     = GameAudio.tone(freq: 1800, dur: 0.04, wave: .square, sr: sr, fmt: format)
    scoreBuffer    = GameAudio.tone(freq: 880,  dur: 0.08, wave: .sine,   sr: sr, fmt: format)
    deathBuffer    = GameAudio.tone(freq: 110,  dur: 0.15, wave: .sine,   sr: sr, fmt: format)
    nearMissBuffer = GameAudio.tone(freq: 2400, dur: 0.05, wave: .sine,   sr: sr, fmt: format)

    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)

    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    try? AVAudioSession.sharedInstance().setActive(true)
    try? engine.start()
  }

  func playFlap()     { play(flapBuffer) }
  func playScore()    { play(scoreBuffer) }
  func playDeath()    { play(deathBuffer) }
  func playNearMiss() { play(nearMissBuffer) }

  private func play(_ buffer: AVAudioPCMBuffer) {
    player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    if !player.isPlaying { player.play() }
  }

  // MARK: - Tone synthesis

  private enum Wave { case sine, square }

  private static func tone(freq: Double, dur: Double, wave: Wave, sr: Double, fmt: AVAudioFormat) -> AVAudioPCMBuffer {
    let frames = AVAudioFrameCount(sr * dur)
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
    buf.frameLength = frames
    let data = buf.floatChannelData![0]

    for i in 0..<Int(frames) {
      let t = Double(i) / sr
      let env = 1.0 - (t / dur)
      let phase = 2.0 * .pi * freq * t
      let sample: Double
      switch wave {
      case .sine:   sample = sin(phase)
      case .square: sample = sin(phase) > 0 ? 1.0 : -1.0
      }
      data[i] = Float(sample * env * 0.3)
    }
    return buf
  }
}
