import SwiftUI
import SpriteKit

struct GameContainerView: View {
  let id: UUID
  let onGameOver: (Int) -> Void
  let onRestartRequested: () -> Void

  var scene: SKScene {
    let s = GameScene(size: CGSize(width: 390, height: 520))
    s.scaleMode = .resizeFill
    s.onGameOver = { score in
      onGameOver(score)
    }
    s.onRestartRequested = {
      onRestartRequested()
    }
    return s
  }

  var body: some View {
    SpriteView(scene: scene, options: [.ignoresSiblingOrder])
      .id(id)
      .clipShape(RoundedRectangle(cornerRadius: 22))
      .overlay(
        RoundedRectangle(cornerRadius: 22)
          .stroke(.white.opacity(0.10), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 14)
  }
}
