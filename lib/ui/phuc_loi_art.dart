import 'package:flutter/material.dart';

import '../logic/reward_rarity.dart';
import 'art.dart';

/// One of Phú's cut-outs (dot1_khung_qua) with the empty areas from his
/// README, in pixels of the full-size file. Widgets place icons and text
/// by these rects as fractions of the canvas, so every size lines up.
class PhucLoiArt {
  const PhucLoiArt(
    this.id, {
    required this.canvas,
    required this.inner,
    this.band,
    this.ink,
  });

  final String id;

  /// Full-size file (shared canvas for the frame and tile families).
  final Size canvas;

  /// "trong": largest safe rect for the icon(s).
  final Rect inner;

  /// "bang_tren": label band at the top of a check-in tile.
  final Rect? band;

  /// Visible picture inside the canvas (alpha > 20), for layout.
  final Rect? ink;

  String get path => Art.phucLoi(id);
  double get aspect => canvas.width / canvas.height;

  /// [r] (file pixels) inside a box of [size].
  Rect place(Rect r, Size size) => Rect.fromLTWH(
    r.left / canvas.width * size.width,
    r.top / canvas.height * size.height,
    r.width / canvas.width * size.width,
    r.height / canvas.height * size.height,
  );

  // Reward frames, shared 425×425 canvas.
  static const khungThuong = PhucLoiArt(
    'khung_thuong',
    canvas: Size(425, 425),
    inner: Rect.fromLTWH(98, 113, 227, 226),
  );
  static const khungHiem = PhucLoiArt(
    'khung_hiem',
    canvas: Size(425, 425),
    inner: Rect.fromLTWH(106, 101, 212, 222),
  );
  static const khungSuThi = PhucLoiArt(
    'khung_su_thi',
    canvas: Size(425, 425),
    inner: Rect.fromLTWH(107, 98, 213, 230),
  );
  static const khungHuyenThoai = PhucLoiArt(
    'khung_huyen_thoai',
    canvas: Size(425, 425),
    inner: Rect.fromLTWH(124, 114, 190, 206),
  );

  static PhucLoiArt frame(RewardRarity r) => switch (r) {
    RewardRarity.thuong => khungThuong,
    RewardRarity.hiem => khungHiem,
    RewardRarity.suThi => khungSuThi,
    RewardRarity.huyenThoai => khungHuyenThoai,
  };

  // Check-in tiles, shared 432×432 canvas.
  static const oDaNhan = PhucLoiArt(
    'o_da_nhan',
    canvas: Size(432, 432),
    band: Rect.fromLTWH(123, 80, 187, 55),
    inner: Rect.fromLTWH(81, 152, 271, 190),
    ink: Rect.fromLTRB(54, 53, 379, 379),
  );
  static const oHomNay = PhucLoiArt(
    'o_hom_nay',
    canvas: Size(432, 432),
    band: Rect.fromLTWH(126, 91, 188, 53),
    inner: Rect.fromLTWH(90, 161, 260, 193),
    ink: Rect.fromLTRB(54, 53, 379, 379),
  );

  /// The lock takes the bottom-right corner; "trong" is the tall area left
  /// of it.
  static const oKhoa = PhucLoiArt(
    'o_khoa',
    canvas: Size(432, 432),
    band: Rect.fromLTWH(120, 80, 189, 55),
    inner: Rect.fromLTWH(80, 151, 149, 192),
    ink: Rect.fromLTRB(54, 53, 379, 379),
  );

  /// Day 7, cut tight with 4 px spare (742×847).
  static const oNgay7 = PhucLoiArt(
    'o_ngay7',
    canvas: Size(742, 847),
    band: Rect.fromLTWH(181, 160, 395, 84),
    inner: Rect.fromLTWH(135, 256, 489, 429),
    ink: Rect.fromLTRB(9, 5, 738, 842),
  );

  static const huyHieuDaNhan = PhucLoiArt(
    'huy_hieu_da_nhan',
    canvas: Size(309, 294),
    inner: Rect.fromLTWH(0, 0, 309, 294),
  );

  // Envelopes, cut tight (no shared canvas).
  static const thuDong = PhucLoiArt(
    'thu_dong',
    canvas: Size(458, 367),
    inner: Rect.fromLTWH(0, 0, 458, 367),
  );
  static const thuMo = PhucLoiArt(
    'thu_mo',
    canvas: Size(523, 422),
    inner: Rect.fromLTWH(0, 0, 523, 422),
  );

  static const all = [
    khungThuong,
    khungHiem,
    khungSuThi,
    khungHuyenThoai,
    oDaNhan,
    oHomNay,
    oKhoa,
    oNgay7,
    huyHieuDaNhan,
    thuDong,
    thuMo,
  ];
}

/// A picture that fills its box; [fallback] if the file is missing.
Widget phucLoiImage(PhucLoiArt art, {Widget? fallback, Key? key}) {
  return Image.asset(
    art.path,
    key: key,
    fit: BoxFit.fill,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
  );
}

/// Reward-slot frame by rarity, [size] square (the 425 canvas), with
/// [child] centred in the frame's empty area.
class RarityFrame extends StatelessWidget {
  const RarityFrame({
    super.key,
    required this.rarity,
    required this.size,
    required this.child,
  });

  final RewardRarity rarity;
  final double size;
  final Widget child;

  /// Icon edge that fits [rarity]'s empty area in a [size] frame.
  static double iconFor(RewardRarity rarity, double size) {
    final art = PhucLoiArt.frame(rarity);
    final r = art.place(art.inner, Size.square(size));
    return (r.shortestSide * 0.86).floorToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final art = PhucLoiArt.frame(rarity);
    final area = art.place(art.inner, Size.square(size));
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: phucLoiImage(art, key: Key('reward-frame-${rarity.name}')),
          ),
          Positioned.fromRect(
            rect: area,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

/// Mailbox envelope: closed (unread / gift not taken) or open. Both files
/// are drawn at one pixel scale, so the open one's flap and sparkles stick
/// out instead of shrinking the envelope.
class MailEnvelope extends StatelessWidget {
  const MailEnvelope({
    super.key,
    required this.open,
    required this.width,
    this.fallback,
  });

  final bool open;

  /// Width of the closed envelope; the box is that wide and tall.
  final double width;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final art = open ? PhucLoiArt.thuMo : PhucLoiArt.thuDong;
    final scale = width / PhucLoiArt.thuDong.canvas.width;
    final height = PhucLoiArt.thuDong.canvas.height * scale;
    return SizedBox(
      width: width,
      height: height,
      child: OverflowBox(
        maxWidth: art.canvas.width * scale,
        maxHeight: art.canvas.height * scale,
        child: SizedBox(
          width: art.canvas.width * scale,
          height: art.canvas.height * scale,
          child: phucLoiImage(
            art,
            key: Key(open ? 'envelope-open' : 'envelope-closed'),
            fallback: fallback,
          ),
        ),
      ),
    );
  }
}
