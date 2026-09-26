import 'dart:math' as math;
import 'dart:ui';

import '../theme/mock_palette.dart';
import '../theme/tokens.dart';

/// Flower drawn with shapes like the mockups (6 petals + centre).
void paintFlower(
  Canvas canvas,
  Offset c,
  double r,
  String flowerId, {
  double opacity = 1,
}) {
  final (petal, center) = MockPalette.petalsFor(flowerId);
  final fill = Paint()..color = petal.withValues(alpha: opacity);
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = AppColors.surfaceBorderStrong.withValues(alpha: opacity);
  final white = petal.toARGB32() == 0xFFFFFFFF;
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.6;
    canvas.drawCircle(p, r * 0.5, fill);
    if (white) canvas.drawCircle(p, r * 0.5, outline);
  }
  canvas.drawCircle(
    c,
    r * 0.35,
    Paint()..color = center.withValues(alpha: opacity),
  );
}

/// Baby's breath: a small cluster of white dots (mock.py).
void paintFillerCluster(Canvas canvas, Offset c, double r) {
  final fill = Paint()..color = AppColors.surfaceCard;
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = AppColors.surfaceBorder;
  for (var k = 0; k < 5; k++) {
    final a = k * 1.26;
    final p = c + Offset(math.cos(a), math.sin(a)) * r;
    canvas.drawCircle(p, r * 0.45, fill);
    canvas.drawCircle(p, r * 0.45, outline);
  }
}

Path starPath(Offset c, double r) {
  final path = Path();
  for (var k = 0; k < 10; k++) {
    final a = -math.pi / 2 + k * math.pi / 5;
    final rr = k.isEven ? r : r * 0.45;
    final p = c + Offset(math.cos(a), math.sin(a)) * rr;
    if (k == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/// Freshness bar colour (mock thresholds: > 0.66 fresh, > 0.33 aging).
Color freshnessColor(double f) {
  if (f > 0.66) return AppColors.freshnessFresh;
  if (f > 0.33) return AppColors.freshnessAging;
  return AppColors.freshnessWilting;
}

/// Patience colour: aging under 50% (spec_ban_bo_hoa), wilting under
/// economy `customers.patienceWarningAt`.
Color patienceColor(double f, double warningAt) {
  if (f < warningAt) return AppColors.freshnessWilting;
  if (f < 0.5) return AppColors.freshnessAging;
  return AppColors.freshnessFresh;
}

/// Avatar background by avatar id (soft tokens, as in the mockups).
Color avatarColor(int avatarId) => const [
  AppColors.primarySoft,
  AppColors.secondarySoft,
  AppColors.accentSoft,
][avatarId % 3];

/// Angry face (spec: "icon giận"; real icon not drawn yet).
void paintAngryFace(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(c, r, Paint()..color = AppColors.statusDanger);
  final ink = Paint()
    ..color = AppColors.textInverse
    ..strokeWidth = 1.6
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    c + Offset(-r * .55, -r * .45),
    c + Offset(-r * .15, -r * .25),
    ink,
  );
  canvas.drawLine(
    c + Offset(r * .55, -r * .45),
    c + Offset(r * .15, -r * .25),
    ink,
  );
  final mouth = Path()
    ..moveTo(c.dx - r * .4, c.dy + r * .45)
    ..quadraticBezierTo(c.dx, c.dy + r * .05, c.dx + r * .4, c.dy + r * .45);
  canvas.drawPath(mouth, ink);
}
