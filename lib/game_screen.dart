import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

const int _cols = 10;
const int _rows = 20;

const List<List<String>> _shapes = [
  ['....', 'XXXX', '....', '....'], // I
  ['XX', 'XX'], // O
  ['.X.', 'XXX', '...'], // T
  ['.XX', 'XX.', '...'], // S
  ['XX.', '.XX', '...'], // Z
  ['X..', 'XXX', '...'], // J
  ['..X', 'XXX', '...'], // L
];

const List<Color> _pieceColors = [
  Color(0xFF22D3EE),
  Color(0xFFFACC15),
  Color(0xFFC084FC),
  Color(0xFF4ADE80),
  Color(0xFFF87171),
  Color(0xFF60A5FA),
  Color(0xFFFB923C),
];

List<List<Point<int>>> _rotationsOf(int s) {
  final g = _shapes[s];
  final n = g.length;
  final base = <Point<int>>[];
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < g[y].length; x++) {
      if (g[y][x] == 'X') base.add(Point(x, y));
    }
  }
  final rots = <List<Point<int>>>[base];
  for (var r = 1; r < 4; r++) {
    rots.add(rots[r - 1].map((p) => Point(n - 1 - p.y, p.x)).toList());
  }
  return rots;
}

class BlockDropScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const BlockDropScreen(
      {super.key, required this.players, required this.callbacks});

  @override
  State<BlockDropScreen> createState() => _BlockDropScreenState();
}

class _BlockDropScreenState extends State<BlockDropScreen> {
  final _rng = Random();
  late List<List<int>> _grid;
  final List<int> _bag = [];
  late final List<List<List<Point<int>>>> _rots;
  int _shape = 0, _rot = 0, _px = 3, _py = 0;
  int _next = 0;
  int? _held;
  bool _canHold = true;
  int _score = 0, _lines = 0, _level = 1, _high = 0;
  bool _over = false;
  Set<int> _flash = {};
  Timer? _timer;
  double _accX = 0, _accY = 0;

  @override
  void initState() {
    super.initState();
    _rots = List.generate(7, _rotationsOf);
    _grid = List.generate(_rows, (_) => List.filled(_cols, 0));
    _next = _draw();
    _spawn();
    _restartTimer();
    _loadHigh();
  }

  Future<void> _loadHigh() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _high = p.getInt('blockdrop_high') ?? 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _draw() {
    if (_bag.isEmpty) {
      _bag.addAll(List.generate(7, (i) => i)..shuffle(_rng));
    }
    return _bag.removeLast();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
        Duration(milliseconds: max(90, 750 - (_level - 1) * 65)), _tick);
  }

  void _tick(Timer t) {
    if (!mounted || _over) return;
    if (ModalRoute.of(context)?.isCurrent != true) return; // paused
    if (_flash.isNotEmpty) return;
    _stepDown();
  }

  List<Point<int>> get _cells => _rots[_shape][_rot];

  bool _collides(List<Point<int>> cells, int x, int y) {
    for (final c in cells) {
      final cx = x + c.x, cy = y + c.y;
      if (cx < 0 || cx >= _cols || cy >= _rows) return true;
      if (cy >= 0 && _grid[cy][cx] != 0) return true;
    }
    return false;
  }

  void _spawn() {
    _shape = _next;
    _next = _draw();
    _rot = 0;
    _px = 3;
    _py = 0;
    _canHold = true;
    if (_collides(_cells, _px, _py)) _gameOver();
  }

  void _move(int dx) {
    if (_over || _flash.isNotEmpty) return;
    if (!_collides(_cells, _px + dx, _py)) {
      _px += dx;
      setState(() {});
    }
  }

  void _rotate() {
    if (_over || _flash.isNotEmpty) return;
    final nr = (_rot + 1) % 4;
    final cells = _rots[_shape][nr];
    for (final dx in [0, -1, 1, -2, 2]) {
      if (!_collides(cells, _px + dx, _py)) {
        _rot = nr;
        _px += dx;
        Sfx.tap();
        setState(() {});
        return;
      }
    }
  }

  void _stepDown({bool manual = false}) {
    if (_over || _flash.isNotEmpty) return;
    if (_collides(_cells, _px, _py + 1)) {
      _lock();
    } else {
      _py++;
      if (manual) _score += 1;
      setState(() {});
    }
  }

  void _hardDrop() {
    if (_over || _flash.isNotEmpty) return;
    var dist = 0;
    while (!_collides(_cells, _px, _py + 1)) {
      _py++;
      dist++;
    }
    _score += dist * 2;
    Sfx.move();
    _lock();
  }

  void _hold() {
    if (!_canHold || _over || _flash.isNotEmpty) return;
    Sfx.tap();
    final cur = _shape;
    if (_held == null) {
      _held = cur;
      _shape = _next;
      _next = _draw();
    } else {
      _shape = _held!;
      _held = cur;
    }
    _rot = 0;
    _px = 3;
    _py = 0;
    _canHold = false;
    if (_collides(_cells, _px, _py)) {
      _gameOver();
      return;
    }
    setState(() {});
  }

  Future<void> _lock() async {
    for (final c in _cells) {
      final cy = _py + c.y, cx = _px + c.x;
      if (cy >= 0) _grid[cy][cx] = _shape + 1;
    }
    final full = <int>[];
    for (var y = 0; y < _rows; y++) {
      if (_grid[y].every((v) => v != 0)) full.add(y);
    }
    if (full.isNotEmpty) {
      const pts = [0, 100, 300, 500, 800];
      _score += pts[full.length] * _level;
      _lines += full.length;
      final newLevel = _lines ~/ 10 + 1;
      _flash = full.toSet();
      if (full.length == 4) {
        Sfx.win();
      } else {
        Sfx.move();
      }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted || _over) return;
      for (final y in full) {
        _grid.removeAt(y);
        _grid.insert(0, List.filled(_cols, 0));
      }
      _flash = {};
      if (newLevel != _level) {
        _level = newLevel;
        _restartTimer();
      }
    } else {
      Sfx.click();
    }
    if (_over) return;
    _spawn();
    if (mounted) setState(() {});
  }

  Future<void> _gameOver() async {
    if (_over) return;
    _over = true;
    _timer?.cancel();
    Sfx.lose();
    final isBest = _score > _high;
    if (isBest) {
      _high = _score;
      final p = await SharedPreferences.getInstance();
      await p.setInt('blockdrop_high', _high);
    }
    widget.players.first.score = _score;
    widget.callbacks.refreshHud();
    widget.callbacks.finish(
      headline: 'You scored $_score!',
      subline: isBest ? '🏆 New best score!' : 'Best: $_high',
    );
  }

  int get _ghostY {
    var y = _py;
    while (!_collides(_cells, _px, y + 1)) {
      y++;
    }
    return y;
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return Column(
      children: [
        _hud(t),
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
        _controls(t),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _hud(GameTheme t) {
    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      color: t.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
              Text(value,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          stat('SCORE', '$_score'),
          stat('BEST', '$_high'),
          stat('LEVEL', '$_level'),
          stat('LINES', '$_lines'),
        ],
      ),
    );
  }

  Widget _board(GameTheme t) {
    return LayoutBuilder(builder: (ctx, c) {
      final w = min(c.maxWidth, c.maxHeight * 0.5);
      return Center(
        child: SizedBox(
          width: w,
          height: w * 2,
          child: GestureDetector(
            onTap: _rotate,
            onHorizontalDragUpdate: (d) {
              _accX += d.delta.dx;
              if (_accX.abs() > 22) {
                _move(_accX.sign.toInt());
                _accX = 0;
              }
            },
            onVerticalDragUpdate: (d) {
              if (d.delta.dy > 0) {
                _accY += d.delta.dy;
                if (_accY > 26) {
                  _stepDown(manual: true);
                  _accY = 0;
                }
              }
            },
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 700) _hardDrop();
              _accY = 0;
            },
            onHorizontalDragEnd: (_) => _accX = 0,
            child: CustomPaint(
              painter: _WellPainter(
                grid: _grid,
                cells: _cells,
                px: _px,
                py: _py,
                ghostY: _ghostY,
                shape: _shape,
                flash: _flash,
                bg: t.surface,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _sidePanel(GameTheme t) {
    return Column(
      children: [
        Text('NEXT',
            style: TextStyle(
                color: t.muted, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: t.surface, borderRadius: BorderRadius.circular(12)),
          child: CustomPaint(painter: _MiniPainter(_rots[_next][0], _next)),
        ),
        const SizedBox(height: 12),
        Text('HOLD',
            style: TextStyle(
                color: t.muted, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _hold,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _canHold ? t.primary : t.muted.withValues(alpha: 0.3),
                  width: 2),
            ),
            child: _held == null
                ? Center(
                    child: Text('H',
                        style: TextStyle(
                            color: t.muted, fontWeight: FontWeight.w800)))
                : CustomPaint(painter: _MiniPainter(_rots[_held!][0], _held!)),
          ),
        ),
      ],
    );
  }

  Widget _controls(GameTheme t) {
    Widget btn(String label, VoidCallback onTap, {bool big = false}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: big ? 64 : 56,
          height: 56,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.primary.withValues(alpha: 0.4)),
          ),
          child: Center(
              child: Text(label,
                  style: TextStyle(fontSize: 22, color: t.text))),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        btn('◀', () => _move(-1)),
        btn('▶', () => _move(1)),
        btn('⟳', _rotate),
        btn('⬇', _hardDrop, big: true),
      ],
    );
  }
}

class _WellPainter extends CustomPainter {
  final List<List<int>> grid;
  final List<Point<int>> cells;
  final int px, py, ghostY, shape;
  final Set<int> flash;
  final Color bg;

  _WellPainter({
    required this.grid,
    required this.cells,
    required this.px,
    required this.py,
    required this.ghostY,
    required this.shape,
    required this.flash,
    required this.bg,
  });

  void _cell(Canvas canvas, double x, double y, double cw, double ch,
      Color color) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(x * cw + 1, y * ch + 1, cw - 2, ch - 2),
      const Radius.circular(4),
    );
    canvas.drawRRect(r, Paint()..color = color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x * cw + 3, y * ch + 3, cw - 6, (ch - 6) / 2.4),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / _cols;
    final ch = size.height / _rows;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(12)),
      Paint()..color = bg,
    );
    // ghost
    for (final c in cells) {
      final gy = ghostY + c.y;
      if (gy >= 0) {
        _cell(canvas, (px + c.x).toDouble(), gy.toDouble(), cw, ch,
            _pieceColors[shape].withValues(alpha: 0.22));
      }
    }
    // locked blocks
    for (var y = 0; y < _rows; y++) {
      for (var x = 0; x < _cols; x++) {
        final v = grid[y][x];
        if (v != 0) {
          var col = _pieceColors[v - 1];
          if (flash.contains(y)) col = Colors.white;
          _cell(canvas, x.toDouble(), y.toDouble(), cw, ch, col);
        }
      }
    }
    // active piece
    for (final c in cells) {
      final cy = py + c.y;
      if (cy >= 0) {
        _cell(canvas, (px + c.x).toDouble(), cy.toDouble(), cw, ch,
            _pieceColors[shape]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WellPainter old) => true;
}

class _MiniPainter extends CustomPainter {
  final List<Point<int>> cells;
  final int colorIdx;
  _MiniPainter(this.cells, this.colorIdx);

  @override
  void paint(Canvas canvas, Size size) {
    var minX = 99, maxX = -99, minY = 99, maxY = -99;
    for (final c in cells) {
      minX = min(minX, c.x);
      maxX = max(maxX, c.x);
      minY = min(minY, c.y);
      maxY = max(maxY, c.y);
    }
    final w = maxX - minX + 1, h = maxY - minY + 1;
    final s = min(size.width / w, size.height / h) * 0.8;
    final ox = (size.width - s * w) / 2, oy = (size.height - s * h) / 2;
    for (final c in cells) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(ox + (c.x - minX) * s + 1, oy + (c.y - minY) * s + 1,
              s - 2, s - 2),
          const Radius.circular(3),
        ),
        Paint()..color = _pieceColors[colorIdx].withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniPainter old) => true;
}
