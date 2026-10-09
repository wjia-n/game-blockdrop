import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/drop_art.dart';
import '../theme/drop_themes.dart';

/// Block Drop PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final DropAudio audio;
  final DropSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  DropThemeDef get _t => DropThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — enjoy everything!',
              style: Drop.body(15, theme: _t)),
          backgroundColor: _t.frameDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Drop.body(15, theme: _t)),
        backgroundColor: _t.frameDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
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
          title: Text('Block Drop PRO', style: Drop.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                children: [
                  _ComparisonCard(theme: t, isPro: s.isPro),
                  const SizedBox(height: 16),
                  _BuyCard(
                    theme: t,
                    settings: s,
                    store: store,
                    audio: widget.audio,
                  ),
                  const SizedBox(height: 16),
                  _TipsCard(
                    theme: t,
                    store: store,
                    audio: widget.audio,
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
}

// ---------------------------------------------------------------------------
/// Free vs Pro comparison table — buyers see the big difference.
class _ComparisonCard extends StatelessWidget {
  final DropThemeDef theme;
  final bool isPro;
  const _ComparisonCard({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Complete Block Drop game', true, true),
      ('All 7 classic pieces', true, true),
      ('Chill & Classic modes', true, true),
      ('Hold piece + ghost piece', true, true),
      ('Renameable player profile', true, true),
      ('Music & sound effects', true, true),
      ('Workshop themes', '4', '12+'),
      ('Block carving styles', '4', '8'),
      ('Custom theme creator', false, true),
      ('Turbo mode (fast levels)', false, true),
      ('Blitz score attack (2 min)', false, true),
      ('New modes & styles first', false, true),
    ];
    Widget cell(dynamic v, {bool header = false}) {
      late final Widget child;
      if (v is bool) {
        child = Icon(
          v ? Icons.check_circle : Icons.remove_circle_outline,
          color: v ? theme.accentLight : theme.muted.withValues(alpha: 0.5),
          size: 20,
        );
      } else {
        child = Text('$v',
            style: Drop.heading(15, theme: theme)
                .copyWith(color: header ? theme.text : theme.accentLight));
      }
      return Expanded(child: Center(child: child));
    }

    return DropPanel(
      theme: theme,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                  child: Center(
                      child: Text('FREE',
                          style: Drop.label(12, theme: theme)))),
              Expanded(
                child: Center(
                  child: Text('PRO',
                      style: Drop.label(12, theme: theme).copyWith(
                          color: theme.accentLight)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (label, free, pro) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(label,
                        style: Drop.body(13, theme: theme)),
                  ),
                  cell(free),
                  cell(pro),
                ],
              ),
            ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: theme.accentLight, size: 18),
                  const SizedBox(width: 6),
                  Text('You are PRO — everything unlocked!',
                      style: Drop.heading(14, theme: theme)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _BuyCard extends StatelessWidget {
  final DropThemeDef theme;
  final DropSettings settings;
  final StoreService store;
  final DropAudio audio;
  const _BuyCard({
    required this.theme,
    required this.settings,
    required this.store,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (settings.isPro) {
      return DropPanel(
        theme: t,
        child: Row(
          children: [
            Icon(Icons.verified, color: t.accentLight, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'PRO is active on this device. Enjoy Turbo, Blitz, '
                'all 12+ themes, 8 block styles and the theme creator!',
                style: Drop.body(14, theme: t),
              ),
            ),
          ],
        ),
      );
    }
    final pro = store.proProduct;
    return DropPanel(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('UNLOCK PRO', style: Drop.label(13, theme: t)),
          const SizedBox(height: 8),
          Text(
            'One payment, yours forever. Turbo + Blitz modes, all themes '
            'and block styles, and the custom theme creator.',
            style: Drop.body(14, theme: t),
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(
              store.error ?? 'Store not ready yet.',
              style: Drop.muted(13, theme: t),
              textAlign: TextAlign.center,
            )
          else if (pro != null)
            DropButton(
              label: 'GET PRO — ${pro.price}',
              icon: Icons.star,
              onTap: () {
                audio.click();
                store.buyPro();
              },
              theme: t,
            ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String?>(
            valueListenable: store.purchaseError,
            builder: (_, err, _) => err == null
                ? const SizedBox.shrink()
                : Text(err,
                    style: Drop.body(13, theme: t)
                        .copyWith(color: const Color(0xFFE0784F)),
                    textAlign: TextAlign.center),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: store.purchaseInProgress,
            builder: (_, busy, _) => busy
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: t.accentLight)),
                  )
                : const SizedBox.shrink(),
          ),
          TextButton(
            onPressed: () {
              audio.click();
              store.restore();
            },
            child: Text('Restore purchases',
                style: Drop.muted(13, theme: t).copyWith(
                    decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _TipsCard extends StatelessWidget {
  final DropThemeDef theme;
  final StoreService store;
  final DropAudio audio;
  const _TipsCard({
    required this.theme,
    required this.store,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Widget tipBtn(ProductDetails? p, String label, IconData icon) {
      final ready = store.storeReady && p != null;
      return Expanded(
        child: GestureDetector(
          onTap: !ready
              ? null
              : () {
                  audio.click();
                  store.buyTip(p);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: t.frame.withValues(alpha: ready ? 0.85 : 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border(
                bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.45),
                    width: 4),
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: t.accentLight, size: 24),
                const SizedBox(height: 4),
                Text(label, style: Drop.heading(13, theme: t)),
                Text(ready ? p.price : '—',
                    style: Drop.muted(11, theme: t)),
              ],
            ),
          ),
        ),
      );
    }

    return DropPanel(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('TIP JAR', style: Drop.label(13, theme: t)),
          const SizedBox(height: 8),
          Text(
            'Block Drop is free forever. If it made you smile, '
            'a small tip keeps the blocks falling.',
            style: Drop.body(14, theme: t),
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(
              store.error ?? 'Store not ready yet.',
              style: Drop.muted(13, theme: t),
              textAlign: TextAlign.center,
            )
          else
            Row(
              children: [
                tipBtn(store.coffeeProduct, 'Coffee', Icons.coffee),
                const SizedBox(width: 12),
                tipBtn(store.chocolateProduct, 'Chocolate',
                    Icons.cake),
              ],
            ),
        ],
      ),
    );
  }
}
