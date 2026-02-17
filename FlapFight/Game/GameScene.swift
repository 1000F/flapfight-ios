import SpriteKit
import GameplayKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
  // MARK: - Tunables
  private let gravity: CGFloat = -14
  private let flapImpulse: CGFloat = 320
  private let scrollSpeed: CGFloat = 160
  private let pipeGap: CGFloat = 170
  private let pipeWidth: CGFloat = 64
  private let pipeSpawnEvery: TimeInterval = 1.35
  private let maxFallSpeed: CGFloat = 500

  // MARK: - State
  var seed: UInt64 = UInt64.random(in: 0...UInt64.max)
  var targetScore: Int? = nil
  var ghostTapTimestamps: [TimeInterval]? = nil
  var onGameOver: ((Int) -> Void)?
  var onRestartRequested: (() -> Void)?

  private var bird = SKShapeNode()
  private var ghostBird: SKShapeNode?
  private var ghostTapIndex = 0
  private var ground = SKNode()
  private var groundVisual1 = SKShapeNode()
  private var groundVisual2 = SKShapeNode()
  private var farLayer1 = SKShapeNode()
  private var farLayer2 = SKShapeNode()
  private var midLayer1 = SKShapeNode()
  private var midLayer2 = SKShapeNode()
  private var isDead = false
  private var hasStarted = false

  private var score = 0
  private var scoreLabel = SKLabelNode(fontNamed: nil)

  private var lastUpdate: TimeInterval = 0
  private var spawnAccumulator: TimeInterval = 0
  private var gameStartTime: TimeInterval = 0
  private(set) var tapTimestamps: [TimeInterval] = []

  private var rng: GKMersenneTwisterRandomSource!

  // FX
  private let audio = GameAudio()
  private let nearMissThreshold: CGFloat = 25
  private var nearMissCooldown: TimeInterval = 0
  private var timeScale: CGFloat = 1.0

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

  private func makeBirdNode() -> SKShapeNode {
    // Main body - circular
    let container = SKShapeNode(circleOfRadius: 18)
    container.fillColor = SKColor.white.withAlphaComponent(0.92)
    container.strokeColor = SKColor.red.withAlphaComponent(0.55)
    container.lineWidth = 2.5

    // Eye - small black dot
    let eye = SKShapeNode(circleOfRadius: 3)
    eye.fillColor = .black
    eye.strokeColor = .clear
    eye.position = CGPoint(x: 7, y: 5)
    eye.name = "eye"
    container.addChild(eye)

    // Beak - small triangle
    let beakPath = CGMutablePath()
    beakPath.move(to: CGPoint(x: 14, y: 0))
    beakPath.addLine(to: CGPoint(x: 22, y: 2))
    beakPath.addLine(to: CGPoint(x: 22, y: -2))
    beakPath.closeSubpath()

    let beak = SKShapeNode(path: beakPath)
    beak.fillColor = SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.9)
    beak.strokeColor = .clear
    beak.name = "beak"
    container.addChild(beak)

    // Wing - arc shape that will animate
    let wingPath = CGMutablePath()
    wingPath.move(to: CGPoint(x: -8, y: -2))
    wingPath.addCurve(
      to: CGPoint(x: -8, y: -12),
      control1: CGPoint(x: -14, y: -4),
      control2: CGPoint(x: -14, y: -10)
    )
    wingPath.addLine(to: CGPoint(x: -8, y: -2))

    let wing = SKShapeNode(path: wingPath)
    wing.fillColor = SKColor.white.withAlphaComponent(0.8)
    wing.strokeColor = SKColor.red.withAlphaComponent(0.4)
    wing.lineWidth = 1.5
    wing.name = "wing"
    container.addChild(wing)

    return container
  }

  private func makeGroundNode(width: CGFloat, height: CGFloat) -> SKShapeNode {
    let ground = SKShapeNode(rectOf: CGSize(width: width, height: height))
    ground.fillColor = SKColor.white.withAlphaComponent(0.20)
    ground.strokeColor = .clear
    ground.name = "groundVisual"

    // Brighter top edge line
    let topLine = SKShapeNode(rectOf: CGSize(width: width, height: 2))
    topLine.fillColor = SKColor.white.withAlphaComponent(0.6)
    topLine.strokeColor = .clear
    topLine.position = CGPoint(x: 0, y: height / 2)
    ground.addChild(topLine)

    return ground
  }

  private func makeFarParallaxLayer(width: CGFloat, height: CGFloat) -> SKShapeNode {
    let container = SKShapeNode(rectOf: CGSize(width: width, height: height))
    container.fillColor = .clear
    container.strokeColor = .clear
    container.name = "farLayer"

    // Add horizontal lines at various heights
    let lineCount = 8
    for i in 0..<lineCount {
      let y = (CGFloat(i) / CGFloat(lineCount - 1)) * height - height / 2
      let line = SKShapeNode(rectOf: CGSize(width: width, height: 1))
      line.fillColor = SKColor.white.withAlphaComponent(0.05)
      line.strokeColor = .clear
      line.position = CGPoint(x: 0, y: y)
      container.addChild(line)
    }

    return container
  }

  private func makeMidParallaxLayer(width: CGFloat, height: CGFloat) -> SKShapeNode {
    let container = SKShapeNode(rectOf: CGSize(width: width, height: height))
    container.fillColor = .clear
    container.strokeColor = .clear
    container.name = "midLayer"

    // Add subtle circular shapes scattered across the layer
    let dotCount = 12
    for i in 0..<dotCount {
      let x = (CGFloat(i) / CGFloat(dotCount - 1)) * width - width / 2
      let y = CGFloat.random(in: -height/2...height/2)
      let dot = SKShapeNode(circleOfRadius: 3)
      dot.fillColor = SKColor.white.withAlphaComponent(0.12)
      dot.strokeColor = .clear
      dot.position = CGPoint(x: x, y: y)
      container.addChild(dot)
    }

    return container
  }

  private func buildScene() {
    removeAllChildren()
    isDead = false
    score = 0
    tapTimestamps = []

    // Initialize seeded RNG
    rng = GKMersenneTwisterRandomSource(seed: seed)

    // Subtle grid background
    let bg = SKShapeNode(rect: frame)
    bg.fillColor = SKColor(white: 0, alpha: 0.18)
    bg.strokeColor = .clear
    bg.zPosition = -10
    addChild(bg)

    // Far parallax layer (very faint horizontal lines, slowest)
    farLayer1 = makeFarParallaxLayer(width: size.width, height: size.height)
    farLayer1.position = CGPoint(x: size.width / 2, y: size.height / 2)
    farLayer1.zPosition = -9
    addChild(farLayer1)

    farLayer2 = makeFarParallaxLayer(width: size.width, height: size.height)
    farLayer2.position = CGPoint(x: size.width * 1.5, y: size.height / 2)
    farLayer2.zPosition = -9
    addChild(farLayer2)

    // Mid parallax layer (slightly brighter dots, medium speed)
    midLayer1 = makeMidParallaxLayer(width: size.width, height: size.height)
    midLayer1.position = CGPoint(x: size.width / 2, y: size.height / 2)
    midLayer1.zPosition = -5
    addChild(midLayer1)

    midLayer2 = makeMidParallaxLayer(width: size.width, height: size.height)
    midLayer2.position = CGPoint(x: size.width * 1.5, y: size.height / 2)
    midLayer2.zPosition = -5
    addChild(midLayer2)

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

    // Visual ground (scrolling)
    let groundHeight: CGFloat = 40
    let groundY: CGFloat = 40
    groundVisual1 = makeGroundNode(width: size.width, height: groundHeight)
    groundVisual1.position = CGPoint(x: size.width / 2, y: groundY)
    groundVisual1.zPosition = -2
    addChild(groundVisual1)

    groundVisual2 = makeGroundNode(width: size.width, height: groundHeight)
    groundVisual2.position = CGPoint(x: size.width * 1.5, y: groundY)
    groundVisual2.zPosition = -2
    addChild(groundVisual2)

    // Bird
    let birdRadius: CGFloat = 18
    bird = makeBirdNode()
    bird.position = CGPoint(x: size.width * 0.34, y: size.height * 0.55)

    let birdBody = SKPhysicsBody(circleOfRadius: birdRadius)
    birdBody.allowsRotation = true
    birdBody.linearDamping = 0.3
    birdBody.angularDamping = 0.5
    birdBody.categoryBitMask = Category.bird
    birdBody.collisionBitMask = Category.pipe | Category.ground
    birdBody.contactTestBitMask = Category.pipe | Category.score | Category.ground
    birdBody.isDynamic = false  // Start frozen until first tap
    bird.physicsBody = birdBody

    addChild(bird)
    hasStarted = false

    // Gentle bob animation during ready state
    let bob = SKAction.sequence([
      SKAction.moveBy(x: 0, y: 3, duration: 0.25),
      SKAction.moveBy(x: 0, y: -3, duration: 0.25)
    ])
    bird.run(SKAction.repeatForever(bob), withKey: "bob")

    // Ghost bird (if replay data provided)
    if let _ = ghostTapTimestamps {
      ghostBird = SKShapeNode(circleOfRadius: 18)
      ghostBird!.fillColor = SKColor.cyan.withAlphaComponent(0.50)
      ghostBird!.strokeColor = SKColor.cyan.withAlphaComponent(0.50)
      ghostBird!.lineWidth = 2
      ghostBird!.position = CGPoint(x: size.width * 0.34, y: size.height * 0.55)

      let ghostBody = SKPhysicsBody(circleOfRadius: 18)
      ghostBody.allowsRotation = true
      ghostBody.linearDamping = 0.3
      ghostBody.angularDamping = 0.5
      ghostBody.categoryBitMask = 0 // No category
      ghostBody.collisionBitMask = 0 // Pass through everything
      ghostBody.contactTestBitMask = 0 // No contacts
      ghostBody.isDynamic = false  // Start frozen until first tap
      ghostBird!.physicsBody = ghostBody

      addChild(ghostBird!)
      ghostTapIndex = 0
    }

    // Score label
    if let target = targetScore {
      scoreLabel = SKLabelNode(text: "0 / \(target)")
      scoreLabel.fontSize = 36
    } else {
      scoreLabel = SKLabelNode(text: "0")
      scoreLabel.fontSize = 42
    }
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

    // Camera (for screen shake)
    let cam = SKCameraNode()
    cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
    addChild(cam)
    camera = cam

    lastUpdate = 0
    spawnAccumulator = 0
    timeScale = 1.0
    Haptics.prepare()
  }

  func handleTap() {
    if isDead {
      onRestartRequested?()
      return
    }

    // First tap starts the game (just enable physics, no impulse)
    if !hasStarted {
      hasStarted = true
      bird.physicsBody?.isDynamic = true
      ghostBird?.physicsBody?.isDynamic = true
      bird.removeAction(forKey: "bob")
      childNode(withName: "hint")?.removeFromParent()
      Haptics.flap()
      audio.playFlap()
      return
    }

    // Record tap timestamp relative to game start
    let relativeTime = lastUpdate - gameStartTime
    tapTimestamps.append(relativeTime)

    Haptics.flap()
    audio.playFlap()

    // flap
    bird.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
    bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: flapImpulse))

    // Animate wing
    if let wing = bird.childNode(withName: "wing") {
      wing.run(SKAction.sequence([
        SKAction.rotate(byAngle: -0.6, duration: 0.05),
        SKAction.rotate(byAngle: 0.6, duration: 0.05)
      ]))
    }
  }

  // Taps handled via SwiftUI onTapGesture → handleTap()

  override func update(_ currentTime: TimeInterval) {
    if lastUpdate == 0 {
      lastUpdate = currentTime
      gameStartTime = currentTime
    }
    let dt = currentTime - lastUpdate
    lastUpdate = currentTime

    if isDead || !hasStarted { return }

    // Ghost replay
    if let timestamps = ghostTapTimestamps,
       let ghost = ghostBird,
       ghostTapIndex < timestamps.count {
      let currentGameTime = currentTime - gameStartTime
      if currentGameTime >= timestamps[ghostTapIndex] {
        // Replay tap on ghost
        ghost.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        ghost.physicsBody?.applyImpulse(CGVector(dx: 0, dy: flapImpulse))
        ghostTapIndex += 1
      }
    }

    // Check if ghost died (out of bounds)
    if let ghost = ghostBird {
      if ghost.position.y < 0 || ghost.position.y > size.height + 60 {
        ghost.removeFromParent()
        ghostBird = nil
      }
    }

    spawnAccumulator += dt
    if spawnAccumulator >= pipeSpawnEvery {
      spawnAccumulator = 0
      spawnPipePair()
    }

    let scaledDt = dt * Double(timeScale)

    // Move pipes
    enumerateChildNodes(withName: "pipe") { node, _ in
      node.position.x -= self.scrollSpeed * scaledDt
      if node.position.x < -200 {
        node.removeFromParent()
      }
    }

    enumerateChildNodes(withName: "scoreZone") { node, _ in
      node.position.x -= self.scrollSpeed * scaledDt
      if node.position.x < -200 {
        node.removeFromParent()
      }
    }

    // Scroll ground
    groundVisual1.position.x -= scrollSpeed * scaledDt
    groundVisual2.position.x -= scrollSpeed * scaledDt

    // Reset ground positions for seamless looping
    if groundVisual1.position.x < -size.width / 2 {
      groundVisual1.position.x = groundVisual2.position.x + size.width
    }
    if groundVisual2.position.x < -size.width / 2 {
      groundVisual2.position.x = groundVisual1.position.x + size.width
    }

    // Scroll parallax layers (only when game has started)
    // Far layer at 20% speed
    let farSpeed = scrollSpeed * 0.2
    farLayer1.position.x -= farSpeed * scaledDt
    farLayer2.position.x -= farSpeed * scaledDt

    if farLayer1.position.x < -size.width / 2 {
      farLayer1.position.x = farLayer2.position.x + size.width
    }
    if farLayer2.position.x < -size.width / 2 {
      farLayer2.position.x = farLayer1.position.x + size.width
    }

    // Mid layer at 50% speed
    let midSpeed = scrollSpeed * 0.5
    midLayer1.position.x -= midSpeed * scaledDt
    midLayer2.position.x -= midSpeed * scaledDt

    if midLayer1.position.x < -size.width / 2 {
      midLayer1.position.x = midLayer2.position.x + size.width
    }
    if midLayer2.position.x < -size.width / 2 {
      midLayer2.position.x = midLayer1.position.x + size.width
    }

    // Near-miss detection
    nearMissCooldown = max(0, nearMissCooldown - dt)
    if nearMissCooldown <= 0 {
      let birdY = bird.position.y
      let birdX = bird.position.x
      enumerateChildNodes(withName: "pipe") { node, stop in
        let halfW = self.pipeWidth / 2
        guard birdX > node.position.x - halfW - 18,
              birdX < node.position.x + halfW + 18 else { return }

        let pipeHalfH = node.frame.height / 2
        let topEdge = node.position.y + pipeHalfH
        let bottomEdge = node.position.y - pipeHalfH

        let distTop = abs(birdY - topEdge)
        let distBottom = abs(birdY - bottomEdge)
        let minDist = min(distTop, distBottom)

        if minDist < self.nearMissThreshold && minDist > 18 {
          self.triggerNearMiss()
          self.nearMissCooldown = 0.4
          stop.pointee = true
        }
      }
    }

    // Fail out-of-bounds
    if bird.position.y < 0 || bird.position.y > size.height + 60 {
      die()
    }

    // Clamp fall speed
    if let vel = bird.physicsBody?.velocity, vel.dy < -maxFallSpeed {
      bird.physicsBody?.velocity = CGVector(dx: vel.dx, dy: -maxFallSpeed)
    }
    if let ghost = ghostBird, let vel = ghost.physicsBody?.velocity, vel.dy < -maxFallSpeed {
      ghost.physicsBody?.velocity = CGVector(dx: vel.dx, dy: -maxFallSpeed)
    }

    // Tilt bird a bit based on vertical velocity
    if let vy = bird.physicsBody?.velocity.dy {
      bird.zRotation = max(min(vy / 900, 0.8), -0.8)
    }

    // Tilt ghost bird too
    if let ghost = ghostBird, let vy = ghost.physicsBody?.velocity.dy {
      ghost.zRotation = max(min(vy / 900, 0.8), -0.8)
    }
  }

  private func spawnPipePair() {
    let minY: CGFloat = 110
    let maxY: CGFloat = size.height - 140
    // Use seeded RNG for deterministic pipe generation
    let normalizedRandom = CGFloat(rng.nextUniform()) // 0.0...1.0
    let centerY = minY + normalizedRandom * (maxY - minY)

    let topHeight = (size.height - centerY) - (pipeGap/2)
    let bottomHeight = (centerY - (pipeGap/2))

    let x = size.width + 90

    let top = pipeNode(height: topHeight, isTop: true)
    top.position = CGPoint(x: x, y: centerY + pipeGap/2 + topHeight/2)

    let bottom = pipeNode(height: bottomHeight, isTop: false)
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

  private func pipeNode(height: CGFloat, isTop: Bool) -> SKShapeNode {
    let actualHeight = max(10, height)
    let n = SKShapeNode(rectOf: CGSize(width: pipeWidth, height: actualHeight), cornerRadius: 10)
    n.name = "pipe"
    n.fillColor = SKColor(white: 1, alpha: 0.3)
    n.strokeColor = SKColor(white: 1, alpha: 0.7)
    n.lineWidth = 2

    // Add subtle colored accent (inner stroke)
    let accentStroke = SKShapeNode(rectOf: CGSize(width: pipeWidth - 4, height: actualHeight - 4), cornerRadius: 8)
    accentStroke.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.25)
    accentStroke.fillColor = .clear
    accentStroke.lineWidth = 1.5
    n.addChild(accentStroke)

    // Add end cap at gap-facing edge
    let capWidth = pipeWidth + 12
    let capHeight: CGFloat = 8
    let cap = SKShapeNode(rectOf: CGSize(width: capWidth, height: capHeight), cornerRadius: 4)
    cap.fillColor = SKColor(white: 1, alpha: 0.35)
    cap.strokeColor = SKColor(white: 1, alpha: 0.8)
    cap.lineWidth = 2
    // Position cap at the gap-facing edge: bottom for top pipes, top for bottom pipes
    let capYOffset = isTop ? -(actualHeight / 2) : (actualHeight / 2)
    cap.position = CGPoint(x: 0, y: capYOffset)
    n.addChild(cap)

    let body = SKPhysicsBody(rectangleOf: CGSize(width: pipeWidth, height: actualHeight))
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
      score += 1
      if let target = targetScore {
        scoreLabel.text = "\(score) / \(target)"
      } else {
        scoreLabel.text = "\(score)"
      }

      Haptics.score()
      audio.playScore()
      scoreLabel.run(SKAction.sequence([
        SKAction.scale(to: 1.5, duration: 0.08),
        SKAction.scale(to: 1.0, duration: 0.12)
      ]))

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

    Haptics.death()
    audio.playDeath()

    // Cancel any slow-mo
    removeAction(forKey: "slowmo")
    timeScale = 1.0
    physicsWorld.speed = 1.0

    // Add death spin
    bird.physicsBody?.applyAngularImpulse(0.08)

    // Delay freeze to let spin play out
    run(SKAction.sequence([
      SKAction.wait(forDuration: 0.4),
      SKAction.run { [weak self] in
        self?.bird.physicsBody?.velocity = .zero
        self?.bird.physicsBody?.isDynamic = false
      }
    ]))

    // Screen shake
    camera?.run(SKAction.sequence([
      SKAction.moveBy(x: 8, y: 0, duration: 0.03),
      SKAction.moveBy(x: -16, y: 0, duration: 0.03),
      SKAction.moveBy(x: 12, y: 0, duration: 0.03),
      SKAction.moveBy(x: -8, y: 0, duration: 0.03),
      SKAction.moveBy(x: 4, y: 0, duration: 0.03),
      SKAction.moveTo(x: size.width / 2, duration: 0.02),
    ]))

    // Red flash
    let flash = SKShapeNode(rect: frame)
    flash.fillColor = SKColor.red.withAlphaComponent(0.3)
    flash.strokeColor = .clear
    flash.zPosition = 15
    addChild(flash)
    flash.run(SKAction.sequence([
      SKAction.fadeOut(withDuration: 0.2),
      SKAction.removeFromParent()
    ]))

    // Delayed overlay
    run(SKAction.sequence([
      SKAction.wait(forDuration: 0.3),
      SKAction.run { [weak self] in self?.showDeathOverlay() }
    ]))

    onGameOver?(score)
  }

  private func showDeathOverlay() {
    let overlay = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 160), cornerRadius: 18)
    overlay.fillColor = SKColor(white: 0, alpha: 0.35)
    overlay.strokeColor = SKColor(white: 1, alpha: 0.12)
    overlay.lineWidth = 1
    overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
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
  }

  // MARK: - Near-miss effect

  private func triggerNearMiss() {
    Haptics.nearMiss()
    audio.playNearMiss()

    // Chromatic flash on bird
    bird.run(SKAction.sequence([
      SKAction.run { [weak self] in
        self?.bird.fillColor = SKColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 0.95)
        self?.bird.strokeColor = SKColor.cyan
      },
      SKAction.wait(forDuration: 0.08),
      SKAction.run { [weak self] in
        self?.bird.fillColor = SKColor.white.withAlphaComponent(0.92)
        self?.bird.strokeColor = SKColor.red.withAlphaComponent(0.55)
      }
    ]), withKey: "nearMiss")

    // Micro slow-mo
    timeScale = 0.6
    physicsWorld.speed = 0.6
    run(SKAction.sequence([
      SKAction.wait(forDuration: 0.1),
      SKAction.run { [weak self] in
        self?.timeScale = 1.0
        self?.physicsWorld.speed = 1.0
      }
    ]), withKey: "slowmo")
  }
}
