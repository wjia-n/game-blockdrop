import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/drop_art.dart';
import '../theme/drop_themes.dart';

/// Settings: sound & music toggles, volume, player name.
class SettingsScreen extends StatefulWidget {
  final DropAudio audio;
  final DropSettings settings;
  const SettingsScreen({super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DropThemeDef get _t => DropThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  late final TextEditingController _nameCtrl;
  late final FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.settings.playerName);
    _nameFocus = FocusNode();
    // Commit the name when the field loses focus (save happens on every
    // keystroke; this is the final commit).
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && mounted) _saveName(silent: true);
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final a = widget.audio;
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
              a.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Drop.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropPanel(
                    theme: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SOUND', style: Drop.label(12, theme: t)),
                        const SizedBox(height: 8),
                        _toggleRow(
                          t,
                          icon: Icons.music_note,
                          label: 'Music',
                          value: s.musicOn,
                          onChanged: (v) {
                            s.setMusic(v);
                            a.configure(
                                musicOn: v,
                                sfxOn: s.sfxOn,
                                volume: s.volume);
                            if (v) {
                              a.startMenuMusic();
                            } else {
                              a.stopMusic();
                            }
                          },
                        ),
                        _toggleRow(
                          t,
                          icon: Icons.volume_up,
                          label: 'Sound effects',
                          value: s.sfxOn,
                          onChanged: (v) {
                            s.setSfx(v);
                            a.configure(
                                musicOn: s.musicOn,
                                sfxOn: v,
                                volume: s.volume);
                            if (v) a.click();
                          },
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.tune,
                                color: t.accentLight, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Volume',
                                  style: Drop.heading(16, theme: t)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Slider(
                                value: s.volume,
                                activeColor: t.accent,
                                inactiveColor:
                                    t.muted.withValues(alpha: 0.35),
                                onChanged: (v) {
                                  s.setVolume(v);
                                  a.configure(
                                      musicOn: s.musicOn,
                                      sfxOn: s.sfxOn,
                                      volume: v);
                                },
                                onChangeEnd: (_) => a.click(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropPanel(
                    theme: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PROFILE', style: Drop.label(12, theme: t)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          maxLength: 16,
                          style: Drop.heading(17, theme: t),
                          decoration: InputDecoration(
                            counterText: '',
                            labelText: 'Player name',
                            labelStyle: Drop.muted(13, theme: t),
                            prefixIcon: Icon(Icons.person,
                                color: t.accentLight),
                            enabledBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: t.frame, width: 2),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: t.accent, width: 2),
                            ),
                          ),
                          // Save on EVERY keystroke into the order-safe
                          // single-JSON-string key (never setStringList).
                          onChanged: (v) =>
                              widget.settings.setPlayerName(v),
                          onSubmitted: (_) => _saveName(),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: DropButton(
                            label: 'SAVE NAME',
                            primary: false,
                            onTap: _saveName,
                            theme: t,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropPanel(
                    theme: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RECORDS', style: Drop.label(12, theme: t)),
                        const SizedBox(height: 8),
                        for (final m in DropThemes.modes)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(m.name,
                                      style: Drop.heading(15, theme: t)),
                                ),
                                Text(
                                  'Best ${(s.highScores[m.id] ?? 0)}'
                                  ' • ${(s.bestLines[m.id] ?? 0)} lines',
                                  style: Drop.muted(13, theme: t),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveName({bool silent = false}) {
    widget.audio.click();
    widget.settings.setPlayerName(_nameCtrl.text);
    FocusScope.of(context).unfocus();
    if (silent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Name saved!', style: Drop.body(14, theme: _t)),
        backgroundColor: _t.frameDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _toggleRow(
    DropThemeDef t, {
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: t.accentLight, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Drop.heading(16, theme: t))),
          Switch(
            value: value,
            activeThumbColor: t.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
