import SpriteKit
import GameplayKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
  // MARK: - Tunables
  private let gravity: CGFloat = -7.5
  private let flapImpulse: CGFloat = 250
  private let scrollSpeed: CGFloat = 160
  private let pipeGap: CGFloat = 170
  private let pipeWidth: CGFloat = 64
  private let pipeSpawnEvery: TimeInterval = 1.35

  // MARK: - State
  var onGameOver: ((Int) -> Void)?
  var onRestartRequested: (() -> Void)?

  private var bird = SKShapeNode()
  private var ground = SKNode()
  private var isDead = false

  private var score = 0
  private var scoreLabel = SKLabelNode(fontNamed: nil)

  private var lastUpdate: TimeInterval = 0
  private var spawnAccumulator: TimeInterval = 0

  private enum Category {
    static let bird: UInt32 = 1 << 0
    static let pipe: UInt32 = 1 << 1
    static let score: UInt32 = 1 << 2
    static let ground: UInt32 = 1 << 3
  }

  override func didMove(to view: SKView) {
    backgroundColor = .clear
    physicsWorld.gravity = CGVector(dx: 0, dy: gravity)
    physicsWorld.contactDelegate = self

    buildScene()
  }

  private func buildScene() {
    removeAllChildren()
    isDead = false
    score = 0

    // Subtle grid background
    let bg = SKShapeNode(rect: frame)
    bg.fillColor = SKColor(white: 0, alpha: 0.18)
    bg.strokeColor = .clear
    bg.zPosition = -10
    addChild(bg)

    // Ground (invisible collider)
    ground = SKNode()
    ground.position = CGPoint(x: 0, y: 40)
    let groundBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 0), to: CGPoint(x: size.width, y: 0))
    groundBody.categoryBitMask = Category.ground
    groundBody.collisionBitMask = Category.bird
    groundBody.contactTestBitMask = Category.bird
    groundBody.isDynamic = false
    ground.physicsBody = groundBody
    addChild(ground)

    // Bird
    bird = SKShapeNode(circleOfRadius: 14)
    bird.fillColor = SKColor.white.withAlphaComponent(0.92)
    bird.strokeColor = SKColor.red.withAlphaComponent(0.55)
    bird.lineWidth = 2
    bird.position = CGPoint(x: size.width * 0.34, y: size.height * 0.55)

    let birdBody = SKPhysicsBody(circleOfRadius: 14)
    birdBody.allowsRotation = true
    birdBody.linearDamping = 0.1
    birdBody.angularDamping = 0.9
    birdBody.categoryBitMask = Category.bird
    birdBody.collisionBitMask = Category.pipe | Category.ground
    birdBody.contactTestBitMask = Category.pipe | Category.score | Category.ground
    bird.physicsBody = birdBody

    addChild(bird)

    // Score label
    scoreLabel = SKLabelNode(text: "0")
    scoreLabel.fontSize = 42
    scoreLabel.fontColor = SKColor.white.withAlphaComponent(0.9)
    scoreLabel.position = CGPoint(x: size.width/2, y: size.height - 90)
    scoreLabel.zPosition = 5
    addChild(scoreLabel)

    // Instructions
    let hint = SKLabelNode(text: "TAP")
    hint.fontSize = 14
    hint.fontColor = SKColor.white.withAlphaComponent(0.55)
    hint.position = CGPoint(x: size.width/2, y: size.height - 130)
    hint.zPosition = 5
    hint.name = "hint"
    addChild(hint)

    lastUpdate = 0
    spawnAccumulator = 0
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    // Visual debug: flash the bird so we know taps are arriving
    let flash = SKAction.sequence([
      SKAction.run { [weak self] in self?.bird.fillColor = SKColor.red.withAlphaComponent(0.95) },
      SKAction.wait(forDuration: 0.05),
      SKAction.run { [weak self] in self?.bird.fillColor = SKColor.white.withAlphaComponent(0.92) }
    ])
    bird.run(flash)

    if isDead {
      onRestartRequested?()
      return
    }

    childNode(withName: "hint")?.removeFromParent()

    // flap
    bird.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
    bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: flapImpulse))
  }

  override func update(_ currentTime: TimeInterval) {
    if lastUpdate == 0 { lastUpdate = currentTime }
    let dt = currentTime - lastUpdate
    lastUpdate = currentTime

    if isDead { return }

    spawnAccumulator += dt
    if spawnAccumulator >= pipeSpawnEvery {
      spawnAccumulator = 0
      spawnPipePair()
    }

    // Move pipes
    enumerateChildNodes(withName: "pipe") { node, _ in
      node.position.x -= self.scrollSpeed * dt
      if node.position.x < -200 {
        node.removeFromParent()
      }
    }

    enumerateChildNodes(withName: "scoreZone") { node, _ in
      node.position.x -= self.scrollSpeed * dt
      if node.position.x < -200 {
        node.removeFromParent()
      }
    }

    // Fail out-of-bounds
    if bird.position.y < 0 || bird.position.y > size.height + 60 {
      die()
    }

    // Tilt bird a bit based on vertical velocity
    if let vy = bird.physicsBody?.velocity.dy {
      bird.zRotation = max(min(vy / 900, 0.8), -0.8)
    }
  }

  private func spawnPipePair() {
    let minY: CGFloat = 110
    let maxY: CGFloat = size.height - 140
    let centerY = CGFloat.random(in: minY...maxY)

    let topHeight = (size.height - centerY) - (pipeGap/2)
    let bottomHeight = (centerY - (pipeGap/2))

    let x = size.width + 90

    let top = pipeNode(height: topHeight)
    top.position = CGPoint(x: x, y: centerY + pipeGap/2 + topHeight/2)

    let bottom = pipeNode(height: bottomHeight)
    bottom.position = CGPoint(x: x, y: bottomHeight/2)

    addChild(top)
    addChild(bottom)

    // Score zone
    let zone = SKNode()
    zone.name = "scoreZone"
    zone.position = CGPoint(x: x + pipeWidth/2 + 22, y: size.height/2)
    let body = SKPhysicsBody(rectangleOf: CGSize(width: 10, height: size.height))
    body.isDynamic = false
    body.categoryBitMask = Category.score
    body.contactTestBitMask = Category.bird
    body.collisionBitMask = 0
    zone.physicsBody = body
    addChild(zone)
  }

  private func pipeNode(height: CGFloat) -> SKShapeNode {
    let n = SKShapeNode(rectOf: CGSize(width: pipeWidth, height: max(10, height)), cornerRadius: 10)
    n.name = "pipe"
    n.fillColor = SKColor(white: 1, alpha: 0.06)
    n.strokeColor = SKColor(white: 1, alpha: 0.12)
    n.lineWidth = 1

    let body = SKPhysicsBody(rectangleOf: CGSize(width: pipeWidth, height: max(10, height)))
    body.isDynamic = false
    body.categoryBitMask = Category.pipe
    body.contactTestBitMask = Category.bird
    body.collisionBitMask = Category.bird
    n.physicsBody = body

    return n
  }

  func didBegin(_ contact: SKPhysicsContact) {
    if isDead { return }

    let a = contact.bodyA.categoryBitMask
    let b = contact.bodyB.categoryBitMask
    let mask = a | b

    if mask & Category.score != 0 && mask & Category.bird != 0 {
      // score
      score += 1
      scoreLabel.text = "\(score)"

      // remove zone so it doesn't score twice
      if a == Category.score {
        contact.bodyA.node?.removeFromParent()
      } else if b == Category.score {
        contact.bodyB.node?.removeFromParent()
      }

      return
    }

    if mask & Category.pipe != 0 && mask & Category.bird != 0 {
      die()
      return
    }

    if mask & Category.ground != 0 && mask & Category.bird != 0 {
      die()
      return
    }
  }

  private func die() {
    guard !isDead else { return }
    isDead = true

    // freeze
    bird.physicsBody?.velocity = .zero
    bird.physicsBody?.isDynamic = false

    // overlay
    let overlay = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 160), cornerRadius: 18)
    overlay.fillColor = SKColor(white: 0, alpha: 0.35)
    overlay.strokeColor = SKColor(white: 1, alpha: 0.12)
    overlay.lineWidth = 1
    overlay.position = CGPoint(x: size.width/2, y: size.height/2)
    overlay.zPosition = 20

    let title = SKLabelNode(text: "DEAD")
    title.fontSize = 28
    title.fontColor = SKColor.white.withAlphaComponent(0.9)
    title.position = CGPoint(x: 0, y: 22)
    title.zPosition = 21

    let sub = SKLabelNode(text: "Score \(score)  •  Tap to restart")
    sub.fontSize = 14
    sub.fontColor = SKColor.white.withAlphaComponent(0.65)
    sub.position = CGPoint(x: 0, y: -18)
    sub.zPosition = 21

    overlay.addChild(title)
    overlay.addChild(sub)
    addChild(overlay)

    onGameOver?(score)
  }
}
