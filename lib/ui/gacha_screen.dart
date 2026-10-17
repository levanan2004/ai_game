import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/gacha.dart';
import '../logic/price_format.dart' show coinFull;
import '../logic/rewards.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'gacha_text.dart';
import 'game_toast.dart';
import 'reward_bundle_view.dart';
import 'ui_skin.dart';

/// Countdown on the last day: a darker orange that keeps 4.5:1 on cream.
const _orange = Color(0xFFA9531A);
const _coinShadow = Color(0xFFC9932A);

/// "0h thứ Hai 26/10" (Việt Nam time) for {week_end}.
String gachaWeekEnd(DateTime? end) {
  if (end == null) return '';
  final vn = end.toUtc().add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '0h thứ Hai ${two(vn.day)}/${two(vn.month)}';
}

/// "dd/MM" (Việt Nam time).
String gachaDate(DateTime? at) {
  if (at == null) return '';
  final vn = at.toUtc().add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(vn.day)}/${two(vn.month)}';
}

/// "1 ngày 5 giờ" for {time_left} (Nhất's example).
String gachaTimeLeft(Duration d) {
  final days = d.inDays;
  final hours = d.inHours - days * 24;
  return days > 0 ? '$days ngày $hours giờ' : '$hours giờ';
}

/// A rate out of the table total, "1%", "0,5%".
String gachaRate(int w, int total) {
  if (total <= 0) return '0%';
  final p = w * 100 / total;
  final s = p == p.roundToDouble()
      ? p.toStringAsFixed(0)
      : p.toStringAsFixed(p < 1 ? 2 : 1).replaceAll(RegExp(r'0+$'), '');
  return '${s.replaceAll('.', ',')}%';
}

/// Nhất's text of a [GachaNote].
String gachaNoteText(GachaController g, GachaNote n) => switch (n.kind) {
  GachaNoteKind.spinFail => GachaText.spinFail(n.code),
  GachaNoteKind.buyFail => GachaText.buyFail(n.code),
  GachaNoteKind.buySuccess => GachaText.buySuccessToast(n.a, n.b),
  GachaNoteKind.xuDailyOut => GachaText.xuDailyOut(n.a),
  GachaNoteKind.xuOverLimit => GachaText.xuOverLimit(n.a),
  GachaNoteKind.notEnoughXu => GachaText.notEnoughXu,
  GachaNoteKind.notEnoughPl => GachaText.notEnoughPl,
  GachaNoteKind.resetNotice => GachaText.pityResetNotice(g.potName(g.potId)),
  GachaNoteKind.reminder => GachaText.pityReminder(
    n.a,
    n.b,
    g.potName(g.potId),
    gachaTimeLeft(n.left ?? Duration.zero),
  ),
};

String _ticket(String? potId) =>
    (potId == null ? null : GachaText.ticketName(potId)) ??
    GachaText.ticketNameGeneric;

/// One reward's line in the result ("Bạn nhận được 500.000 xu.").
String _resultLine(GachaController g, SpinResult r) {
  final pot = g.potName(g.potId);
  if (r.featured && r.dup) {
    return GachaText.resultDupXu(pot, coinFull(g.dupCoins));
  }
  if (r.featured) return GachaText.resultFeatured(pot);
  final items = r.items.items;
  if (items.length == 1 && items.first.kind == RewardKind.coins) {
    return GachaText.resultXu(coinFull(items.first.amount));
  }
  return GachaText.resultItem(r.items.label);
}

/// Vòng quay tuần (spec 1 G1, Nhất 1a): banner, the week's card, the wheel
/// with its glow, the countdown beside the pity counter, cards and the two
/// spin buttons. Popups: Tỉ lệ, results, thiếu thẻ, mua thẻ, kho thẻ, lịch
/// sử quay, one-time notices.
class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wheel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  double _from = 0;
  double _to = 0;
  final _rng = math.Random();

  GachaController get g => widget.session.gacha;

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  void _showToast() {
    final t = g.toast;
    if (t == null) return;
    g.clearToast();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showGameToast(context, gachaNoteText(g, t));
    });
  }

  Future<void> _spin(int count) async {
    if (_wheel.isAnimating) return;
    final res = await g.spin(count);
    if (res == null || !mounted) return;
    if (count > 1) {
      g.showResults();
      return;
    }
    // One spin: the wheel turns 2.6 s and stops on a segment (8 painted
    // segments; the featured pot stops on the top one).
    final seg = res.first.featured ? 0 : 1 + _rng.nextInt(7);
    _from = _to % 1;
    _to = _from.floorToDouble() + 5 + (1 - seg / 8);
    _wheel.reset();
    await _wheel.forward();
    if (mounted) g.showResults();
  }

  void _skipWheel() {
    if (_wheel.isAnimating) _wheel.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return ListenableBuilder(
      listenable: Listenable.merge([g, s]),
      builder: (context, _) {
        _showToast();
        final potId = g.potId;
        return OpaqueScreen(
          color: AppColors.bgBase,
          child: Stack(
            key: const Key('gacha-screen'),
            children: [
              if (potId == null)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        GachaText.ended,
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 14, weight: 700),
                      ),
                    ),
                  ),
                )
              else
                ..._main(s, potId),
              Positioned(
                left: 12,
                top: 46,
                child: SkinRoundButton(
                  key: const Key('gacha-back'),
                  kind: SkinRound.back,
                  width: 40,
                  onTap: g.closeScreen,
                ),
              ),
              const Positioned(
                left: 64,
                right: 92,
                top: 46,
                child: Center(
                  child: SkinRibbon(
                    title: GachaText.weekTitle,
                    width: 190,
                    height: 44,
                    fontSize: 17,
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 48,
                child: _OddsChip(onTap: () => g.showPopup(GachaPopup.odds)),
              ),
              if (g.popup != GachaPopup.none) Positioned.fill(child: _popup(s)),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _main(ShopSession s, String potId) {
    final asset = g.assetOf(potId);
    final pot = g.pot(potId);
    final name = g.potName(potId);
    return [
      // Banner with the week's pot.
      Positioned(
        left: 50,
        right: 50,
        top: 94,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (asset != null)
              Positioned.fill(
                child: Image.asset(
                  Art.gachaPot(asset, 'banner'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 58),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      GachaText.weekCardTitle(name),
                      key: const Key('gacha-pot-name'),
                      maxLines: 1,
                      style: AppText.title(size: 16, weight: 800),
                    ),
                  ),
                  if (pot != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        GachaText.weekCardSub(pot.charm),
                        maxLines: 1,
                        style: AppText.caption(
                          size: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      // The week's card (left) and the wheel (right).
      Positioned(
        left: 12,
        top: 230,
        width: 120,
        height: 168,
        child: _WeekCard(g: g, potId: potId),
      ),
      Positioned(
        left: 140,
        top: 218,
        width: 212,
        height: 196,
        child: _Wheel(
          asset: asset,
          turns: _wheel,
          from: () => _from,
          to: () => _to,
          onTap: g.spinning ? _skipWheel : null,
        ),
      ),
      // Countdown beside the pity counter.
      Positioned(left: 12, right: 12, top: 418, child: _WeekLine(g: g)),
      if (s.signedIn) ...[
        Positioned(
          left: 12,
          right: 12,
          top: 476,
          height: 40,
          child: _CardsRow(g: g, potId: potId),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 522,
          height: 56,
          child: _SpinButtons(g: g, onSpin: _spin),
        ),
      ] else
        Positioned(
          left: 24,
          right: 24,
          top: 482,
          child: Column(
            children: [
              Text(
                GachaText.guestLocked,
                key: const Key('gacha-guest'),
                textAlign: TextAlign.center,
                style: AppText.body(size: 14, weight: 800),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: SkinButton(label: 'Đăng nhập', onPressed: s.signIn),
              ),
            ],
          ),
        ),
      Positioned(
        left: 0,
        right: 0,
        top: 586,
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (s.signedIn)
              TextButton(
                key: const Key('gacha-history-open'),
                onPressed: () => g.showPopup(GachaPopup.history),
                child: Text(
                  GachaText.historyBtn,
                  style: AppText.body(
                    size: 13,
                    weight: 800,
                    color: AppColors.primaryPressed,
                  ),
                ),
              ),
          ],
        ),
      ),
      if (g.pending.isNotEmpty && g.popup == GachaPopup.none)
        Positioned(left: 12, right: 12, top: 230, child: _PendingBar(g: g)),
    ];
  }

  Widget _popup(ShopSession s) {
    return switch (g.popup) {
      GachaPopup.none => const SizedBox.shrink(),
      GachaPopup.result => _ResultPopup(g: g, onAgain: _spin),
      GachaPopup.short => _ShortPopup(g: g),
      GachaPopup.buy => _BuySheet(g: g),
      GachaPopup.plConfirm => _PlConfirm(g: g),
      GachaPopup.odds => _OddsSheet(g: g),
      GachaPopup.history => _HistorySheet(g: g),
      GachaPopup.cards => _CardsSheet(g: g),
      GachaPopup.notice => _NoticePopup(g: g),
    };
  }
}

// ---- pieces of the main screen ------------------------------------------------

class _OddsChip extends StatelessWidget {
  const _OddsChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('gacha-odds-open'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.primaryBase, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              GachaText.oddsBtn,
              style: AppText.body(
                size: 13,
                weight: 800,
                color: AppColors.primaryPressed,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.info_outline,
              size: 16,
              color: AppColors.primaryBase,
            ),
          ],
        ),
      ),
    );
  }
}

/// `gacha/<id>/the.webp` with the pot inside and its name on the scroll.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.g, required this.potId});

  final GachaController g;
  final String potId;

  @override
  Widget build(BuildContext context) {
    final asset = g.assetOf(potId);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          key: const Key('gacha-week-card'),
          children: [
            if (asset != null)
              Positioned.fill(
                child: Image.asset(
                  Art.gachaPot(asset, 'the'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // The pot sits inside the frame (its inside is painted).
            Positioned(
              left: w * 0.16,
              right: w * 0.16,
              top: h * 0.2,
              bottom: h * 0.26,
              child: ArtImage(Art.pot(potId), size: w * 0.68),
            ),
            Positioned(
              left: w * 0.2,
              right: w * 0.2,
              bottom: h * 0.09,
              height: h * 0.1,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  g.potName(potId).replaceFirst('Chậu ', ''),
                  maxLines: 1,
                  style: AppText.title(size: 13, weight: 800),
                ),
              ),
            ),
            if (g.ownsPot)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBase,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      GachaText.ownedBadge,
                      key: const Key('gacha-owned-badge'),
                      style: AppText.caption(
                        size: 10,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The wheel: vang_sang glow behind, vong_quay turning, the pointer on top.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.asset,
    required this.turns,
    required this.from,
    required this.to,
    this.onTap,
  });

  final String? asset;
  final Animation<double> turns;
  final double Function() from;
  final double Function() to;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = asset;
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = math.min(c.maxWidth, c.maxHeight);
          return Stack(
            alignment: Alignment.center,
            children: [
              if (a != null)
                Image.asset(
                  Art.gachaPot(a, 'vang_sang'),
                  key: const Key('gacha-glow'),
                  width: side,
                  height: side,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              AnimatedBuilder(
                animation: turns,
                builder: (context, child) {
                  final t = Curves.easeOutCubic.transform(turns.value);
                  final v = from() + (to() - from()) * t;
                  return Transform.rotate(angle: v * 2 * math.pi, child: child);
                },
                child: a == null
                    ? const SizedBox.shrink()
                    : Image.asset(
                        Art.gachaPot(a, 'vong_quay'),
                        key: const Key('gacha-wheel'),
                        width: side * 0.78,
                        height: side * 0.78,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
              ),
              Positioned(
                top: side * 0.02,
                child: Image.asset(
                  Art.gacha('vong_quay_kim'),
                  width: side * 0.13,
                  height: side * 0.17,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.templeGold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "Đổi chậu lúc … · còn X ngày Y giờ" beside "Còn N lượt chắc chắn ra …".
/// The last day the countdown turns orange and `reset_soon` shows.
class _WeekLine extends StatelessWidget {
  const _WeekLine({required this.g});

  final GachaController g;

  @override
  Widget build(BuildContext context) {
    final left = g.timeLeft;
    final soon = g.lastDay;
    final pot = g.potName(g.potId);
    Widget box({
      required Key key,
      required List<Widget> children,
      Color? border,
    }) => Expanded(
      child: Container(
        key: key,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: border ?? AppColors.surfaceBorder,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        box(
          key: const Key('gacha-countdown'),
          border: soon ? AppColors.secondaryBase : null,
          children: [
            Text(
              GachaText.weekCountdown(gachaWeekEnd(g.weekEnd), left),
              maxLines: 2,
              style: AppText.body(
                size: 11.5,
                weight: 800,
                color: soon ? _orange : AppColors.textPrimary,
              ),
            ),
            if (soon)
              Text(
                GachaText.pityResetSoon,
                key: const Key('gacha-reset-soon'),
                maxLines: 1,
                style: AppText.caption(
                  size: 10,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(width: 6),
        box(
          key: const Key('gacha-pity'),
          children: [
            Text(
              g.pityLeft == 1
                  ? GachaText.pityNext(pot)
                  : GachaText.pityCounter(g.pityLeft, pot),
              maxLines: 2,
              style: AppText.body(size: 11.5, weight: 800),
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: g.pityAt <= 0 ? 0 : g.pityCount / g.pityAt,
                  backgroundColor: AppColors.freshnessTrack,
                  color: AppColors.accentBase,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// This week's card count and "Mua thẻ"; the card icon opens Kho thẻ.
class _CardsRow extends StatelessWidget {
  const _CardsRow({required this.g, required this.potId});

  final GachaController g;
  final String potId;

  @override
  Widget build(BuildContext context) {
    final k = g.cards;
    return Row(
      children: [
        GestureDetector(
          key: const Key('gacha-cards-open'),
          onTap: () => g.showPopup(GachaPopup.cards),
          child: Semantics(
            label: k > 0 ? GachaText.owned(k) : GachaText.ownedZero,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ticketCardIcon(
                      potId,
                      size: 40,
                      assetId: g.assetOf(potId),
                    ),
                  ),
                  Positioned(right: -2, bottom: -2, child: _CountBadge(k)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            k > 0 ? GachaText.owned(k) : GachaText.ownedZero,
            key: const Key('gacha-owned'),
            maxLines: 2,
            style: AppText.body(size: 12.5, weight: 800),
          ),
        ),
        SizedBox(
          width: 112,
          height: 40,
          child: ChunkyButton(
            key: const Key('gacha-buy-open'),
            label: GachaText.buyBtn,
            kind: ButtonKind.secondary,
            fontSize: 14,
            onPressed: () => g.openBuy(1),
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.n);

  final int n;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryPressed,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.onPrimary, width: 1.5),
      ),
      child: Text(
        '$n',
        textAlign: TextAlign.center,
        style: AppText.caption(size: 10.5, color: AppColors.onPrimary),
      ),
    );
  }
}

class _SpinButtons extends StatelessWidget {
  const _SpinButtons({required this.g, required this.onSpin});

  final GachaController g;
  final Future<void> Function(int count) onSpin;

  @override
  Widget build(BuildContext context) {
    Widget button(int count, Key key) {
      final busy = g.spinning;
      final one = count == 1;
      return Expanded(
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: busy || g.buying ? null : () => onSpin(count),
          child: Container(
            decoration: BoxDecoration(
              color: busy
                  ? AppColors.surfaceSunken
                  : one
                  ? AppColors.primaryBase
                  : AppColors.accentBase,
              borderRadius: BorderRadius.circular(16),
              boxShadow: busy
                  ? null
                  : [
                      BoxShadow(
                        color: one ? AppColors.primaryPressed : _coinShadow,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  busy
                      ? GachaText.btnSpinning
                      : one
                      ? GachaText.btnX1
                      : GachaText.btnX10,
                  style: AppText.title(
                    size: 16,
                    weight: 800,
                    color: busy
                        ? AppColors.textDisabled
                        : one
                        ? AppColors.onPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                if (!busy)
                  Text(
                    one ? GachaText.btnCostX1 : GachaText.btnCostX10,
                    style: AppText.caption(
                      size: 10.5,
                      color: one ? AppColors.onPrimary : AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        button(1, const Key('gacha-spin-1')),
        const SizedBox(width: 10),
        button(10, const Key('gacha-spin-10')),
      ],
    );
  }
}

class _PendingBar extends StatelessWidget {
  const _PendingBar({required this.g});

  final GachaController g;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('gacha-pending'),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accentBase),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              GachaText.pending,
              style: AppText.body(size: 12, weight: 800),
            ),
          ),
          SizedBox(
            width: 80,
            height: 36,
            child: ChunkyButton(
              key: const Key('gacha-pending-claim'),
              label: GachaText.resultClaim,
              fontSize: 14,
              onPressed: g.claimPending,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- popups -----------------------------------------------------------------

/// Dim layer + a card in the middle (or a sheet at the bottom).
class _Modal extends StatelessWidget {
  const _Modal({
    required this.child,
    this.onDismiss,
    this.sheet = false,
    this.modalKey,
  });

  final Widget child;
  final VoidCallback? onDismiss;
  final bool sheet;
  final Key? modalKey;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      key: modalKey,
      margin: sheet
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        borderRadius: sheet
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            child: const ColoredBox(color: AppColors.bgOverlay),
          ),
        ),
        if (sheet)
          Positioned(left: 0, right: 0, bottom: 0, child: card)
        else
          Center(child: card),
      ],
    );
  }
}

Widget _title(String text) => Text(
  text,
  textAlign: TextAlign.center,
  style: AppText.title(size: 18, weight: 800),
);

Widget _note(String text, {Key? key}) => Padding(
  padding: const EdgeInsets.only(top: 4),
  child: Text(
    text,
    key: key,
    style: AppText.caption(size: 11, color: AppColors.textSecondary),
  ),
);

/// Quay 1: one prize, big. Quay 10: a 5×2 grid revealed card by card
/// ("Bỏ qua" shows all), then "Nhận hết".
class _ResultPopup extends StatefulWidget {
  const _ResultPopup({required this.g, required this.onAgain});

  final GachaController g;
  final Future<void> Function(int count) onAgain;

  @override
  State<_ResultPopup> createState() => _ResultPopupState();
}

class _ResultPopupState extends State<_ResultPopup> {
  int _shown = 0;
  Timer? _timer;

  GachaController get g => widget.g;

  @override
  void initState() {
    super.initState();
    if (g.results.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 120), (t) {
        if (!mounted) return;
        setState(() => _shown++);
        if (_shown >= g.results.length) t.cancel();
      });
    } else {
      _shown = g.results.length;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _skip() {
    _timer?.cancel();
    setState(() => _shown = g.results.length);
  }

  @override
  Widget build(BuildContext context) {
    final res = g.results;
    final many = res.length > 1;
    final all = _shown >= res.length;
    final pot = g.potName(g.potId);
    final hit = res.where((r) => r.featured).toList();
    final pityHit = res.any((r) => r.pity);
    return _Modal(
      modalKey: const Key('gacha-result'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(
            hit.isNotEmpty && hit.first.dup && !many
                ? GachaText.resultDupTitle
                : many
                ? GachaText.resultTitleX10
                : GachaText.resultTitle,
          ),
          const SizedBox(height: 10),
          if (!many && res.isNotEmpty) _single(res.first) else _grid(res),
          if (pityHit && all) ...[
            const SizedBox(height: 6),
            Text(
              hit.isNotEmpty && hit.first.dup
                  ? GachaText.pityHitDup(pot, coinFull(g.dupCoins))
                  : GachaText.pityHit(pot),
              key: const Key('gacha-pity-hit'),
              textAlign: TextAlign.center,
              style: AppText.body(
                size: 12.5,
                weight: 800,
                color: AppColors.primaryPressed,
              ),
            ),
          ],
          if (all) ...[
            _note(GachaText.resultSavedNote),
            _note(GachaText.resultTicketsLeft(g.cards)),
          ],
          const SizedBox(height: 10),
          if (many && !all)
            SizedBox(
              height: 46,
              child: ChunkyButton(
                key: const Key('gacha-result-skip'),
                label: GachaText.resultSkip,
                kind: ButtonKind.secondary,
                onPressed: _skip,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ChunkyButton(
                      key: const Key('gacha-result-claim'),
                      label: many
                          ? GachaText.resultClaimAll
                          : GachaText.resultClaim,
                      fontSize: 16,
                      enabled: !g.claiming,
                      onPressed: g.claiming ? null : g.claimResults,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ChunkyButton(
                      key: const Key('gacha-result-again'),
                      label: many
                          ? GachaText.resultAgainX10
                          : GachaText.resultAgain,
                      kind: ButtonKind.secondary,
                      fontSize: 14,
                      onPressed: g.claiming
                          ? null
                          : () async {
                              await g.claimResults();
                              await widget.onAgain(many ? 10 : 1);
                            },
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _single(SpinResult r) {
    final featuredNew = r.featured && !r.dup;
    final pot = g.pot(g.potId);
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (r.featured)
                Image.asset(
                  Art.gacha('tia_sang'),
                  width: 150,
                  height: 150,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              if (r.items.items.isNotEmpty)
                rewardIcon(r.items.items.first, size: 96),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _resultLine(g, r),
          key: const Key('gacha-result-line'),
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, weight: 800),
        ),
        if (featuredNew && pot != null)
          _note(GachaText.resultFeaturedSub(pot.nameVi, pot.charm)),
      ],
    );
  }

  Widget _grid(List<SpinResult> res) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 5,
      runSpacing: 6,
      children: [
        for (var i = 0; i < res.length; i++)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: i < _shown
                ? _cell(res[i], i)
                : Container(
                    key: ValueKey('back-$i'),
                    width: 50,
                    height: 68,
                    alignment: Alignment.center,
                    child: ticketCardIcon(
                      g.potId,
                      size: 50,
                      assetId: g.assetOf(g.potId),
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _cell(SpinResult r, int i) {
    final item = r.items.items.isEmpty ? null : r.items.items.first;
    return Container(
      key: Key('gacha-result-cell-$i'),
      width: 50,
      height: 68,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: r.featured ? AppColors.accentSoft : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: r.featured ? AppColors.templeGold : AppColors.surfaceBorder,
          width: r.featured ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item != null) rewardIcon(item, size: 36),
          if (item != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                rewardAmountText(item),
                maxLines: 1,
                style: AppText.number(size: 11),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Thiếu {N} thẻ" (Nhất 1h): buy the missing cards with xu or Pha lê, then
/// spin right away.
class _ShortPopup extends StatelessWidget {
  const _ShortPopup({required this.g});

  final GachaController g;

  @override
  Widget build(BuildContext context) {
    final n = g.missing;
    final need = g.spinCount;
    final ticket = _ticket(g.potId);
    final left = g.xuLeftToday;
    final xuOk = left == null || left >= n;
    return _Modal(
      modalKey: const Key('gacha-short'),
      onDismiss: g.closePopup,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(GachaText.shortTitle(n)),
          const SizedBox(height: 6),
          Text(
            GachaText.shortBody(g.cards, ticket, need, n),
            style: AppText.body(size: 13, weight: 700),
          ),
          if (!xuOk)
            _note(
              GachaText.shortXuLimit(left, n),
              key: const Key('gacha-short-xu-limit'),
            ),
          _note(GachaText.shortAfterBuy(need)),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: ChunkyButton(
              key: const Key('gacha-short-xu'),
              label: GachaText.shortBtnXu(coinFull(g.cardCoins * n)),
              fontSize: 14,
              enabled: xuOk && !g.buying,
              onPressed: xuOk && !g.buying
                  ? () => g.buy(n, withPhaLe: false, thenSpin: true)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: ChunkyButton(
              key: const Key('gacha-short-pl'),
              label: GachaText.shortBtnPl(coinFull(g.cardPhaLe * n)),
              kind: ButtonKind.secondary,
              fontSize: 14,
              onPressed: g.buying ? null : () => g.askPhaLe(n),
            ),
          ),
          TextButton(
            key: const Key('gacha-short-later'),
            onPressed: g.closePopup,
            child: Text(
              GachaText.shortBtnLater,
              style: AppText.body(size: 14, weight: 800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mua thẻ (Nhất 1g): 1 or 10, xu (daily cap) or Pha lê (confirmed).
class _BuySheet extends StatelessWidget {
  const _BuySheet({required this.g});

  final GachaController g;

  @override
  Widget build(BuildContext context) {
    final potId = g.potId;
    final pot = g.potName(potId);
    final ticket = _ticket(potId);
    final n = g.buyCount;
    final max = g.xuDailyMax;
    final left = g.xuLeftToday;
    final xuOk = left == null || left >= n;
    Widget opt(int count, String label) => Expanded(
      child: GestureDetector(
        key: Key('gacha-buy-opt-$count'),
        onTap: () => g.openBuy(count),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: n == count ? AppColors.primarySoft : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: n == count
                  ? AppColors.primaryBase
                  : AppColors.surfaceBorder,
              width: n == count ? 2 : 1.5,
            ),
          ),
          child: Text(label, style: AppText.body(size: 13, weight: 800)),
        ),
      ),
    );
    return _Modal(
      sheet: true,
      modalKey: const Key('gacha-buy'),
      onDismiss: g.closePopup,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ticketCardIcon(potId, size: 56, assetId: g.assetOf(potId)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        GachaText.buyTitle(ticket),
                        style: AppText.title(size: 17, weight: 800),
                      ),
                      Text(
                        GachaText.buyOwned(g.cards),
                        style: AppText.caption(size: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _note(GachaText.buySubtitle(pot)),
            _note(GachaText.buyWeekOnly(pot, gachaWeekEnd(g.weekEnd))),
            _note(
              GachaText.buyUnitPrice(
                coinFull(g.cardCoins),
                coinFull(g.cardPhaLe),
              ),
            ),
            if (max > 0 && left != null)
              _note(
                left <= 0
                    ? GachaText.xuDailyOut(max)
                    : GachaText.xuDailyLeft(left, max),
                key: const Key('gacha-buy-xu-left'),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                opt(1, GachaText.buyOpt1),
                const SizedBox(width: 8),
                opt(10, GachaText.buyOpt10),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: ChunkyButton(
                key: const Key('gacha-buy-xu'),
                label: GachaText.buyBtnXu(coinFull(g.cardCoins * n)),
                fontSize: 15,
                enabled: xuOk && !g.buying,
                onPressed: xuOk && !g.buying
                    ? () => g.buy(n, withPhaLe: false)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: ChunkyButton(
                key: const Key('gacha-buy-pl'),
                label: GachaText.buyBtnPl(coinFull(g.cardPhaLe * n)),
                kind: ButtonKind.secondary,
                fontSize: 15,
                onPressed: g.buying ? null : () => g.askPhaLe(n),
              ),
            ),
            _note(GachaText.noRefundNote),
            _note(GachaText.giftNote),
            TextButton(
              key: const Key('gacha-buy-cancel'),
              onPressed: g.closePopup,
              child: Text(
                GachaText.buyCancel,
                style: AppText.body(size: 14, weight: 800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Trừ {cost} Pha lê để mua {n} thẻ?" (Nhất 1g): the only Pha lê step.
class _PlConfirm extends StatelessWidget {
  const _PlConfirm({required this.g});

  final GachaController g;

  @override
  Widget build(BuildContext context) {
    final n = g.buyCount;
    final cost = coinFull(g.cardPhaLe * n);
    final thenSpin = g.spinCount > g.cards && n == g.missing;
    return _Modal(
      modalKey: const Key('gacha-pl-confirm'),
      onDismiss: g.closePopup,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(GachaText.plConfirmTitle(cost, n)),
          const SizedBox(height: 6),
          Text(
            GachaText.plConfirmBody(n, cost),
            style: AppText.body(size: 13, weight: 700),
          ),
          _note(GachaText.plConfirmMinor),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ChunkyButton(
                    key: const Key('gacha-pl-cancel'),
                    label: GachaText.plConfirmCancel,
                    kind: ButtonKind.ghost,
                    onPressed: g.closePopup,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ChunkyButton(
                    key: const Key('gacha-pl-ok'),
                    label: GachaText.plConfirmBtn,
                    enabled: !g.buying,
                    onPressed: g.buying
                        ? null
                        : () => g.buy(n, withPhaLe: true, thenSpin: thenSpin),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tỉ lệ (spec G2, Nhất 1b): from `gacha.table_permyriad`, always readable
/// before a spin.
class _OddsSheet extends StatelessWidget {
  const _OddsSheet({required this.g});

  final GachaController g;

  @override
  Widget build(BuildContext context) {
    final c = g.config;
    final total = c.table.fold<int>(0, (a, e) => a + e.weight);
    final pot = g.potName(g.potId);
    final ticket = _ticket(g.potId);
    final dup = coinFull(g.dupCoins);
    final rows = <Widget>[];
    void line(String t, {bool sub = false}) => rows.add(
      Padding(
        padding: EdgeInsets.only(left: sub ? 12 : 0, top: 3),
        child: Text(
          t,
          style: sub
              ? AppText.caption(size: 11.5)
              : AppText.body(size: 13, weight: 800),
        ),
      ),
    );
    for (final e in c.table) {
      final r = gachaRate(e.weight, total);
      switch (e.item) {
        case 'potOfWeek':
          line(
            g.ownsPot
                ? GachaText.oddsFeaturedOwned(pot, dup, r)
                : GachaText.oddsFeatured(pot, r),
          );
        case 'petItemRare':
          line(GachaText.oddsPetRare(r));
          for (final id in e.split) {
            final t = GachaText.oddsItems[id];
            if (t != null) line(t, sub: true);
          }
        case 'petItemCommon':
          line(GachaText.oddsPetCommon(r));
          for (final id in e.split) {
            final t = GachaText.oddsItems[id];
            if (t != null) line(t, sub: true);
          }
        case 'chomSaoPot':
          line(GachaText.oddsZodiac(r));
          for (final t in GachaText.oddsZodiacItems) {
            line(t, sub: true);
          }
        default:
          if (e.coins == 2000000) line(GachaText.oddsXu2m(r));
          if (e.coins == 500000) line(GachaText.oddsXu500k(r));
          if (e.coins == 200000) line(GachaText.oddsXu200k(r));
          if (e.giotHoa == 10) line(GachaText.oddsDrop10(r));
          if (e.giotHoa == 3) line(GachaText.oddsDrop3(r));
          if (e.banhMat == 3) line(GachaText.oddsHoney3(r));
      }
    }
    return _Modal(
      sheet: true,
      modalKey: const Key('gacha-odds'),
      onDismiss: g.closePopup,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(GachaText.oddsTitle),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _note(GachaText.oddsWeek(pot, gachaWeekEnd(g.weekEnd))),
                  _note(
                    GachaText.oddsRotation(
                      '0h thứ Hai',
                      c.weeklyRotation.length,
                    ),
                  ),
                  _note(GachaText.oddsIntro(ticket)),
                  const SizedBox(height: 4),
                  ...rows,
                  const SizedBox(height: 6),
                  _note(GachaText.oddsX10Note),
                  _note(GachaText.oddsPity(pot, g.pityAt, ticket)),
                  _note(GachaText.oddsPityShared),
                  if (g.ownsPot) _note(GachaText.oddsPityOwned(pot, dup)),
                  _note(GachaText.pityCounterLong(g.pityLeft, pot)),
                  _note(
                    GachaText.oddsTicketPrice(
                      ticket,
                      coinFull(g.cardCoins),
                      coinFull(g.cardPhaLe),
                    ),
                  ),
                  _note(GachaText.oddsTicketWeekOnly(pot)),
                  _note(GachaText.oddsNoPl),
                  _note(GachaText.oddsGroupNote),
                  _note(GachaText.oddsRoundNote),
                  _note(GachaText.oddsServer),
                  _note(GachaText.oddsChangeNotice),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: ChunkyButton(
              key: const Key('gacha-odds-close'),
              label: GachaText.oddsClose,
              kind: ButtonKind.secondary,
              onPressed: g.closePopup,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lịch sử quay (Nhất 1d): open to everyone, newest first.
class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.g});

  final GachaController g;

  @override
  Widget build(BuildContext context) {
    final rows = g.historyRows;
    String two(int v) => v.toString().padLeft(2, '0');
    final lines = <String>[
      if (rows != null)
        for (final r in rows)
          for (final res in r.results)
            GachaText.historyRow(
              () {
                final vn = r.at.toUtc().add(const Duration(hours: 7));
                return '${two(vn.hour)}:${two(vn.minute)}';
              }(),
              gachaDate(r.at),
              _ticket(r.potId),
              res.items.label,
            ),
    ];
    return _Modal(
      sheet: true,
      modalKey: const Key('gacha-history'),
      onDismiss: g.closePopup,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(GachaText.historyTitle),
          const SizedBox(height: 6),
          if (rows == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (g.historyFailed)
            Text(GachaText.spinFailNetwork, style: AppText.caption())
          else if (lines.isEmpty)
            Text(
              GachaText.historyEmpty,
              key: const Key('gacha-history-empty'),
              style: AppText.caption(),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        lines[i],
                        key: Key('gacha-history-row-$i'),
                        style: AppText.body(size: 12, weight: 700),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: ChunkyButton(
              key: const Key('gacha-history-close'),
              label: GachaText.oddsClose,
              kind: ButtonKind.secondary,
              onPressed: g.closePopup,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kho thẻ: one cell per card type with its count in the corner; this
/// week's first, with a glowing border.
class _CardsSheet extends StatelessWidget {
  const _CardsSheet({required this.g});

  final GachaController g;

  @override
  Widget build(BuildContext context) {
    final inv = g.inventory;
    final cur = g.potId;
    return _Modal(
      sheet: true,
      modalKey: const Key('gacha-cards'),
      onDismiss: g.closePopup,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(GachaText.ticketNameGeneric),
          _note(GachaText.inventoryDesc),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in inv)
                    TicketCell(
                      key: Key('gacha-card-${e.key}'),
                      potId: e.key,
                      assetId: g.assetOf(e.key),
                      count: e.value,
                      current: e.key == cur,
                      caption: e.key == cur
                          ? GachaText.inventoryRowCurrent
                          : GachaText.inventoryRowLater(
                              g.potName(e.key),
                              gachaDate(g.returnOf(e.key)),
                            ),
                      onTap: e.key == cur
                          ? null
                          : () => showGameToast(
                              context,
                              GachaText.notCurrentToast(g.potName(e.key)),
                            ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: ChunkyButton(
              key: const Key('gacha-cards-close'),
              label: GachaText.oddsClose,
              kind: ButtonKind.secondary,
              onPressed: g.closePopup,
            ),
          ),
        ],
      ),
    );
  }
}

/// One card type: `icon_the` (3:4, contained) with its count in the corner;
/// the current week's has a gold glow.
class TicketCell extends StatelessWidget {
  const TicketCell({
    super.key,
    required this.potId,
    required this.count,
    this.current = false,
    this.caption,
    this.onTap,
    this.width = 96,
    this.assetId,
  });

  final String potId;

  /// Phú's art folder (`gacha.assetIdByPot`).
  final String? assetId;
  final int count;
  final bool current;
  final String? caption;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 4 / 3;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Container(
              width: width,
              height: h,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: current
                      ? AppColors.templeGold
                      : AppColors.surfaceBorder,
                  width: current ? 2.5 : 1.5,
                ),
                boxShadow: current
                    ? const [
                        BoxShadow(
                          color: Color(0x99F2C94C),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ticketCardIcon(
                      potId,
                      size: width - 8,
                      assetId: assetId,
                    ),
                  ),
                  Positioned(right: 0, bottom: 0, child: _CountBadge(count)),
                ],
              ),
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  caption!,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: AppText.caption(
                    size: 9.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoticePopup extends StatelessWidget {
  const _NoticePopup({required this.g});

  final GachaController g;

  @override
  Widget build(BuildContext context) {
    final n = g.notice;
    return _Modal(
      modalKey: const Key('gacha-notice'),
      onDismiss: g.closeNotice,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            n == null ? '' : gachaNoteText(g, n),
            key: const Key('gacha-notice-text'),
            textAlign: TextAlign.center,
            style: AppText.body(size: 14, weight: 800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ChunkyButton(
              key: const Key('gacha-notice-ok'),
              label: GachaText.introClose,
              onPressed: g.closeNotice,
            ),
          ),
        ],
      ),
    );
  }
}
