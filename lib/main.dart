import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/drop_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = DropSettings();
  await settings.load();
  final audio = DropAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(BlockDropApp(settings: settings, audio: audio));
}

class BlockDropApp extends StatefulWidget {
  final DropSettings settings;
  final DropAudio audio;
  const BlockDropApp({super.key, required this.settings, required this.audio});

  @override
  State<BlockDropApp> createState() => _BlockDropAppState();
}

class _BlockDropAppState extends State<BlockDropApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; the game screen additionally freezes its engine.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) {
        final theme = DropThemes.byId(
          widget.settings.themeId,
          custom: widget.settings.customTheme,
        );
        return MaterialApp(
          title: 'Block Drop',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: theme.pageBg,
            colorScheme: ColorScheme.fromSeed(
              seedColor: theme.accent,
              brightness: theme.pageBg.computeLuminance() > 0.5
                  ? Brightness.light
                  : Brightness.dark,
            ),
          ),
          home: SplashScreen(audio: widget.audio, settings: widget.settings),
        );
      },
    );
  }
}
