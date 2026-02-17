import SwiftUI
import SpriteKit

enum GameMode {
  case classic
}

struct RootView: View {
  @State private var mode: GameMode = .classic
  @State private var bestScore: Int = UserDefaults.standard.integer(forKey: "bestScore")
  @State private var lastScore: Int? = nil
  @State private var gameID = UUID()

  var body: some View {
    ZStack {
      NeoBackground()
        .ignoresSafeArea()

      VStack(spacing: 16) {
        VStack(spacing: 6) {
          Text("FLAPFIGHT")
            .font(.system(size: 34, weight: .black, design: .rounded))
            .tracking(2)
            .foregroundStyle(.white)

          Text("brutal/neo tap-to-fly")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.70))
        }
        .padding(.top, 18)

        ScoreBar(best: bestScore, last: lastScore)

        GameContainerView(
          id: gameID,
          onGameOver: { score in
            lastScore = score
            if score > bestScore {
              bestScore = score
              UserDefaults.standard.set(bestScore, forKey: "bestScore")
            }
          },
          onRestartRequested: {
            gameID = UUID()
          }
        )
        .frame(maxWidth: .infinity)
        .frame(height: 520)
        .padding(.horizontal, 16)

        HStack(spacing: 12) {
          Button {
            gameID = UUID()
          } label: {
            Text("RESTART")
              .font(.system(size: 14, weight: .heavy, design: .rounded))
              .tracking(1)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(.white.opacity(0.08))
              .overlay(
                RoundedRectangle(cornerRadius: 14)
                  .stroke(.white.opacity(0.12), lineWidth: 1)
              )
              .clipShape(RoundedRectangle(cornerRadius: 14))
          }

          Button {
            // Placeholder for share challenge
          } label: {
            Text("CHALLENGE")
              .font(.system(size: 14, weight: .heavy, design: .rounded))
              .tracking(1)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(
                LinearGradient(colors: [Color.red, Color(red: 0.80, green: 0.10, blue: 0.08)], startPoint: .top, endPoint: .bottom)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 14)
                  .stroke(Color.red.opacity(0.5), lineWidth: 1)
              )
              .clipShape(RoundedRectangle(cornerRadius: 14))
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
      }
    }
  }
}

struct ScoreBar: View {
  let best: Int
  let last: Int?

  var body: some View {
    HStack {
      Label("BEST \(best)", systemImage: "crown.fill")
        .symbolRenderingMode(.hierarchical)

      Spacer()

      if let last {
        Text("LAST \(last)")
      } else {
        Text("LAST —")
      }
    }
    .font(.system(size: 12, weight: .bold, design: .rounded))
    .foregroundStyle(.white.opacity(0.80))
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.black.opacity(0.20))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(.white.opacity(0.10), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .padding(.horizontal, 16)
  }
}

struct NeoBackground: View {
  var body: some View {
    ZStack {
      Color(red: 0.03, green: 0.04, blue: 0.06)

      RadialGradient(colors: [Color.red.opacity(0.22), .clear], center: .topLeading, startRadius: 10, endRadius: 520)
      RadialGradient(colors: [Color.green.opacity(0.16), .clear], center: .topTrailing, startRadius: 10, endRadius: 520)

      LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
    }
  }
}
