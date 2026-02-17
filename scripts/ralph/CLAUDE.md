# Ralph Agent Instructions

You are an autonomous coding agent working on FlapFight, an iOS game built with SwiftUI + SpriteKit.

## Project Context

- **Stack**: Swift, SwiftUI, SpriteKit, iOS 17+, xcodegen
- **Entry point**: `FlapFight/App.swift` → `RootView.swift` → `GameContainerView.swift` → `GameScene.swift`
- **Game logic**: `FlapFight/Game/GameScene.swift` (SpriteKit scene with physics, pipes, scoring)
- **Effects**: `FlapFight/Game/GameFX.swift` (haptics + procedural audio via AVAudioEngine)
- **UI layer**: `FlapFight/UI/` (SwiftUI views)
- **PRD**: `docs/PRD.md`
- **Project config**: `project.yml` (xcodegen) — run `xcodegen generate` after adding new files

## Quality Checks

After implementing a story, run:
```bash
xcodebuild -project FlapFight.xcodeproj -scheme FlapFight -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build
```

If you add a new file, regenerate the Xcode project first:
```bash
xcodegen generate
```

## Codebase Patterns

- Game objects are all programmatic (no storyboards, no asset catalogs)
- Bird is an SKShapeNode(circleOfRadius: 14), pipes are SKShapeNode(rectOf:)
- Physics categories: bird (1<<0), pipe (1<<1), score (1<<2), ground (1<<3)
- Contact detection in `didBegin(_:)` uses bitmask pattern
- Callbacks from GameScene to SwiftUI via closures: `onGameOver`, `onRestartRequested`
- GameContainerView forwards SwiftUI taps to `scene.handleTap()`
- Pipe spawning uses `spawnPipePair()` — currently `CGFloat.random(in:)` for gap position
- Dark neo aesthetic: black backgrounds, white/red accents, translucent overlays
- Audio is procedural (AVAudioEngine + pre-rendered PCM buffers), no sound files
- Score persisted via UserDefaults in RootView

## Your Task

1. Read the PRD at `scripts/ralph/prd.json`
2. Read the progress log at `scripts/ralph/progress.txt` (check Codebase Patterns section first)
3. Check you're on the correct branch from PRD `branchName`. If not, create it from main.
4. Pick the **highest priority** user story where `passes: false`
5. Implement that single user story
6. Run quality checks (xcodebuild must succeed)
7. If checks pass, commit ALL changes with message: `feat: [Story ID] - [Story Title]`
8. Update the PRD to set `passes: true` for the completed story
9. Append your progress to `scripts/ralph/progress.txt`

## Progress Report Format

APPEND to scripts/ralph/progress.txt (never replace, always append):
```
## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered
  - Gotchas encountered
  - Useful context
---
```

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`.

If ALL stories are complete and passing, reply with:
<promise>COMPLETE</promise>

If there are still stories with `passes: false`, end your response normally (another iteration will pick up the next story).

## Important

- Work on ONE story per iteration
- Commit frequently
- Keep builds green
- Read the Codebase Patterns section in progress.txt before starting
- After adding new .swift files, run `xcodegen generate` before building
- Follow existing code style: minimal, no over-engineering, programmatic UI
