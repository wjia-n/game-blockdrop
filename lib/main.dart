import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const BlockDropApp());

class BlockDropApp extends StatelessWidget {
  const BlockDropApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Block Drop',
      tagline: 'Stack falling blocks and clear lines in the endless puzzler',
      emoji: '🟪',
      slug: 'blockdrop',
      howToPlay: '• Drag sideways to move, tap to rotate\n'
          '• Swipe down fast to slam a piece\n'
          '• Clear lines to score — every 10 lines it speeds up\n'
          '• Tap HOLD to stash a piece for later',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) =>
          BlockDropScreen(players: players, callbacks: cb),
    );
  }
}
