import 'dart:async';

import 'package:flutter/material.dart';

import '../data/phale_shop.dart';
import '../logic/phale_shop_controller.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'phale_order_screen.dart';
import 'phale_popups.dart';
import 'phale_text.dart';
import 'reward_bundle_view.dart' show PhaLeIcon;
import 'ui_skin.dart';

/// Everything of the Pha lê shop in one overlay: S1 or the transfer screen S6,
/// and the popups S2a–S2e, S6f over them. Shown while
/// `session.phaleShopOpen`; the Pha lê itself is only ever written by the
/// server (the screens just show what the controller reports).
class PhaleShopHost extends StatelessWidget {
  const PhaleShopHost({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final c = session.phaleShop;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final onOrder =
            c.step == PhaleStep.order ||
            c.step == PhaleStep.cancelAsk ||
            c.step == PhaleStep.done;
        return Stack(
          children: [
            Positioned.fill(
              child: onOrder
                  ? PhaleOrderScreen(session: session)
                  : PhaleShopScreen(session: session),
            ),
            if (c.step == PhaleStep.confirm && c.pack != null)
              Positioned.fill(
                child: PhaleConfirmPopup(session: session, pack: c.pack!),
              ),
            if (c.step == PhaleStep.creating)
              const Positioned.fill(child: PhaleCreatingPopup()),
            if (c.step == PhaleStep.createFailed)
              Positioned.fill(child: PhaleCreateFailPopup(session: session)),
            if (c.step == PhaleStep.cancelAsk)
              Positioned.fill(child: PhaleCancelAskPopup(session: session)),
            if (c.step == PhaleStep.cancelled)
              Positioned.fill(child: PhaleCancelledPopup(session: session)),
            if (c.step == PhaleStep.done && c.order != null)
              Positioned.fill(child: PhaleDonePopup(session: session)),
          ],
        );
      },
    );
  }
}

/// Rebuilds [builder] every second (countdowns).
class SecondTicker extends StatefulWidget {
  const SecondTicker({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<SecondTicker> createState() => _SecondTickerState();
}

class _SecondTickerState extends State<SecondTicker> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// S1: the six packs (S5c while the shop is closed, S3 for a guest).
class PhaleShopScreen extends StatelessWidget {
  const PhaleShopScreen({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final c = s.phaleShop;
    final cfg = c.config;
    final guest = c.open && !s.signedIn;
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        key: const Key('phale-shop'),
        children: [
          Positioned.fill(
            top: 108,
            child: ListView(
              key: const Key('phale-shop-list'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                if (!c.open)
                  const _Strip(
                    key: Key('phale-soon'),
                    icon: Icons.schedule_rounded,
                    text: PhaleText.soonBanner,
                  )
                else if (guest)
                  _Strip(
                    key: const Key('phale-guest'),
                    icon: Icons.priority_high_rounded,
                    text: PhaleText.guestStrip,
                    action: PhaleText.guestBtn,
                    onAction: s.signIn,
                  ),
                if (c.context != null) ...[
                  const SizedBox(height: 6),
                  _Strip(
                    key: const Key('phale-ctx'),
                    icon: Icons.diamond_outlined,
                    text: PhaleText.ctxBanner(c.context!.need, c.context!.name),
                    soft: true,
                  ),
                ],
                if (c.hasPending) ...[
                  const SizedBox(height: 6),
                  SecondTicker(
                    builder: (_) => c.hasPending
                        ? _Strip(
                            key: const Key('phale-pending'),
                            icon: Icons.timer_outlined,
                            text: PhaleText.pendingTitle,
                            sub: PhaleText.pendingSub(
                              vndLabel(c.order!.amount),
                              PhaleText.clock(c.remaining),
                            ),
                            action: PhaleText.pendingBtn,
                            onAction: c.viewOrder,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        PhaleText.pick,
                        style: AppText.title(size: 16, weight: 800),
                      ),
                    ),
                    _BalanceChip(amount: s.state.phaLe),
                  ],
                ),
                const SizedBox(height: 10),
                if (cfg.packs.isEmpty)
                  const _NoPacks()
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 14,
                    children: [
                      for (final p in cfg.packs) _PackCard(session: s, pack: p),
                    ],
                  ),
                const SizedBox(height: 16),
                _UseBlock(session: s),
                const SizedBox(height: 12),
                _Note(session: s),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: TopBar(
              session: s,
              showRating: false,
              showDay: false,
              showPhaLe: true,
              phaleAdd: false,
            ),
          ),
          Positioned(
            left: 16,
            top: 54,
            child: SkinRoundButton(
              key: const Key('phale-back'),
              kind: SkinRound.back,
              width: 40,
              onTap: s.closePhaleShop,
            ),
          ),
          const Positioned(
            left: 70,
            right: 70,
            top: 54,
            child: Center(
              child: SkinRibbon(
                title: PhaleText.title,
                width: 200,
                height: 46,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The amber strip under the ribbon: soon (S5c), guest (S3), the context of a
/// shortfall (S4c) and the waiting order (S6g).
class _Strip extends StatelessWidget {
  const _Strip({
    super.key,
    required this.icon,
    required this.text,
    this.sub,
    this.action,
    this.onAction,
    this.soft = false,
  });

  final IconData icon;
  final String text;
  final String? sub;
  final String? action;
  final VoidCallback? onAction;

  /// A plain note on the green tint instead of the amber warning.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final fg = soft ? AppColors.primaryPressed : const Color(0xFF8A5A12);
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: soft ? AppColors.primarySoft : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: soft ? AppColors.primaryBase : AppColors.statusWarning,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: AppText.body(size: 12.5, weight: 800, color: fg),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: AppText.caption(
                      size: 11.5,
                      weight: 700,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryBase,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  action!,
                  style: AppText.button(size: 13, color: AppColors.onPrimary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('phale-balance'),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PhaLeIcon(size: 18),
          const SizedBox(width: 4),
          Text(coinFull(amount), style: AppText.number(size: 14, weight: 800)),
        ],
      ),
    );
  }
}

class _NoPacks extends StatelessWidget {
  const _NoPacks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('phale-error'),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(PhaleText.errTitle, style: AppText.title(size: 18)),
          const SizedBox(height: 4),
          Text(PhaleText.errBody, style: AppText.body(size: 13)),
        ],
      ),
    );
  }
}

/// A transparent catcher over a disabled button (the skin button swallows its
/// own taps), so a blocked "Mua" can still say why.
class BlockedTap extends StatelessWidget {
  const BlockedTap({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.session, required this.pack});

  final ShopSession session;
  final PhaPack pack;

  @override
  Widget build(BuildContext context) {
    final c = session.phaleShop;
    final best = c.config.bestPackId == pack.id;
    final canBuy = c.canBuy;
    void blocked() {
      switch (c.block) {
        case PhaleBlock.closed:
          showGameToast(context, PhaleText.soonToast);
        case PhaleBlock.guest:
          showGameToast(context, PhaleText.guestToast);
        case PhaleBlock.none:
          break;
      }
    }

    final label = !c.open ? PhaleText.soonBtn : PhaleText.buy;
    final button = SkinButton(
      key: Key('phale-buy-${pack.id}'),
      label: label,
      height: 32,
      fontSize: 15,
      enabled: canBuy,
      onPressed: canBuy ? () => c.pick(pack.id) : null,
    );
    final card = Container(
      key: Key('phale-pack-${pack.id}'),
      width: 159,
      height: 140,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: best ? AppColors.primaryBase : AppColors.surfaceBorder,
          width: best ? 2.5 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.surfaceBorderStrong, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 46,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // All six pictures stand on one baseline: same box, same
                // bottom alignment.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 1),
                    child: Image.asset(
                      Art.phale(pack.id),
                      alignment: Alignment.bottomCenter,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                if (pack.hasBonus)
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Container(
                      height: 19,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.statusSuccess,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        PhaleText.bonus(pack.bonusPercent),
                        style: AppText.button(size: 12.5, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const PhaLeIcon(size: 18),
              const SizedBox(width: 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: coinFull(pack.phaLe),
                          style: AppText.number(size: 20, weight: 800),
                        ),
                        TextSpan(
                          text: ' Pha lê',
                          style: AppText.body(
                            size: 11.5,
                            weight: 800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(
            PhaleText.price(pack.priceVnd),
            style: AppText.number(
              size: 14,
              weight: 700,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 32,
            child: canBuy ? button : BlockedTap(onTap: blocked, child: button),
          ),
        ],
      ),
    );
    if (!best) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -9,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              key: const Key('phale-best'),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryPressed,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                PhaleText.best,
                style: AppText.button(size: 12, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Pha lê dùng để làm gì": three tiles that open the three shops.
class _UseBlock extends StatelessWidget {
  const _UseBlock({required this.session});

  final ShopSession session;

  int? _min(Iterable<int> prices) =>
      prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);

  @override
  Widget build(BuildContext context) {
    final s = session;
    final e = s.e;
    final pot = _min([
      for (final p in e.pots)
        if (p.paysPhaLe) p.cost,
    ]);
    final pet = _min([
      for (final p in e.pets)
        if (p.paysPhaLe) p.price,
    ]);
    final item = _min([
      for (final i in e.petItems)
        if (i.paysPhaLe) i.price,
    ]);
    void go(VoidCallback open) {
      s.closePhaleShop();
      open();
    }

    Widget tile(String key, String label, int? from, VoidCallback open) {
      return Expanded(
        child: GestureDetector(
          key: Key(key),
          behavior: HitTestBehavior.opaque,
          onTap: () => go(open),
          child: Container(
            height: 76,
            padding: const EdgeInsets.fromLTRB(8, 8, 6, 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(size: 13.5, weight: 800),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const Spacer(),
                if (from != null)
                  Row(
                    children: [
                      const PhaLeIcon(size: 16),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          PhaleText.useFrom(from),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.number(size: 13, weight: 800),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(PhaleText.useTitle, style: AppText.title(size: 15, weight: 800)),
        const SizedBox(height: 8),
        Row(
          children: [
            tile('phale-use-pot', PhaleText.usePot, pot, () => s.openPotShop()),
            const SizedBox(width: 8),
            tile('phale-use-pet', PhaleText.usePet, pet, s.openPetShop),
            const SizedBox(width: 8),
            tile(
              'phale-use-item',
              PhaleText.useItem,
              item,
              () => s.openPetItemShop(),
            ),
          ],
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                PhaleText.note,
                key: const Key('phale-note'),
                style: AppText.body(
                  size: 12,
                  weight: 700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: const Key('phale-link-terms'),
          behavior: HitTestBehavior.opaque,
          onTap: session.openTermsReview,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                PhaleText.linkTerms,
                style: AppText.body(
                  size: 12.5,
                  weight: 800,
                  color: AppColors.primaryPressed,
                ).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
