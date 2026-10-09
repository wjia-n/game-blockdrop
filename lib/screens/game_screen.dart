import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/blockdrop_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/drop_art.dart';
import '../theme/drop_themes.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.blockdrop';

/// Active gameplay: well, next/hold trays, HUD, chunky controls, gestures,
/// pause and game-over overlays. The [BlockDropEngine] owns all state;
/// this widget only renders and forwards input.
class GameScreen extends StatefulWidget {
  final DropAudio audio;
  final DropSettings settings;
  const GameScreen({super.key, required this.audio, required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final BlockDropEngine _engine;
  bool _reviewAsked = false;
  Timer? _softDropTimer;
  double _accX = 0, _accY = 0;

  DropThemeDef get _t => DropThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = BlockDropEngine(
      mode: DropThemes.modeById(widget.settings.modeId),
      onSound: _onEngineSound,
      onGameOver: _onGameOver,
    );
    widget.audio.startGameMusic();
    // Start after first frame so the well is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _engine.start();
    });
  }

  void _onEngineSound(DropSound s) {
    final a = widget.audio;
    switch (s) {
      case DropSound.move:
        a.move();
      case DropSound.rotate:
        a.rotate();
      case DropSound.invalid:
        a.invalid();
      case DropSound.lock:
        a.lock();
      case DropSound.hardDrop:
        a.hardDrop();
      case DropSound.hold:
        a.hold();
      case DropSound.clear1:
        a.clear(1);
      case DropSound.clear2:
        a.clear(2);
      case DropSound.clear3:
        a.clear(3);
      case DropSound.tetris:
        a.tetris();
      case DropSound.levelUp:
        a.levelUp();
      case DropSound.start:
        a.gameStart();
    }
  }

  Future<void> _onGameOver(
      {required int score, required int lines, required bool timeUp}) async {
    final s = widget.settings;
    final newBest = await s.recordGame(
      mode: _engine.mode.id,
      score: score,
      lines: lines,
    );
    if (!mounted) return;
    if (newBest) {
      widget.audio.win();
    } else {
      widget.audio.lose();
    }
    // Sensible review moment: a new personal best, asked at most once
    // per session. Graceful when not installed from Play.
    if (newBest && !_reviewAsked) {
      _reviewAsked = true;
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) {}
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _softDropTimer?.cancel();
    _engine.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _engine.pause();
    }
  }

  void _togglePause() {
    widget.audio.click();
    if (_engine.paused) {
      _engine.resume();
    } else {
      widget.audio.pause();
      _engine.pause();
    }
  }

  void _restart() {
    widget.audio.gameStart();
    _engine.start();
  }

  Future<void> _shareScore() async {
    widget.audio.click();
    await Share.share(
      'I scored ${_engine.score} in Block Drop (${_engine.mode.name})! '
      'Can you beat me? $_storeUrl',
    );
  }

  String _fmtTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return DropBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              _engine.pause();
              Navigator.of(context).pop();
            },
          ),
          title: Text(_engine.mode.name.toUpperCase(),
              style: Drop.label(16, theme: t)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _engine.paused ? Icons.play_arrow : Icons.pause,
                color: t.accentLight,
              ),
              onPressed: _engine.over ? null : _togglePause,
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _engine,
            builder: (_, _) => Stack(
              children: [
                Column(
                  children: [
                    _hud(t),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _board(t)),
                          const SizedBox(width: 10),
                          _sidePanel(t),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _toastLine(t),
                    _controls(t),
                    const SizedBox(height: 10),
                  ],
                ),
                if (_engine.paused && !_engine.over) _pauseOverlay(t),
                if (_engine.over) _gameOverOverlay(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hud(DropThemeDef t) {
    Widget stat(String label, String value, {Color? valueColor}) => Expanded(
          child: Column(
            children: [
              Text(label, style: Drop.muted(10, theme: t)),
              const SizedBox(height: 2),
              Text(value,
                  style: Drop.heading(19, theme: t)
                      .copyWith(color: valueColor ?? t.text)),
            ],
          ),
        );
    final best = widget.settings.highScores[_engine.mode.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          stat('SCORE', '${_engine.score}'),
          stat('BEST', '$best'),
          stat('LEVEL', '${_engine.level}'),
          if (_engine.mode.timeLimitSec != null)
            stat('TIME', _fmtTime(_engine.blitzLeft),
                valueColor:
                    _engine.blitzLeft <= 10 ? const Color(0xFFE0784F) : null)
          else
            stat('LINES', '${_engine.lines}'),
        ],
      ),
    );
  }

  Widget _board(DropThemeDef t) {
    return LayoutBuilder(builder: (ctx, c) {
      final w = min(c.maxWidth, c.maxHeight * 0.5);
      return Center(
        child: Container(
          width: w,
          height: w * 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.frame, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                offset: const Offset(0, 8),
                blurRadius: 18,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onTap: () => _engine.rotate(),
            onHorizontalDragUpdate: (d) {
              _accX += d.delta.dx;
              if (_accX.abs() > 24) {
                _engine.move(_accX.sign.toInt());
                _accX = 0;
              }
            },
            onHorizontalDragEnd: (_) => _accX = 0,
            onVerticalDragUpdate: (d) {
              if (d.delta.dy > 0) {
                _accY += d.delta.dy;
                if (_accY > 26) {
                  _engine.softStep();
                  _accY = 0;
                }
              }
            },
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 750) _engine.hardDrop();
              _accY = 0;
            },
            child: CustomPaint(
              painter: _WellPainter(
                engine: _engine,
                theme: t,
                style: widget.settings.blockStyle,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _sidePanel(DropThemeDef t) {
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Text('NEXT', style: Drop.muted(10, theme: t)),
          const SizedBox(height: 4),
          Container(
            height: 150,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: t.boardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.frame, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final s in _engine.nextQueue)
                  SizedBox(
                    height: 42,
                    child: CustomPaint(
                      painter: _MiniPainter(
                        shape: s,
                        theme: t,
                        style: widget.settings.blockStyle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('HOLD', style: Drop.muted(10, theme: t)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _engine.hold,
            child: Container(
              width: 84,
              height: 56,
              decoration: BoxDecoration(
                color: t.boardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _engine.canHold
                      ? t.accent
                      : t.muted.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: _engine.held == null
                  ? Center(
                      child: Text('H',
                          style: Drop.heading(20, theme: t)
                              .copyWith(color: t.muted)))
                  : CustomPaint(
                      painter: _MiniPainter(
                        shape: _engine.held!,
                        theme: t,
                        style: widget.settings.blockStyle,
                      ),
                    ),
            ),
          ),
          const Spacer(),
          if (_engine.mode.timeLimitSec != null)
            Text('LINES\n${_engine.lines}',
                textAlign: TextAlign.center,
                style: Drop.muted(11, theme: t)),
        ],
      ),
    );
  }

  Widget _toastLine(DropThemeDef t) {
    return SizedBox(
      height: 26,
      child: ValueListenableBuilder<String?>(
        valueListenable: _engine.toast,
        builder: (_, msg, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: msg == null
              ? const SizedBox.shrink()
              : Text(
                  msg,
                  key: ValueKey(msg),
                  style: Drop.heading(17, theme: t)
                      .copyWith(color: t.accentLight),
                ),
        ),
      ),
    );
  }

  Widget _controls(DropThemeDef t) {
    Widget btn(IconData icon, VoidCallback onTap, {bool big = false}) {
      return GestureDetector(
        onTap: onTap,
        onLongPressStart: icon == Icons.keyboard_arrow_down
            ? (_) {
                _softDropTimer?.cancel();
                _softDropTimer = Timer.periodic(
                    const Duration(milliseconds: 45),
                    (_) => _engine.softStep());
              }
            : null,
        onLongPressEnd: icon == Icons.keyboard_arrow_down
            ? (_) => _softDropTimer?.cancel()
            : null,
        child: Container(
          width: big ? 72 : 60,
          height: 60,
          decoration: BoxDecoration(
            color: t.frame.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              bottom: BorderSide(
                  color: Colors.black.withValues(alpha: 0.45), width: 4),
            ),
          ),
          child: Icon(icon, color: t.accentLight, size: big ? 34 : 28),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        btn(Icons.keyboard_arrow_left, () => _engine.move(-1)),
        btn(Icons.keyboard_arrow_right, () => _engine.move(1)),
        btn(Icons.rotate_right, _engine.rotate),
        btn(Icons.keyboard_arrow_down, () => _engine.softStep()),
        btn(Icons.vertical_align_bottom, _engine.hardDrop, big: true),
      ],
    );
  }

  Widget _pauseOverlay(DropThemeDef t) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: DropPanel(
            theme: t,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Paused', style: Drop.display(34, theme: t)),
                const SizedBox(height: 8),
                Text('Take a breath. The blocks wait.',
                    style: Drop.body(14, theme: t)),
                const SizedBox(height: 20),
                DropButton(
                  label: 'RESUME',
                  icon: Icons.play_arrow,
                  onTap: _togglePause,
                  theme: t,
                ),
                const SizedBox(height: 12),
                DropButton(
                  label: 'RESTART',
                  icon: Icons.refresh,
                  primary: false,
                  onTap: _restart,
                  theme: t,
                ),
                const SizedBox(height: 12),
                DropButton(
                  label: 'QUIT',
                  icon: Icons.home,
                  primary: false,
                  onTap: () {
                    widget.audio.click();
                    Navigator.of(context).pop();
                  },
                  theme: t,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameOverOverlay(DropThemeDef t) {
    final s = widget.settings;
    final best = s.highScores[_engine.mode.id] ?? 0;
    final isBest = _engine.score >= best && _engine.score > 0;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        child: Center(
          child: SingleChildScrollView(
            child: DropPanel(
              theme: t,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _engine.timeUp ? "Time's Up!" : 'Game Over',
                    style: Drop.display(34, theme: t),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.playerName} scored ${_engine.score}',
                    style: Drop.heading(17, theme: t),
                    textAlign: TextAlign.center,
                  ),
                  if (isBest)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('🏆 New personal best!',
                          style: Drop.label(14, theme: t)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Best: $best',
                          style: Drop.muted(14, theme: t)),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Level ${_engine.level} • ${_engine.lines} lines',
                    style: Drop.body(14, theme: t),
                  ),
                  const SizedBox(height: 20),
                  DropButton(
                    label: 'PLAY AGAIN',
                    icon: Icons.refresh,
                    onTap: _restart,
                    theme: t,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropButton(
                        label: 'SHARE',
                        icon: Icons.share,
                        primary: false,
                        onTap: _shareScore,
                        theme: t,
                      ),
                      const SizedBox(width: 12),
                      DropButton(
                        label: 'MENU',
                        icon: Icons.home,
                        primary: false,
                        onTap: () {
                          widget.audio.click();
                          Navigator.of(context).pop();
                        },
                        theme: t,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _WellPainter extends CustomPainter {
  final BlockDropEngine engine;
  final DropThemeDef theme;
  final int style;

  _WellPainter({
    required this.engine,
    required this.theme,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / dropCols;
    final ch = size.height / dropRows;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = theme.boardBg,
    );
    // Subtle column guides.
    final guide = Paint()
      ..color = theme.text.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var x = 1; x < dropCols; x++) {
      canvas.drawLine(
          Offset(x * cw, 0), Offset(x * cw, size.height), guide);
    }

    void cell(int x, int y, Color color, {double alpha = 1.0}) {
      BlockCellPainter.paintCell(
        canvas,
        Rect.fromLTWH(x * cw, y * ch, cw, ch),
        color,
        style,
        alpha: alpha,
      );
    }

    // Ghost piece.
    if (!engine.over) {
      final gy = engine.ghostY;
      final cells = BlockDropEngine.cellsFor(engine.shape, engine.rot);
      for (final c in cells) {
        final gx = engine.px + c.x, yy = gy + c.y;
        if (yy >= 0 && yy < dropRows) {
          cell(gx, yy, theme.pieceColors[engine.shape], alpha: 0.22);
        }
      }
    }
    // Locked blocks.
    for (var y = 0; y < dropRows; y++) {
      for (var x = 0; x < dropCols; x++) {
        final v = engine.grid[y][x];
        if (v != 0) {
          var col = theme.pieceColors[v - 1];
          if (engine.flashRows.contains(y)) col = Colors.white;
          cell(x, y, col);
        }
      }
    }
    // Active piece.
    if (!engine.over && engine.phase != DropPhase.idle) {
      final cells = BlockDropEngine.cellsFor(engine.shape, engine.rot);
      for (final c in cells) {
        final cx = engine.px + c.x, cy = engine.py + c.y;
        if (cy >= 0 && cy < dropRows) {
          cell(cx, cy, theme.pieceColors[engine.shape]);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WellPainter old) => true;
}

class _MiniPainter extends CustomPainter {
  final int shape;
  final DropThemeDef theme;
  final int style;
  _MiniPainter(
      {required this.shape, required this.theme, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final cells = BlockDropEngine.cellsFor(shape, 0);
    var minX = 99, maxX = -99, minY = 99, maxY = -99;
    for (final c in cells) {
      minX = min(minX, c.x);
      maxX = max(maxX, c.x);
      minY = min(minY, c.y);
      maxY = max(maxY, c.y);
    }
    final w = maxX - minX + 1, h = maxY - minY + 1;
    final s = min(size.width / w, size.height / h) * 0.85;
    final ox = (size.width - s * w) / 2, oy = (size.height - s * h) / 2;
    for (final c in cells) {
      BlockCellPainter.paintCell(
        canvas,
        Rect.fromLTWH(ox + (c.x - minX) * s + 1, oy + (c.y - minY) * s + 1,
            s - 2, s - 2),
        theme.pieceColors[shape],
        style,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniPainter old) => true;
}
