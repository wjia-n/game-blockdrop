import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Block Drop — all sounds synthesized in code as WAV
/// bytes. No asset files. Warm, physical, toy-block sounds: wooden knocks,
/// clacks, chimes.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu
///   in/out, pause/resume, toggles) can never swallow a start or leave the
///   player half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class DropAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  // Cache synthesized clips so we only build them once.
  final Map<String, Uint8List> _cache = {};

  // Music state machine. [_musicGen] is bumped by every start/stop request;
  // async work checks it still owns the latest generation before touching
  // the player, so overlapping requests can never desync the music.
  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  DropAudio() {
    // Fire-and-forget is fine here: configure() runs before any play.
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.55 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _knock({double pitch = 170}) {
    // Wooden block knock: low thump + short click.
    final n = (_rate * 0.14).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.005) *
          (0.9 * sin(2 * pi * pitch * t) * exp(-t * 30) +
              0.5 * sin(2 * pi * pitch * 2 * t) * exp(-t * 55) +
              0.25 * (_rand.nextDouble() * 2 - 1) * exp(-t * 120));
    }
    return out;
  }

  List<double> _clack() {
    // Two blocks clacking together.
    final n = (_rate * 0.12).round();
    final out = List<double>.filled(n, 0);
    for (final start in [0, (_rate * 0.045).round()]) {
      final len = min((_rate * 0.06).round(), n - start);
      for (int i = 0; i < len; i++) {
        final t = i / _rate;
        out[start + i] += (sin(2 * pi * 420 * t) * exp(-t * 60) +
                0.6 * (_rand.nextDouble() * 2 - 1) * exp(-t * 150)) *
            0.6;
      }
    }
    return out;
  }

  List<double> _whoosh() {
    // Hard-drop slide: filtered noise sweep downward.
    final n = (_rate * 0.28).round();
    final out = List<double>.filled(n, 0);
    double last = 0;
    for (int i = 0; i < n; i++) {
      final t = i / n;
      final cutoff = 0.35 * (1 - t) + 0.05;
      last = last * (1 - cutoff) + (_rand.nextDouble() * 2 - 1) * cutoff;
      out[i] = last * 2.2 * sin(pi * t); // swell in/out
    }
    return out;
  }

  List<double> _thud() {
    // Invalid move: dull low thud.
    final n = (_rate * 0.18).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (sin(2 * pi * 95 * t) * exp(-t * 26) +
              0.3 * sin(2 * pi * 190 * t) * exp(-t * 40));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs,
      {double harmonics = 0.3}) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: harmonics));
      final gap = List<double>.filled((_rate * gapSecs).round(), 0);
      out.addAll(gap);
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0)); // slow swell in/out
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  List<double> _pluckLine(List<double> freqs, double noteSecs) {
    // Bright marimba-ish plucks.
    final out = <double>[];
    for (final f in freqs) {
      final tone = _tone(f, noteSecs, harmonics: 0.5, attack: 0.004);
      // Extra marimba body: boost the decay of the fundamental.
      for (int i = 0; i < tone.length; i++) {
        final t = i / _rate;
        tone[i] += 0.4 * sin(2 * pi * f * t) * exp(-t * 9) * (i / tone.length);
      }
      out.addAll(tone);
      out.addAll(List<double>.filled((_rate * 0.03).round(), 0));
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Cozy C – Am – F – G marimba line over a soft pad, 16s loop.
        final pad = _padChord([130.81, 196.0, 261.63], 16.0);
        final n = (_rate * 16).round();
        final out = List<double>.from(pad);
        final line = _pluckLine(
            [523.25, 587.33, 659.25, 523.25, 440.0, 523.25, 392.0, 440.0],
            0.42);
        for (int r = 0; r < 2; r++) {
          final start = (n * r / 2).round();
          for (int i = 0; i < line.length && start + i < n; i++) {
            out[start + i] += line[i] * 0.4;
          }
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Driving A-minor pentatonic groove with a walking bass, 12s loop.
        final bass = _pluckLine(
            [110.0, 110.0, 130.81, 110.0, 98.0, 110.0, 146.83, 130.81], 0.3);
        final n = (_rate * 12).round();
        final out = List<double>.filled(n, 0);
        final lead = _pluckLine(
            [440.0, 523.25, 587.33, 523.25, 659.25, 587.33, 523.25, 440.0],
            0.32);
        for (int k = 0; k < lead.length && k < n; k++) {
          out[k] += lead[k] * 0.42 + (k < bass.length ? bass[k] * 0.5 : 0);
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> move() => _play(_clip('move', () => _knock(pitch: 240)));
  Future<void> rotate() => _play(_clip('rotate', () => _clack()));
  Future<void> invalid() => _play(_clip('invalid', _thud));
  Future<void> lock() => _play(_clip('lock', () => _knock(pitch: 150)));
  Future<void> hardDrop() => _play(_clip('harddrop', _whoosh));
  Future<void> hold() => _play(_clip('hold', () => _tone(700, 0.12, freqEnd: 500)));
  Future<void> pause() => _play(_clip('pause', () => _tone(520, 0.14, freqEnd: 360)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(330, 0.35, freqEnd: 660)));
  Future<void> levelUp() => _play(_clip(
      'levelup', () => _arp([523.25, 659.25, 783.99], 0.12, 0.02)));
  Future<void> clear(int lines) => _play(_clip(
      'clear$lines',
      () => _arp(
          [523.25, 659.25, 783.99, 1046.5].sublist(0, lines.clamp(1, 4)),
          0.13,
          0.02)));
  Future<void> tetris() => _play(_clip('tetris',
      () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0], 0.14, 0.02)));
  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(
      _clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      // Already on this track — make sure it is actually audible.
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    // Wait for any in-flight op, then bail if superseded meanwhile.
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen; // cancel any in-flight start
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where we left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      // Resume failed (e.g. player was released) — restart the track.
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
