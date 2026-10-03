import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../logic/giftcodes.dart';
import '../logic/login_rewards.dart';
import '../logic/rewards.dart';
import '../logic/welfare.dart';
import '../logic/welfare_slides.dart';
import '../logic/welfare_text.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'login_tiles.dart';
import 'reward_bundle_view.dart';
import 'ui_skin.dart';
import 'welfare_slides_view.dart';

/// Phúc lợi button, under the Hộp thư button. A dot while today's tile is
/// waiting.
class WelfareButton extends StatelessWidget {
  const WelfareButton({super.key, required this.feed});

  final WelfareFeed feed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) {
        return GestureDetector(
          key: const Key('welfare-button'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            SoundScope.maybeOf(
              context,
            )?.effect(feed.open ? 'popup_close' : 'popup_open');
            feed.toggle();
          },
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.headerChip,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  // Phú's phuc_loi_icon (the 128 px cut: about 30 dp here,
                  // so phones at 3x still get a sharp picture).
                  child: Image.asset(
                    Art.phucLoi('phuc_loi_icon'),
                    key: const Key('welfare-icon'),
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.card_giftcard_rounded,
                      size: 20,
                      color: AppColors.primaryBase,
                    ),
                  ),
                ),
                if (feed.canClaimToday)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      key: const Key('welfare-badge'),
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: AppColors.statusDanger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Điểm danh 7 ngày, Giftcode and "Bạn biết?" in one card.
class WelfareSheet extends StatelessWidget {
  const WelfareSheet({
    super.key,
    required this.feed,
    required this.signedIn,
    required this.canClaim,
    required this.grantLogin,
    required this.grantCode,
    required this.onSlide,
    this.onSignIn,
  });

  final WelfareFeed feed;
  final bool signedIn;

  /// False while this tab may not write the account (seat moving, leaving).
  final bool Function() canClaim;

  /// `grantRewards(source: RewardSource.loginReward)`.
  final RewardBundle Function(RewardBundle bundle) grantLogin;

  /// `grantRewards(source: RewardSource.giftcode)`.
  final RewardBundle Function(RewardBundle bundle) grantCode;

  /// Opens a slide's link. Returns a message when it could not.
  final String? Function(WelfareSlide slide) onSlide;
  final Future<void> Function()? onSignIn;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) {
        if (!feed.open) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  SoundScope.maybeOf(context)?.effect('popup_close');
                  feed.close();
                },
                child: const ColoredBox(color: AppColors.bgOverlay),
              ),
            ),
            Positioned(
              left: 8,
              top: 56,
              width: 344,
              child: ConstrainedBox(
                // Shrinks to the tab's content; long tabs scroll inside.
                constraints: const BoxConstraints(maxHeight: 560),
                child: GestureDetector(
                  onTap: () {},
                  child: SkinPopup(
                    key: const Key('welfare-sheet'),
                    title: 'Phúc lợi',
                    onBack: feed.close,
                    onClose: feed.close,
                    backKey: const Key('welfare-back'),
                    closeKey: const Key('welfare-close'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _tab(context, WelfareTab.login, 'Điểm danh'),
                            _tab(context, WelfareTab.giftcode, 'Giftcode'),
                            _tab(context, WelfareTab.slides, 'Bạn biết?'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Flexible(child: _body(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (signedIn &&
                feed.tab == WelfareTab.login &&
                feed.detailDay != null)
              Positioned.fill(
                child: LoginDayDetail(
                  feed: feed,
                  onClaim: () {
                    feed.showDay(null);
                    claimTodayLogin(context, feed, canClaim(), grantLogin);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tab(BuildContext context, WelfareTab tab, String label) {
    final on = feed.tab == tab;
    return Expanded(
      child: SkinTab(
        key: Key('welfare-tab-${tab.name}'),
        label: label,
        selected: on,
        onTap: () {
          SoundScope.maybeOf(context)?.effect('ui_tab');
          feed.selectTab(tab);
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (feed.tab) {
      case WelfareTab.slides:
        return _SlidesTab(feed: feed, onSlide: onSlide);
      case WelfareTab.login:
        if (!signedIn) return _guest(WelfareText.loginGuest);
        return _LoginTab(feed: feed, canClaim: canClaim, grant: grantLogin);
      case WelfareTab.giftcode:
        if (!signedIn) return _guest(WelfareText.codeGuest);
        return _GiftcodeTab(feed: feed, canClaim: canClaim, grant: grantCode);
    }
  }

  Widget _guest(String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(
          Icons.card_giftcard_rounded,
          size: 48,
          color: AppColors.primaryBase,
        ),
        const SizedBox(height: 8),
        Text(
          text,
          key: const Key('welfare-guest'),
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, weight: 700),
        ),
        const SizedBox(height: 12),
        if (onSignIn != null)
          SkinButton(
            key: const Key('welfare-sign-in'),
            label: 'Đăng nhập Google',
            height: 48,
            fontSize: 16,
            onPressed: () => onSignIn!(),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LoginTab extends StatefulWidget {
  const _LoginTab({
    required this.feed,
    required this.canClaim,
    required this.grant,
  });

  final WelfareFeed feed;
  final bool Function() canClaim;
  final RewardBundle Function(RewardBundle bundle) grant;

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Ticks the "Quà tiếp theo sau" countdown (and flips the board at
    // midnight).
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _claim() =>
      claimTodayLogin(context, widget.feed, widget.canClaim(), widget.grant);

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    final plan = feed.plan;
    final busy = feed.loginBusy;
    final label = busy
        ? WelfareText.loginBusy
        : plan.canClaim
        ? WelfareText.loginClaim
        : WelfareText.loginClaimed;
    // Day 7 is claimed and the table stops: only the thank-you line.
    final allDone =
        !feed.config.repeat &&
        (plan.finished || feed.loginState.claimedCount >= loginRewardDays);
    final note = allDone
        ? WelfareText.loginFinished(repeat: false)
        : feed.loginMessage ??
              (plan.claimedToday
                  ? WelfareText.loginAlready
                  : plan.finished
                  ? WelfareText.loginFinished(repeat: feed.config.repeat)
                  : null);
    // Scrolls on short screens (board, countdown, milestones, button).
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            WelfareText.loginTitle,
            key: const Key('login-title'),
            textAlign: TextAlign.center,
            style: AppText.heading(size: 16),
          ),
          Text(
            plan.cycle <= 1
                ? WelfareText.loginWeekNewbie
                : WelfareText.loginWeekly,
            key: const Key('login-week'),
            textAlign: TextAlign.center,
            style: AppText.caption(),
          ),
          const SizedBox(height: 6),
          LoginWeekBoard(tile: (n) => _tile(n, plan)),
          const SizedBox(height: 10),
          Text(
            'Đã nhận ${plan.shownCount}/$loginRewardDays ngày',
            key: const Key('login-progress'),
            textAlign: TextAlign.center,
            style: AppText.body(size: 14, weight: 800),
          ),
          if (!allDone) ...[
            const SizedBox(height: 2),
            Text(
              WelfareText.loginNext(untilNextVnDay(feed.now())),
              key: const Key('login-next'),
              textAlign: TextAlign.center,
              style: AppText.body(
                size: 13,
                weight: 700,
                color: AppColors.primaryPressed,
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note,
              key: const Key('login-message'),
              textAlign: TextAlign.center,
              style: AppText.caption(),
            ),
          ],
          if (feed.config.milestones.isNotEmpty) ...[
            const SizedBox(height: 8),
            LoginMilestones(
              milestones: feed.config.milestones,
              total: feed.loginState.totalDays,
            ),
          ],
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 200,
              child: SkinButton(
                key: const Key('login-claim'),
                label: label,
                height: 52,
                fontSize: 17,
                enabled: plan.canClaim && !busy,
                onPressed: plan.canClaim && !busy ? _claim : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(int n, LoginPlan plan) {
    final state = plan.tile(n);
    return LoginDayTile(
      day: n,
      state: state,
      bundle: widget.feed.config.day(n, cycle: plan.cycle),
      // Every tile opens its gift detail; today's has "Nhận quà" there.
      onTap: () {
        SoundScope.maybeOf(context)?.effect('ui_tap');
        widget.feed.showDay(n);
      },
    );
  }
}

class _GiftcodeTab extends StatefulWidget {
  const _GiftcodeTab({
    required this.feed,
    required this.canClaim,
    required this.grant,
  });

  final WelfareFeed feed;
  final bool Function() canClaim;
  final RewardBundle Function(RewardBundle bundle) grant;

  @override
  State<_GiftcodeTab> createState() => _GiftcodeTabState();
}

class _GiftcodeTabState extends State<_GiftcodeTab> {
  // Plain field: no formatter and no length cap, so UniKey typing is never
  // rewritten. The code is trimmed and upper-cased only on "Nhập".
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sounds = SoundScope.maybeOf(context);
    final outcome = await widget.feed.redeem(
      _code.text,
      allowed: widget.canClaim(),
      grant: widget.grant,
    );
    if (!mounted) return;
    if (outcome.result == RedeemResult.busy) return;
    if (outcome.result == RedeemResult.success) {
      sounds?.effect('login_ok');
      _code.clear();
    } else {
      sounds?.effect('error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    final last = feed.lastRedeem;
    final busy = feed.redeemBusy;
    final ok = last?.result == RedeemResult.success;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nhập mã quà từ fanpage, livestream hay sự kiện của tiệm.',
          style: AppText.body(size: 13, weight: 700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SkinInput(
                field: TextField(
                  key: const Key('giftcode-input'),
                  controller: _code,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => busy ? null : _submit(),
                  style: AppText.body(size: 14, weight: 700),
                  decoration: SkinInput.decoration(WelfareText.codeHint),
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 92,
              child: SkinButton(
                key: const Key('giftcode-submit'),
                label: busy ? '…' : WelfareText.codeButton,
                height: 44,
                fontSize: 15,
                enabled: !busy,
                onPressed: busy ? null : _submit,
              ),
            ),
          ],
        ),
        if (last != null) ...[
          const SizedBox(height: 10),
          Text(
            last.message,
            key: const Key('giftcode-message'),
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 14,
              weight: 800,
              color: ok ? AppColors.primaryPressed : AppColors.statusDanger,
            ),
          ),
          if (ok && last.rewards.isNotEmpty) ...[
            const SizedBox(height: 8),
            SkinTray(
              child: RewardBundleView(
                key: const Key('giftcode-reward'),
                bundle: last.rewards,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SlidesTab extends StatefulWidget {
  const _SlidesTab({required this.feed, required this.onSlide});

  final WelfareFeed feed;
  final String? Function(WelfareSlide slide) onSlide;

  @override
  State<_SlidesTab> createState() => _SlidesTabState();
}

class _SlidesTabState extends State<_SlidesTab> {
  String? _message;

  void _open(WelfareSlide slide) {
    if (slide.linkType == SlideLinkType.none) return;
    SoundScope.maybeOf(context)?.effect('ui_tap');
    final problem = widget.onSlide(slide);
    if (mounted) setState(() => _message = problem);
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    final slides = feed.slides;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (slides.isEmpty && feed.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Đang tải…',
              textAlign: TextAlign.center,
              style: AppText.body(size: 14, weight: 700),
            ),
          )
        else
          WelfareSlidesView(slides: slides, onTap: _open),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            key: const Key('slide-message'),
            textAlign: TextAlign.center,
            style: AppText.caption(),
          ),
        ],
      ],
    );
  }
}

/// One-time gifts for total check-in days (14 → Chậu cá chép, 30 → Chậu
/// hạc by default), with the player's progress.
class LoginMilestones extends StatelessWidget {
  const LoginMilestones({
    super.key,
    required this.milestones,
    required this.total,
  });

  final List<LoginMilestone> milestones;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('login-milestones'),
      children: [
        Text(
          WelfareText.loginTotal(total),
          key: const Key('login-total'),
          textAlign: TextAlign.center,
          style: AppText.body(size: 13, weight: 800),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final m in milestones) _chip(m, done: total >= m.day),
          ],
        ),
      ],
    );
  }

  Widget _chip(LoginMilestone m, {required bool done}) {
    return Container(
      key: Key('login-milestone-${m.day}'),
      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
      decoration: BoxDecoration(
        color: done ? AppColors.surfaceSunken : AppColors.headerChip,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in m.rewards.items.take(2))
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Opacity(
                opacity: done ? 0.5 : 1,
                child: rewardIcon(item, size: 26),
              ),
            ),
          Flexible(
            child: Text(
              // Milestones are granted when reached, so reached = claimed.
              done
                  ? WelfareText.loginMilestoneDone(m.day)
                  : '${WelfareText.loginMilestone(m.day)} '
                        '(${total.clamp(0, m.day)}/${m.day})',
              key: Key('login-milestone-text-${m.day}'),
              maxLines: 2,
              textScaler: TextScaler.noScaling,
              style: AppText.body(
                size: 12,
                weight: 800,
                color: done ? AppColors.primaryPressed : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Claims today's tile and leaves the answer under the board.
Future<void> claimTodayLogin(
  BuildContext context,
  WelfareFeed feed,
  bool allowed,
  RewardBundle Function(RewardBundle bundle) grant,
) async {
  final sounds = SoundScope.maybeOf(context);
  final result = await feed.claimLogin(allowed: allowed, grant: grant);
  if (result == LoginClaimResult.claimed) {
    sounds?.effect('diem_danh');
  } else if (result != LoginClaimResult.busy) {
    sounds?.effect('error');
  }
  final message = switch (result) {
    LoginClaimResult.claimed => WelfareText.loginDone(
      feed.loginState.claimedCount,
    ),
    LoginClaimResult.already => WelfareText.loginAlready,
    LoginClaimResult.finished => WelfareText.loginFinished(
      repeat: feed.config.repeat,
    ),
    LoginClaimResult.busy => null,
    LoginClaimResult.refused => WelfareText.loginRefused,
    LoginClaimResult.failed => WelfareText.loginFailed,
  };
  if (message != null) feed.setLoginMessage(message);
}

/// Every gift of one check-in day (small tiles draw only the first one).
/// Today's card carries the "Nhận quà" button.
class LoginDayDetail extends StatelessWidget {
  const LoginDayDetail({super.key, required this.feed, required this.onClaim});

  final WelfareFeed feed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final day = feed.detailDay!;
    final plan = feed.plan;
    final state = plan.tile(day);
    final bundle = feed.config.day(day, cycle: plan.cycle);
    final canClaim = state == LoginTile.today && plan.canClaim;
    final status = switch (state) {
      LoginTile.claimed => WelfareText.loginDetailClaimed,
      LoginTile.today => WelfareText.loginDetailToday,
      LoginTile.locked => WelfareText.loginDetailLocked,
    };
    void close() => feed.showDay(null);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: close,
            child: const ColoredBox(color: Color(0x55000000)),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          top: 150,
          child: GestureDetector(
            onTap: () {},
            child: SkinPopup(
              key: const Key('login-detail'),
              title: WelfareText.loginDay(day),
              ribbonWidth: 150,
              onClose: close,
              closeKey: const Key('login-detail-close'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    status,
                    key: const Key('login-detail-status'),
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 13, weight: 800),
                  ),
                  const SizedBox(height: 8),
                  SkinTray(
                    child: Opacity(
                      opacity: state == LoginTile.claimed ? 0.6 : 1,
                      child: RewardBundleView(
                        key: const Key('login-detail-gifts'),
                        bundle: bundle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bundle.label,
                    key: const Key('login-detail-label'),
                    textAlign: TextAlign.center,
                    style: AppText.caption(),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: SizedBox(
                      width: 170,
                      child: canClaim
                          ? SkinButton(
                              key: const Key('login-detail-claim'),
                              label: feed.loginBusy
                                  ? WelfareText.loginBusy
                                  : WelfareText.loginClaim,
                              height: 50,
                              enabled: !feed.loginBusy,
                              onPressed: feed.loginBusy ? null : onClaim,
                            )
                          : SkinButton(
                              key: const Key('login-detail-ok'),
                              label: WelfareText.loginDetailClose,
                              kind: SkinButtonKind.secondary,
                              height: 46,
                              fontSize: 16,
                              onPressed: close,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
