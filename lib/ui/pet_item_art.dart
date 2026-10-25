import 'package:flutter/material.dart';

import '../data/pet_items.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'petdo_text.dart';

/// The dark green tile every item picture sits on.
const petItemTile = Color(0xFF2F5B3F);

/// The larger dark panel behind an item in a popup or shop card.
const petItemPanel = Color(0xFF244A33);

/// Colours of a tier: frame, fill and the glyph (the mocks' "hình tạm").
class PetItemPalette {
  const PetItemPalette(this.frame, this.fill, this.glyph, this.chipFill);

  final Color frame;
  final Color fill;
  final Color glyph;
  final Color chipFill;

  static PetItemPalette of(PetItemTier tier) => switch (tier) {
    PetItemTier.thuong => const PetItemPalette(
      Color(0xFFA8693A),
      Color(0xFFFBF3E6),
      Color(0xFF8A5A3C),
      Color(0xFFF4EBDD),
    ),
    PetItemTier.hiem => const PetItemPalette(
      Color(0xFF4F8FB5),
      Color(0xFFE8F3FA),
      Color(0xFF2E6C99),
      Color(0xFFE3F0F8),
    ),
    PetItemTier.suThi => const PetItemPalette(
      Color(0xFF8A6FC0),
      Color(0xFFF1ECFA),
      Color(0xFF6E4FB0),
      Color(0xFFEEE8F8),
    ),
    PetItemTier.huyenThoai => const PetItemPalette(
      Color(0xFFE0A030),
      Color(0xFFFFF6D8),
      Color(0xFFC98A2A),
      Color(0xFFFDEFC6),
    ),
  };
}

/// Temporary picture of an item (until the real sheet exists): a square
/// frame in the tier's colours with a glyph for the slot, drawn in code.
/// [count] >= 1 adds the `xN` badge at the bottom right. [locked] fades it
/// with a padlock (an item the player does not own yet).
class PetItemIcon extends StatelessWidget {
  const PetItemIcon({
    super.key,
    required this.slot,
    required this.tier,
    this.itemId,
    this.size = 44,
    this.count = 0,
    this.locked = false,
  });

  /// The item's id: its picture is `assets/images/pet_do/<id>.webp` (no frame
  /// in the file, the tier frame is drawn here). Without it, or while the file
  /// is missing, the glyph for the slot is drawn in code.
  final String? itemId;

  final String slot;
  final PetItemTier tier;
  final double size;
  final int count;
  final bool locked;

  /// The picture scaled into the frame (the real file may be smaller than the
  /// 512 standard), with the code-drawn glyph as the fallback.
  Widget _picture(Widget glyph) => Padding(
    padding: EdgeInsets.all(size * 0.05),
    child: LayoutBuilder(
      builder: (context, c) => Image.asset(
        Art.petDo(itemId!),
        width: c.maxWidth,
        height: c.maxHeight,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => glyph,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = PetItemPalette.of(tier);
    final legendary = tier == PetItemTier.huyenThoai;
    final glyph = CustomPaint(
      painter: _GlyphPainter(slot: slot, color: p.glyph),
      size: Size.infinite,
    );
    final frame = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: p.frame,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: legendary
            ? [
                BoxShadow(
                  color: p.frame.withValues(alpha: 0.45),
                  blurRadius: size * 0.22,
                ),
              ]
            : null,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The pictures carry a soft glow (necklace, crown, lantern, wings):
          // they sit on a dark green tile, never on a light one.
          color: itemId == null ? p.fill : petItemTile,
          borderRadius: BorderRadius.circular(size * 0.14),
        ),
        child: itemId == null ? glyph : _picture(glyph),
      ),
    );
    final badge = count >= 1
        ? Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                PetDo.copies(count),
                style: AppText.caption(
                  size: size >= 50 ? 12 : 10,
                  weight: 800,
                  color: Colors.white,
                ),
              ),
            ),
          )
        : null;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Opacity(opacity: locked ? 0.45 : 1, child: frame),
          ),
          if (locked)
            Positioned(
              right: 2,
              bottom: 2,
              child: Icon(
                Icons.lock,
                size: size * 0.3,
                color: AppColors.textSecondary,
              ),
            ),
          ?badge,
        ],
      ),
    );
  }
}

/// File of the empty-slot glyph (ssets/images/trong/).
String emptySlotFile(String slot) => switch (slot) {
  'neck' => 'slot_trong_co',
  'head' => 'slot_trong_dau',
  _ => 'slot_trong_phu_kien',
};

/// An empty slot in the room: dashed frame with a plus (P1).
class PetItemEmptyFrame extends StatelessWidget {
  const PetItemEmptyFrame({super.key, required this.slot, this.size = 44});

  final String slot;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DashedFramePainter(size * 0.2)),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: Padding(
                padding: EdgeInsets.all(size * 0.16),
                child: ArtImage(
                  Art.trong(emptySlotFile(slot)),
                  size: size * 0.68,
                  fallback: CustomPaint(
                    painter: _GlyphPainter(
                      slot: slot,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: const BoxDecoration(
                color: AppColors.primaryBase,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, size: size * 0.3, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedFramePainter extends CustomPainter {
  _DashedFramePainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    final paint = Paint()
      ..color = AppColors.surfaceBorderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rrect.deflate(1));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFramePainter old) => old.radius != radius;
}

/// Crown (head), necklace (neck), bow (accessory).
class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.slot, required this.color});

  final String slot;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;
    switch (slot) {
      case 'head':
        final p = Path()
          ..moveTo(w * 0.2, h * 0.68)
          ..lineTo(w * 0.15, h * 0.34)
          ..lineTo(w * 0.36, h * 0.5)
          ..lineTo(w * 0.5, h * 0.28)
          ..lineTo(w * 0.64, h * 0.5)
          ..lineTo(w * 0.85, h * 0.34)
          ..lineTo(w * 0.8, h * 0.68)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.2, h * 0.72, w * 0.6, h * 0.08),
            Radius.circular(w * 0.03),
          ),
          fill,
        );
      case 'neck':
        final p = Path()
          ..moveTo(w * 0.2, h * 0.3)
          ..quadraticBezierTo(w * 0.5, h * 0.82, w * 0.8, h * 0.3);
        canvas.drawPath(p, line);
        canvas.drawCircle(Offset(w * 0.5, h * 0.68), w * 0.08, fill);
      default:
        final p = Path()
          ..moveTo(w * 0.5, h * 0.5)
          ..lineTo(w * 0.18, h * 0.3)
          ..lineTo(w * 0.18, h * 0.7)
          ..close()
          ..moveTo(w * 0.5, h * 0.5)
          ..lineTo(w * 0.82, h * 0.3)
          ..lineTo(w * 0.82, h * 0.7)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.07, fill);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.slot != slot || old.color != color;
}

/// The chip with the tier name (Thường, Hiếm, ...).
class PetItemTierChip extends StatelessWidget {
  const PetItemTierChip({super.key, required this.tier, this.fontSize = 11});

  final PetItemTier tier;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final p = PetItemPalette.of(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: p.chipFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: p.frame, width: 1),
      ),
      child: Text(
        PetDo.tierName(tier),
        style: AppText.caption(size: fontSize, weight: 800, color: p.glyph),
      ),
    );
  }
}
