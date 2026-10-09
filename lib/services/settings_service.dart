import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/drop_themes.dart';

/// Persisted settings + profile + stats for Block Drop.
///
/// The player profile (display name) is stored as ONE JSON string.
/// NEVER use setStringList for ordered data — Android's SharedPreferences
/// stores StringLists as an unordered StringSet and scrambles the order.
class DropSettings extends ChangeNotifier {
  static const _kMusic = 'blockdrop_music_on';
  static const _kSfx = 'blockdrop_sfx_on';
  static const _kVolume = 'blockdrop_volume';
  static const _kTheme = 'blockdrop_theme_id';
  static const _kStyle = 'blockdrop_block_style';
  static const _kMode = 'blockdrop_mode_id';
  static const _kIsPro = 'blockdrop_is_pro';
  static const _kGames = 'blockdrop_games_played';
  static const _kCustomPrefix = 'blockdrop_custom_';

  /// Order-safe profile storage: a single JSON string like
  /// {"name":"Player"}. A plain-string legacy key ('blockdrop_profile_legacy')
  /// is migrated into this once, then removed.
  static const _kProfileJson = 'blockdrop_player_names_json';
  static const _kProfileLegacy = 'blockdrop_profile_legacy';

  static const String defaultName = 'Player';

  static String encodeProfile(String name) =>
      jsonEncode({'name': name.trim().isEmpty ? defaultName : name.trim()});

  static String decodeProfile(String? raw) {
    if (raw == null) return defaultName;
    try {
      final d = jsonDecode(raw);
      if (d is Map) {
        final n = d['name'];
        if (n is String && n.trim().isNotEmpty) return n.trim();
      } else if (d is String && d.trim().isNotEmpty) {
        return d.trim();
      }
    } catch (_) {}
    return defaultName;
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String playerName = defaultName;
  String themeId = 'workshop';
  int blockStyle = 0;
  String modeId = DropModes.classic;
  bool isPro = false;
  int gamesPlayed = 0;

  /// High score / best lines per mode id.
  final Map<String, int> highScores = {};
  final Map<String, int> bestLines = {};

  /// Custom theme colors (ARGB ints). Pro feature.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'pageBg': 0xFF2A1B12,
    'boardBg': 0xFF17100B,
    'frame': 0xFF5C3A21,
    'accent': 0xFFD9A441,
    'text': 0xFFF5EDE0,
    'pc0': 0xFFE0784F,
    'pc1': 0xFFD9A441,
    'pc2': 0xFF7FB069,
    'pc3': 0xFF5FA8A0,
    'pc4': 0xFFC25E5E,
    'pc5': 0xFF6E8FB2,
    'pc6': 0xFF9C7BB5,
  };

  DropThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return DropThemeDef(
      id: 'custom',
      name: 'My Creation',
      pageBg: c('pageBg'),
      boardBg: c('boardBg'),
      frame: c('frame'),
      frameDark: Color(customColors['frame'] ?? 0xFF5C3A21).withValues(alpha: 0.55),
      accent: c('accent'),
      accentLight: Color(customColors['accent'] ?? 0xFFD9A441).withValues(alpha: 0.75),
      text: c('text'),
      muted: Color(customColors['text'] ?? 0xFFF5EDE0).withValues(alpha: 0.6),
      pieceColors: [for (int i = 0; i < 7; i++) c('pc$i')],
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Profile: prefer the order-safe JSON key; migrate the legacy plain
    // string once, then drop it.
    final raw = p.getString(_kProfileJson);
    if (raw != null) {
      playerName = decodeProfile(raw);
    } else {
      playerName = (p.getString(_kProfileLegacy) ?? '').trim();
      if (playerName.isEmpty) playerName = defaultName;
    }
    themeId = p.getString(_kTheme) ?? 'workshop';
    blockStyle = (p.getInt(_kStyle) ?? 0).clamp(0, BlockStyles.all.length - 1);
    modeId = p.getString(_kMode) ?? DropModes.classic;
    isPro = p.getBool(_kIsPro) ?? false;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    for (final m in DropThemes.modes) {
      highScores[m.id] = p.getInt('blockdrop_high_${m.id}') ?? 0;
      bestLines[m.id] = p.getInt('blockdrop_lines_${m.id}') ?? 0;
    }
    // Migrate the ancient single high-score key into classic's slot.
    final ancient = p.getInt('blockdrop_high');
    if (ancient != null && (highScores[DropModes.classic] ?? 0) == 0) {
      highScores[DropModes.classic] = ancient;
    }
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kProfileJson, encodeProfile(playerName));
    await p.remove(_kProfileLegacy); // legacy key gone for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kStyle, blockStyle);
    await p.setString(_kMode, modeId);
    await p.setBool(_kIsPro, isPro);
    await p.setInt(_kGames, gamesPlayed);
    for (final m in DropThemes.modes) {
      await p.setInt('blockdrop_high_${m.id}', highScores[m.id] ?? 0);
      await p.setInt('blockdrop_lines_${m.id}', bestLines[m.id] ?? 0);
    }
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || DropThemes.isProTheme(themeId)) {
      themeId = 'workshop';
      changed = true;
    }
    if (BlockStyles.isPro(blockStyle)) {
      blockStyle = 0;
      changed = true;
    }
    final mode = DropThemes.modeById(modeId);
    if (!mode.free) {
      modeId = DropModes.classic;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? defaultName : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || DropThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setBlockStyle(int v) async {
    v = v.clamp(0, BlockStyles.all.length - 1);
    if (!isPro && BlockStyles.isPro(v)) return;
    blockStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(String id) async {
    final mode = DropThemes.modeById(id);
    if (!mode.free && !isPro) return;
    modeId = mode.id;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  /// Record a finished game. Returns true when a new high score was set.
  Future<bool> recordGame({
    required String mode,
    required int score,
    required int lines,
  }) async {
    gamesPlayed++;
    var newBest = false;
    if (score > (highScores[mode] ?? 0)) {
      highScores[mode] = score;
      newBest = true;
    }
    if (lines > (bestLines[mode] ?? 0)) bestLines[mode] = lines;
    notifyListeners();
    await _save();
    return newBest;
  }
}
