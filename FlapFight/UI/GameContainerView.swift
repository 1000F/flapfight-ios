import SwiftUI
import SpriteKit

struct GameContainerView: View {
  let id: UUID
  let onGameOver: (Int) -> Void
  let onRestartRequested: () -> Void

  @State private var scene: GameScene

  init(id: UUID, onGameOver: @escaping (Int) -> Void, onRestartRequested: @escaping () -> Void) {
    self.id = id
    self.onGameOver = onGameOver
    self.onRestartRequested = onRestartRequested

    let s = GameScene(size: CGSize(width: 390, height: 520))
    s.scaleMode = .resizeFill
    s.isUserInteractionEnabled = true
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
        scene.onGameOver = { score in onGameOver(score) }
        scene.onRestartRequested = { onRestartRequested() }
      }
  }
}
