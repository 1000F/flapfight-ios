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

    // Flap: frequency sweep 2200→1600 Hz over 80ms, exponential decay
    flapBuffer     = GameAudio.sweep(from: 2200, to: 1600, dur: 0.08, envelope: .exponential, sr: sr, fmt: format)

    // Score: two-tone chord (880 + 1100 Hz), 120ms, exponential decay
    scoreBuffer    = GameAudio.chord(freqs: [880, 1100], dur: 0.12, envelope: .exponential, sr: sr, fmt: format)

    // Death: low rumble 150→60 Hz sweep over 200ms
    deathBuffer    = GameAudio.sweep(from: 150, to: 60, dur: 0.2, envelope: .exponential, sr: sr, fmt: format)

    // Near-miss: high shimmer 2800 Hz with vibrato (±200 Hz at 30 Hz), 60ms
    nearMissBuffer = GameAudio.vibrato(freq: 2800, vibDepth: 200, vibRate: 30, dur: 0.06, sr: sr, fmt: format)

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

  private enum Envelope { case linear, exponential }

  /// Frequency sweep from one frequency to another
  private static func sweep(from startFreq: Double, to endFreq: Double, dur: Double, envelope: Envelope, sr: Double, fmt: AVAudioFormat) -> AVAudioPCMBuffer {
    let frames = AVAudioFrameCount(sr * dur)
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
    buf.frameLength = frames
    let data = buf.floatChannelData![0]

    var phase: Double = 0.0

    for i in 0..<Int(frames) {
      let t = Double(i) / sr
      let progress = t / dur

      // Exponential envelope: pow(1 - progress, 2)
      let env: Double
      switch envelope {
      case .linear:      env = 1.0 - progress
      case .exponential: env = pow(1.0 - progress, 2.0)
      }

      // Lerp frequency over time
      let freq = startFreq + (endFreq - startFreq) * progress

      // Accumulate phase to avoid discontinuities
      phase += 2.0 * .pi * freq / sr
      let sample = sin(phase)

      data[i] = Float(sample * env * 0.3)
    }
    return buf
  }

  /// Chord - sum multiple sine waves
  private static func chord(freqs: [Double], dur: Double, envelope: Envelope, sr: Double, fmt: AVAudioFormat) -> AVAudioPCMBuffer {
    let frames = AVAudioFrameCount(sr * dur)
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
    buf.frameLength = frames
    let data = buf.floatChannelData![0]

    for i in 0..<Int(frames) {
      let t = Double(i) / sr
      let progress = t / dur

      // Exponential envelope
      let env: Double
      switch envelope {
      case .linear:      env = 1.0 - progress
      case .exponential: env = pow(1.0 - progress, 2.0)
      }

      // Sum all frequencies
      var sample = 0.0
      for freq in freqs {
        let phase = 2.0 * .pi * freq * t
        sample += sin(phase)
      }
      sample /= Double(freqs.count) // Normalize to prevent clipping

      data[i] = Float(sample * env * 0.3)
    }
    return buf
  }

  /// Vibrato - frequency modulation
  private static func vibrato(freq: Double, vibDepth: Double, vibRate: Double, dur: Double, sr: Double, fmt: AVAudioFormat) -> AVAudioPCMBuffer {
    let frames = AVAudioFrameCount(sr * dur)
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
    buf.frameLength = frames
    let data = buf.floatChannelData![0]

    var phase: Double = 0.0

    for i in 0..<Int(frames) {
      let t = Double(i) / sr
      let progress = t / dur

      // Exponential envelope
      let env = pow(1.0 - progress, 2.0)

      // Vibrato: modulate frequency with a sine wave
      let vibrato = sin(2.0 * .pi * vibRate * t) * vibDepth
      let modulatedFreq = freq + vibrato

      // Accumulate phase
      phase += 2.0 * .pi * modulatedFreq / sr
      let sample = sin(phase)

      data[i] = Float(sample * env * 0.3)
    }
    return buf
  }
}
