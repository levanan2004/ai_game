import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'open_url.dart';
import 'popups.dart';

// Copy: Nhất, man_dieu_khoan_v1.md. Layout: Phú, spec_dieu_khoan.md.
const termsTitle = 'Chào mừng đến Tiệm Hoa Sớm Mai';
const termsOpening =
    'Trước khi mở cửa tiệm, bạn đọc nhanh mấy điều dưới đây nhé.';
const termsUpdatedOpening =
    'Tụi mình vừa cập nhật điều khoản. '
    'Bạn xem lại và đồng ý để chơi tiếp nhé.';
const termsSummary = [
  'Game chơi miễn phí. Không cần nạp tiền để mở tiệm, bó hoa hay giữ tiến trình.',
  'Tiền trong tiệm chỉ dùng trong game, không đổi ra tiền thật và không đổi sang Pha lê.',
  'Pha lê mua bằng tiền thật và không hoàn lại khi đã cộng vào tài khoản. '
      'Người dưới 18 tuổi chỉ nạp khi cha mẹ đồng ý.',
  'Tiến trình lưu trên trình duyệt của bạn. Nếu đăng nhập Google, game lưu '
      'thêm tên, email và ảnh đại diện để bạn chơi tiếp trên máy khác.',
  'Game có quảng cáo của Google và dùng công cụ đo lượt chơi, có cookie.',
];
const termsCheckbox =
    'Mình chấp nhận Quy chế hoạt động và Chính sách quyền riêng tư của '
    'Tiệm Hoa Sớm Mai, và phụ huynh đã cho phép nếu mình chưa đủ 16 tuổi.';
const termsAcceptLabel = 'Nhận chìa khóa tiệm';
const termsHintOff = 'Tích vào ô phía trên để nhận chìa khóa';
const termsHintOn = 'Bạn chỉ cần đồng ý một lần';

/// Full texts are static pages on the same site (web/terms.html, privacy.html).
const termsUrl = '/terms';
const privacyUrl = '/privacy';

/// Disabled main button (spec §2). Not tokens yet.
const _offFill = Color(0xFFECEEE6);
const _offText = Color(0xFF8F877A);

/// Terms screen, shown before the title flow until the player agrees, and
/// read-only from Cài đặt. A screen of its own: no X, no tap-outside close.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen>
    with SingleTickerProviderStateMixin {
  static const _logo = 'assets/images/brand/logo_0_nen.webp';

  var _ticked = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(vsync: this, duration: AppMotion.base);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// Tap on the disabled button: shake the checkbox row 4px for 200ms.
  void _pointAtCheckbox() {
    SoundScope.maybeOf(context)?.effect('error');
    _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final review = s.termsMode == TermsMode.review;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: 150,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.bgShop,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(40),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 10,
            child: Center(
              child: Image.asset(
                _logo,
                width: 96,
                height: 72,
                fit: BoxFit.contain,
                semanticLabel: 'Tiệm Hoa Sớm Mai',
                errorBuilder: (_, _, _) =>
                    const SizedBox(width: 96, height: 72),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 88,
            bottom: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.slow,
              curve: reduceMotion ? Curves.easeOut : Curves.easeOutBack,
              builder: (_, t, c) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: reduceMotion
                    ? c
                    : Transform.scale(scale: 0.85 + 0.15 * t, child: c),
              ),
              child: CardBox(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        termsTitle,
                        key: const Key('terms-title'),
                        style: AppText.title(size: 22, weight: 800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.termsOutdated && !review
                          ? termsUpdatedOpening
                          : termsOpening,
                      key: const Key('terms-opening'),
                      textAlign: TextAlign.center,
                      style: AppText.caption(size: 13),
                    ),
                    const SizedBox(height: 10),
                    const Expanded(child: _SummaryBox()),
                    const _FullTextLinks(),
                    if (!review) ...[
                      AnimatedBuilder(
                        animation: _shake,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(
                            math.sin(_shake.value * math.pi * 4) * 4,
                            0,
                          ),
                          child: child,
                        ),
                        child: _CheckboxRow(
                          ticked: _ticked,
                          onTap: () => setState(() => _ticked = !_ticked),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: AppSize.button + AppSize.shadowOffset,
                      child: review
                          ? ChunkyButton(
                              key: const Key('terms-close'),
                              label: 'Đóng',
                              radius: AppRadius.md,
                              weight: 700,
                              onPressed: s.closeTermsReview,
                            )
                          : AnimatedSwitcher(
                              duration: AppMotion.fast,
                              child: _ticked
                                  ? ChunkyButton(
                                      key: const Key('terms-accept'),
                                      label: termsAcceptLabel,
                                      radius: AppRadius.md,
                                      weight: 700,
                                      onPressed: s.acceptTerms,
                                    )
                                  : _DisabledButton(
                                      key: const Key('terms-accept-off'),
                                      onTap: _pointAtCheckbox,
                                    ),
                            ),
                    ),
                    if (!review) ...[
                      const SizedBox(height: 4),
                      Text(
                        _ticked ? termsHintOn : termsHintOff,
                        key: const Key('terms-hint'),
                        textAlign: TextAlign.center,
                        style: AppText.caption(
                          color: _ticked
                              ? AppColors.primaryBase
                              : AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        key: const Key('terms-later'),
                        onTap: s.postponeTerms,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: AppSize.touchMin,
                          child: Center(
                            child: Text(
                              'Để sau',
                              style: AppText.button(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Five-line summary. Scrolls on short frames, with an always-on bar and a
/// fade at the bottom so it is clear there is more.
class _SummaryBox extends StatefulWidget {
  const _SummaryBox();

  @override
  State<_SummaryBox> createState() => _SummaryBoxState();
}

class _SummaryBoxState extends State<_SummaryBox> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('terms-summary'),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: AppBorder.thin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          RawScrollbar(
            controller: _scroll,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 4,
            radius: const Radius.circular(2),
            crossAxisMargin: 4,
            mainAxisMargin: 8,
            thumbColor: AppColors.surfaceBorderStrong,
            trackColor: AppColors.surfaceBorder,
            trackRadius: const Radius.circular(2),
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < termsSummary.length; i++)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 7, right: 10),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBase,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(termsSummary[i], style: AppText.body()),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 36,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00F1F4E8), AppColors.surfaceSunken],
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

/// "Đọc đầy đủ: Quy chế hoạt động · Chính sách quyền riêng tư".
class _FullTextLinks extends StatelessWidget {
  const _FullTextLinks();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        Text('Đọc đầy đủ:', style: AppText.caption()),
        SizedBox(
          height: AppSize.touchMin,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Link(
                  key: Key('terms-link-terms'),
                  label: 'Quy chế hoạt động',
                  url: termsUrl,
                ),
                Text(' · ', style: AppText.caption(size: 14)),
                const _Link(
                  key: Key('terms-link-privacy'),
                  label: 'Chính sách quyền riêng tư',
                  url: privacyUrl,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({super.key, required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openUrl(url),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: AppSize.touchMin,
        child: Center(
          child: Text(
            label,
            style: AppText.body(weight: 800, color: AppColors.primaryBase)
                .copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primaryBase,
                  decorationThickness: 1.5,
                ),
          ),
        ),
      ),
    );
  }
}

/// The whole row is the tap target (spec §1, §3).
class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({required this.ticked, required this.onTap});

  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: ticked,
      child: GestureDetector(
        key: const Key('terms-checkbox'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          constraints: const BoxConstraints(minHeight: AppSize.touchMin),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ticked ? AppColors.primarySoft : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: ticked ? AppColors.primaryBase : AppColors.surfaceBorder,
              width: AppBorder.thin,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppMotion.fast,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: ticked ? AppColors.primaryBase : AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: ticked
                        ? AppColors.primaryBase
                        : AppColors.textSecondary,
                    width: 2,
                  ),
                ),
                child: ticked
                    ? const Icon(
                        Icons.check,
                        size: 20,
                        color: AppColors.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  termsCheckbox,
                  style: AppText.body(size: 13, weight: 700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grey, flat, no shadow (spec §2). Taps shake the checkbox row instead.
class _DisabledButton extends StatelessWidget {
  const _DisabledButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSize.shadowOffset),
        child: Container(
          decoration: BoxDecoration(
            color: _offFill,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.surfaceBorder,
              width: AppBorder.thin,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            termsAcceptLabel,
            style: AppText.button(size: 17, color: _offText),
          ),
        ),
      ),
    );
  }
}

/// "Để sau" leads here, over the title (Nhất: "Tiệm vẫn chờ bạn").
class TermsLaterPopup extends StatelessWidget {
  const TermsLaterPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return PopupFrame(
      key: const Key('terms-later-popup'),
      rect: const Rect.fromLTWH(40, 200, 280, 230),
      onOutsideTap: s.closeTermsLater,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tiệm vẫn chờ bạn',
              textAlign: TextAlign.center,
              style: AppText.title(size: 20, weight: 800),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Text(
                  'Bạn cần đồng ý điều khoản thì mới chơi được. '
                  'Tiến trình của bạn vẫn được giữ nguyên.',
                  textAlign: TextAlign.center,
                  style: AppText.body(),
                ),
              ),
            ),
            SizedBox(
              height: AppSize.button + AppSize.shadowOffset,
              child: ChunkyButton(
                key: const Key('terms-reread'),
                label: 'Đọc lại điều khoản',
                radius: AppRadius.md,
                onPressed: s.reopenTerms,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
