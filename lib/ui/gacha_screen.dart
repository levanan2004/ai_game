import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sounds.dart' show SoundScope;
import '../data/pot_rules.dart' show GachaConfig;
import '../data/pot_book.dart' show potBookOrder;
import '../logic/gacha.dart';
import '../logic/pet.dart' show giftKind;
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
import 'ui_chung.dart';
import 'ui_skin.dart';

/// Countdown on the last day: a darker orange that keeps 4.5:1 on cream.
const _orange = Color(0xFFA9531A);

/// Title text on khung_popup's green strip.
const _cream = Color(0xFFFFF4D6);

/// "0h thứ Hai 26/10" (Việt Nam time) for {week_end}.
/// The pot's name as on its card ("Cửu Vĩ Hồ"), for `ticket.buy.title`.
String gachaShortPotName(String? potId) {
  final t = potId == null ? null : GachaText.ticketName(potId);
  return t == null ? (potId ?? '') : t.replaceFirst('Thẻ gacha ', '');
}

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

/// Rare prizes (gold border + sparkle in Quay 10): the week's pot, the
/// biggest xu, a rare pet item, a Hoàng đạo pot.
bool gachaRare(SpinResult r, GachaConfig c) {
  final seg = GachaSegment.values[gachaSegmentOf(r, c)];
  return seg == GachaSegment.pot ||
      seg == GachaSegment.xuBig ||
      seg == GachaSegment.petRare ||
      seg == GachaSegment.zodiac;
}

/// The short name of a prize from the existing names (pot names from
/// economy, everything else from the gift catalog); null when none exists.
String? gachaRewardName(RewardItem item, GachaController g) {
  if (item.kind == RewardKind.pot) {
    final n = g.potName(item.id);
    return n.isEmpty ? null : n;
  }
  final keys = RewardBundle([item]).toGiftItems().keys;
  return keys.isEmpty ? null : giftKind(keys.first)?.name;
}

/// The icon painted on [seg] (~28 dp): the week's pot on its own segment,
/// the repo's reward icons elsewhere.
Widget gachaSegmentIcon(GachaSegment seg, GachaConfig c, String potId) {
  const size = 44.0; // Phú: 44 dp, the weekly pot 52 dp
  String? first(String item) {
    for (final e in c.table) {
      if (e.item == item && e.split.isNotEmpty) return e.split.first;
    }
    return null;
  }

  Widget pet(String item) {
    final id = first(item);
    // The item's own picture (pet_do/<id>), not the tier frame.
    return id == null
        ? const SizedBox(width: size, height: size)
        : Image.asset(
            Art.petDo(id),
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                rewardIcon(RewardItem.petItem(id), size: size),
          );
  }

  return switch (seg) {
    GachaSegment.pot => ArtImage(Art.pot(potId), size: 52),
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

/// A reward's icon in the gacha: pet items show their own picture
/// (`pet_do/<id>`) instead of the tier frame; the rest as everywhere.
Widget gachaRewardIcon(RewardItem item, {double size = 28}) =>
    item.kind == RewardKind.petItem && item.id != null
    ? Image.asset(
        Art.petDo(item.id!),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => rewardIcon(item, size: size),
      )
    : rewardIcon(item, size: size);

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The game frame is 360×640 inside a FittedBox. MediaQuery is
              // the browser window, which would park the wheel outside the
              // frame on desktop.
              final frame = Size(
                constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : AppSize.frameWidth,
                constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : AppSize.frameHeight,
              );
              return Stack(
                key: const Key('gacha-screen'),
                children: [
                  // Phú G1: the week's background (its pot's, else nen_chung).
                  Positioned.fill(
                    child: Image.asset(
                      UiChung.wheelBg(potId),
                      key: Key('gacha-bg-${UiChung.wheelBg(potId)}'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
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
                    ..._main(s, potId, frame),
                  Positioned(
                    left: 12,
                    top: 46,
                    child: LeafRoundButton(
                      key: const Key('gacha-back'),
                      onTap: g.closeScreen,
                    ),
                  ),
                  Positioned(
                    left: 64,
                    right: 10 + 84 + 6 + 40 + 6,
                    top: 46,
                    child: LayoutBuilder(
                      builder: (context, c) => Center(
                        child: SkinRibbon(
                          title: GachaText.weekTitle,
                          width: math.min(190, c.maxWidth),
                          height: 44,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  // Top-right: Tỉ lệ, "Lịch sử quay" right under it (Phú).
                  Positioned(
                    right: 10,
                    top: 48,
                    child: _OddsChip(onTap: () => g.showPopup(GachaPopup.odds)),
                  ),
                  // Phú: round nut_tron_la with a clock, left of Tỉ lệ.
                  if (potId != null && s.signedIn)
                    Positioned(
                      right: 10 + 84 + 6,
                      top: 48,
                      child: _HistoryButton(
                        onTap: () => g.showPopup(GachaPopup.history),
                      ),
                    ),
                  if (g.popup != GachaPopup.none)
                    Positioned.fill(child: _popup(s)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Pot-name ribbon (one line, 36 dp) and the bottom dock.
  static const _ribbonTop = 94.0;
  static const _ribbonH = 36.0;
  static const _dockBottom = 16.0;
  static const _dockGap = 10.0;

  /// Info row: two boxes (2 lines at 12 sp + the pity bar, ~92) or,
  /// merged, one 12 sp line (~28).
  static const _infoH = 92.0;
  static const _infoMergedH = 28.0;

  /// Phú: below 240 dp of wheel the two info boxes merge into one line.
  static const _minWheel = 240.0;

  List<Widget> _main(ShopSession s, String potId, Size size) {
    const wheelTop = _ribbonTop + _ribbonH + 6;
    double room(double info) => math.max(
      0.0,
      size.height - wheelTop - 8 - (info + _dockGap + 52 + _dockBottom),
    );
    final merged =
        math.min(size.width * 0.86, room(_infoH)) < _minWheel && s.signedIn;
    final wheelRoom = room(merged ? _infoMergedH : _infoH);
    // Fill the room, at most 86% of the width.
    final wheelSide = math.min(size.width * 0.86, wheelRoom);
    final asset = g.assetOf(potId);
    final name = g.potName(potId);
    return [
      // Phú: the pot's name on a one-line ribbon (SkinRibbon, the title's
      // 3-part ribbon art), 36 dp, centred under the title, 14 sp.
      Positioned(
        left: 0,
        right: 0,
        top: _ribbonTop,
        height: _ribbonH,
        child: Center(
          child: KeyedSubtree(
            key: const Key('gacha-pot-name'),
            child: SkinRibbon(
              title: GachaText.weekCardTitle(name),
              width: math.min(size.width - 48, 300),
              height: _ribbonH,
              fontSize: 14,
            ),
          ),
        ),
      ),
      // Phú: the wheel alone, centred, ~86% of the width; scaled down to
      // the room between the banner and the bottom cluster (360x640).
      Positioned(
        left: (size.width - wheelSide) / 2,
        top: wheelTop + (wheelRoom - wheelSide) / 2,
        width: wheelSide,
        height: wheelSide,
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
          potName: g.potName(potId),
          onTap: _skipWheel,
        ),
      ),
      // Bottom cluster docked 16 dp from the bottom, 10 dp between rows.
      Positioned(
        left: 12,
        right: 12,
        bottom: _dockBottom,
        child: Column(
          key: const Key('gacha-dock'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.signedIn) ...[
              // Phú: the two info boxes split the width; "Mua thẻ" is the
              // chip on Quay 1 lượt.
              _WeekLine(g: g, merged: merged),
              const SizedBox(height: _dockGap),
              SizedBox(
                height: 52,
                child: _SpinButtons(g: g, onSpin: _spin),
              ),
            ] else ...[
              _WeekLine(g: g),
              const SizedBox(height: _dockGap),
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
    return SizedBox(
      width: 84,
      child: SliceButton(
        key: const Key('gacha-odds-open'),
        piece: UiChung.nutTrangNho,
        label: GachaText.oddsBtn,
        height: 40,
        fontSize: 13,
        onPressed: onTap,
      ),
    );
  }
}

/// khung_tron_ruy_bang (Phú G3): the round frame with the week's pot big
/// inside and its name on the ribbon, for a Cửu Vĩ Hồ win.
class PotRibbonFrame extends StatelessWidget {
  const PotRibbonFrame({
    super.key,
    required this.potId,
    required this.name,
    required this.width,
  });

  final String potId;
  final String name;
  final double width;

  @override
  Widget build(BuildContext context) {
    const p = UiChung.khungTronRuyBang;
    final k = width / p.w;
    return SizedBox(
      width: width,
      height: p.h * k,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              p.path,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          // The cream circle: centre (319, 220), radius ~170 in the art.
          Positioned(
            left: (319 - 150) * k,
            top: (220 - 150) * k,
            width: 300 * k,
            height: 300 * k,
            child: ArtImage(Art.pot(potId), size: 300 * k),
          ),
          // The ribbon: art x 200–440, y 425–484.
          Positioned(
            left: 200 * k,
            width: 240 * k,
            top: 425 * k,
            height: 59 * k,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  key: const Key('pot-ribbon-name'),
                  maxLines: 1,
                  style: AppText.title(size: 14, weight: 800, color: _cream),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `gacha/<id>/the.webp` with the pot inside and its name on the scroll.
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
    required this.potName,
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
  final String potName;
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
          // The vong_quay art has a transparent margin: drawn at 1.22 of
          // the box its visible frame (tails included) fills the box, so
          // the box size is the wheel's on-screen size (Phú: <= 86% width).
          final wheel = side * 1.22;
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
                  // Bigger than the box on purpose (transparent margin).
                  return OverflowBox(
                    maxWidth: wheel,
                    maxHeight: wheel,
                    child: Transform.rotate(
                      angle: v * 2 * math.pi,
                      child: child,
                    ),
                  );
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
                                  disc * 0.62,
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
                  child: PotRibbonFrame(
                    key: const Key('gacha-wheel-pot'),
                    potId: potId,
                    name: potName,
                    width: side,
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
  const _WeekLine({required this.g, this.merged = false});

  final GachaController g;

  /// Small screens: the two boxes as one 12 sp text row.
  final bool merged;

  @override
  Widget build(BuildContext context) {
    final left = g.timeLeft;
    final soon = g.lastDay;
    final pot = g.potName(g.potId);
    if (merged) {
      return UiSlice(
        key: const Key('gacha-info-merged'),
        piece: UiChung.theThongTin,
        scale: 8.5,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '${GachaText.weekEndsLabel} ${GachaText.weekCountdown(left)} · '
            '${g.pityLeft == 1 ? GachaText.pityNext(pot) : GachaText.pityCounter(g.pityLeft, pot)}',
            maxLines: 1,
            style: AppText.body(size: 12, weight: 800),
          ),
        ),
      );
    }
    Widget box({
      required Key key,
      required List<Widget> children,
      Color? border,
    }) => Expanded(
      // Phú G2: the_thong_tin at 8.5 px per dp, so Phú's 18/12 dp padding
      // clears the corner flowers (152/135 px wide, 48 px top border).
      child: UiSlice(
        key: key,
        piece: UiChung.theThongTin,
        scale: 8.5,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
    // Both boxes the height of the taller one.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          box(
            key: const Key('gacha-countdown'),
            border: soon ? AppColors.secondaryBase : null,
            children: [
              // Phú: "Đổi chậu sau" 12 sp regular, then the time left 14 sp
              // bold; one line each (scaled down, never cut).
              Text(
                GachaText.weekEndsLabel,
                key: const Key('gacha-countdown-l1'),
                maxLines: 1,
                softWrap: false,
                style: AppText.body(
                  size: 12,
                  weight: 500,
                  color: soon ? _orange : AppColors.textPrimary,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  GachaText.weekCountdown(left),
                  key: const Key('gacha-countdown-l2'),
                  maxLines: 1,
                  softWrap: false,
                  style: AppText.body(
                    size: 14,
                    weight: 800,
                    color: soon ? _orange : AppColors.textPrimary,
                  ),
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
              // Phú + Nhất: same layout as the countdown, no pot name; the
              // screen reader gets the whole sentence.
              Semantics(
                key: const Key('gacha-pity-a11y'),
                label: GachaText.pityA11y(g.pityLeft, pot),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      GachaText.pityLabel,
                      key: const Key('gacha-pity-l1'),
                      maxLines: 1,
                      softWrap: false,
                      style: AppText.body(size: 12, weight: 500),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        GachaText.pityCount(g.pityLeft),
                        key: const Key('gacha-pity-l2'),
                        maxLines: 1,
                        softWrap: false,
                        style: AppText.body(size: 14, weight: 800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // thanh_tien_do, the 8 dp #F2C94C fill inside, a tick at
              // `pityReminderAt` (60 of 90).
              SliceProgress(
                key: const Key('gacha-pity-bar'),
                value: g.pityAt <= 0 ? 0 : g.pityCount / g.pityAt,
                marks: [if (g.pityAt > 0) g.config.pityReminderAt / g.pityAt],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// This week's card count and "Mua thẻ"; the card icon opens Kho thẻ.
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

/// "Lịch sử quay": nut_tron_la (40 dp) with a clock (Phú).
class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: GachaText.historyBtn,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('gacha-history-open'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          SoundScope.maybeOf(context)?.effect('ui_tap');
          onTap();
        },
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                UiChung.nutTronLa.path,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              const Icon(
                Icons.schedule,
                size: 20,
                color: AppColors.primaryPressed,
              ),
            ],
          ),
        ),
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
    final busy = g.spinning;
    Widget button(int count, Key key) {
      final one = count == 1;
      return Expanded(
        // Phú G3: nut_xanh (Quay 1 lượt), nut_vang (Quay 10 lượt), 52 dp.
        child: SliceButton(
          key: key,
          piece: one ? UiChung.nutXanh : UiChung.nutVang,
          label: busy
              ? GachaText.btnSpinning
              : one
              ? GachaText.btnX1
              : GachaText.btnX10,
          sub: busy
              ? null
              : one
              ? GachaText.btnCostX1
              : GachaText.btnCostX10,
          enabled: !busy && !g.buying,
          onPressed: () => onSpin(count),
        ),
      );
    }

    final k = g.cards;
    return Row(
      children: [
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(children: [button(1, const Key('gacha-spin-1'))]),
              // Phú: "{n} thẻ +" on the top-right corner, sticking out a
              // third; opens Mua thẻ. No card: nut_cam "Mua thẻ" there.
              // (Most of it stays inside the Stack so it gets the taps.)
              Positioned(
                right: 0,
                top: 0,
                child: FractionalTranslation(
                  translation: const Offset(1 / 3, -1 / 3),
                  child: GestureDetector(
                    key: const Key('gacha-buy-open'),
                    behavior: HitTestBehavior.opaque,
                    onTap: g.buying ? null : () => g.openBuy(1),
                    child: k > 0
                        ? Container(
                            key: const Key('gacha-owned'),
                            height: 22,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2C94C),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: _cream, width: 1.5),
                            ),
                            child: Text(
                              GachaText.chipBuy(k),
                              style: AppText.caption(
                                size: 11,
                                weight: 800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          )
                        : IgnorePointer(
                            child: SizedBox(
                              key: const Key('gacha-buy-empty'),
                              width: 84,
                              height: 26,
                              child: SliceButton(
                                piece: UiChung.nutCam,
                                label: GachaText.buyBtn,
                                height: 26,
                                fontSize: 12,
                                onPressed: () => g.openBuy(1),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    this.title,
  });

  final Widget child;
  final VoidCallback? onDismiss;
  final bool sheet;
  final Key? modalKey;

  /// Framed in Phú's khung_popup, [title] on its green strip in cream.
  final String? title;

  /// khung_popup drawn at 2.4 image px per dp: the green strip (art y
  /// 70–128, x 165–510 between the flowers); content below the top
  /// flowers (art y 200) and above the bottom ones (UiChung.safe).
  static const _popupScale = 2.4;

  @override
  Widget build(BuildContext context) {
    final t = title;
    if (t != null) {
      const sc = _popupScale;
      final framed = Container(
        key: modalKey,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(maxHeight: 600),
        child: UiSlice(
          piece: UiChung.khungPopup,
          scale: sc,
          child: Stack(
            children: [
              Positioned(
                left: 165 / sc,
                right: (669 - 510) / sc,
                top: 70 / sc,
                height: 58 / sc,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      t,
                      key: const Key('gacha-popup-title'),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: AppText.title(
                        size: 18,
                        weight: 800,
                        color: _cream,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                // Phú: content in the centre area, 24 dp sides, 28 dp from
                // the bottom edge; top below the corner flowers.
                padding: EdgeInsets.fromLTRB(
                  24,
                  UiChung.padFor(UiChung.khungPopup, sc, extra: 4).top,
                  24,
                  28,
                ),
                child: Material(type: MaterialType.transparency, child: child),
              ),
            ],
          ),
        ),
      );
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: const ColoredBox(color: AppColors.bgOverlay),
            ),
          ),
          Center(child: framed),
        ],
      );
    }
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

Widget _note(String text, {Key? key, TextAlign? align}) => Padding(
  padding: const EdgeInsets.only(top: 4),
  child: Text(
    text,
    key: key,
    textAlign: align,
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
      title: hit.isNotEmpty && hit.first.dup && !many
          ? GachaText.resultDupTitle
          : many
          ? GachaText.resultTitleX10
          : GachaText.resultTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          _note(GachaText.resultSavedNote, align: TextAlign.center),
          _note(GachaText.resultTicketsLeft(g.cards), align: TextAlign.center),
          const SizedBox(height: 10),
          // Phú: one row, half width each, 12 dp gap; "Quay tiếp" on
          // nut_vang sized to its text + 20 dp; two rows when that won't fit.
          LayoutBuilder(
            builder: (context, c) {
              final again = many
                  ? GachaText.resultAgainX10
                  : GachaText.resultAgain;
              final claim = SliceButton(
                key: const Key('gacha-result-claim'),
                piece: UiChung.nutXanh,
                height: PopupButton.primaryH,
                label: many ? GachaText.resultClaimAll : GachaText.resultClaim,
                fontSize: 16,
                enabled: !g.claiming,
                onPressed: g.claiming ? null : g.claimResults,
              );
              final againBtn = SliceButton(
                key: const Key('gacha-result-again'),
                piece: UiChung.nutVang,
                height: PopupButton.primaryH,
                label: again,
                fontSize: 14,
                textPad: 20,
                onPressed: g.claiming
                    ? null
                    : () async {
                        await g.claimResults();
                        await widget.onAgain(many ? 10 : 1);
                      },
              );
              final tp = TextPainter(
                text: TextSpan(
                  text: again,
                  style: AppText.title(size: 14, weight: 800),
                ),
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              const p = UiChung.nutVang;
              const k = 175 / 52;
              final need =
                  tp.width +
                  2 * 20 +
                  (p.slice!.left + p.w - p.slice!.right) / k;
              if (need <= (c.maxWidth - 12) / 2) {
                return Row(
                  key: const Key('gacha-result-buttons-row'),
                  children: [
                    Expanded(child: claim),
                    const SizedBox(width: 12),
                    Expanded(child: againBtn),
                  ],
                );
              }
              return Column(
                key: const Key('gacha-result-buttons-col'),
                children: [
                  SizedBox(width: double.infinity, child: claim),
                  const SizedBox(height: 12),
                  SizedBox(width: math.min(need, c.maxWidth), child: againBtn),
                ],
              );
            },
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
        if (r.featured)
          Center(
            child: PotRibbonFrame(
              key: const Key('gacha-result-pot-frame'),
              potId: g.potId!,
              name: g.potName(g.potId),
              width: 190,
            ),
          )
        else
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
    final rare = gachaRare(r, g.config);
    final name = item == null ? null : gachaRewardName(item, g);
    return SizedBox(
      key: Key('gacha-result-cell-$i'),
      width: 56,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 62,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: rare ? AppColors.accentSoft : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: rare ? AppColors.templeGold : AppColors.surfaceBorder,
                width: rare ? 2 : 1,
              ),
              boxShadow: rare
                  ? const [BoxShadow(color: Color(0x66F2C94C), blurRadius: 6)]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (item != null) gachaRewardIcon(item, size: 34),
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
                ),
                // A subtle sparkle on the rare ones.
                if (rare)
                  Positioned(
                    key: Key('gacha-result-sparkle-$i'),
                    right: -6,
                    top: -6,
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppColors.templeGold,
                    ),
                  ),
              ],
            ),
          ),
          if (name != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                name,
                key: Key('gacha-result-name-$i'),
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: AppText.caption(size: 11, weight: 700),
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
      title: GachaText.shortTitle(n),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          PopupButton(
            key: const Key('gacha-short-xu'),
            piece: UiChung.nutXanh,
            label: GachaText.shortBtnXu(coinFull(g.cardCoins * n)),
            fontSize: 14,
            enabled: xuOk && !g.buying,
            onPressed: xuOk && !g.buying
                ? () => g.buy(n, withPhaLe: false, thenSpin: true)
                : null,
          ),
          const SizedBox(height: PopupButton.gap),
          PopupButton(
            key: const Key('gacha-short-pl'),
            piece: UiChung.nutCam,
            label: GachaText.shortBtnPl(coinFull(g.cardPhaLe * n)),
            fontSize: 14,
            onPressed: g.buying ? null : () => g.askPhaLe(n),
          ),
          Padding(
            padding: const EdgeInsets.only(top: PopupButton.gap),
            child: PopupButton(
              key: const Key('gacha-short-later'),
              secondary: true,
              label: GachaText.shortBtnLater,
              fontSize: 14,
              onPressed: g.closePopup,
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
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          GachaText.buyTitle(
                            gachaShortPotName(potId ?? g.potId),
                          ),
                          key: const Key('gacha-buy-title'),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: AppText.title(size: 15, weight: 800),
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
                    ],
                  ),
                ),
                // Phú: "Đang có" is the way to Kho thẻ (› chevron).
                Semantics(
                  button: true,
                  child: GestureDetector(
                    key: const Key('gacha-buy-owned-open'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      SoundScope.maybeOf(context)?.effect('ui_tap');
                      g.showPopup(GachaPopup.cards);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 28),
                      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            GachaText.buyOwned(g.cards),
                            key: const Key('gacha-buy-owned'),
                            style: AppText.caption(size: 11.5),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
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
            FractionallySizedBox(
              widthFactor: 0.8,
              child: SizedBox(
                height: PopupButton.primaryH,
                child: SliceButton(
                  key: const Key('gacha-buy-xu'),
                  piece: UiChung.nutXanh,
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
            ),
            const SizedBox(height: PopupButton.gap),
            FractionallySizedBox(
              widthFactor: 0.8,
              child: SizedBox(
                height: PopupButton.primaryH,
                child: SliceButton(
                  key: const Key('gacha-buy-pl'),
                  piece: UiChung.nutCam,
                  label: GachaText.buyBtnPl(coinFull(g.cardPhaLe * n)),
                  fontSize: 15,
                  onPressed: g.buying ? null : () => g.askPhaLe(n),
                ),
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
      title: GachaText.plConfirmTitle(cost, n),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  height: 40,
                  child: SliceButton(
                    key: const Key('gacha-pl-cancel'),
                    piece: UiChung.nutTrangNho,
                    label: GachaText.plConfirmCancel,
                    onPressed: g.closePopup,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: PopupButton.primaryH,
                  child: SliceButton(
                    key: const Key('gacha-pl-ok'),
                    piece: UiChung.nutXanh,
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
      title: GachaText.plShortTitle(coinFull(n)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          Text(
            GachaText.plShortBody,
            textAlign: TextAlign.center,
            style: AppText.body(size: 13, weight: 700),
          ),
          const SizedBox(height: 12),
          if (phaLeTopUpOffered) ...[
            PopupButton(
              key: const Key('gacha-pl-short-topup'),
              piece: UiChung.nutCam,
              label: GachaText.plShortTopup,
              fontSize: 15,
              onPressed: () {
                g.closePopup();
                session.openPhaleShop(need: n, name: _ticket(g.potId));
              },
            ),
            const SizedBox(height: 4),
          ],
          Padding(
            padding: const EdgeInsets.only(top: PopupButton.gap),
            child: PopupButton(
              key: const Key('gacha-pl-short-later'),
              secondary: true,
              label: GachaText.plShortLater,
              fontSize: 14,
              onPressed: g.closePopup,
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
          PopupButton(
            key: const Key('gacha-odds-close'),
            label: GachaText.oddsClose,
            secondary: true,
            onPressed: g.closePopup,
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
          PopupButton(
            key: const Key('gacha-history-close'),
            label: GachaText.oddsClose,
            secondary: true,
            onPressed: g.closePopup,
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
              // An: few cards sit in the middle, not on the left.
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  key: const Key('gacha-cards-wrap'),
                  alignment: WrapAlignment.center,
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
          ),
          const SizedBox(height: 8),
          PopupButton(
            key: const Key('gacha-cards-close'),
            label: GachaText.oddsClose,
            secondary: true,
            onPressed: g.closePopup,
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
          PopupButton(
            key: const Key('gacha-notice-ok'),
            label: GachaText.introClose,
            onPressed: g.closeNotice,
          ),
        ],
      ),
    );
  }
}
