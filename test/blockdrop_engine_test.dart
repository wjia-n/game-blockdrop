import 'package:blockdrop/engine/blockdrop_engine.dart';
import 'package:blockdrop/services/settings_service.dart';
import 'package:blockdrop/theme/drop_themes.dart';
import 'package:flutter_test/flutter_test.dart';

BlockDropEngine makeEngine({
  void Function({required int score, required int lines, required bool timeUp})?
      onOver,
}) {
  return BlockDropEngine(
    mode: DropThemes.modeById(DropModes.classic),
    onSound: (_) {},
    onGameOver: onOver ??
        ({required int score, required int lines, required bool timeUp}) {},
  );
}

void main() {
  group('BlockDropEngine state machine', () {
    test('start() enters falling with a live piece', () {
      final e = makeEngine();
      e.start();
      expect(e.phase, DropPhase.falling);
      expect(e.over, isFalse);
      expect(e.nextQueue.length, 3);
      e.dispose();
    });

    test('move/rotate are refused after game over', () {
      var overCalled = false;
      final e = makeEngine(onOver: (
          {required int score,
          required int lines,
          required bool timeUp}) {
        overCalled = true;
      });
      e.start();
      // Fill the well, then hard-drop from above the field: every shape has
      // a cell at local y<=1, so cy<0 and the piece "blocks out".
      for (var y = 0; y < dropRows; y++) {
        for (var x = 0; x < dropCols; x++) {
          e.grid[y][x] = 1;
        }
      }
      e.py = -2;
      e.hardDrop();
      expect(overCalled, isTrue);
      expect(e.phase, DropPhase.gameOver);
      final px = e.px;
      e.move(1);
      e.rotate();
      expect(e.px, px); // no movement accepted
      e.dispose();
    });

    test('lock delay: floor contact locks after 15 nudge resets', () {
      final e = makeEngine();
      e.start();
      // Drive the piece to the floor with synchronous gravity ticks.
      var guard = 0;
      while (e.phase == DropPhase.falling && guard++ < 200) {
        e.debugGravityTick();
      }
      expect(e.phase, DropPhase.locking);
      // 15 successful nudges, each returning to falling and re-touching.
      for (var i = 0; i < 15; i++) {
        e.move(i.isEven ? 1 : -1);
        expect(e.phase, DropPhase.falling);
        expect(e.lockResets, i + 1);
        var g2 = 0;
        while (e.phase == DropPhase.falling && g2++ < 200) {
          e.debugGravityTick();
        }
        expect(e.phase, DropPhase.locking);
      }
      // The 16th nudge attempt locks the piece immediately and spawns the
      // next piece (whose own lock-delay budget starts at 0).
      e.move(1);
      expect(e.lockResets, 0);
      expect(e.phase, isNot(DropPhase.locking));
      e.dispose();
    });

    test('pause freezes and resume restores falling', () {
      final e = makeEngine();
      e.start();
      e.pause();
      expect(e.paused, isTrue);
      final py = e.py;
      e.resume();
      expect(e.paused, isFalse);
      expect(e.phase, DropPhase.falling);
      expect(e.py, py);
      e.dispose();
    });

    test('hard drop locks and spawns the next piece', () {
      final e = makeEngine();
      e.start();
      final first = e.shape;
      e.hardDrop();
      // After locking an empty well, a new piece spawns.
      expect(e.phase, isIn([DropPhase.falling, DropPhase.gameOver]));
      expect(e.shape == first || e.over, isTrue);
      e.dispose();
    });

    test('hold swaps once per piece', () {
      final e = makeEngine();
      e.start();
      final first = e.shape;
      e.hold();
      expect(e.held, first);
      expect(e.canHold, isFalse);
      final second = e.shape;
      e.hold(); // refused
      expect(e.shape, second);
      e.dispose();
    });

    test('line clear scores and collapses rows', () async {
      final e = makeEngine();
      e.start();
      // Fill bottom row except one cell, then drop a piece to fill it.
      for (var x = 0; x < dropCols - 1; x++) {
        e.grid[dropRows - 1][x] = 1;
      }
      // Force-spawn an I piece horizontally at the bottom.
      e.shape = 0;
      e.rot = 0;
      e.px = 6;
      e.py = dropRows - 2; // I cells sit at py+1
      e.hardDrop();
      expect(e.phase, DropPhase.clearing);
      expect(e.lines, 1);
      expect(e.score, greaterThan(0));
      e.dispose();
    });
  });

  group('profile name encoding (single JSON string)', () {
    test('JSON round-trip preserves exact names, never a StringList', () {
      const names = ['Wajiha', 'Player 2', 'Ångström ✓', ''];
      for (final n in names) {
        final raw = DropSettings.encodeProfile(n);
        expect(raw.startsWith('{'), isTrue); // one JSON string
        final back = DropSettings.decodeProfile(raw);
        expect(back, n.isEmpty ? DropSettings.defaultName : n);
      }
    });

    test('corrupt or missing data falls back to default', () {
      expect(DropSettings.decodeProfile(null), DropSettings.defaultName);
      expect(DropSettings.decodeProfile('not json{{{'),
          DropSettings.defaultName);
      expect(DropSettings.decodeProfile('{"name":"  "}'),
          DropSettings.defaultName);
    });
  });
}
