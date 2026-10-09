import 'package:flutter/material.dart';

/// Theme, block-style and game-mode catalogs for Block Drop.
///
/// Art direction: physical toy blocks on warm workshop materials — wood,
/// brass, felt, clay, marble. No neon, no cyberpunk, no glow. Variety comes
/// from different materials, wood finishes and block paint palettes.
class DropThemeDef {
  final String id;
  final String name;
  final Color pageBg; // screen backdrop
  final Color boardBg; // playfield well
  final Color frame; // well frame / panel wood
  final Color frameDark; // frame shadow edge
  final Color accent; // buttons, highlights
  final Color accentLight;
  final Color text;
  final Color muted;
  final List<Color> pieceColors; // 7 tetromino paint colors (I O T S Z J L)

  const DropThemeDef({
    required this.id,
    required this.name,
    required this.pageBg,
    required this.boardBg,
    required this.frame,
    required this.frameDark,
    required this.accent,
    required this.accentLight,
    required this.text,
    required this.muted,
    required this.pieceColors,
  });
}

/// Block render styles — how an individual cell is drawn by the painter.
class BlockStyleDef {
  final int id;
  final String name;
  final String desc;
  const BlockStyleDef(this.id, this.name, this.desc);
}

class BlockStyles {
  static const List<BlockStyleDef> all = [
    BlockStyleDef(0, 'Classic Bevel',
        'The original toy-block bevel with a top light catch.'),
    BlockStyleDef(1, 'Rounded Soft',
        'Plush rounded cubes with soft shadow edges.'),
    BlockStyleDef(2, 'Flat Matte',
        'Flat paint with a subtle inner lip. Calm and readable.'),
    BlockStyleDef(3, 'Glossy Dome',
        'Shiny domed candy-like blocks with a bright highlight.'),
    BlockStyleDef(4, 'Chiseled',
        'Faceted stone cuts with angular side shading.'),
    BlockStyleDef(5, 'Brushed Metal',
        'Cool brushed-metal sheen with a horizontal grain.'),
    BlockStyleDef(6, 'Wood Grain',
        'Turned wooden blocks with visible grain streaks.'),
    BlockStyleDef(7, 'Candy Shell',
        'Hard candy coating: glossy edge ring, creamy center.'),
  ];

  /// First 4 are FREE. Styles 4+ need PRO.
  static bool isPro(int id) => id >= 4;

  static String nameOf(int id) =>
      (id >= 0 && id < all.length) ? all[id].name : all[0].name;
}

class DropModes {
  /// A game mode: speed tier + progression + optional score-attack timer.
  static const chill = 'chill';
  static const classic = 'classic';
  static const turbo = 'turbo';
  static const blitz = 'blitz';
}

class DropModeDef {
  final String id;
  final String name;
  final String tagline;
  final int startIntervalMs; // gravity tick at level 1
  final int speedStepMs; // ms faster per level
  final int minIntervalMs; // fastest gravity tick
  final int linesPerLevel; // lines to clear per level
  final int? timeLimitSec; // null = endless
  final bool free; // false = PRO-only mode

  const DropModeDef({
    required this.id,
    required this.name,
    required this.tagline,
    required this.startIntervalMs,
    required this.speedStepMs,
    required this.minIntervalMs,
    required this.linesPerLevel,
    this.timeLimitSec,
    required this.free,
  });

  int intervalForLevel(int level) {
    final v = startIntervalMs - (level - 1) * speedStepMs;
    return v.clamp(minIntervalMs, startIntervalMs);
  }
}

class DropThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'workshop',
    'cherry',
    'ivory',
    'midnight',
  ];

  static const List<DropThemeDef> all = [
    DropThemeDef(
      id: 'workshop',
      name: 'Workshop Walnut',
      pageBg: Color(0xFF2A1B12),
      boardBg: Color(0xFF17100B),
      frame: Color(0xFF5C3A21),
      frameDark: Color(0xFF2E1D10),
      accent: Color(0xFFD9A441),
      accentLight: Color(0xFFF3D48A),
      text: Color(0xFFF5EDE0),
      muted: Color(0xFFB9A58C),
      pieceColors: [
        Color(0xFFE0784F), // I — terracotta
        Color(0xFFD9A441), // O — amber
        Color(0xFF7FB069), // T — sage
        Color(0xFF5FA8A0), // S — teal
        Color(0xFFC25E5E), // Z — brick
        Color(0xFF6E8FB2), // J — dusty blue
        Color(0xFF9C7BB5), // L — mauve
      ],
    ),
    DropThemeDef(
      id: 'cherry',
      name: 'Cherry Toybox',
      pageBg: Color(0xFF3A1E17),
      boardBg: Color(0xFF1D0E0A),
      frame: Color(0xFF7C3F24),
      frameDark: Color(0xFF3C1C10),
      accent: Color(0xFFE0B34C),
      accentLight: Color(0xFFF7DE9C),
      text: Color(0xFFF8F0E2),
      muted: Color(0xFFC4A487),
      pieceColors: [
        Color(0xFFED8B5C),
        Color(0xFFE3B04B),
        Color(0xFF8CB86F),
        Color(0xFF6FB5AC),
        Color(0xFFD36A5E),
        Color(0xFF7C9CC4),
        Color(0xFFAB8AC2),
      ],
    ),
    DropThemeDef(
      id: 'ivory',
      name: 'Ivory Morning',
      pageBg: Color(0xFFEFE6D2),
      boardBg: Color(0xFFE2D4B8),
      frame: Color(0xFF8A6F4D),
      frameDark: Color(0xFF5C4A33),
      accent: Color(0xFFB07A2A),
      accentLight: Color(0xFFE3B04B),
      text: Color(0xFF2E2118),
      muted: Color(0xFF7A6A54),
      pieceColors: [
        Color(0xFFD4693E),
        Color(0xFFC9962E),
        Color(0xFF6E9A52),
        Color(0xFF4E9189),
        Color(0xFFB04A3E),
        Color(0xFF54789C),
        Color(0xFF84649E),
      ],
    ),
    DropThemeDef(
      id: 'midnight',
      name: 'Midnight Oil',
      pageBg: Color(0xFF1B2130),
      boardBg: Color(0xFF0E121C),
      frame: Color(0xFF3A4358),
      frameDark: Color(0xFF1E2434),
      accent: Color(0xFFD9A441),
      accentLight: Color(0xFFF3D48A),
      text: Color(0xFFF0EBDD),
      muted: Color(0xFF9AA3B5),
      pieceColors: [
        Color(0xFFE07B4E),
        Color(0xFFDCAD4A),
        Color(0xFF82B36B),
        Color(0xFF63AC9E),
        Color(0xFFC9625B),
        Color(0xFF7498BC),
        Color(0xFFA181BC),
      ],
    ),
    // ------------------------------- PRO themes ---------------------------
    DropThemeDef(
      id: 'emerald',
      name: 'Emerald Felt',
      pageBg: Color(0xFF1E2E24),
      boardBg: Color(0xFF101A14),
      frame: Color(0xFF4A5A34),
      frameDark: Color(0xFF28331B),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      text: Color(0xFFF5EFE0),
      muted: Color(0xFFA8B39A),
      pieceColors: [
        Color(0xFFE0835A),
        Color(0xFFD9B04C),
        Color(0xFF8FBE6E),
        Color(0xFF66B39C),
        Color(0xFFC9655C),
        Color(0xFF769DC2),
        Color(0xFFA485C0),
      ],
    ),
    DropThemeDef(
      id: 'copper',
      name: 'Copper Forge',
      pageBg: Color(0xFF2E1E16),
      boardBg: Color(0xFF17100B),
      frame: Color(0xFF6B4A2E),
      frameDark: Color(0xFF3A2716),
      accent: Color(0xFFD98E4A),
      accentLight: Color(0xFFF2BC85),
      text: Color(0xFFF7EEE0),
      muted: Color(0xFFBFA184),
      pieceColors: [
        Color(0xFFE0895A),
        Color(0xFFDDAB4E),
        Color(0xFF8FB36D),
        Color(0xFF66B09E),
        Color(0xFFCB685C),
        Color(0xFF7A9DC0),
        Color(0xFFA789C2),
      ],
    ),
    DropThemeDef(
      id: 'ocean',
      name: 'Ocean Drift',
      pageBg: Color(0xFF1E2B33),
      boardBg: Color(0xFF0F161B),
      frame: Color(0xFF3E5A66),
      frameDark: Color(0xFF223239),
      accent: Color(0xFFE0B34C),
      accentLight: Color(0xFFF7DE9C),
      text: Color(0xFFF0EFE6),
      muted: Color(0xFF9DB3B8),
      pieceColors: [
        Color(0xFFDF8357),
        Color(0xFFDCAD4A),
        Color(0xFF86B46C),
        Color(0xFF5FAFA0),
        Color(0xFFC7675E),
        Color(0xFF6E97BC),
        Color(0xFF9E84BE),
      ],
    ),
    DropThemeDef(
      id: 'desert',
      name: 'Desert Clay',
      pageBg: Color(0xFF3B2A1C),
      boardBg: Color(0xFF1E140C),
      frame: Color(0xFF7A5A38),
      frameDark: Color(0xFF453222),
      accent: Color(0xFFD9A441),
      accentLight: Color(0xFFF3D48A),
      text: Color(0xFFF8F1E2),
      muted: Color(0xFFC2A680),
      pieceColors: [
        Color(0xFFD97B4A),
        Color(0xFFD2A23E),
        Color(0xFF7FA35E),
        Color(0xFF579F90),
        Color(0xFFBE5F52),
        Color(0xFF6B8FAE),
        Color(0xFF9678B2),
      ],
    ),
    DropThemeDef(
      id: 'sakura',
      name: 'Sakura Wood',
      pageBg: Color(0xFF33232A),
      boardBg: Color(0xFF1B1216),
      frame: Color(0xFF6E4552),
      frameDark: Color(0xFF40262E),
      accent: Color(0xFFDEB05C),
      accentLight: Color(0xFFF5DC9E),
      text: Color(0xFFF8EEE4),
      muted: Color(0xFFC2A49F),
      pieceColors: [
        Color(0xFFDD7F62),
        Color(0xFFD9A851),
        Color(0xFF86B06A),
        Color(0xFF64AD97),
        Color(0xFFC06066),
        Color(0xFF7599BE),
        Color(0xFFAE84B0),
      ],
    ),
    DropThemeDef(
      id: 'slate',
      name: 'Slate & Brass',
      pageBg: Color(0xFF262A30),
      boardBg: Color(0xFF131519),
      frame: Color(0xFF4E555E),
      frameDark: Color(0xFF2C3036),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      text: Color(0xFFF2EEE2),
      muted: Color(0xFFA6ADB6),
      pieceColors: [
        Color(0xFFE08355),
        Color(0xFFD9AC48),
        Color(0xFF84B26A),
        Color(0xFF62AD9B),
        Color(0xFFC6635B),
        Color(0xFF7399BE),
        Color(0xFFA082BD),
      ],
    ),
    DropThemeDef(
      id: 'forest',
      name: 'Forest Cabin',
      pageBg: Color(0xFF24301F),
      boardBg: Color(0xFF121A0F),
      frame: Color(0xFF55663C),
      frameDark: Color(0xFF323D22),
      accent: Color(0xFFD9A441),
      accentLight: Color(0xFFF3D48A),
      text: Color(0xFFF4F0E2),
      muted: Color(0xFFACB79A),
      pieceColors: [
        Color(0xFFE18158),
        Color(0xFFD8AD4C),
        Color(0xFF8DB96D),
        Color(0xFF64B199),
        Color(0xFFC7665C),
        Color(0xFF759CC0),
        Color(0xFFA284C0),
      ],
    ),
    DropThemeDef(
      id: 'plum',
      name: 'Royal Plum',
      pageBg: Color(0xFF2C2133),
      boardBg: Color(0xFF17121C),
      frame: Color(0xFF584A66),
      frameDark: Color(0xFF352A40),
      accent: Color(0xFFD9A441),
      accentLight: Color(0xFFF3D48A),
      text: Color(0xFFF5F0E6),
      muted: Color(0xFFB3A6BE),
      pieceColors: [
        Color(0xFFE0835E),
        Color(0xFFDBAE50),
        Color(0xFF87B36E),
        Color(0xFF63AE9C),
        Color(0xFFC86561),
        Color(0xFF759BC0),
        Color(0xFF9F83C2),
      ],
    ),
  ];

  static bool isProTheme(String id) => !freeThemeIds.contains(id);

  static DropThemeDef byId(String id, {DropThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static const List<DropModeDef> modes = [
    DropModeDef(
      id: DropModes.chill,
      name: 'Chill',
      tagline: 'Slow and gentle — learn the ropes.',
      startIntervalMs: 850,
      speedStepMs: 60,
      minIntervalMs: 150,
      linesPerLevel: 10,
      free: true,
    ),
    DropModeDef(
      id: DropModes.classic,
      name: 'Classic',
      tagline: 'The true arcade pace.',
      startIntervalMs: 700,
      speedStepMs: 70,
      minIntervalMs: 110,
      linesPerLevel: 10,
      free: true,
    ),
    DropModeDef(
      id: DropModes.turbo,
      name: 'Turbo',
      tagline: 'Fast drops, faster levels. PRO.',
      startIntervalMs: 500,
      speedStepMs: 80,
      minIntervalMs: 80,
      linesPerLevel: 8,
      free: false,
    ),
    DropModeDef(
      id: DropModes.blitz,
      name: 'Blitz',
      tagline: '2-minute score attack. PRO.',
      startIntervalMs: 430,
      speedStepMs: 45,
      minIntervalMs: 110,
      linesPerLevel: 12,
      timeLimitSec: 120,
      free: false,
    ),
  ];

  static DropModeDef modeById(String id) {
    for (final m in modes) {
      if (m.id == id) return m;
    }
    return modes[1];
  }
}
