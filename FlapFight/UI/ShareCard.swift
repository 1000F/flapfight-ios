import UIKit

struct ShareCard {
  let score: Int
  let bestScore: Int
  let challengeCode: String

  /// Generates a shareable card image with dark neo aesthetic
  func generateImage() -> UIImage {
    let width: CGFloat = 1080
    let height: CGFloat = 1920
    let size = CGSize(width: width, height: height)

    let renderer = UIGraphicsImageRenderer(size: size)

    return renderer.image { context in
      let ctx = context.cgContext

      // Dark background
      ctx.setFillColor(UIColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1.0).cgColor)
      ctx.fill(CGRect(origin: .zero, size: size))

      // Gradient accents
      drawRadialGradient(
        ctx: ctx,
        center: CGPoint(x: width * 0.2, y: height * 0.15),
        color: UIColor.red.withAlphaComponent(0.22),
        radius: 600,
        in: size
      )

      drawRadialGradient(
        ctx: ctx,
        center: CGPoint(x: width * 0.8, y: height * 0.15),
        color: UIColor.green.withAlphaComponent(0.16),
        radius: 600,
        in: size
      )

      // Title
      let titleText = "FLAPFIGHT"
      let titleFont = UIFont.systemFont(ofSize: 120, weight: .black)
      let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: UIColor.white,
        .kern: 8
      ]
      let titleSize = titleText.size(withAttributes: titleAttrs)
      let titleRect = CGRect(
        x: (width - titleSize.width) / 2,
        y: height * 0.25,
        width: titleSize.width,
        height: titleSize.height
      )
      titleText.draw(in: titleRect, withAttributes: titleAttrs)

      // Score
      let scoreText = "\(score)"
      let scoreFont = UIFont.monospacedSystemFont(ofSize: 240, weight: .heavy)
      let scoreAttrs: [NSAttributedString.Key: Any] = [
        .font: scoreFont,
        .foregroundColor: UIColor.white.withAlphaComponent(0.95)
      ]
      let scoreSize = scoreText.size(withAttributes: scoreAttrs)
      let scoreRect = CGRect(
        x: (width - scoreSize.width) / 2,
        y: height * 0.40,
        width: scoreSize.width,
        height: scoreSize.height
      )
      scoreText.draw(in: scoreRect, withAttributes: scoreAttrs)

      // Best score label
      let bestText = "BEST: \(bestScore)"
      let bestFont = UIFont.systemFont(ofSize: 42, weight: .bold)
      let bestAttrs: [NSAttributedString.Key: Any] = [
        .font: bestFont,
        .foregroundColor: UIColor.white.withAlphaComponent(0.65),
        .kern: 2
      ]
      let bestSize = bestText.size(withAttributes: bestAttrs)
      let bestRect = CGRect(
        x: (width - bestSize.width) / 2,
        y: height * 0.58,
        width: bestSize.width,
        height: bestSize.height
      )
      bestText.draw(in: bestRect, withAttributes: bestAttrs)

      // Challenge code box
      let boxRect = CGRect(
        x: width * 0.1,
        y: height * 0.68,
        width: width * 0.8,
        height: 160
      )
      ctx.setFillColor(UIColor.white.withAlphaComponent(0.06).cgColor)
      ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
      ctx.setLineWidth(2)
      let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 24)
      boxPath.fill()
      boxPath.stroke()

      // Challenge code label
      let codeLabel = "CHALLENGE CODE"
      let codeLabelFont = UIFont.systemFont(ofSize: 32, weight: .bold)
      let codeLabelAttrs: [NSAttributedString.Key: Any] = [
        .font: codeLabelFont,
        .foregroundColor: UIColor.white.withAlphaComponent(0.55),
        .kern: 2
      ]
      let codeLabelSize = codeLabel.size(withAttributes: codeLabelAttrs)
      let codeLabelRect = CGRect(
        x: (width - codeLabelSize.width) / 2,
        y: boxRect.minY + 35,
        width: codeLabelSize.width,
        height: codeLabelSize.height
      )
      codeLabel.draw(in: codeLabelRect, withAttributes: codeLabelAttrs)

      // Challenge code text
      let codeFont = UIFont.monospacedSystemFont(ofSize: 48, weight: .heavy)
      let codeAttrs: [NSAttributedString.Key: Any] = [
        .font: codeFont,
        .foregroundColor: UIColor.white.withAlphaComponent(0.95),
        .kern: 3
      ]
      let codeSize = challengeCode.size(withAttributes: codeAttrs)
      let codeRect = CGRect(
        x: (width - codeSize.width) / 2,
        y: boxRect.minY + 85,
        width: codeSize.width,
        height: codeSize.height
      )
      challengeCode.draw(in: codeRect, withAttributes: codeAttrs)

      // CTA
      let ctaText = "Can you beat me?"
      let ctaFont = UIFont.systemFont(ofSize: 56, weight: .black)
      let ctaAttrs: [NSAttributedString.Key: Any] = [
        .font: ctaFont,
        .foregroundColor: UIColor.white.withAlphaComponent(0.90),
        .kern: 1
      ]
      let ctaSize = ctaText.size(withAttributes: ctaAttrs)
      let ctaRect = CGRect(
        x: (width - ctaSize.width) / 2,
        y: height * 0.88,
        width: ctaSize.width,
        height: ctaSize.height
      )
      ctaText.draw(in: ctaRect, withAttributes: ctaAttrs)
    }
  }

  private func drawRadialGradient(ctx: CGContext, center: CGPoint, color: UIColor, radius: CGFloat, in size: CGSize) {
    ctx.saveGState()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [color.cgColor, UIColor.clear.cgColor] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]

    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
      return
    }

    ctx.drawRadialGradient(
      gradient,
      startCenter: center,
      startRadius: 0,
      endCenter: center,
      endRadius: radius,
      options: []
    )

    ctx.restoreGState()
  }
}
