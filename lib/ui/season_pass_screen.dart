import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/season_pass_text.dart';
import '../logic/format.dart';
import '../logic/pet.dart';
import '../logic/price_format.dart';
import '../logic/season_pass.dart';
import '../logic/season_pass_controller.dart';
import '../logic/shop_session.dart';
import 'popups.dart' show featuredNames;

/// Season Pass tokens (season_pass_ui/spec.md §1, Phú).
abstract final class SpColors {
  static const primary = Color(0xFF3F7F52);
  static const cream = Color(0xFFFFF6E3);
  static const barBg = Color(0xFFE8F0EA);
  static const premium = Color(0xFFF2B544);
  static const dot = Color(0xFFE26D5A);
  static const ink = Color(0xFF4A3B36);
  static const inkSoft = Color(0xFF8A7670);
  static const disabled = Color(0xFFC4B4AC);
}

const _img = 'assets/images/';

/// One reward piece as the cell / sheet shows it.
class SpRewardPart {
  const SpRewardPart(this.label, this.icon, this.qty, {this.fallback});

  final String label;
  final String? icon;

  /// Corner number: "×2", "200k"; '' for one-off items.
  final String qty;

  /// Material icon when there is no picture (skins: art is the skin
  /// pipeline's, outside the spec).
  final IconData? fallback;
}

/// The frame shown while the season's own frame has no art yet (tier 30
/// free, tier 22 premium): the default frame preview.
const spFrameFallback = '${_img}avatar_frames/khung_avatar_mac_dinh_nho.webp';

/// Label + icon of every piece of [reward], read from the block's keys
/// (never from sp_tier_N_*, spec §0).
List<SpRewardPart> spRewardParts(
  SeasonPassReward reward, {
  required SeasonPassText t,
  required String themeId,
  required String seasonName,
  String Function(String id)? petItemName,
}) {
  final out = <SpRewardPart>[];
  for (final (k, v) in reward.parts) {
    final n = v is int ? v : 0;
    final id = v is String ? v.replaceAll('{theme}', themeId) : '';
    switch (k) {
      case 'coins':
        out.add(
          SpRewardPart(
            t.get('sp_reward_coins', {'n': coinFull(n)}),
            '${_img}nav/xu.webp',
            formatK(n),
          ),
        );
      case 'phaLe':
        out.add(
          SpRewardPart(
            t.get('sp_reward_phaLe', {'n': coinFull(n)}),
            '${_img}nav/pha_le.webp',
            '×$n',
          ),
        );
      case 'gachaTicket':
        out.add(
          SpRewardPart(
            t.get('sp_reward_gachaTicket', {'n': coinFull(n)}),
            '${_img}gacha/icon_vong_quay.webp',
            '×$n',
          ),
        );
      case 'banhMat':
        out.add(
          SpRewardPart(
            t.get('sp_reward_banhMat', {'n': coinFull(n)}),
            '${_img}pet_ui/item_banh_mat.webp',
            '×$n',
          ),
        );
      case 'giotHoa':
        out.add(
          SpRewardPart(
            t.get('sp_reward_giotHoa', {'n': coinFull(n)}),
            '${_img}ui/giot_hoa.webp',
            '×$n',
          ),
        );
      case 'khungAvatar':
        out.add(
          SpRewardPart(
            t.get('sp_reward_khungAvatar', {'tenMua': seasonName}),
            '${_img}avatar_frames/${id}_nho.webp',
            '',
          ),
        );
      case 'skin':
        final kind = (v as String).replaceAll('_sp_{theme}', '');
        final frame = kind.startsWith('khung_avatar');
        out.add(
          SpRewardPart(
            t.get('sp_reward_skin_$kind', {'tenMua': seasonName}),
            frame ? '${_img}avatar_frames/${id}_nho.webp' : null,
            '',
            fallback: frame ? null : Icons.storefront_rounded,
          ),
        );
      case 'petItem':
        final key = 'pet_item_$id';
        final name = t.has(key) ? t.get(key) : (petItemName?.call(id) ?? id);
        out.add(
          SpRewardPart(
            t.get('sp_reward_petItem', {'ten': name}),
            '${_img}phuc_loi/${giftKind(petItemGiftKey(id))?.asset ?? 'khung_thuong'}.webp',
            '',
          ),
        );
    }
  }
  return out;
}

/// The icon of one piece; frames fall back to the default frame preview.
class SpRewardIcon extends StatelessWidget {
  const SpRewardIcon(this.part, {super.key, required this.size});

  final SpRewardPart part;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fb = Icon(
      part.fallback ?? Icons.card_giftcard_rounded,
      size: size * 0.9,
      color: SpColors.primary,
    );
    final icon = part.icon;
    if (icon == null) return SizedBox.square(dimension: size, child: fb);
    return Image.asset(
      icon,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => icon.contains('avatar_frames/')
          ? Image.asset(
              spFrameFallback,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fb,
            )
          : fb,
    );
  }
}

/// Lối vào (spec §2): 48dp next to Sổ tay, red dot while a tier waits.
class SeasonPassButton extends StatelessWidget {
  const SeasonPassButton({super.key, required this.session});

  static const size = 48.0;

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final c = session.seasonPass;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.entryVisible) return const SizedBox.shrink();
        return GestureDetector(
          key: const Key('season-pass-button'),
          behavior: HitTestBehavior.opaque,
          onTap: session.openSeasonPass,
          child: Semantics(
            button: true,
            label: 'Season Pass',
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      '${_img}ui/ve_season_pass.webp',
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.local_activity_rounded,
                        color: SpColors.primary,
                      ),
                    ),
                  ),
                  if (c.claimableCount > 0)
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: _Dot(key: Key('season-pass-dot'), size: 10),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: SpColors.dot,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
  );
}

enum _Dialog { none, buy, notEnough, claimed, detail }

/// Mission art (existing assets). Goals without a fitting picture use the
/// Season Pass ticket; the theme-flower goal uses the theme's first flower.
const _goalArt = {
  'bouquetsSold': 'nav/gia_ban.webp',
  'greatReviews': 'nav/danh_gia.webp',
  'onlineDelivered': 'shippers/motorbike.webp',
  'occasionVariety': 'le/le_8_3_20_10.webp',
  'gameDaysPlayed': 'nav/cho_hoa.webp',
  'loginDays': 'phuc_loi/o_hom_nay.webp',
};

const _ticketArt = 'ui/ve_season_pass.webp';

/// Asset path (under assets/images/) for [goal].
String spMissionArt(String goal, String? firstFlower) =>
    goal == 'themeFlowerStemsSold' && firstFlower != null
    ? 'flowers/$firstFlower.webp'
    : _goalArt[goal] ?? _ticketArt;

/// Màn Season Pass (spec §3–§6), full screen over the shop.
class SeasonPassScreen extends StatefulWidget {
  const SeasonPassScreen({
    super.key,
    required this.session,
    this.initialTab = 0,
  });

  final ShopSession session;

  /// 0 = Phần thưởng, 1 = Nhiệm vụ.
  final int initialTab;

  @override
  State<SeasonPassScreen> createState() => _SeasonPassScreenState();
}

class _SeasonPassScreenState extends State<SeasonPassScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _minute;
  Timer? _toastTimer;
  ScrollController? _track;
  int? _scrolledTo;
  late int _tab = widget.initialTab;
  _Dialog _dialog = _Dialog.none;
  List<(int, SeasonPassTrack)> _claimedShown = const [];
  (int, SeasonPassTrack)? _detail;
  String? _toast;

  ShopSession get s => widget.session;
  SeasonPassController get c => s.seasonPass;
  SeasonPassText get t => s.data.seasonPassText ?? SeasonPassText.empty;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    c.addListener(_changed);
    _minute = Timer.periodic(const Duration(minutes: 1), (_) => c.tick());
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    _minute?.cancel();
    _toastTimer?.cancel();
    _pulse.dispose();
    _track?.dispose();
    super.dispose();
  }

  void _changed() {
    final k = c.takeToast();
    if (k != null) _showToast(k);
    if (mounted) setState(() {});
  }

  void _showToast(String key) {
    _toast = key;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  String get _seasonName {
    final v = c.view;
    final theme = v == null ? null : v.config.themes[v.themeId];
    return theme == null ? '' : t.get(theme.nameKey);
  }

  int? get _balance => s.wallet?.phaLe;

  Future<void> _claim(int tier, SeasonPassTrack track) async {
    if (await c.claim(tier, track)) {
      setState(() {
        _claimedShown = [(tier, track)];
        _dialog = _Dialog.claimed;
      });
    }
  }

  Future<void> _claimAll() async {
    final done = await c.claimAll();
    if (done.isNotEmpty && mounted) {
      setState(() {
        _claimedShown = done;
        _dialog = _Dialog.claimed;
      });
    }
  }

  void _openBuy() {
    final v = c.view;
    if (v == null) return;
    final bal = _balance;
    setState(
      () => _dialog = bal != null && bal < v.config.premiumPrice
          ? _Dialog.notEnough
          : _Dialog.buy,
    );
  }

  Future<void> _confirmBuy() async {
    final r = await c.buy();
    if (!mounted) return;
    if (r == SeasonPassBuy.bought) unawaited(s.syncWallet());
    setState(
      () => _dialog = r == SeasonPassBuy.notEnough
          ? _Dialog.notEnough
          : _Dialog.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    return Material(
      color: SpColors.cream,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _appBar(),
                Expanded(child: _body(compact)),
              ],
            ),
            if (_toast != null) _toastView(),
            if (_dialog != _Dialog.none) _dialogView(compact),
          ],
        ),
      ),
    );
  }

  Widget _appBar() => SizedBox(
    height: 56,
    child: Row(
      children: [
        SizedBox.square(
          dimension: 44,
          child: IconButton(
            key: const Key('season-pass-back'),
            onPressed: s.closeSeasonPass,
            icon: const Icon(Icons.arrow_back_rounded, color: SpColors.ink),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _seasonName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: SpColors.ink,
            ),
          ),
        ),
        if (_balance != null)
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: SpColors.premium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    '${_img}nav/pha_le.webp',
                    width: 20,
                    height: 20,
                    errorBuilder: (_, _, _) => const SizedBox(width: 20),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    coinFull(_balance!),
                    key: const Key('season-pass-balance'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: SpColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _body(bool compact) {
    switch (c.phase) {
      case SeasonPassPhase.loading:
        return _skeleton();
      case SeasonPassPhase.error:
        return _errorView();
      case SeasonPassPhase.closed:
        return _closedView();
      case SeasonPassPhase.ready:
        break;
    }
    final v = c.view!;
    return Column(
      children: [
        _countdown(v),
        _levelBar(v),
        _tabs(v),
        Expanded(child: _tab == 0 ? _rewards(v, compact) : _missions(v)),
        _bottomBar(v),
      ],
    );
  }

  Widget _skeleton() => AnimatedBuilder(
    key: const Key('season-pass-loading'),
    animation: _pulse,
    builder: (context, _) {
      final grey = Color.lerp(
        const Color(0xFFE6DED6),
        const Color(0xFFF2ECE6),
        _pulse.value,
      )!;
      Widget box(double w, double h, double r) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: grey,
          borderRadius: BorderRadius.circular(r),
        ),
      );
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            box(120, 14, 4),
            const SizedBox(height: 16),
            box(double.infinity, 8, 4),
            const SizedBox(height: 32),
            Row(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  box(52, 52, 10),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _errorView() => Center(
    child: Container(
      key: const Key('season-pass-error'),
      width: 296,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.get('sp_error_retry'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: SpColors.ink),
          ),
          const SizedBox(height: 16),
          _pill(
            t.get('sp_retry'),
            onTap: () => unawaited(c.load()),
            key: const Key('season-pass-retry'),
          ),
        ],
      ),
    ),
  );

  Widget _closedView() {
    final at = c.opensAt;
    final text = at == null
        ? t.get('sp_season_ended')
        : t.get('sp_coming_soon', {'ngay': _vnDayMonth(at)});
    return Center(
      key: const Key('season-pass-closed'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            '${_img}nav/chau_hoa.webp',
            width: 96,
            height: 96,
            errorBuilder: (_, _, _) => const SizedBox(height: 96),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: SpColors.ink),
          ),
        ],
      ),
    );
  }

  static String _vnDayMonth(DateTime at) {
    final d = at.toUtc().add(const Duration(hours: 7));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Widget _countdown(SeasonPassView v) {
    final left = v.season.end.difference(v.now);
    final String text;
    if (v.ended) {
      text = t.get('sp_season_ended');
    } else if (left.inDays >= 1) {
      text = t.get('sp_header_days_left', {'n': left.inDays});
    } else {
      text = t.get('sp_hours_left', {
        'hh': left.inHours.toString().padLeft(2, '0'),
        'mm': (left.inMinutes % 60).toString().padLeft(2, '0'),
      });
    }
    return Container(
      key: const Key('season-pass-countdown'),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      color: v.ended ? SpColors.disabled.withValues(alpha: 0.3) : null,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: SpColors.inkSoft),
      ),
    );
  }

  Widget _levelBar(SeasonPassView v) {
    final (into, need) = v.config.progressAt(v.status.xp);
    final frac = v.maxed ? 1.0 : (need == 0 ? 0.0 : into / need);
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  t.get('sp_header_tier', {
                    'x': v.tier,
                    'y': v.config.tierCount,
                  }),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SpColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    v.maxed
                        ? t.get('sp_max_tier')
                        : t.get('sp_xp_progress', {
                            'xp': coinFull(into),
                            'need': coinFull(need),
                          }),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SpColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                width: double.infinity,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: SpColors.barBg),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: frac.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: const ColoredBox(color: SpColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs(SeasonPassView v) {
    Widget tab(int i, String label, bool dot) => Expanded(
      child: InkWell(
        key: Key('season-pass-tab-$i'),
        onTap: () => setState(() => _tab = i),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _tab == i ? SpColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _tab == i ? SpColors.primary : SpColors.inkSoft,
                ),
              ),
              if (dot) ...[const SizedBox(width: 4), const _Dot(size: 8)],
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        tab(0, t.get('sp_tab_rewards'), v.claimables.isNotEmpty),
        // Missions are completed and paid by the server: nothing waits.
        tab(1, t.get('sp_tab_missions'), false),
      ],
    );
  }

  Widget _rewards(SeasonPassView v, bool compact) {
    final col = compact ? 68.0 : 76.0;
    final cell = compact ? 56.0 : 64.0;
    final icon = compact ? 32.0 : 36.0;
    // First claimable tier, else the current one (Phú 31/10).
    final focus = v.claimables.isNotEmpty
        ? v.claimables.first.$1
        : v.tier.clamp(1, v.config.tierCount);
    _track ??= ScrollController(initialScrollOffset: max(0, (focus - 2) * col));
    if (_scrolledTo != focus) {
      _scrolledTo = focus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tc = _track;
        if (!mounted || tc == null || !tc.hasClients) return;
        final target = ((focus - 2) * col).clamp(
          0.0,
          tc.position.maxScrollExtent,
        );
        tc.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
    final waiting = v.claimables.length;
    const labelW = 56.0;
    Widget rowLabel(String text, Color color) => SizedBox(
      height: cell + 36,
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: waiting >= 2 && !v.ended
              ? Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _pill(
                      t.get('sp_claim_all'),
                      height: 32,
                      busy: c.pending.isNotEmpty,
                      onTap: c.pending.isEmpty ? _claimAll : null,
                      key: const Key('season-pass-claim-all'),
                    ),
                  ),
                )
              : null,
        ),
        SizedBox(
          height: 20 + 2 * (cell + 36) + 8,
          child: Row(
            children: [
              SizedBox(
                width: labelW,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    rowLabel(t.get('sp_row_free'), SpColors.primary),
                    const SizedBox(height: 8),
                    rowLabel(t.get('sp_row_premium'), const Color(0xFFB07A10)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  key: const Key('season-pass-track'),
                  controller: _track,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: v.config.tierCount,
                  itemBuilder: (context, i) => SizedBox(
                    width: col,
                    child: _tierColumn(v, i + 1, cell, icon),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (v.ended)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              key: const Key('season-pass-ended'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                t.get('sp_season_ended'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: SpColors.ink),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tierColumn(SeasonPassView v, int tier, double cell, double icon) {
    final reached = v.reached(tier);
    return Column(
      children: [
        SizedBox(
          height: 20,
          child: Center(
            child: Text(
              '$tier',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: reached ? SpColors.primary : SpColors.inkSoft,
              ),
            ),
          ),
        ),
        _cellWithButton(v, tier, SpTrack.free, cell, icon),
        SizedBox(
          height: 8,
          child: Center(
            child: Container(
              width: 2,
              color: reached ? SpColors.primary : SpColors.disabled,
            ),
          ),
        ),
        _cellWithButton(v, tier, SpTrack.premium, cell, icon),
      ],
    );
  }

  Widget _cellWithButton(
    SeasonPassView v,
    int tier,
    SeasonPassTrack track,
    double cell,
    double icon,
  ) {
    final def = v.config.tiers[tier - 1];
    final reward = def.track(track);
    final parts = spRewardParts(
      reward,
      t: t,
      themeId: v.themeId,
      seasonName: _seasonName,
      petItemName: (id) =>
          s.e.petItems.where((p) => p.id == id).firstOrNull?.nameVi ?? id,
    );
    final claimed = v.status.isClaimed(tier, track);
    final claimable = v.claimable(tier, track);
    final busy = c.pending.contains(SeasonPassController.key(tier, track));
    final locked = track == SpTrack.premium && !v.status.premium;
    final premium = track == SpTrack.premium;
    Widget face = Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        color: claimable ? SpColors.cream : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: claimable
              ? SpColors.primary
              : premium
              ? SpColors.premium
              : const Color(0xFFE6DED6),
          width: claimable || premium ? 2 : 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (parts.length > 1)
            Positioned(
              left: cell * 0.12,
              top: cell * 0.08,
              child: Opacity(
                opacity: 0.55,
                child: SpRewardIcon(parts[1], size: icon * 0.8),
              ),
            ),
          if (parts.isNotEmpty)
            Center(child: SpRewardIcon(parts.first, size: icon)),
          if (parts.isNotEmpty && parts.first.qty.isNotEmpty)
            Positioned(
              right: 4,
              bottom: 2,
              child: Text(
                parts.first.qty,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SpColors.ink,
                  shadows: [Shadow(color: Colors.white, blurRadius: 3)],
                ),
              ),
            ),
          if (locked)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                key: const Key('season-pass-lock-chip'),
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SpColors.ink.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  '${_img}phuc_loi/o_khoa.webp',
                  width: 12,
                  height: 12,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.lock_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (claimed)
            const Positioned(
              right: -4,
              top: -4,
              child: Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: SpColors.primary,
              ),
            ),
        ],
      ),
    );
    if (claimed) face = Opacity(opacity: 0.5, child: face);
    if (claimable && !busy) {
      face = AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: SpColors.primary.withValues(
                  alpha: 0.15 + 0.25 * _pulse.value,
                ),
                blurRadius: 8,
              ),
            ],
          ),
          child: child,
        ),
        child: face,
      );
    }
    return SizedBox(
      height: cell + 36,
      child: Column(
        children: [
          GestureDetector(
            key: Key('season-pass-cell-${track.json}-$tier'),
            onTap: busy || parts.isEmpty
                ? null
                : () => setState(() {
                    _detail = (tier, track);
                    _dialog = _Dialog.detail;
                  }),
            child: face,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 28,
            child: claimable || busy
                ? _pill(
                    t.get('sp_claim'),
                    height: 28,
                    fontSize: 12,
                    busy: busy,
                    onTap: () => _claim(tier, track),
                    key: Key('season-pass-claim-${track.json}-$tier'),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _missions(SeasonPassView v) {
    final flowers = v.config.themes[v.themeId]?.flowers ?? const <String>[];
    final flowerNames = flowers.isEmpty ? '' : featuredNames(s.e, flowers);
    final now = v.now.toUtc().add(const Duration(hours: 7));
    final toMidnight = DateTime.utc(
      now.year,
      now.month,
      now.day + 1,
    ).difference(now);
    final groups = [
      (
        SeasonPassMissionType.daily,
        t.get('sp_group_daily'),
        t.get('sp_hours_left', {
          'hh': toMidnight.inHours.toString().padLeft(2, '0'),
          'mm': (toMidnight.inMinutes % 60).toString().padLeft(2, '0'),
        }),
      ),
      (SeasonPassMissionType.weekly, t.get('sp_group_weekly'), ''),
      (SeasonPassMissionType.season, t.get('sp_group_season'), ''),
    ];
    return ListView(
      key: const Key('season-pass-missions'),
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        for (final (type, title, clock) in groups) ...[
          SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: SpColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    clock,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SpColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (type == SeasonPassMissionType.daily && v.dailyCapped)
            Container(
              key: const Key('season-pass-daily-cap'),
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SpColors.barBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                t.get('sp_daily_cap'),
                style: const TextStyle(fontSize: 12, color: SpColors.primary),
              ),
            ),
          for (final m in _ordered(v, type))
            _missionCard(v.mission(m), flowerNames, flowers.firstOrNull),
        ],
      ],
    );
  }

  /// In progress first, then the ones the server already completed (spec
  /// §4 order without a "done, not claimed" step: the server pays them).
  List<SeasonPassMission> _ordered(
    SeasonPassView v,
    SeasonPassMissionType type,
  ) {
    final list = [
      for (final m in v.config.missions)
        if (m.type == type) m,
    ];
    return [
      ...list.where((m) => !v.mission(m).done),
      ...list.where((m) => v.mission(m).done),
    ];
  }

  static IconData _goalIcon(String goal) => switch (goal) {
    'bouquetsSold' => Icons.local_florist_rounded,
    'greatReviews' => Icons.star_rounded,
    'onlineDelivered' => Icons.delivery_dining_rounded,
    'occasionVariety' => Icons.celebration_rounded,
    'themeFlowerStemsSold' => Icons.spa_rounded,
    'gameDaysPlayed' => Icons.storefront_rounded,
    'loginDays' => Icons.event_available_rounded,
    _ => Icons.task_alt_rounded,
  };

  Widget _missionCard(
    SeasonPassMissionState st,
    String flowers,
    String? firstFlower,
  ) {
    final m = st.mission;
    final title = t.get(m.titleKey, {
      'target': coinFull(m.target),
      'flower': flowers,
    });
    final art = spMissionArt(m.goal, firstFlower);
    final fb = Image.asset(
      '$_img$_ticketArt',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(_goalIcon(m.goal), size: 28, color: SpColors.primary),
    );
    final card = Container(
      key: Key('season-pass-mission-${m.key}'),
      height: 72,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 40,
            child: Image.asset(
              '$_img$art',
              key: Key('season-pass-mission-art-${m.key}'),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fb,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: SpColors.ink),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: m.target == 0 ? 0 : st.current / m.target,
                          minHeight: 4,
                          backgroundColor: SpColors.barBg,
                          color: SpColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.get('sp_mission_progress', {
                        'cur': coinFull(st.current),
                        'target': coinFull(m.target),
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        color: SpColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                t.get('sp_points', {'n': coinFull(m.xp)}),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SpColors.primary,
                ),
              ),
              if (st.done)
                Text(
                  t.get('sp_claimed'),
                  style: const TextStyle(fontSize: 12, color: SpColors.inkSoft),
                ),
            ],
          ),
        ],
      ),
    );
    return st.done ? Opacity(opacity: 0.5, child: card) : card;
  }

  Widget _bottomBar(SeasonPassView v) {
    final Widget? child;
    if (v.ended) {
      child = null;
    } else if (v.status.premium) {
      child = Container(
        key: const Key('season-pass-bought'),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SpColors.primary, width: 2),
        ),
        child: Text(
          t.get('sp_bought'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: SpColors.primary,
          ),
        ),
      );
    } else if (v.canBuy) {
      child = _pill(
        t.get('sp_buy_button', {'n': coinFull(v.config.premiumPrice)}),
        height: 48,
        busy: c.buying,
        onTap: _openBuy,
        key: const Key('season-pass-buy'),
      );
    } else {
      child = null;
    }
    if (child == null) return const SizedBox.shrink();
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: SpColors.cream,
        border: Border(top: BorderSide(color: Color(0xFFEDE3D3))),
      ),
      child: SizedBox(width: double.infinity, child: child),
    );
  }

  Widget _pill(
    String label, {
    required VoidCallback? onTap,
    double height = 44,
    double fontSize = 14,
    bool busy = false,
    bool outlined = false,
    Key? key,
  }) => SizedBox(
    height: height,
    child: Material(
      color: outlined ? Colors.white : SpColors.primary,
      shape: StadiumBorder(
        side: outlined
            ? const BorderSide(color: SpColors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        key: key,
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: height < 32 ? 10 : 18),
          child: Center(
            widthFactor: 1,
            child: busy
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: outlined ? SpColors.primary : Colors.white,
                    ),
                  )
                : Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: outlined ? SpColors.primary : Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );

  Widget _toastView() {
    final failed = _toast == 'sp_claim_failed' || _toast == 'sp_claim_flagged';
    return Positioned(
      left: 24,
      right: 24,
      bottom: 88,
      child: Container(
        key: Key('season-pass-toast-$_toast'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: failed ? SpColors.dot : SpColors.ink,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          t.get(_toast!),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
      ),
    );
  }

  Widget _dialogView(bool compact) {
    final v = c.view;
    if (v == null) return const SizedBox.shrink();
    final close = c.buying
        ? null
        : () => setState(() => _dialog = _Dialog.none);
    final price = v.config.premiumPrice;
    final bal = _balance;
    Widget balanceRow() => bal == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  '${_img}nav/pha_le.webp',
                  width: 16,
                  height: 16,
                  errorBuilder: (_, _, _) => const SizedBox(width: 16),
                ),
                const SizedBox(width: 4),
                Text(
                  t.get('sp_balance', {'n': coinFull(bal)}),
                  style: const TextStyle(fontSize: 12, color: SpColors.inkSoft),
                ),
              ],
            ),
          );
    Text title(String text) => Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: SpColors.ink,
      ),
    );
    Text body(String text) => Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, color: SpColors.ink),
    );
    final List<Widget> content;
    switch (_dialog) {
      case _Dialog.buy:
        content = [
          title(t.get('sp_buy_title')),
          const SizedBox(height: 12),
          body(
            t.get('sp_buy_body', {'n': coinFull(price), 'tenMua': _seasonName}),
          ),
          balanceRow(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _pill(
                  t.get('sp_buy_cancel'),
                  outlined: true,
                  onTap: close,
                  key: const Key('season-pass-buy-cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pill(
                  t.get('sp_buy_confirm'),
                  busy: c.buying,
                  onTap: _confirmBuy,
                  key: const Key('season-pass-buy-confirm'),
                ),
              ),
            ],
          ),
        ];
      case _Dialog.notEnough:
        content = [
          title(t.get('sp_not_enough_title')),
          const SizedBox(height: 12),
          body(
            t.get('sp_not_enough', {'n': coinFull(max(0, price - (bal ?? 0)))}),
          ),
          balanceRow(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _pill(
              t.get('sp_ok'),
              onTap: close,
              key: const Key('season-pass-not-enough-ok'),
            ),
          ),
        ];
      case _Dialog.claimed:
        final rewards = [
          for (final (tier, track) in _claimedShown)
            v.config.tiers[tier - 1].track(track),
        ];
        final parts = [
          for (final r in rewards)
            ...spRewardParts(
              r,
              t: t,
              themeId: v.themeId,
              seasonName: _seasonName,
            ),
        ];
        content = [
          title(t.get('sp_claim_done_title')),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final p in parts)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SpRewardIcon(p, size: 56),
                    if (p.qty.isNotEmpty)
                      Text(
                        p.qty,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SpColors.ink,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (rewards.any((r) => r.hasWardrobeItem)) ...[
            const SizedBox(height: 12),
            body(t.get('sp_claim_done_wardrobe')),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _pill(
              t.get('sp_claim_done_ok'),
              onTap: close,
              key: const Key('season-pass-claimed-ok'),
            ),
          ),
        ];
      case _Dialog.detail:
        final (tier, track) = _detail!;
        final parts = spRewardParts(
          v.config.tiers[tier - 1].track(track),
          t: t,
          themeId: v.themeId,
          seasonName: _seasonName,
        );
        content = [
          title(t.get('sp_reward_header', {'x': tier})),
          const SizedBox(height: 4),
          Text(
            t.get(track == SpTrack.free ? 'sp_row_free' : 'sp_row_premium'),
            style: const TextStyle(fontSize: 12, color: SpColors.inkSoft),
          ),
          const SizedBox(height: 12),
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SpRewardIcon(p, size: 36),
                  const SizedBox(width: 12),
                  Expanded(child: body(p.label)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _pill(
              t.get('sp_ok'),
              onTap: close,
              key: const Key('season-pass-detail-ok'),
            ),
          ),
        ];
      case _Dialog.none:
        content = const [];
    }
    return Positioned.fill(
      child: GestureDetector(
        onTap: _dialog == _Dialog.detail ? close : null,
        child: ColoredBox(
          color: SpColors.ink.withValues(alpha: 0.45),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                key: Key('season-pass-dialog-${_dialog.name}'),
                width: compact ? 296 : 312,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Short names for the two tracks inside this file.
typedef SpTrack = SeasonPassTrack;
