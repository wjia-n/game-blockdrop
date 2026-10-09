import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../theme/drop_themes.dart';

/// Engine phases for the falling-block state machine. The engine (never UI
/// timers) owns every phase and every transition; a watchdog recovers any
/// phase found without a live timer, so stuck states are impossible by
/// construction.
enum DropPhase { idle, spawning, falling, locking, clearing, gameOver }

/// Sound events the engine emits; the UI maps them to audio clips.
enum DropSound {
  move,
  rotate,
  invalid,
  lock,
  hardDrop,
  hold,
  clear1,
  clear2,
  clear3,
  tetris,
  levelUp,
  start,
}

const int dropCols = 10;
const int dropRows = 20;

const List<List<String>> _shapes = [
  ['....', 'XXXX', '....', '....'], // I
  ['XX', 'XX'], // O
  ['.X.', 'XXX', '...'], // T
  ['.XX', 'XX.', '...'], // S
  ['XX.', '.XX', '...'], // Z
  ['X..', 'XXX', '...'], // J
  ['..X', 'XXX', '...'], // L
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

/// 7-bag piece randomizer state lives here, owned by the engine.
class BlockDropEngine extends ChangeNotifier {
  final DropModeDef mode;
  final Random _rng;
  final void Function(DropSound) onSound;
  final void Function({required int score, required int lines, required bool timeUp}) onGameOver;

  static final _rots = List.generate(7, _rotationsOf);

  /// Rotation cells for a shape — also used by the UI painters.
  static List<Point<int>> cellsFor(int shape, int rot) =>
      _rots[shape.clamp(0, 6)][rot.clamp(0, 3)];

  // ---- board -----------------------------------------------------------
  final List<List<int>> grid =
      List.generate(dropRows, (_) => List.filled(dropCols, 0));

  // ---- active piece -----------------------------------------------------
  int shape = 0, rot = 0, px = 3, py = 0;
  final List<int> _bag = [];
  int nextShape = 0;
  final List<int> nextQueue = []; // 3-piece preview
  int? held;
  bool canHold = true;

  // ---- run stats ---------------------------------------------------------
  int score = 0, lines = 0, level = 1, combo = -1;
  int blitzLeft = 0; // seconds, blitz mode only
  bool timeUp = false;

  // ---- state machine ------------------------------------------------------
  DropPhase phase = DropPhase.idle;
  bool paused = false;
  bool over = false;
  Set<int> flashRows = {};
  int lockResets = 0;

  /// Transient toast message for the UI ("TETRIS!", "LEVEL 4!").
  final ValueNotifier<String?> toast = ValueNotifier(null);

  Timer? _gravity;
  Timer? _lockDelay;
  Timer? _flashTimer;
  Timer? _blitzTimer;
  Timer? _watchdog;
  DateTime? _lastGravityTick;
  bool _disposed = false;

  BlockDropEngine({
    required this.mode,
    required this.onSound,
    required this.onGameOver,
    Random? rng,
  }) : _rng = rng ?? Random();

  bool get playing => !over && !paused && phase != DropPhase.idle;

  int get intervalMs => mode.intervalForLevel(level);

  // ---------------------------------------------------------------- spawn
  int _draw() {
    if (_bag.isEmpty) {
      _bag.addAll(List.generate(7, (i) => i)..shuffle(_rng));
    }
    return _bag.removeLast();
  }

  void start() {
    if (_disposed) return;
    for (var y = 0; y < dropRows; y++) {
      grid[y].fillRange(0, dropCols, 0);
    }
    _bag.clear();
    nextQueue.clear();
    for (var i = 0; i < 3; i++) {
      nextQueue.add(_draw());
    }
    held = null;
    score = 0;
    lines = 0;
    level = 1;
    combo = -1;
    blitzLeft = mode.timeLimitSec ?? 0;
    timeUp = false;
    over = false;
    paused = false;
    flashRows = {};
    onSound(DropSound.start);
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _recover());
    if (mode.timeLimitSec != null) {
      _blitzTimer?.cancel();
      _blitzTimer = Timer.periodic(const Duration(seconds: 1), (_) => _blitzTick());
    }
    _spawn();
  }

  void _spawn() {
    if (_disposed || over) return;
    phase = DropPhase.spawning;
    shape = nextQueue.removeAt(0);
    nextQueue.add(_draw());
    nextShape = nextQueue.first;
    rot = 0;
    px = 3;
    py = -1; // spawn slightly above so I/T pieces enter cleanly
    canHold = true;
    lockResets = 0;
    if (_collides(_cells, px, py)) {
      _gameOver();
      return;
    }
    phase = DropPhase.falling;
    _restartGravity();
    notifyListeners();
  }

  // --------------------------------------------------------------- gravity
  void _restartGravity() {
    _gravity?.cancel();
    if (_disposed || over || paused) return;
    _lastGravityTick = DateTime.now();
    _gravity =
        Timer.periodic(Duration(milliseconds: intervalMs), (_) => _gravityTick());
  }

  /// Test hook: drive one gravity tick synchronously.
  @visibleForTesting
  void debugGravityTick() => _gravityTick();

  void _gravityTick() {
    if (_disposed || over || paused) return;
    if (phase != DropPhase.falling) return; // watchdog owns recovery
    _lastGravityTick = DateTime.now();
    if (_collides(_cells, px, py + 1)) {
      _beginLockDelay();
    } else {
      py++;
      notifyListeners();
    }
  }

  void _beginLockDelay() {
    if (phase == DropPhase.locking) return;
    phase = DropPhase.locking;
    _lockDelay?.cancel();
    _lockDelay = Timer(const Duration(milliseconds: 500), () {
      if (!_disposed && !over && !paused && phase == DropPhase.locking) {
        _lockPiece();
      }
    });
    notifyListeners();
  }

  // ----------------------------------------------------------------- input
  List<Point<int>> get _cells => _rots[shape][rot];

  bool _collides(List<Point<int>> cells, int x, int y) {
    for (final c in cells) {
      final cx = x + c.x, cy = y + c.y;
      if (cx < 0 || cx >= dropCols || cy >= dropRows) return true;
      if (cy >= 0 && grid[cy][cx] != 0) return true;
    }
    return false;
  }

  bool get _inputLive =>
      !_disposed && !over && !paused &&
      (phase == DropPhase.falling || phase == DropPhase.locking);

  /// A successful nudge during lock delay reverts to falling and resets the
  /// delay (capped, per guideline lock-delay rules).
  bool _nudgeSucceeded() {
    if (phase == DropPhase.locking) {
      if (lockResets >= 15) {
        _lockPiece();
        return false;
      }
      lockResets++;
      phase = DropPhase.falling;
      _lockDelay?.cancel();
    }
    return true;
  }

  void move(int dx) {
    if (!_inputLive) return;
    if (!_collides(_cells, px + dx, py)) {
      if (!_nudgeSucceeded()) return;
      px += dx;
      onSound(DropSound.move);
      notifyListeners();
    } else {
      onSound(DropSound.invalid);
    }
  }

  void rotate() {
    if (!_inputLive) return;
    final nr = (rot + 1) % 4;
    final cells = _rots[shape][nr];
    for (final dx in [0, -1, 1, -2, 2]) {
      if (!_collides(cells, px + dx, py)) {
        if (!_nudgeSucceeded()) return;
        rot = nr;
        px += dx;
        onSound(DropSound.rotate);
        notifyListeners();
        return;
      }
    }
    onSound(DropSound.invalid);
  }

  /// One manual soft-drop step. Returns true if the piece moved.
  bool softStep() {
    if (!_inputLive) return false;
    if (_collides(_cells, px, py + 1)) {
      _lockPiece();
      return false;
    }
    if (!_nudgeSucceeded()) return false;
    py++;
    score += 1;
    notifyListeners();
    return true;
  }

  void hardDrop() {
    if (!_inputLive) return;
    var dist = 0;
    while (!_collides(_cells, px, py + 1)) {
      py++;
      dist++;
    }
    score += dist * 2;
    onSound(DropSound.hardDrop);
    _lockDelay?.cancel();
    _lockPiece();
  }

  void hold() {
    if (!_inputLive || !canHold) {
      if (_inputLive) onSound(DropSound.invalid);
      return;
    }
    onSound(DropSound.hold);
    final cur = shape;
    if (held == null) {
      held = cur;
      shape = nextQueue.removeAt(0);
      nextQueue.add(_draw());
      nextShape = nextQueue.first;
    } else {
      shape = held!;
      held = cur;
    }
    rot = 0;
    px = 3;
    py = -1;
    canHold = false;
    lockResets = 0;
    if (_collides(_cells, px, py)) {
      _gameOver();
      return;
    }
    phase = DropPhase.falling;
    _lockDelay?.cancel();
    _restartGravity();
    notifyListeners();
  }

  int get ghostY {
    var y = py;
    while (!_collides(_cells, px, y + 1)) {
      y++;
    }
    return y;
  }

  // ------------------------------------------------------------------ lock
  void _lockPiece() {
    if (_disposed || over) return;
    _lockDelay?.cancel();
    var blockedOut = false;
    for (final c in _cells) {
      final cy = py + c.y, cx = px + c.x;
      if (cy < 0) {
        blockedOut = true; // piece locked above the visible field
      } else {
        grid[cy][cx] = shape + 1;
      }
    }
    onSound(DropSound.lock);
    if (blockedOut) {
      _gameOver();
      return;
    }
    final full = <int>[];
    for (var y = 0; y < dropRows; y++) {
      if (grid[y].every((v) => v != 0)) full.add(y);
    }
    if (full.isEmpty) {
      combo = -1;
      _spawn();
      return;
    }
    combo++;
    const pts = [0, 100, 300, 500, 800];
    var gained = pts[full.length] * level;
    if (combo > 0) gained += 50 * combo * level;
    score += gained;
    lines += full.length;
    phase = DropPhase.clearing;
    flashRows = full.toSet();
    if (full.length == 4) {
      onSound(DropSound.tetris);
      toast.value = 'TETRIS! +$gained';
    } else {
      onSound(switch (full.length) {
        1 => DropSound.clear1,
        2 => DropSound.clear2,
        _ => DropSound.clear3,
      });
      toast.value =
          '${['', 'SINGLE', 'DOUBLE', 'TRIPLE'][full.length]} +$gained${combo > 0 ? '  COMBO x$combo' : ''}';
    }
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 240), () {
      if (!_disposed && !over && !paused && phase == DropPhase.clearing) {
        _finishClear(full);
      }
    });
    notifyListeners();
  }

  void _finishClear(List<int> full) {
    if (_disposed || over) return;
    for (final y in full) {
      grid.removeAt(y);
      grid.insert(0, List.filled(dropCols, 0));
    }
    flashRows = {};
    final newLevel = lines ~/ mode.linesPerLevel + 1;
    if (newLevel != level) {
      level = newLevel;
      onSound(DropSound.levelUp);
      toast.value = 'LEVEL $level — FASTER!';
    }
    _spawn(); // _spawn restarts gravity at the new level's interval
  }

  // ----------------------------------------------------------------- blitz
  void _blitzTick() {
    if (_disposed || over || paused) return;
    if (mode.timeLimitSec == null) return;
    blitzLeft--;
    if (blitzLeft <= 0) {
      blitzLeft = 0;
      timeUp = true;
      _gameOver();
      return;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- game over
  void _gameOver() {
    if (over || _disposed) return;
    over = true;
    phase = DropPhase.gameOver;
    _gravity?.cancel();
    _lockDelay?.cancel();
    _flashTimer?.cancel();
    _blitzTimer?.cancel();
    notifyListeners();
    onGameOver(score: score, lines: lines, timeUp: timeUp);
  }

  // ----------------------------------------------------------- pause/resume
  void pause() {
    if (_disposed || over || paused || phase == DropPhase.idle) return;
    paused = true;
    _gravity?.cancel();
    _lockDelay?.cancel();
    _flashTimer?.cancel();
    _blitzTimer?.cancel();
    notifyListeners();
  }

  void resume() {
    if (_disposed || over || !paused) return;
    paused = false;
    // Re-arm timers per current phase; watchdog also covers us.
    switch (phase) {
      case DropPhase.falling:
        _restartGravity();
      case DropPhase.locking:
        _lockDelay?.cancel();
        _lockDelay = Timer(const Duration(milliseconds: 300), () {
          if (!_disposed && !over && !paused && phase == DropPhase.locking) {
            _lockPiece();
          }
        });
      case DropPhase.clearing:
        // Finish the clear immediately rather than leaving a dangling flash.
        final rows = flashRows.toList();
        if (rows.isNotEmpty) {
          _finishClear(rows);
        } else {
          _spawn();
        }
      case DropPhase.spawning:
        _spawn();
      case DropPhase.idle:
      case DropPhase.gameOver:
        break;
    }
    if (mode.timeLimitSec != null && !over) {
      _blitzTimer?.cancel();
      _blitzTimer =
          Timer.periodic(const Duration(seconds: 1), (_) => _blitzTick());
    }
    notifyListeners();
  }

  // --------------------------------------------------------------- watchdog
  /// Stuck-state recovery: if any live phase is found without its timer,
  /// repair it. Runs every 2s; never fights pause/game-over/idle.
  void _recover() {
    if (_disposed || over || paused) return;
    switch (phase) {
      case DropPhase.falling:
        final stale = _lastGravityTick == null ||
            DateTime.now().difference(_lastGravityTick!) >
                Duration(milliseconds: intervalMs * 2 + 500);
        if (_gravity == null || !_gravity!.isActive || stale) {
          _restartGravity();
        }
      case DropPhase.locking:
        if (_lockDelay == null || !_lockDelay!.isActive) {
          // Lock delay died without locking — lock now, never hang.
          _lockPiece();
        }
      case DropPhase.clearing:
        if (_flashTimer == null || !_flashTimer!.isActive) {
          final rows = flashRows.toList();
          if (rows.isNotEmpty) {
            _finishClear(rows);
          } else {
            _spawn();
          }
        }
      case DropPhase.spawning:
        _spawn();
      case DropPhase.idle:
      case DropPhase.gameOver:
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _gravity?.cancel();
    _lockDelay?.cancel();
    _flashTimer?.cancel();
    _blitzTimer?.cancel();
    _watchdog?.cancel();
    toast.dispose();
    super.dispose();
  }
}
