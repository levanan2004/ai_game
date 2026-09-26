import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../logic/supporters.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'png_download.dart';

/// Màn Đại thiện nhân (spec_dai_thien_nhan.md v0.4).
class DonorsScreen extends StatefulWidget {
  const DonorsScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<DonorsScreen> createState() => _DonorsScreenState();
}

class _DonorsScreenState extends State<DonorsScreen>
    with SingleTickerProviderStateMixin {
  static const _copyText = 'TIEMHOA ';

  List<Supporter>? _people;
  Object? _error;
  var _shown = supportPageSize;
  var _copied = false;
  Timer? _toast;

  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _toast?.cancel();
    _blink.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _people = null;
      _error = null;
    });
    try {
      final list = sortSupporters(await widget.session.supporters.load());
      if (!mounted) return;
      setState(() => _people = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: _copyText));
    _toast?.cancel();
    setState(() => _copied = true);
    _toast = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _saveQr() async {
    final data = await rootBundle.load(Art.donate('qr_bidv_levanan'));
    await downloadPng(data.buffer.asUint8List(), 'qr_bidv_levanan.png');
  }

  @override
  Widget build(BuildContext context) {
    return OpaqueScreen(
      color: AppColors.templeSkyBottom,
      child: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Stack(
                  children: [
                    Image.asset(
                      Art.scene('dai_thien_nhan_bg'),
                      width: 360,
                      height: 160,
                      fit: BoxFit.fill,
                    ),
                    const Positioned(
                      left: 48,
                      right: 48,
                      top: 30,
                      child: Text(
                        'Đại thiện nhân',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: AppColors.textInverse,
                          fontVariations: [FontVariation.weight(700)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 140, 12, 0),
                      child: _DonateCard(onCopy: _copy, onSaveQr: _saveQr),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: _Board(
                    people: _people,
                    error: _error,
                    shown: _shown,
                    blink: _blink,
                    onRetry: _load,
                    onMore: () => setState(() => _shown += supportPageSize),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: _BackCircle(onTap: widget.session.closeDonors),
          ),
          if (_copied)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: Container(
                  key: const Key('donate-copied'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Đã sao chép',
                    style: AppText.caption(color: AppColors.textInverse),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  const _BackCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('donors-back'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xD9FFFFFF),
          shape: BoxShape.circle,
        ),
        child: CustomPaint(painter: _ChevronPainter()),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width / 2 + 4, size.height / 2 - 6)
      ..lineTo(size.width / 2 - 4, size.height / 2)
      ..lineTo(size.width / 2 + 4, size.height / 2 + 6);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => false;
}

class _DonateCard extends StatelessWidget {
  const _DonateCard({required this.onCopy, required this.onSaveQr});

  final VoidCallback onCopy;
  final VoidCallback onSaveQr;

  @override
  Widget build(BuildContext context) {
    final body = AppText.body(size: 11, weight: 600).copyWith(height: 16 / 11);
    final bold = AppText.body(size: 11, weight: 800).copyWith(height: 16 / 11);
    return Container(
      key: const Key('donors-card'),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.popupShadow,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        children: [
          Text(
            'Ủng hộ Tiệm Hoa Sớm Mai',
            textAlign: TextAlign.center,
            style: AppText.heading(size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'Game miễn phí, ủng hộ tùy tâm',
            textAlign: TextAlign.center,
            style: AppText.caption(),
          ),
          const SizedBox(height: 12),
          Container(
            width: 236,
            height: 218,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.surfaceBorder,
                width: AppBorder.thin,
              ),
            ),
            child: Image.asset(
              Art.donate('qr_bidv_levanan'),
              width: 220,
              fit: BoxFit.fitWidth,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 312,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nội dung chuyển khoản (gõ không dấu)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(size: 10, weight: 700),
                        ),
                        Text(
                          'TIEMHOA Tên muốn hiện',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.heading(size: 15),
                        ),
                        Text(
                          'có thể thêm: - lời nhắn',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(size: 10, weight: 700),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlineButton(
                    key: const Key('donate-copy'),
                    label: 'Sao chép',
                    width: 64,
                    height: 30,
                    fontSize: 12,
                    onTap: onCopy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 296,
            child: Text.rich(
              TextSpan(
                style: body,
                children: const [
                  TextSpan(
                    text:
                        'Tên và số tiền bạn ủng hộ sẽ hiện trên bảng Đại thiện nhân.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 296,
            child: Text.rich(
              TextSpan(
                style: body,
                children: [
                  const TextSpan(text: 'Muốn ẩn tên thì chỉ ghi '),
                  TextSpan(text: 'TIEMHOA', style: bold),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 296,
            child: Text.rich(
              TextSpan(
                style: body,
                children: [
                  const TextSpan(text: 'Muốn ẩn số tiền thì ghi thêm '),
                  TextSpan(text: 'ANSOTIEN', style: bold),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 312,
            height: 52,
            child: ChunkyButton(
              key: const Key('donate-save-qr'),
              label: 'Lưu ảnh QR',
              onPressed: onSaveQr,
            ),
          ),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.people,
    required this.error,
    required this.shown,
    required this.blink,
    required this.onRetry,
    required this.onMore,
  });

  final List<Supporter>? people;
  final Object? error;
  final int shown;
  final Animation<double> blink;
  final VoidCallback onRetry;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final list = people;
    return Container(
      key: const Key('donors-board'),
      width: 320,
      decoration: BoxDecoration(
        color: AppColors.templeWood,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.templeWoodDark, width: 3),
      ),
      child: Column(
        children: [
          Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.templePillar,
              border: Border.all(
                color: AppColors.templeGold,
                width: AppBorder.thin,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
            child: Text(
              'BẢNG ĐẠI THIỆN NHÂN',
              style: AppText.heading(size: 14, color: AppColors.templeGold),
            ),
          ),
          CustomPaint(painter: _GrainPainter(), child: _body(list)),
        ],
      ),
    );
  }

  Widget _body(List<Supporter>? list) {
    if (error != null) {
      return _message(
        'Chưa tải được danh sách, thử lại sau',
        action: 'Thử lại',
        onAction: onRetry,
        actionKey: const Key('donors-retry'),
      );
    }
    if (list == null) {
      return AnimatedBuilder(
        animation: blink,
        builder: (context, _) => Opacity(
          opacity: 0.35 + 0.45 * blink.value,
          child: Column(
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  height: 58,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 14,
                    width: 180,
                    decoration: BoxDecoration(
                      color: AppColors.templeWoodDark.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (list.isEmpty) {
      return _message('Chưa có tên nào trên bảng');
    }
    final page = list.take(shown).toList();
    final more = list.length > shown;
    return Column(
      children: [
        for (final p in page) _Row(person: p),
        if (more)
          GestureDetector(
            key: const Key('donors-more'),
            onTap: onMore,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Xem thêm',
                style: AppText.body(
                  size: 14,
                  weight: 800,
                  color: AppColors.templeGold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _message(
    String text, {
    String? action,
    VoidCallback? onAction,
    Key? actionKey,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 13,
              weight: 700,
              color: AppColors.templeText,
            ),
          ),
          if (action != null)
            GestureDetector(
              key: actionKey,
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  action,
                  style: AppText.body(
                    size: 14,
                    weight: 800,
                    color: AppColors.templeGold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.templeWoodDark.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var y = 8.0; y < size.height; y += 10) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), p);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => false;
}

class _Row extends StatelessWidget {
  const _Row({required this.person});

  final Supporter person;

  @override
  Widget build(BuildContext context) {
    final chip = formatSupportAmount(person.amount);
    final message = person.message.trim();
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.only(left: 22, right: 16),
        child: Row(
          children: [
            _Avatar(avatar: person.avatar),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.heading(
                      size: 15,
                      color: AppColors.templeGold,
                    ),
                  ),
                  if (message.isNotEmpty)
                    Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption(
                        size: 11,
                        color: AppColors.templeText,
                      ),
                    ),
                ],
              ),
            ),
            if (chip != null) ...[
              const SizedBox(width: 8),
              _AmountChip(label: chip),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.templeWoodDark,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.templeGold, width: AppBorder.thin),
      ),
      child: Text(
        label,
        style: AppText.number(size: 13, color: AppColors.templeGold),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatar});

  final String avatar;

  @override
  Widget build(BuildContext context) {
    final url = storageAvatarUrl(avatar);
    final Widget face;
    if (url != null) {
      face = Image.network(
        url,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        loadingBuilder: (context, child, progress) {
          if (progress != null) return const _Lotus();
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.base,
            builder: (_, v, c) => Opacity(opacity: v, child: c!),
            child: child,
          );
        },
        errorBuilder: (_, _, _) => const _Lotus(),
      );
    } else if (avatar.isEmpty) {
      face = const _Lotus();
    } else {
      face = Image.asset(
        Art.customer(avatar),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _Lotus(),
      );
    }
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.templeGold, width: 2),
      ),
      child: ClipOval(child: face),
    );
  }
}

class _Lotus extends StatelessWidget {
  const _Lotus();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.templeWoodDark,
      child: Center(child: ArtImage(Art.nav('sen'), size: 24)),
    );
  }
}
