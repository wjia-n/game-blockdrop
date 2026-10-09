import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/drop_art.dart';
import '../theme/drop_themes.dart';
/// Themes + block styles + custom theme creator (Pro).
class ThemesScreen extends StatefulWidget {
  final DropAudio audio;
  final DropSettings settings;
  const ThemesScreen({super.key, required this.audio, required this.settings});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  DropThemeDef get _t => DropThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  void _lockedSnack(String what) {
    widget.audio.invalid();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what needs Block Drop PRO.',
            style: Drop.body(14, theme: _t)),
        backgroundColor: _t.frameDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
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
              Navigator.of(context).pop();
            },
          ),
          title: Text('Themes', style: Drop.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHead(t, 'WORKSHOP THEMES',
                      '${DropThemes.freeThemeIds.length} free • ${DropThemes.all.length - DropThemes.freeThemeIds.length} pro'),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.35,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: DropThemes.all.length + 1, // + custom
                    itemBuilder: (_, i) {
                      if (i == DropThemes.all.length) {
                        return _customTile(t, s);
                      }
                      final th = DropThemes.all[i];
                      return _themeTile(t, s, th);
                    },
                  ),
                  const SizedBox(height: 22),
                  _sectionHead(t, 'BLOCK STYLES',
                      '4 free • 4 pro — how each block is carved'),
                  const SizedBox(height: 10),
                  for (final st in BlockStyles.all) _styleRow(t, s, st),
                  const SizedBox(height: 22),
                  if (s.isPro) ...[
                    _sectionHead(t, 'MY CREATION',
                        'Your custom theme — PRO'),
                    const SizedBox(height: 10),
                    _customEditor(t, s),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHead(DropThemeDef t, String title, String sub) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Drop.label(12, theme: t))),
        Text(sub, style: Drop.muted(11, theme: t)),
      ],
    );
  }

  Widget _themeTile(DropThemeDef t, DropSettings s, DropThemeDef th) {
    final locked = !s.isPro && DropThemes.isProTheme(th.id);
    final selected = s.themeId == th.id;
    return GestureDetector(
      onTap: () {
        if (locked) {
          _lockedSnack('${th.name} theme');
          return;
        }
        widget.audio.click();
        s.setTheme(th.id);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: th.pageBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? t.accent : th.frame,
            width: selected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(th.name,
                      style: Drop.heading(14, theme: th)
                          .copyWith(fontSize: 14)),
                ),
                if (locked)
                  Icon(Icons.lock, size: 15, color: th.muted)
                else if (selected)
                  Icon(Icons.check_circle,
                      size: 17, color: th.accent),
              ],
            ),
            const Spacer(),
            Wrap(
              spacing: 5,
              children: [
                for (final c in th.pieceColors)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: Colors.black.withValues(alpha: 0.4)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _customTile(DropThemeDef t, DropSettings s) {
    final locked = !s.isPro;
    final selected = s.themeId == 'custom';
    final th = s.customTheme;
    return GestureDetector(
      onTap: () {
        if (locked) {
          _lockedSnack('The custom theme creator');
          return;
        }
        widget.audio.click();
        s.setTheme('custom');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: th.pageBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? t.accent : th.frame,
            width: selected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('My Creation',
                        style: Drop.heading(14, theme: th))),
                if (locked)
                  Icon(Icons.lock, size: 15, color: th.muted)
                else if (selected)
                  Icon(Icons.check_circle,
                      size: 17, color: th.accent),
              ],
            ),
            const Spacer(),
            Text('Paint your own blocks',
                style: Drop.muted(11, theme: th)),
          ],
        ),
      ),
    );
  }

  Widget _styleRow(
      DropThemeDef t, DropSettings s, BlockStyleDef st) {
    final locked = !s.isPro && BlockStyles.isPro(st.id);
    final selected = s.blockStyle == st.id;
    return GestureDetector(
      onTap: () {
        if (locked) {
          _lockedSnack('${st.name} style');
          return;
        }
        widget.audio.click();
        s.setBlockStyle(st.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? t.accent : t.frame,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                painter: _StylePreview(
                  style: st.id,
                  colors: t.pieceColors,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(st.name, style: Drop.heading(15, theme: t)),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock, size: 14, color: t.muted),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(st.desc, style: Drop.muted(12, theme: t)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: t.accentLight),
          ],
        ),
      ),
    );
  }

  Widget _customEditor(DropThemeDef t, DropSettings s) {
    const labels = {
      'pageBg': 'Backdrop',
      'boardBg': 'Playfield',
      'frame': 'Wood frame',
      'accent': 'Accent',
      'text': 'Text',
      'pc0': 'I piece',
      'pc1': 'O piece',
      'pc2': 'T piece',
      'pc3': 'S piece',
      'pc4': 'Z piece',
      'pc5': 'J piece',
      'pc6': 'L piece',
    };
    return DropPanel(
      theme: t,
      child: Column(
        children: [
          for (final e in labels.entries)
            _colorRow(t, s, e.key, e.value),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: DropButton(
              label: 'RESET COLORS',
              primary: false,
              onTap: () {
                widget.audio.click();
                s.resetCustomColors();
              },
              theme: t,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorRow(
      DropThemeDef t, DropSettings s, String key, String label) {
    final color = Color(s.customColors[key] ?? 0xFF000000);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Drop.heading(14, theme: t))),
          GestureDetector(
            onTap: () => _pickColor(t, s, key, label),
            child: Container(
              width: 44,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.accent, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor(
      DropThemeDef t, DropSettings s, String key, String label) async {
    widget.audio.click();
    const presets = [
      0xFFE0784F, 0xFFD9A441, 0xFF7FB069, 0xFF5FA8A0, 0xFFC25E5E, 0xFF6E8FB2,
      0xFF9C7BB5, 0xFFED8B5C, 0xFF8CB86F, 0xFFD36A5E, 0xFF7C9CC4, 0xFFAB8AC2,
      0xFF5C3A21, 0xFF3B2416, 0xFF17100B, 0xFF2A1B12, 0xFFF5EDE0, 0xFFEFE6D2,
      0xFF1B2130, 0xFF0E121C, 0xFF1E2E24, 0xFF101A14, 0xFFC9A227, 0xFFF3D48A,
    ];
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.frameDark,
        title: Text('Pick: $label', style: Drop.heading(17, theme: t)),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in presets)
                GestureDetector(
                  onTap: () {
                    s.setCustomColor(key, p);
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(p),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: t.accent.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                Text('Cancel', style: Drop.heading(14, theme: t)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// 2x2 preview of a block style.
class _StylePreview extends CustomPainter {
  final int style;
  final List<Color> colors;
  _StylePreview({required this.style, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 2;
    var i = 0;
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 2; x++) {
        BlockCellPainter.paintCell(
          canvas,
          Rect.fromLTWH(x * s, y * s, s, s),
          colors[i % colors.length],
          style,
        );
        i++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StylePreview old) => true;
}
