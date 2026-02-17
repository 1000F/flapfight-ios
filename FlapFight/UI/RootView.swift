import SwiftUI
import SpriteKit

enum GameMode {
  case classic
  case challenge(ChallengeCode)
}

struct RootView: View {
  @State private var mode: GameMode = .classic
  @State private var bestScore: Int = UserDefaults.standard.integer(forKey: "bestScore")
  @State private var lastScore: Int? = nil
  @State private var lastChallengeCode: String? = nil
  @State private var gameID = UUID()
  @State private var showChallengeInput = false
  @State private var challengeCodeInput = ""

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
          mode: mode,
          bestScore: bestScore,
          onGameOver: { score, seed, tapTimestamps in
            lastScore = score
            if score > bestScore {
              bestScore = score
              UserDefaults.standard.set(bestScore, forKey: "bestScore")
            }
            // Generate challenge code after classic run
            if case .classic = mode {
              let challengeCode = ChallengeCode(seed: seed, targetScore: score, tapTimestamps: tapTimestamps)
              lastChallengeCode = challengeCode.encode()
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
            showChallengeInput = true
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

        // Show last challenge code if available
        if let code = lastChallengeCode, let last = lastScore {
          VStack(spacing: 12) {
            VStack(spacing: 8) {
              Text("Challenge Code")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

              Text(code)
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.06))
                .overlay(
                  RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Share button
            ShareLink(
              item: generateShareImage(score: last, code: code),
              subject: Text("FlapFight Challenge"),
              message: Text("I scored \(last) in FlapFight! Can you beat me? Code: \(code)"),
              preview: SharePreview("FlapFight Challenge", image: generateShareImage(score: last, code: code))
            ) {
              HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                  .font(.system(size: 14, weight: .bold))
                Text("SHARE CHALLENGE")
                  .font(.system(size: 14, weight: .heavy, design: .rounded))
                  .tracking(1)
              }
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(
                LinearGradient(colors: [Color.purple, Color.blue], startPoint: .leading, endPoint: .trailing)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 14)
                  .stroke(.white.opacity(0.25), lineWidth: 1)
              )
              .clipShape(RoundedRectangle(cornerRadius: 14))
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 12)
        }
      }
    }
    .sheet(isPresented: $showChallengeInput) {
      ChallengeInputSheet(
        challengeCode: $challengeCodeInput,
        onSubmit: { code in
          if let decoded = ChallengeCode.decode(code: code) {
            mode = .challenge(decoded)
            gameID = UUID()
            showChallengeInput = false
            challengeCodeInput = ""
          }
        }
      )
    }
  }

  private func generateShareImage(score: Int, code: String) -> Image {
    let card = ShareCard(score: score, bestScore: bestScore, challengeCode: code)
    let uiImage = card.generateImage()
    return Image(uiImage: uiImage)
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

struct ChallengeInputSheet: View {
  @Binding var challengeCode: String
  @Environment(\.dismiss) private var dismiss
  let onSubmit: (String) -> Void

  var body: some View {
    ZStack {
      NeoBackground()
        .ignoresSafeArea()

      VStack(spacing: 24) {
        VStack(spacing: 8) {
          Text("ENTER CHALLENGE")
            .font(.system(size: 22, weight: .black, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(.white)

          Text("Paste a challenge code to compete")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.top, 32)

        TextField("", text: $challengeCode, prompt: Text("Challenge code").foregroundStyle(.white.opacity(0.35)))
          .font(.system(size: 16, weight: .heavy, design: .monospaced))
          .tracking(1)
          .foregroundStyle(.white)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
          .multilineTextAlignment(.center)
          .padding(.vertical, 16)
          .padding(.horizontal, 18)
          .background(.white.opacity(0.08))
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .stroke(.white.opacity(0.12), lineWidth: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 14))
          .padding(.horizontal, 24)

        Button {
          onSubmit(challengeCode)
        } label: {
          Text("START CHALLENGE")
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .tracking(1)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
              LinearGradient(colors: [Color.red, Color(red: 0.80, green: 0.10, blue: 0.08)], startPoint: .top, endPoint: .bottom)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 24)
        .disabled(challengeCode.isEmpty)
        .opacity(challengeCode.isEmpty ? 0.4 : 1.0)

        Button {
          dismiss()
        } label: {
          Text("Cancel")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.60))
        }
        .padding(.bottom, 32)

        Spacer()
      }
    }
  }
}
