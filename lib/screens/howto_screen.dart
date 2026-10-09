import 'package:flutter/material.dart';
import '../theme/drop_art.dart';
import '../theme/drop_themes.dart';

/// How to play — the player-facing summary of RULES.md.
class HowToScreen extends StatelessWidget {
  final DropThemeDef theme;
  const HowToScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return DropBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('How to Play', style: Drop.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(t, 'GOAL',
                    'Guide the falling blocks into the well. Fill complete horizontal rows to clear them and score. The game ends when the stack reaches the top.'),
                _section(t, 'CONTROLS',
                    '• ◀ ▶ — slide the piece left / right\n'
                    '• ⟳ — rotate the piece\n'
                    '• ⬇ (tap) — soft drop one row (+1 point)\n'
                    '• ⬇ (hold) — keep dropping fast\n'
                    '• ⤓ — hard drop: slam it down (+2 per row)\n'
                    '• Drag on the board: slide to move, tap to rotate, swipe down to drop, fast swipe to slam.'),
                _section(t, 'HOLD',
                    'Tap HOLD (or the hold tray) to stash the current piece and swap it with the stored one. One hold per piece — use it wisely!'),
                _section(t, 'SCORING',
                    '• Single: 100 × level\n'
                    '• Double: 300 × level\n'
                    '• Triple: 500 × level\n'
                    '• TETRIS (4 lines): 800 × level\n'
                    '• Back-to-back clears build a COMBO bonus: +50 × combo × level.'),
                _section(t, 'LEVELS',
                    'Clear 10 lines to level up. Every level drops the pieces faster. Chill starts gentle; Turbo starts fast and ramps quicker.'),
                _section(t, 'MODES',
                    '• Chill — slow and gentle, learn the ropes\n'
                    '• Classic — the true arcade pace\n'
                    '• Turbo (PRO) — fast drops, faster levels\n'
                    '• Blitz (PRO) — 2-minute score attack: most points wins'),
                _section(t, 'TIPS',
                    '• Keep the stack flat — holes are trouble.\n'
                    '• Save the long I-piece for a Tetris.\n'
                    '• Watch the NEXT tray and plan two pieces ahead.\n'
                    '• The pale outline shows where your piece will land.'),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(DropThemeDef t, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropPanel(
        theme: t,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Drop.label(12, theme: t)),
            const SizedBox(height: 6),
            Text(body, style: Drop.body(14, theme: t)),
          ],
        ),
      ),
    );
  }
}
