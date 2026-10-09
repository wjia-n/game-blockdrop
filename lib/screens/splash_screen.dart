import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/drop_art.dart';
import '../theme/drop_themes.dart';
import 'menu_screen.dart';

/// Single splash with two moments: first the WAJIHA company moment, then the
/// game splash (logo + name + animated loading line + "Credits: WAJIHA").
class SplashScreen extends StatefulWidget {
  final DropAudio audio;
  final DropSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _loader;
  late final AnimationController _companyFade;
  bool _showGame = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _companyFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    // Company moment: the WAJIHA logo alone on dark.
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _showGame = true);
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    _companyFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DropThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF120C08),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _showGame ? _gameSplash(theme) : _companyMoment(),
      ),
    );
  }

  /// Moment 1: the official WAJIHA company logo, unaltered, on near-black.
  Widget _companyMoment() {
    return FadeTransition(
      key: const ValueKey('company'),
      opacity: _companyFade,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/wajiha_logo.png',
              width: 130,
              height: 130,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 18),
            Text(
              'WAJIHA',
              style: Drop.display(34, theme: _wajihaTheme),
            ),
          ],
        ),
      ),
    );
  }

  static final DropThemeDef _wajihaTheme = DropThemes.byId('workshop');

  /// Moment 2: game logo + name + animated loading line + credits.
  Widget _gameSplash(DropThemeDef theme) {
    return DropBackdrop(
      key: const ValueKey('game'),
      theme: theme,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/blockdrop_logo.png',
                  fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('Block Drop', style: Drop.display(52, theme: theme)),
            const SizedBox(height: 6),
            Text(
              'THE FALLING-BLOCK ARCADE',
              style: Drop.label(13, theme: theme),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: _loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: theme.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _loader.value < 1
                          ? 'Stacking the blocks…'
                          : 'Ready!',
                      style: Drop.body(13,
                          theme: theme,
                          color: theme.text.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: Drop.label(14, theme: theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
