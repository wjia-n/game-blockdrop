import 'package:flutter/material.dart';
import 'drop_themes.dart';

/// Shared text styles + physical UI widgets for Block Drop.
/// Everything stays in the toy-workshop material world: chunky rounded
/// buttons with drop shadows, wood panels, flat readable text.
class Drop {
  static TextStyle display(double size, {required DropThemeDef theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: theme.text,
        letterSpacing: 1.2,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.45),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      );

  static TextStyle heading(double size, {required DropThemeDef theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: theme.text,
        letterSpacing: 0.6,
      );

  static TextStyle label(double size, {required DropThemeDef theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: theme.accentLight,
        letterSpacing: 1.6,
      );

  static TextStyle body(double size,
          {required DropThemeDef theme, Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? theme.text.withValues(alpha: 0.92),
        height: 1.45,
      );

  static TextStyle muted(double size, {required DropThemeDef theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: theme.muted,
        letterSpacing: 0.8,
      );
}

/// Warm workshop backdrop: flat page color with a soft vignette.
class DropBackdrop extends StatelessWidget {
  final DropThemeDef theme;
  final Widget child;
  const DropBackdrop({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.pageBg,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.4,
                  colors: [
                    theme.pageBg.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.38),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Chunky toy-like button: solid accent, dark edge, drop shadow, press squash.
class DropButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final DropThemeDef theme;
  final bool primary;
  final IconData? icon;
  const DropButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.theme,
    this.primary = true,
    this.icon,
  });

  @override
  State<DropButton> createState() => _DropButtonState();
}

class _DropButtonState extends State<DropButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: BoxDecoration(
            color: widget.primary
                ? t.accent
                : t.frame.withValues(alpha: enabled ? 1.0 : 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.4),
                width: _down ? 2 : 5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                offset: Offset(0, _down ? 2 : 6),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    color: widget.primary ? t.frameDark : t.text, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: widget.primary ? t.frameDark : t.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wood-framed panel card.
class DropPanel extends StatelessWidget {
  final DropThemeDef theme;
  final Widget child;
  final EdgeInsetsGeometry padding;
  const DropPanel({
    super.key,
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.frame.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.frame, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
/// Physical block cell painter with 8 render styles.
/// Every style reads like a real object: bevels, highlights, side shading.
class BlockCellPainter {
  static void paintCell(
    Canvas canvas,
    Rect rect,
    Color base,
    int style, {
    double alpha = 1.0,
  }) {
    final c = base.withValues(alpha: alpha);
    final dark = _shade(c, 0.55);
    final darker = _shade(c, 0.38);
    final light = _shade(c, 1.25);
    final lighter = _shade(c, 1.45);
    switch (style) {
      case 1:
        _roundedSoft(canvas, rect, c, dark, light);
      case 2:
        _flatMatte(canvas, rect, c, dark);
      case 3:
        _glossyDome(canvas, rect, c, dark, lighter);
      case 4:
        _chiseled(canvas, rect, c, dark, darker, light);
      case 5:
        _brushedMetal(canvas, rect, c, dark, lighter);
      case 6:
        _woodGrain(canvas, rect, c, dark, light);
      case 7:
        _candyShell(canvas, rect, c, dark, lighter);
      default:
        _classicBevel(canvas, rect, c, dark, light);
    }
  }

  static Color _shade(Color c, double f) {
    int ch(double v) => ((v * f).clamp(0.0, 1.0) * 255).round();
    return Color.fromARGB((c.a * 255).round(), ch(c.r), ch(c.g), ch(c.b));
  }

  static void _classicBevel(
      Canvas canvas, Rect r, Color c, Color dark, Color light) {
    final rr = RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(5));
    canvas.drawRRect(rr, Paint()..color = dark);
    final inner = RRect.fromRectAndRadius(
        r.deflate(3.5), const Radius.circular(4));
    canvas.drawRRect(inner, Paint()..color = c);
    // Top light catch.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left + 4, r.top + 4, r.width - 8, (r.height - 8) * 0.38),
        const Radius.circular(3),
      ),
      Paint()..color = light.withValues(alpha: 0.55),
    );
  }

  static void _roundedSoft(
      Canvas canvas, Rect r, Color c, Color dark, Color light) {
    final rr = RRect.fromRectAndRadius(r.deflate(1.5), const Radius.circular(9));
    canvas.drawRRect(rr, Paint()..color = dark.withValues(alpha: 0.7));
    final body = RRect.fromRectAndRadius(
        r.deflate(3), const Radius.circular(8));
    canvas.drawRRect(body, Paint()..color = c);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left + 5, r.top + 4.5, r.width - 10, (r.height - 9) * 0.4),
        const Radius.circular(5),
      ),
      Paint()..color = light.withValues(alpha: 0.4),
    );
  }

  static void _flatMatte(Canvas canvas, Rect r, Color c, Color dark) {
    final rr = RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(3));
    canvas.drawRRect(rr, Paint()..color = c);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = dark.withValues(alpha: 0.6),
    );
  }

  static void _glossyDome(
      Canvas canvas, Rect r, Color c, Color dark, Color lighter) {
    final rr = RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(8));
    canvas.drawRRect(rr, Paint()..color = dark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(2.5), const Radius.circular(7)),
      Paint()..color = c,
    );
    // Dome highlight.
    canvas.drawOval(
      Rect.fromLTWH(
          r.left + r.width * 0.2, r.top + r.height * 0.12,
          r.width * 0.6, r.height * 0.42),
      Paint()..color = lighter.withValues(alpha: 0.75),
    );
  }

  static void _chiseled(Canvas canvas, Rect r, Color c, Color dark,
      Color darker, Color light) {
    final pts = [
      Offset(r.left + 1, r.top + 1),
      Offset(r.right - 1, r.top + 1),
      Offset(r.right - 1, r.bottom - 1),
      Offset(r.left + 1, r.bottom - 1),
    ];
    canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = c);
    // Facet shading: dark right/bottom, light top/left.
    final cx = r.center.dx, cy = r.center.dy;
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy)
        ..lineTo(r.right - 1, r.top + 1)
        ..lineTo(r.right - 1, r.bottom - 1)
        ..close(),
      Paint()..color = darker.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy)
        ..lineTo(r.left + 1, r.bottom - 1)
        ..lineTo(r.right - 1, r.bottom - 1)
        ..close(),
      Paint()..color = dark.withValues(alpha: 0.45),
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy)
        ..lineTo(r.left + 1, r.top + 1)
        ..lineTo(r.right - 1, r.top + 1)
        ..close(),
      Paint()..color = light.withValues(alpha: 0.5),
    );
  }

  static void _brushedMetal(
      Canvas canvas, Rect r, Color c, Color dark, Color lighter) {
    final rr = RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(4));
    canvas.drawRRect(rr, Paint()..color = darkerOf(dark));
    // Horizontal grain bands.
    canvas.save();
    canvas.clipRRect(rr);
    for (var i = 0; i < 6; i++) {
      final y = r.top + 2 + i * (r.height - 4) / 6;
      canvas.drawRect(
        Rect.fromLTWH(r.left + 2, y, r.width - 4, (r.height - 4) / 12),
        Paint()..color = (i.isEven ? lighter : dark).withValues(alpha: 0.35),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(r.left + 2, r.top + 2, r.width - 4, r.height - 4),
      Paint()..color = c.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  static Color darkerOf(Color c) => _shade(c, 0.7);

  static void _woodGrain(
      Canvas canvas, Rect r, Color c, Color dark, Color light) {
    final rr = RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(5));
    canvas.drawRRect(rr, Paint()..color = c);
    canvas.save();
    canvas.clipRRect(rr);
    // Grain streaks.
    for (var i = 0; i < 3; i++) {
      final y = r.top + r.height * (0.25 + i * 0.25);
      final path = Path()
        ..moveTo(r.left + 3, y)
        ..quadraticBezierTo(
            r.center.dx, y + (i.isEven ? 2.5 : -2.5), r.right - 3, y);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = dark.withValues(alpha: 0.5),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left + 4, r.top + 3.5, r.width - 8, (r.height - 7) * 0.3),
        const Radius.circular(3),
      ),
      Paint()..color = light.withValues(alpha: 0.45),
    );
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = dark.withValues(alpha: 0.7),
    );
  }

  static void _candyShell(
      Canvas canvas, Rect r, Color c, Color dark, Color lighter) {
    final rr = RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(10));
    canvas.drawRRect(rr, Paint()..color = dark);
    final shell = RRect.fromRectAndRadius(
        r.deflate(3), const Radius.circular(8));
    canvas.drawRRect(shell, Paint()..color = lighter.withValues(alpha: 0.9));
    final core = RRect.fromRectAndRadius(
        r.deflate(6), const Radius.circular(6));
    canvas.drawRRect(core, Paint()..color = c);
    canvas.drawOval(
      Rect.fromLTWH(r.left + r.width * 0.22, r.top + r.height * 0.14,
          r.width * 0.34, r.height * 0.22),
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );
  }
}
