import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/pot_rules.dart' show GachaConfig;
import '../data/pot_book.dart' show potBookOrder;
import '../logic/gacha.dart';
import '../logic/platform_flags.dart' show phaLeTopUpOffered;
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

/// Pity bar fill (Phú).
const _pityGold = Color(0xFFF2C94C);

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

/// Wheel segments painted on `vong_quay` (dividers every 45°, one on top).
const _segments = 8;

/// Quay 1: ~2.5 s ease-out; Quay 10: one fast long spin ~3 s (Phú).
const _spin1 = Duration(milliseconds: 2500);
const _spin10 = Duration(milliseconds: 3000);

/// How long the landed segment stays lit before the result opens.
const _landHold = Duration(milliseconds: 700);

/// The 8 segments of the wheel, clockwise from the top divider, by the
/// `gacha.table_permyriad` lines: the week's pot, the biggest xu, rare pet
/// item, a Hoàng đạo pot, common pet item, giọt hoa, the other xu, bánh mật.
enum GachaSegment { pot, xuBig, petRare, zodiac, petCommon, drop, xu, honey }

/// The segment a result lands on (the server decides the prize; the wheel
/// only shows it).
int gachaSegmentOf(SpinResult r, GachaConfig c) {
  if (r.featured) return GachaSegment.pot.index;
  final item = r.items.items.isEmpty ? null : r.items.items.first;
  if (item == null) return GachaSegment.xu.index;
  final rare = <String>{
    for (final e in c.table)
      if (e.item == 'petItemRare') ...e.split,
  };
  final bigXu = c.table.fold<int>(0, (m, e) => math.max(m, e.coins));
  final seg = switch (item.kind) {
    RewardKind.coins when item.amount >= bigXu && bigXu > 0 =>
      GachaSegment.xuBig,
    RewardKind.coins => GachaSegment.xu,
    RewardKind.petItem when rare.contains(item.id) => GachaSegment.petRare,
    RewardKind.petItem => GachaSegment.petCommon,
    RewardKind.pot => GachaSegment.zodiac,
    RewardKind.giotHoa => GachaSegment.drop,
    RewardKind.treat => GachaSegment.honey,
    _ => GachaSegment.xu,
  };
  return seg.index;
}

/// The icon painted on [seg] (~28 dp): the week's pot on its own segment,
/// the repo's reward icons elsewhere.
Widget gachaSegmentIcon(GachaSegment seg, GachaConfig c, String potId) {
  const size = 28.0;
  String? first(String item) {
    for (final e in c.table) {
      if (e.item == item && e.split.isNotEmpty) return e.split.first;
    }
    return null;
  }

  Widget pet(String item) {
    final id = first(item);
    return id == null
        ? const SizedBox(width: size, height: size)
        : rewardIcon(RewardItem.petItem(id), size: size);
  }

  return switch (seg) {
    GachaSegment.pot => ArtImage(Art.pot(potId), size: size + 6),
    GachaSegment.xuBig || GachaSegment.xu => const CoinIcon(size: size),
    GachaSegment.petRare => pet('petItemRare'),
    GachaSegment.petCommon => pet('petItemCommon'),
    GachaSegment.zodiac => ArtImage(
      Art.pot(potBookOrder['chomSao']!.first),
      size: size,
    ),
    GachaSegment.drop => rewardIcon(const RewardItem.giotHoa(1), size: size),
    GachaSegment.honey => rewardIcon(const RewardItem.treat(1), size: size),
  };
}

/// Wheel turns (clockwise) that bring [seg]'s middle under the pointer.
double gachaSegmentTurn(int seg) {
  final mid = (seg + 0.5) / _segments;
  return (1 - mid) % 1;
}

class _GachaScreenState extends State<GachaScreen>
    with TickerProviderStateMixin {
  late final AnimationController _wheel = AnimationController(
    vsync: this,
    duration: _spin1,
  );

  /// Gold flashes when the week's pot lands.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  double _from = 0;
  double _to = 0;
  Curve _curve = Curves.easeOutCubic;

  /// The landed segment while it is lit (null while turning / idle).
  int? _lit;
  bool _gold = false;

  GachaController get g => widget.session.gacha;

  @override
  void dispose() {
    _wheel.dispose();
    _flash.dispose();
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
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final res = await g.spin(count);
    if (res == null || res.isEmpty || !mounted) return;
    // The wheel lands on the server's result: the week's pot if any came
    // out (Quay 10: the first one), else the (first) prize.
    final hit = res.where((r) => r.featured);
    final land = hit.isNotEmpty ? hit.first : res.first;
    final seg = gachaSegmentOf(land, g.config);
    final many = count > 1;
    setState(() {
      _lit = null;
      _gold = false;
    });
    _flash.reset();
    _from = _to % 1;
    _to = _from.floorToDouble() + (many ? 9 : 5) + gachaSegmentTurn(seg);
    _curve = many ? Curves.easeOutQuart : Curves.easeOutCubic;
    _wheel.duration = many ? _spin10 : _spin1;
    _wheel.reset();
    if (reduce) {
      _wheel.value = 1;
    } else {
      await _wheel.forward();
    }
    if (!mounted) return;
    setState(() {
      _lit = seg;
      _gold = land.featured;
    });
    if (land.featured && !reduce) unawaited(_flash.forward());
    await Future<void>.delayed(_landHold);
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
            // The plain paper of `banner` (900x458 art: x 200-720,
            // y 185-300), text centred in it with 12 dp side padding.
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) {
                  final scale = math.min(c.maxWidth / 900, c.maxHeight / 458);
                  final dx = (c.maxWidth - 900 * scale) / 2;
                  final dy = (c.maxHeight - 458 * scale) / 2;
                  return Stack(
                    children: [
                      Positioned(
                        key: const Key('gacha-banner-paper'),
                        left: dx + 200 * scale,
                        width: 520 * scale,
                        top: dy + 185 * scale,
                        height: 115 * scale,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      GachaText.weekCardTitle(name),
                                      key: const Key('gacha-pot-name'),
                                      maxLines: 1,
                                      style: AppText.title(
                                        size: 16,
                                        weight: 800,
                                      ),
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
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
          potId: potId,
          turns: _wheel,
          curve: () => _curve,
          from: () => _from,
          to: () => _to,
          lit: _lit,
          gold: _gold,
          flash: _flash,
          config: g.config,
          onTap: _skipWheel,
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
      GachaPopup.plShort => _PlShortPopup(g: g, session: s),
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
/// Landed: the segment under the pointer lights up; the week's pot flashes
/// gold and shows the pot big.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.asset,
    required this.potId,
    required this.turns,
    required this.curve,
    required this.from,
    required this.to,
    required this.flash,
    required this.config,
    this.lit,
    this.gold = false,
    this.onTap,
  });

  final String? asset;
  final String potId;
  final Animation<double> turns;
  final Curve Function() curve;
  final double Function() from;
  final double Function() to;
  final Animation<double> flash;
  final GachaConfig config;
  final int? lit;
  final bool gold;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = asset;
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = math.min(c.maxWidth, c.maxHeight);
          final wheel = side * 0.78;
          // The painted disc inside the frame (vong_quay: ~0.3 of the art).
          final disc = wheel * 0.3;
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
                  final t = curve().transform(turns.value);
                  final v = from() + (to() - from()) * t;
                  return Transform.rotate(angle: v * 2 * math.pi, child: child);
                },
                child: a == null
                    ? const SizedBox.shrink()
                    : SizedBox(
                        width: wheel,
                        height: wheel,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              Art.gachaPot(a, 'vong_quay'),
                              key: const Key('gacha-wheel'),
                              width: wheel,
                              height: wheel,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                            for (final seg in GachaSegment.values)
                              Transform.translate(
                                key: Key('gacha-seg-${seg.index}'),
                                offset: Offset.fromDirection(
                                  (seg.index + 0.5) / _segments * 2 * math.pi -
                                      math.pi / 2,
                                  disc * 0.64,
                                ),
                                child: gachaSegmentIcon(seg, config, potId),
                              ),
                          ],
                        ),
                      ),
              ),
              if (lit != null)
                IgnorePointer(
                  child: AnimatedBuilder(
                    key: Key(gold ? 'gacha-wheel-gold' : 'gacha-wheel-lit'),
                    animation: flash,
                    builder: (context, _) => CustomPaint(
                      size: Size(disc * 2, disc * 2),
                      painter: _LitPainter(
                        gold: gold,
                        // Three gold pulses, then steady.
                        pulse: gold && flash.isAnimating
                            ? (math.sin(flash.value * 3 * math.pi)).abs()
                            : 1,
                      ),
                    ),
                  ),
                ),
              if (lit != null && gold)
                IgnorePointer(
                  child: ArtImage(
                    Art.pot(potId),
                    key: const Key('gacha-wheel-pot'),
                    size: wheel * 0.62,
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

/// The lit segment under the pointer (top), and for the week's pot a gold
/// wash over the whole disc.
class _LitPainter extends CustomPainter {
  _LitPainter({required this.gold, required this.pulse});

  final bool gold;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    const sweep = 2 * math.pi / _segments;
    const start = -math.pi / 2 - sweep / 2;
    if (gold) {
      canvas.drawCircle(
        rect.center,
        r,
        Paint()..color = AppColors.templeGold.withValues(alpha: 0.45 * pulse),
      );
    }
    canvas.drawArc(
      rect,
      start,
      sweep,
      true,
      Paint()
        ..color = (gold ? AppColors.templeGold : Colors.white).withValues(
          alpha: gold ? 0.7 * pulse : 0.55,
        ),
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      true,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.templeGold,
    );
  }

  @override
  bool shouldRepaint(_LitPainter old) => old.gold != gold || old.pulse != pulse;
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
            // 8 dp gold bar, a tick at `pityReminderAt` (60 of 90).
            SizedBox(
              key: const Key('gacha-pity-bar'),
              height: 8,
              child: LayoutBuilder(
                builder: (context, c) {
                  final mark = g.pityAt <= 0
                      ? 0.0
                      : g.config.pityReminderAt / g.pityAt;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: g.pityAt <= 0 ? 0 : g.pityCount / g.pityAt,
                            backgroundColor: AppColors.freshnessTrack,
                            color: _pityGold,
                          ),
                        ),
                      ),
                      if (mark > 0 && mark < 1)
                        Positioned(
                          key: const Key('gacha-pity-mark'),
                          left: c.maxWidth * mark - 1,
                          top: -2,
                          bottom: -2,
                          width: 2,
                          child: const ColoredBox(color: AppColors.textPrimary),
                        ),
                    ],
                  );
                },
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

/// Quay 1: one prize, big. Quay 10: the 10 gifts at once (the wheel already
/// turned), then "Nhận hết".
class _ResultPopup extends StatefulWidget {
  const _ResultPopup({required this.g, required this.onAgain});

  final GachaController g;
  final Future<void> Function(int count) onAgain;

  @override
  State<_ResultPopup> createState() => _ResultPopupState();
}

class _ResultPopupState extends State<_ResultPopup> {
  GachaController get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final res = g.results;
    final many = res.length > 1;
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
          if (pityHit) ...[
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
          _note(GachaText.resultSavedNote),
          _note(GachaText.resultTicketsLeft(g.cards)),
          const SizedBox(height: 10),
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
      children: [for (var i = 0; i < res.length; i++) _cell(res[i], i)],
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

/// Mua thẻ (Nhất 1g, bản gọn 23:30): title + "Đang có", the xu quota chip,
/// Mua 1 / Mua 10, the two price buttons, one footnote. The longer lines sit
/// behind the (i) button.
class _BuySheet extends StatefulWidget {
  const _BuySheet({required this.g});

  final GachaController g;

  @override
  State<_BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends State<_BuySheet> {
  bool _info = false;

  GachaController get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final potId = g.potId;
    final ticket = _ticket(potId);
    final n = g.buyCount;
    final max = g.xuDailyMax;
    final left = g.xuLeftToday;
    final soldOut = left != null && left <= 0;
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
                ticketCardIcon(potId, size: 44, assetId: g.assetOf(potId)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    ticket,
                    key: const Key('gacha-buy-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(size: 17, weight: 800),
                  ),
                ),
                IconButton(
                  key: const Key('gacha-buy-info'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: () => setState(() => _info = !_info),
                  icon: const Icon(
                    Icons.info_outline,
                    color: AppColors.primaryBase,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Text(
                    GachaText.buyOwned(g.cards),
                    key: const Key('gacha-buy-owned'),
                    style: AppText.caption(size: 11.5),
                  ),
                ),
              ],
            ),
            if (_info)
              Container(
                key: const Key('gacha-buy-info-panel'),
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final t in GachaText.buyInfo(
                      g.potName(potId),
                      gachaDate(g.weekEnd),
                    ))
                      _note(t),
                  ],
                ),
              ),
            if (max > 0 && left != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    key: const Key('gacha-buy-xu-left'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: soldOut
                          ? AppColors.surfaceSunken
                          : AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: soldOut
                            ? AppColors.surfaceBorder
                            : AppColors.accentBase,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      GachaText.buyCoinQuota((max - left).clamp(0, max), max),
                      style: AppText.body(size: 13.5, weight: 800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      GachaText.buyCrystalQuota,
                      style: AppText.caption(
                        size: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                label: soldOut
                    ? GachaText.buyCoinSoldOut
                    : GachaText.buyBtnXu(coinFull(g.cardCoins * n)),
                fontSize: soldOut ? 13 : 15,
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
            _note(GachaText.buyFootnote, key: const Key('gacha-buy-footnote')),
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

/// "Thiếu {n} Pha lê" (Nhất 23:30): a Pha lê buy came up short. "Nạp Pha lê"
/// opens Cửa hàng Pha lê (over the wheel), "Để sau" closes.
class _PlShortPopup extends StatelessWidget {
  const _PlShortPopup({required this.g, required this.session});

  final GachaController g;
  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final n = g.plShortNeed;
    return _Modal(
      modalKey: const Key('gacha-pl-short'),
      onDismiss: g.closePopup,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(GachaText.plShortTitle(coinFull(n))),
          const SizedBox(height: 6),
          Text(
            GachaText.plShortBody,
            textAlign: TextAlign.center,
            style: AppText.body(size: 13, weight: 700),
          ),
          const SizedBox(height: 12),
          if (phaLeTopUpOffered) ...[
            SizedBox(
              height: 46,
              child: ChunkyButton(
                key: const Key('gacha-pl-short-topup'),
                label: GachaText.plShortTopup,
                fontSize: 15,
                onPressed: () {
                  g.closePopup();
                  session.openPhaleShop(need: n, name: _ticket(g.potId));
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
          TextButton(
            key: const Key('gacha-pl-short-later'),
            onPressed: g.closePopup,
            child: Text(
              GachaText.plShortLater,
              style: AppText.body(size: 14, weight: 800),
            ),
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
          // No pot this week (wheel not open yet): no row without a name.
          if (g.potId == null) break;
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
                  if (g.potId != null)
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
