# Block Drop

The falling-block arcade puzzler by WAJIHA. Guide chunky physical toy blocks
into the well, clear lines, chase your personal best.

## Gameplay
- 10×20 well, all 7 classic tetrominoes, 7-bag randomizer
- Ghost piece, hold tray, 3-piece next preview
- Scoring: 100/300/500/800 × level, combo bonuses, soft/hard drop points
- Modes: **Chill** (gentle), **Classic** (arcade pace), **Turbo** (PRO, fast),
  **Blitz** (PRO, 2-minute score attack)
- 12 workshop-material themes, 8 block carving styles, custom theme creator
  (PRO), renameable player profile

## Architecture
- `lib/engine/blockdrop_engine.dart` — owns ALL game state and phases
  (idle → spawning → falling → locking → clearing → gameOver) plus a 2 s
  watchdog that recovers any phase found without a live timer. Stuck states
  are impossible by construction.
- `lib/services/audio_service.dart` — synthesized WAV clips, cached once,
  generation-serialized music, busy guard, lifecycle pause/resume.
- `lib/services/settings_service.dart` — profile persisted as ONE JSON
  string (never setStringList), themes/styles/modes, per-mode records, Pro.
- `lib/services/iap_service.dart` — real Play Billing: `blockdroppro`
  (one-time), `blockdropcoffee` / `blockdropchocolate` (consumable tips).
- `lib/theme/` — theme + block-style catalogs, physical toy-block painter.
- `lib/screens/` — splash, menu, game, settings, themes, pro, how-to.

Rules are authoritative in [RULES.md](RULES.md).

## Build
```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

## Store
- Package: `com.gameswajiha.blockdrop`
- Play listing: https://play.google.com/store/apps/details?id=com.gameswajiha.blockdrop
- IAP products (create in Play Console): `blockdroppro`, `blockdropcoffee`,
  `blockdropchocolate`
