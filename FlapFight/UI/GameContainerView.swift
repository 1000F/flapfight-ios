import SwiftUI
import SpriteKit

struct GameContainerView: View {
  let id: UUID
  let mode: GameMode
  let bestScore: Int
  let onGameOver: (Int, UInt64, [TimeInterval]) -> Void
  let onRestartRequested: () -> Void

  @State private var scene: GameScene

  init(id: UUID, mode: GameMode, bestScore: Int, onGameOver: @escaping (Int, UInt64, [TimeInterval]) -> Void, onRestartRequested: @escaping () -> Void) {
    self.id = id
    self.mode = mode
    self.bestScore = bestScore
    self.onGameOver = onGameOver
    self.onRestartRequested = onRestartRequested

    let s = GameScene(size: CGSize(width: 390, height: 520))
    s.scaleMode = .resizeFill
    s.isUserInteractionEnabled = true
    s.bestScore = bestScore

    // Set seed, target score, and ghost data based on mode
    switch mode {
    case .classic:
      s.seed = UInt64.random(in: 0...UInt64.max)
      s.targetScore = nil
      s.ghostTapTimestamps = nil
    case .challenge(let challengeCode):
      s.seed = challengeCode.seed
      s.targetScore = challengeCode.targetScore
      s.ghostTapTimestamps = challengeCode.tapTimestamps
    }

    _scene = State(initialValue: s)
  }

  var body: some View {
    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
      .id(id)
      .contentShape(Rectangle())
      .onTapGesture {
        scene.handleTap()
      }
      .clipShape(RoundedRectangle(cornerRadius: 22))
      .overlay(
        RoundedRectangle(cornerRadius: 22)
          .stroke(.white.opacity(0.10), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 14)
      .onAppear {
        scene.onGameOver = { score in onGameOver(score, scene.seed, scene.tapTimestamps) }
        scene.onRestartRequested = { onRestartRequested() }
      }
  }
}
