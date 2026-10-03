import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../logic/giftcodes.dart';
import '../logic/login_rewards.dart';
import '../logic/rewards.dart';
import '../logic/welfare.dart';
import '../logic/welfare_slides.dart';
import '../logic/welfare_text.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'login_tiles.dart';
import 'reward_bundle_view.dart';
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
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    size: 20,
                    color: AppColors.primaryBase,
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
              left: 20,
              top: 72,
              width: 320,
              height: 500,
              child: GestureDetector(
                onTap: () {},
                child: CardBox(
                  key: const Key('welfare-sheet'),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            BackButtonBox(
                              key: const Key('welfare-back'),
                              onTap: feed.close,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Phúc lợi',
                                style: AppText.heading(size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _tab(context, WelfareTab.login, 'Điểm danh'),
                          const SizedBox(width: 6),
                          _tab(context, WelfareTab.giftcode, 'Giftcode'),
                          const SizedBox(width: 6),
                          _tab(context, WelfareTab.slides, 'Bạn biết?'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(child: _body(context)),
                    ],
                  ),
                ),
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
      child: GestureDetector(
        key: Key('welfare-tab-${tab.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          SoundScope.maybeOf(context)?.effect('ui_tab');
          feed.selectTab(tab);
        },
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.primaryBase : AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            label,
            style: AppText.body(
              size: 13,
              weight: 800,
              color: on ? AppColors.onPrimary : AppColors.textPrimary,
            ),
          ),
        ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
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
          SizedBox(
            height: 44,
            child: ChunkyButton(
              key: const Key('welfare-sign-in'),
              label: 'Đăng nhập Google',
              fontSize: 15,
              onPressed: () => onSignIn!(),
            ),
          ),
        const Spacer(),
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
  String? _message;

  Future<void> _claim() async {
    final sounds = SoundScope.maybeOf(context);
    final result = await widget.feed.claimLogin(
      allowed: widget.canClaim(),
      grant: widget.grant,
    );
    if (!mounted) return;
    if (result == LoginClaimResult.claimed) {
      sounds?.effect('diem_danh');
    } else if (result != LoginClaimResult.busy) {
      sounds?.effect('error');
    }
    final message = switch (result) {
      LoginClaimResult.claimed => WelfareText.loginDone(
        widget.feed.loginState.claimedCount,
      ),
      LoginClaimResult.already => WelfareText.loginAlready,
      LoginClaimResult.finished => WelfareText.loginFinished(
        repeat: widget.feed.config.repeat,
      ),
      LoginClaimResult.busy => null,
      LoginClaimResult.refused => WelfareText.loginRefused,
      LoginClaimResult.failed => WelfareText.loginFailed,
    };
    if (message != null) setState(() => _message = message);
  }

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
    final note =
        _message ??
        (plan.claimedToday
            ? WelfareText.loginAlready
            : plan.finished
            ? WelfareText.loginFinished(repeat: feed.config.repeat)
            : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          WelfareText.loginTitle,
          key: const Key('login-title'),
          textAlign: TextAlign.center,
          style: AppText.heading(size: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var n = 1; n <= 4; n++) ...[
              if (n > 1) const SizedBox(width: 6),
              Expanded(child: _tile(n, plan)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _tile(5, plan)),
            const SizedBox(width: 6),
            Expanded(child: _tile(6, plan)),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: _tile(7, plan)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Đã nhận ${plan.shownCount}/$loginRewardDays ngày',
          key: const Key('login-progress'),
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, weight: 800),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note,
            key: const Key('login-message'),
            textAlign: TextAlign.center,
            style: AppText.caption(),
          ),
        ],
        const Spacer(),
        SizedBox(
          height: 44,
          child: ChunkyButton(
            key: const Key('login-claim'),
            label: label,
            fontSize: 15,
            enabled: plan.canClaim && !busy,
            onPressed: plan.canClaim && !busy ? _claim : null,
          ),
        ),
      ],
    );
  }

  Widget _tile(int n, LoginPlan plan) {
    final state = plan.tile(n);
    return LoginDayTile(
      day: n,
      state: state,
      bundle: widget.feed.config.day(n),
      onTap: state == LoginTile.today && !widget.feed.loginBusy ? _claim : null,
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
              child: TextField(
                key: const Key('giftcode-input'),
                controller: _code,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => busy ? null : _submit(),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: WelfareText.codeHint,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 84,
              child: ChunkyButton(
                key: const Key('giftcode-submit'),
                label: busy ? '…' : WelfareText.codeButton,
                height: 40,
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
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
