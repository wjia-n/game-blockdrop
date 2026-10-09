import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/drop_art.dart';
import '../theme/drop_themes.dart';
import 'game_screen.dart';
import 'howto_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'themes_screen.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.blockdrop';

/// Main menu: logo, profile, mode select, theme preview, and all actions.
class MenuScreen extends StatefulWidget {
  final DropAudio audio;
  final DropSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();

  DropSettings get _s => widget.settings;
  DropThemeDef get _t => DropThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Drop.body(15, theme: _t)),
        backgroundColor: _t.frameDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  /// Real in-app review flow: the Play in-app review sheet when available,
  /// otherwise fall back to opening the store listing. No fake dialogs.
  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _play() {
    widget.audio.gameStart();
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        audio: widget.audio,
        settings: _s,
      ),
    ))
        .then((_) {
      if (mounted) widget.audio.startMenuMusic();
    });
  }

  Future<void> _share() async {
    widget.audio.click();
    await Share.share(
      'Block Drop — the falling-block arcade puzzler! '
      'Stack, clear, and chase the high score. $_storeUrl',
    );
  }

  void _open(Widget page) {
    widget.audio.click();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return DropBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo plaque.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/blockdrop_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('Block Drop', style: Drop.display(46, theme: t)),
                  Text(
                    'STACK • CLEAR • SURVIVE',
                    style: Drop.label(13, theme: t),
                  ),
                  const SizedBox(height: 18),
                  _ProfileCard(
                    settings: _s,
                    audio: widget.audio,
                    theme: t,
                  ),
                  const SizedBox(height: 16),
                  _ModeCard(settings: _s, audio: widget.audio, theme: t),
                  const SizedBox(height: 22),
                  DropButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow,
                    onTap: _play,
                    theme: t,
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    alignment: WrapAlignment.center,
                    children: [
                      _MenuIcon(
                        icon: Icons.palette,
                        label: 'Themes',
                        theme: t,
                        onTap: () => _open(ThemesScreen(
                            audio: widget.audio, settings: _s)),
                      ),
                      _MenuIcon(
                        icon: Icons.settings,
                        label: 'Settings',
                        theme: t,
                        onTap: () => _open(SettingsScreen(
                            audio: widget.audio, settings: _s)),
                      ),
                      _MenuIcon(
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        theme: t,
                        onTap: () => _open(HowToScreen(theme: t)),
                      ),
                      _MenuIcon(
                        icon: _s.isPro ? Icons.star : Icons.star_border,
                        label: _s.isPro ? 'PRO ✓' : 'Go PRO',
                        theme: t,
                        onTap: () => _open(ProScreen(
                            audio: widget.audio,
                            settings: _s,
                            store: _store)),
                      ),
                      _MenuIcon(
                        icon: Icons.share,
                        label: 'Share',
                        theme: t,
                        onTap: _share,
                      ),
                      _MenuIcon(
                        icon: Icons.rate_review,
                        label: 'Rate Us',
                        theme: t,
                        onTap: _requestReview,
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Made with ♥ by WAJIHA',
                          style: Drop.muted(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 10),
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
class _MenuIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final DropThemeDef theme;
  final VoidCallback onTap;
  const _MenuIcon({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: theme.frame.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(18),
                border: Border(
                  bottom: BorderSide(
                      color: Colors.black.withValues(alpha: 0.45), width: 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, color: theme.accentLight, size: 28),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: Drop.muted(11, theme: theme)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Renameable player profile card.
class _ProfileCard extends StatefulWidget {
  final DropSettings settings;
  final DropAudio audio;
  final DropThemeDef theme;
  const _ProfileCard({
    required this.settings,
    required this.audio,
    required this.theme,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _editing = false;
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.settings.playerName);
    _focus = FocusNode();
    // Commit the name when the field loses focus (save happens on every
    // keystroke; this is the final commit).
    _focus.addListener(() {
      if (!_focus.hasFocus && mounted) _save();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final s = widget.settings;
    return DropPanel(
      theme: t,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person, color: t.frameDark, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    autofocus: true,
                    maxLength: 16,
                    style: Drop.heading(17, theme: t),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Your name',
                      hintStyle: Drop.muted(14, theme: t),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: t.accent),
                      ),
                    ),
                    // Save on EVERY keystroke (not just keyboard-done) into
                    // the order-safe single-JSON-string key.
                    onChanged: (v) => widget.settings.setPlayerName(v),
                    onSubmitted: (_) => _save(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.playerName,
                          style: Drop.heading(17, theme: t)),
                      Text('${s.gamesPlayed} games played',
                          style: Drop.muted(11, theme: t)),
                    ],
                  ),
          ),
          IconButton(
            icon: Icon(_editing ? Icons.check : Icons.edit,
                color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              if (_editing) {
                _save();
              } else {
                setState(() {
                  _ctrl.text = s.playerName;
                  _editing = true;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  void _save() {
    widget.settings.setPlayerName(_ctrl.text);
    setState(() => _editing = false);
  }
}

// ---------------------------------------------------------------------------
/// Mode select: difficulty tiers with clear progression + score attack.
class _ModeCard extends StatelessWidget {
  final DropSettings settings;
  final DropAudio audio;
  final DropThemeDef theme;
  const _ModeCard({
    required this.settings,
    required this.audio,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return DropPanel(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GAME MODE', style: Drop.label(12, theme: t)),
          const SizedBox(height: 10),
          for (final m in DropThemes.modes)
            _modeRow(context, m, t),
        ],
      ),
    );
  }

  Widget _modeRow(BuildContext context, DropModeDef m, DropThemeDef t) {
    final locked = !m.free && !settings.isPro;
    final selected = settings.modeId == m.id;
    final best = settings.highScores[m.id] ?? 0;
    return GestureDetector(
      onTap: () {
        if (locked) {
          audio.invalid();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Turbo & Blitz need PRO — tap Go PRO!',
                  style: Drop.body(14, theme: t)),
              backgroundColor: t.frameDark,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        audio.click();
        settings.setMode(m.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? t.accent : t.frame,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              m.id == DropModes.blitz
                  ? Icons.timer
                  : m.id == DropModes.turbo
                      ? Icons.bolt
                      : m.id == DropModes.chill
                          ? Icons.spa
                          : Icons.videogame_asset,
              color: selected ? t.accentLight : t.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(m.name, style: Drop.heading(16, theme: t)),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock, size: 14, color: t.muted),
                      ],
                    ],
                  ),
                  Text(m.tagline, style: Drop.muted(11, theme: t)),
                ],
              ),
            ),
            if (best > 0)
              Text('$best', style: Drop.heading(15, theme: t)),
          ],
        ),
      ),
    );
  }
}
