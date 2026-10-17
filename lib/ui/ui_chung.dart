import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../audio/sounds.dart' show SoundScope;

/// Phú's G1–G3 shared art (`assets/images/ui_chung/`, `vong_quay/`):
/// 9-slice buttons, frames and bars. Each piece knows its pixel size and
/// centre slice (LTRB, tuned on the real images); [UiSlice] draws it at a
/// scale that makes the art's height match the box.
class UiPiece {
  const UiPiece(this.file, this.w, this.h, this.slice);

  final String file;
  final double w;
  final double h;

  /// Centre slice in image pixels (null: not stretched, drawn contained).
  final Rect? slice;

  String get path => 'assets/images/ui_chung/$file.webp';

  /// Non-stretched width / height at [scale] (the box can't be smaller).
  double minW(double scale) => slice == null ? 0 : (w - slice!.width) / scale;
  double minH(double scale) => slice == null ? 0 : (h - slice!.height) / scale;
}

/// The pieces with Phú's 9-slice estimates, checked against the art
/// (17/10): every centre stays inside the plain fill, clear of flowers.
abstract final class UiChung {
  static const nutXanh = UiPiece(
    'nut_xanh',
    482,
    175,
    Rect.fromLTRB(120, 60, 362, 115),
  );
  static const nutVang = UiPiece(
    'nut_vang',
    479,
    175,
    Rect.fromLTRB(120, 60, 359, 115),
  );
  static const nutCam = UiPiece(
    'nut_cam',
    478,
    175,
    Rect.fromLTRB(120, 60, 358, 115),
  );
  static const nutTrangNho = UiPiece(
    'nut_trang_nho',
    374,
    135,
    Rect.fromLTRB(110, 45, 324, 90),
  );
  static const theThongTin = UiPiece(
    'the_thong_tin',
    573,
    246,
    Rect.fromLTRB(150, 100, 453, 146),
  );
  static const oDemThe = UiPiece(
    'o_dem_the',
    323,
    154,
    Rect.fromLTRB(110, 50, 203, 104),
  );
  static const khungPopup = UiPiece(
    'khung_popup',
    669,
    410,
    Rect.fromLTRB(140, 140, 529, 335),
  );
  static const thanhTienDo = UiPiece(
    'thanh_tien_do',
    510,
    137,
    Rect.fromLTRB(105, 50, 455, 87),
  );
  static const nutTronLa = UiPiece('nut_tron_la', 218, 220, null);
  static const nutVipVang = UiPiece(
    'nut_vip_vang',
    622,
    214,
    Rect.fromLTRB(240, 110, 500, 164),
  );
  static const nutVipXanh = UiPiece(
    'nut_vip_xanh',
    609,
    214,
    Rect.fromLTRB(240, 110, 487, 164),
  );
  static const trangGiay = UiPiece(
    'trang_giay',
    599,
    706,
    Rect.fromLTRB(200, 185, 419, 511),
  );
  static const khungTronRuyBang = UiPiece(
    'khung_tron_ruy_bang',
    638,
    507,
    null,
  );

  /// Vòng quay background: the pot's own when Phú drew one, else the
  /// shared one (BoxFit.cover).
  static const _wheelBgByPot = {'chau_cuu_vi_ho': 'nen_cuu_vy_ho'};

  /// Decoration-free insets in image px: the flower/leaf clusters and the
  /// frame border measured on the art (17/10). Content padding is these
  /// divided by the draw scale, plus a few dp.
  static const safe = {
    'the_thong_tin': EdgeInsets.fromLTRB(152, 48, 135, 40),
    'o_dem_the': EdgeInsets.fromLTRB(105, 25, 125, 25),
    'khung_popup': EdgeInsets.fromLTRB(65, 200, 65, 110),
    'trang_giay': EdgeInsets.fromLTRB(210, 195, 199, 226),
    'nut_vip_vang': EdgeInsets.fromLTRB(240, 0, 92, 0),
    'nut_vip_xanh': EdgeInsets.fromLTRB(240, 0, 90, 0),
  };

  /// [safe] (or the slice insets) of [p] in dp at [scale], plus [extra].
  static EdgeInsets padFor(UiPiece p, double scale, {double extra = 0}) {
    final s =
        safe[p.file] ??
        EdgeInsets.fromLTRB(
          p.slice!.left,
          p.slice!.top,
          p.w - p.slice!.right,
          p.h - p.slice!.bottom,
        );
    return EdgeInsets.fromLTRB(
      s.left / scale + extra,
      s.top / scale + extra,
      s.right / scale + extra,
      s.bottom / scale + extra,
    );
  }

  static String wheelBg(String? potId) =>
      'assets/images/vong_quay/${_wheelBgByPot[potId] ?? 'nen_chung'}.webp';
}

/// [piece] stretched over the box (9-slice), drawn at [scale] image pixels
/// per dp.
class UiSlice extends StatelessWidget {
  const UiSlice({
    super.key,
    required this.piece,
    required this.scale,
    this.child,
    this.padding = EdgeInsets.zero,
  });

  final UiPiece piece;
  final double scale;
  final Widget? child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final sl = piece.slice;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: piece.minW(scale),
        minHeight: piece.minH(scale),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // The art is nine-sliced at 1 image px per px in a box [scale]
          // times bigger, then fitted down: paintImage's own `scale` path
          // asserts on rounding (sourceSize == inputSize) for most scales.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth <= 0 || c.maxHeight <= 0) {
                  return const SizedBox.shrink();
                }
                return FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: c.maxWidth * scale,
                    height: c.maxHeight * scale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(piece.path),
                          centerSlice: sl,
                          fit: sl == null ? BoxFit.contain : BoxFit.fill,
                          onError: (_, _) {},
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(padding: padding, child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// A 9-slice button: nut_xanh / nut_vang / nut_cam (52 dp, bold white
/// text; dark green on yellow) or nut_trang_nho (small, dark text).
/// Disabled: dimmed, no tap.
class SliceButton extends StatelessWidget {
  const SliceButton({
    super.key,
    required this.piece,
    required this.label,
    this.sub,
    this.onPressed,
    this.enabled = true,
    this.height = 52,
    this.fontSize = 16,
    this.textColor,
    this.textPad = 2,
  });

  final UiPiece piece;
  final String label;
  final String? sub;
  final VoidCallback? onPressed;
  final bool enabled;
  final double height;
  final double fontSize;
  final Color? textColor;

  /// Extra dp between the text and the end flowers (the side insets).
  final double textPad;

  static const yellowText = Color(0xFF2E5E3D);

  Color get _color =>
      textColor ??
      (identical(piece, UiChung.nutVang)
          ? yellowText
          : identical(piece, UiChung.nutTrangNho)
          ? AppColors.textPrimary
          : Colors.white);

  @override
  Widget build(BuildContext context) {
    final on = enabled && onPressed != null;
    final c = _color;
    // Scale so the art's full height fits the button.
    final scale = piece.h / height;
    return Semantics(
      button: true,
      enabled: on,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: on
            ? () {
                SoundScope.maybeOf(context)?.effect('ui_tap');
                onPressed!();
              }
            : null,
        child: Opacity(
          opacity: on ? 1 : 0.5,
          child: SizedBox(
            height: height,
            child: UiSlice(
              piece: piece,
              scale: scale,
              // Text clear of the end flowers: the full side insets + 2 dp.
              padding: EdgeInsets.fromLTRB(
                piece.slice!.left / scale + textPad,
                0,
                (piece.w - piece.slice!.right) / scale + textPad,
                0,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        style: AppText.title(
                          size: fontSize,
                          weight: 800,
                          color: c,
                        ),
                      ),
                      if (sub != null)
                        Text(
                          sub!,
                          maxLines: 1,
                          style: AppText.caption(size: 10.5, color: c),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// thanh_tien_do: the framed bar, stretched sideways only, the #F2C94C fill
/// inside the frame's track. [value] 0..1; [marks] ticks (0..1).
class SliceProgress extends StatelessWidget {
  const SliceProgress({
    super.key,
    required this.value,
    this.trackHeight = 8,
    this.marks = const [],
    this.fill = const Color(0xFFF2C94C),
  });

  final double value;

  /// The fill's height; the frame is sized around it.
  final double trackHeight;
  final List<double> marks;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    const p = UiChung.thanhTienDo;
    // Track inside the art: x 105..455, y 50..87 (the centre slice).
    final scale = p.slice!.height / trackHeight;
    final h = p.h / scale;
    final left = p.slice!.left / scale;
    final right = (p.w - p.slice!.right) / scale;
    final top = p.slice!.top / scale;
    return SizedBox(
      height: h,
      child: UiSlice(
        piece: p,
        scale: scale,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - left - right).clamp(0.0, double.infinity);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  key: const Key('slice-progress-fill'),
                  left: left,
                  top: top,
                  width: w * value.clamp(0.0, 1.0),
                  height: trackHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                  ),
                ),
                for (final m in marks)
                  if (m > 0 && m < 1)
                    Positioned(
                      key: const Key('slice-progress-mark'),
                      left: left + w * m - 1,
                      top: top - 2,
                      width: 2,
                      height: trackHeight + 4,
                      child: const ColoredBox(color: AppColors.textPrimary),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// nut_tron_la: the round leaf back/close button (40 dp).
class LeafRoundButton extends StatelessWidget {
  const LeafRoundButton({
    super.key,
    required this.onTap,
    this.size = 40,
    this.label = 'Quay lại',
  });

  final VoidCallback onTap;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          SoundScope.maybeOf(context)?.effect('ui_tap');
          onTap();
        },
        child: Image.asset(
          UiChung.nutTronLa.path,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
        ),
      ),
    );
  }
}

/// The VIP button (Phú G3): nut_vip_vang with "VIP {n}" right of the
/// crown in #2E5E3D, or nut_vip_xanh with "VIP" in gold below VIP 1.
class VipBadgeButton extends StatelessWidget {
  const VipBadgeButton({
    super.key,
    required this.level,
    this.height = 40,
    this.alwaysGold = false,
  });

  final int level;
  final double height;

  /// nut_vip_vang even at VIP 0 (Pha lê shop, An 18/10).
  final bool alwaysGold;

  @override
  Widget build(BuildContext context) {
    final gold = level > 0 || alwaysGold;
    final p = gold ? UiChung.nutVipVang : UiChung.nutVipXanh;
    final k = p.h / height;
    return SizedBox(
      key: Key(gold ? 'vip-badge-gold' : 'vip-badge-green'),
      width: p.w / k,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              p.path,
              fit: BoxFit.fill,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          // Text area: right of the crown (art x 240) to the right cap.
          Positioned(
            left: UiChung.padFor(p, k, extra: 2).left,
            right: UiChung.padFor(p, k, extra: 2).right,
            top: 0,
            bottom: 0,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  level > 0 ? 'VIP $level' : 'VIP',
                  key: const Key('vip-badge-text'),
                  style: AppText.title(
                    size: 15,
                    weight: 800,
                    color: gold ? _vipGreen : _vipGold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _vipGreen = Color(0xFF2E5E3D);
const _vipGold = Color(0xFFF2C94C);

/// Phú (17/10): a popup button. Width hugs the text (28 dp each side, or
/// clear of the end flowers), min 160 dp, max 70% of the popup, centred.
/// Primary 44 dp; secondary ("Để sau", "Đóng", nut_trang_nho) 40 dp. The
/// end flowers keep their size, only the middle stretches (9-slice).
class PopupButton extends StatelessWidget {
  const PopupButton({
    super.key,
    required this.label,
    this.piece,
    this.sub,
    this.onPressed,
    this.enabled = true,
    this.secondary = false,
    this.fontSize,
  });

  final String label;
  final UiPiece? piece;
  final String? sub;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool secondary;
  final double? fontSize;

  static const primaryH = 44.0;
  static const secondaryH = 40.0;
  static const gap = 10.0;
  static const minW = 160.0;
  static const textSide = 28.0;

  @override
  Widget build(BuildContext context) {
    final p = piece ?? (secondary ? UiChung.nutTrangNho : UiChung.nutXanh);
    final h = secondary ? secondaryH : primaryH;
    final fs = fontSize ?? (secondary ? 14.0 : 15.0);
    return LayoutBuilder(
      builder: (context, c) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: AppText.title(size: fs, weight: 800),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final scale = p.h / h;
        final flower = math.max(p.slice!.left, p.w - p.slice!.right) / scale;
        final side = math.max(textSide, flower + 2);
        final room = c.maxWidth.isFinite ? c.maxWidth : 320.0;
        final hi = math.min(room, math.max(minW, room * 0.7));
        final w = (tp.width + 2 * side)
            .clamp(math.min(minW, room), hi)
            .toDouble();
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: SliceButton(
              piece: p,
              label: label,
              sub: sub,
              onPressed: onPressed,
              enabled: enabled,
              height: h,
              fontSize: fs,
              textPad: math.max(2.0, side - flower),
            ),
          ),
        );
      },
    );
  }
}
