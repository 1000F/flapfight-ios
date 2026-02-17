# FlapFight — PRD (v0.1)

**Tagline:** Brutal/neo one-tap flyer with async duels.

## Summary
FlapFight is a Flappy-inspired iOS game where the core loop is ~10 seconds, and every run turns into a shareable challenge. The game is designed to be *played in private* and *shared in public*.

## Goals
- Ship a fun, responsive, "one more run" game.
- Bake in virality: async challenges, ghost races, and share cards.

## Success metrics (TestFlight)
- D1 retention: 35%+
- D7 retention: 12%+
- Share rate: 20% of sessions
- Challenge conversion: 30% of received challenges result in a run

## Audience
- iOS players who like quick skill games
- Group-chat competitors
- TikTok/IG share behavior (Phase 2 clip export)

## Core loop (MVP)
- Tap to flap, gravity down.
- Pipes scroll right → left.
- Score increments per pipe passed.
- Death on collision/out-of-bounds.
- Instant restart.

## Brutal/neo direction
- Dark UI, sharp typography, high-contrast accents.
- Near-miss = micro slow-mo + chromatic flash + haptic tick.
- Sound palette: tight clicks, deep thumps, minimal synth stabs.

## Viral features
### 1) Challenge codes (no backend)
- After a run, generate a shareable **Challenge Code** = seed + score target.
- Receiver plays the same seed and tries to beat the score.

### 2) Ghost duel
- Record tap timestamps.
- In challenge mode, show ghost bird.

### 3) Share card (MVP)
- Generate an image card: score, best, code, CTA.

## Modes
- Classic
- Challenge (code)

## Milestones
- M1: playable core (tap/flap + pipes + scoring + restart)
- M2: deterministic seed + code
- M3: ghost duel
- M4: share card polish
