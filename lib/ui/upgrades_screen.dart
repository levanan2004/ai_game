import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../logic/upgrades.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// Màn Nâng cấp và mở khóa (spec_nang_cap.md): tab "Tiệm" with the
/// upgrades in economy.json order, tab "Hoa, giấy và nơ" with the unlock
/// grid, and the confirm popup.
class UpgradesScreen extends StatefulWidget {
  const UpgradesScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<UpgradesScreen> createState() => _UpgradesScreenState();
}

/// What the confirm popup is about: an upgrade level or an item unlock.
class _Pending {
  const _Pending.upgrade(this.id) : unlock = false;
  const _Pending.unlock(this.id) : unlock = true;

  final String id;
  final bool unlock;
}

class _UpgradesScreenState extends State<UpgradesScreen>
    with TickerProviderStateMixin {
  late int _tab = widget.session.upgradesInitialTab;
  _Pending? _pending;

  /// Coin bursts from the money pill after a purchase (`coinGain`).
  final List<AnimationController> _bursts = [];

  ShopSession get s => widget.session;

  @override
  void dispose() {
    for (final b in _bursts) {
      b.dispose();
    }
    super.dispose();
  }

  void _coinBurst() {
    final c = AnimationController(vsync: this, duration: AppMotion.celebrate);
    c.addStatusListener((st) {
      if (st == AnimationStatus.completed && mounted) {
        setState(() => _bursts.remove(c));
        c.dispose();
      }
    });
    setState(() => _bursts.add(c));
    c.forward();
  }

  void _confirm() {
    final p = _pending;
    if (p == null) return;
    final ok = p.unlock ? s.unlockItem(p.id) : s.buyUpgrade(p.id);
    setState(() => _pending = null);
    if (ok) _coinBurst();
  }

  @override
  Widget build(BuildContext context) {
    final negative = s.state.money < 0;
    final listTop = negative ? 192.0 : 150.0;
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: TopBar(session: s, dayLabel: 'Ngày ${s.state.day}'),
          ),
          Positioned(
            left: 12,
            top: 54,
            child: BackButtonBox(
              key: const Key('upgrades-back'),
              onTap: s.closeUpgrades,
            ),
          ),
          Positioned(
            left: 56,
            right: 56,
            top: 54,
            height: 32,
            child: Center(
              child: Text('Nâng cấp tiệm', style: AppText.heading(size: 20)),
            ),
          ),
          Positioned(
            left: 12,
            top: 98,
            width: 336,
            height: 40,
            child: _Tabs(active: _tab, onTap: (i) => setState(() => _tab = i)),
          ),
          if (negative)
            Positioned(
              left: 12,
              top: 150,
              width: 336,
              height: 34,
              child: Container(
                key: const Key('debt-banner'),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.accentBase,
                    width: AppBorder.thin,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Trả hết nợ để nâng cấp tiếp nhé',
                  style: AppText.body(size: 13, weight: 800),
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: listTop,
            width: 360,
            bottom: 0,
            child: _tab == 0 ? _upgradeList() : _unlockGrid(),
          ),
          for (final b in _bursts) _CoinBurst(animation: b),
          if (_pending != null)
            Positioned.fill(
              child: _ConfirmPopup(
                session: s,
                pending: _pending!,
                onCancel: () => setState(() => _pending = null),
                onConfirm: _confirm,
              ),
            ),
        ],
      ),
    );
  }

  Widget _upgradeList() {
    final ups = s.e.upgrades;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: ups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _UpgradeCard(
        key: Key('upgrade-${ups[i].id}'),
        session: s,
        upgrade: ups[i],
        onBuy: () => setState(() => _pending = _Pending.upgrade(ups[i].id)),
      ),
    );
  }

  Widget _unlockGrid() {
    final e = s.e;
    final groups = <(String, List<String>)>[
      ('Hoa', [for (final f in e.flowers) f.id]),
      ('Giấy gói', [for (final p in e.papers) p.id]),
      ('Nơ', [for (final r in e.ribbons) r.id]),
    ];
    final children = <Widget>[];
    for (final (title, ids) in groups) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(title, style: AppText.heading(size: 14)),
        ),
      );
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in ids)
              _UnlockCard(
                key: Key('unlock-$id'),
                session: s,
                itemId: id,
                onBuy: () => setState(() => _pending = _Pending.unlock(id)),
              ),
          ],
        ),
      );
      children.add(const SizedBox(height: 12));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: children,
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.active, required this.onTap});

  final int active;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const labels = ['Tiệm', 'Hoa, giấy và nơ'];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: AppBorder.thin,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: GestureDetector(
                key: Key('upgrades-tab-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: AppMotion.base,
                  decoration: BoxDecoration(
                    color: i == active ? AppColors.primaryBase : null,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: AppText.button(
                      size: 14,
                      weight: 800,
                      color: i == active
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
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

/// Placeholder dot colours from Phú's mockup, used only if a PNG is missing.
/// TODO(Phú): display/online/ads had no mock colour.
Color _upgradeDotColor(String id) => switch (id) {
  'cold_storage' => AppColors.statusInfo,
  'wrapping_table' => AppColors.primaryBase,
  'bench' => AppColors.secondaryBase,
  'counter' => AppColors.accentBase,
  'staff' => AppColors.currencyCoin,
  _ => AppColors.surfaceBorderStrong,
};

class _UpgradeIcon extends StatelessWidget {
  const _UpgradeIcon({
    required this.id,
    required this.box,
    required this.image,
  });

  final String id;
  final double box;
  final double image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: ArtImage(
        Art.upgrade(id),
        size: image,
        fallback: Container(
          width: box * 0.55,
          height: box * 0.55,
          decoration: BoxDecoration(
            color: _upgradeDotColor(id),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// "Cấp 2: hoa tươi thêm 2 ngày" for the next level (or the top level
/// when maxed). Ads has one level and no "Cấp" prefix.
String upgradeCardLine(UpgradeDef u, int level, UpgradeStatus st) {
  final shown =
      st.next ?? u.levels[math.max(0, math.min(level, u.maxLevel) - 1)];
  final text = describeEffect(shown.effect);
  if (u.consumable) return capitalize(text);
  return 'Cấp ${shown.level}: $text';
}

/// Status caption: "Chưa có" or "Đang có cấp N · phí Xk/ngày".
String upgradeStatusLine(ShopSession s, UpgradeDef u) {
  if (u.consumable) {
    final left = s.state.adsDaysLeft;
    // TODO(Phú): spec only gives the button label "Đang chạy".
    return left > 0 ? 'Còn $left ngày' : 'Chưa có';
  }
  final lv = s.state.upgradeLevels[u.id] ?? 0;
  if (lv <= 0) return 'Chưa có';
  final fee = upkeepLabel(u.levels[math.min(lv, u.maxLevel) - 1]);
  return fee == null ? 'Đang có cấp $lv' : 'Đang có cấp $lv · $fee';
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    super.key,
    required this.session,
    required this.upgrade,
    required this.onBuy,
  });

  final ShopSession session;
  final UpgradeDef upgrade;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final u = upgrade;
    final lv = s.state.upgradeLevels[u.id] ?? 0;
    final st = s.statusOf(u.id);
    return SizedBox(
      height: 80,
      child: CardBox(
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 14,
              child: _UpgradeIcon(id: u.id, box: 52, image: 44),
            ),
            Positioned(
              left: 74,
              top: 5,
              width: 180,
              height: 22,
              child: Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(u.nameVi, style: AppText.heading(size: 15)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (u.consumable)
                    Text(
                      'Dùng ${u.levels.first.durationDays ?? 1} ngày',
                      style: AppText.caption(size: 10, weight: 800),
                    )
                  else
                    for (var i = 0; i < u.maxLevel; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _LevelDot(
                          lit: i < lv,
                          key: ValueKey('dot-$i-${i < lv}'),
                        ),
                      ),
                ],
              ),
            ),
            Positioned(
              left: 74,
              top: 27,
              width: 176,
              child: Text(
                upgradeCardLine(u, lv, st),
                key: Key('upgrade-line-${u.id}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  size: 11,
                  weight: 700,
                ).copyWith(height: 1.2),
              ),
            ),
            Positioned(
              left: 74,
              top: 57,
              width: 176,
              child: Text(
                upgradeStatusLine(s, u),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(size: 10),
              ),
            ),
            Positioned(
              right: 12,
              top: 23,
              width: 66,
              height: 34,
              child: _PriceArea(
                session: s,
                upgrade: u,
                status: st,
                onBuy: onBuy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Level dot (8 px, 12 apart); a newly lit dot pops in (`easing.pop`).
class _LevelDot extends StatelessWidget {
  const _LevelDot({super.key, required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: lit ? AppColors.primaryBase : AppColors.freshnessTrack,
        shape: BoxShape.circle,
      ),
    );
    if (!lit) return dot;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: AppMotion.slow,
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: dot,
    );
  }
}

class _PriceArea extends StatelessWidget {
  const _PriceArea({
    required this.session,
    required this.upgrade,
    required this.status,
    required this.onBuy,
  });

  final ShopSession session;
  final UpgradeDef upgrade;
  final UpgradeStatus status;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final st = status;
    switch (st.block) {
      case UpgradeBlock.maxed:
        return Center(
          child: Text(
            'Tối đa',
            style: AppText.body(
              size: 13,
              weight: 800,
              color: AppColors.textSecondary,
            ),
          ),
        );
      case UpgradeBlock.requires:
        final name = session.e.upgrade(st.requiresId!).nameVi;
        return DisabledPrice(
          label: 'Cần $name cấp ${st.requiresLevel}',
          small: true,
        );
      case UpgradeBlock.adsRunning:
        return const DisabledPrice(label: 'Đang chạy');
      case UpgradeBlock.comingSoon:
        // TODO(Khoa/Phú): online orders are not in the game yet.
        return const DisabledPrice(label: 'Sắp có');
      case UpgradeBlock.poor:
      case UpgradeBlock.negativeMoney:
      case UpgradeBlock.shopOpen:
        return DisabledPrice(label: formatK(st.next!.cost));
      case null:
        return PriceButton(
          key: Key('buy-${upgrade.id}'),
          label: formatK(st.next!.cost),
          onTap: onBuy,
        );
    }
  }
}

/// Green price button 66×30 (`secondary`).
class PriceButton extends StatelessWidget {
  const PriceButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChunkyButton(
    label: label,
    onPressed: onTap,
    kind: ButtonKind.secondary,
    radius: 15,
    fontSize: 13,
  );
}

/// Disabled price: `surface.sunken` with `text.disabled`.
class DisabledPrice extends StatelessWidget {
  const DisabledPrice({super.key, required this.label, this.small = false});

  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSize.shadowOffset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: AppColors.surfaceBorder,
            width: AppBorder.thin,
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: small ? 2 : 1,
            style: small
                ? AppText.caption(
                    size: 9,
                    weight: 800,
                    color: AppColors.textDisabled,
                  )
                : AppText.button(
                    size: 13,
                    weight: 800,
                    color: AppColors.textDisabled,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Flower / paper / ribbon card 164×132 in the unlock grid.
class _UnlockCard extends StatelessWidget {
  const _UnlockCard({
    super.key,
    required this.session,
    required this.itemId,
    required this.onBuy,
  });

  final ShopSession session;
  final String itemId;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final info = unlockInfo(s.e, itemId);
    final owned = s.owned.contains(itemId);
    final cost = s.unlockCostOf(itemId) ?? 0;
    return SizedBox(
      width: 164,
      height: 132,
      child: CardBox(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 6,
              child: Center(
                child: ArtImage(
                  info.image,
                  size: 56,
                  opacity: owned ? 1 : 0.85,
                ),
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              top: 62,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(info.name, style: AppText.heading(size: 13)),
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              top: 81,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(info.line, style: AppText.caption(size: 10)),
              ),
            ),
            Positioned(
              left: 41,
              width: 82,
              top: 98,
              height: 30,
              child: owned
                  ? Center(
                      child: Text(
                        'Đã có',
                        style: AppText.body(
                          size: 13,
                          weight: 800,
                          color: AppColors.statusSuccess,
                        ),
                      ),
                    )
                  : s.canUnlock(itemId)
                  ? PriceButton(
                      key: Key('buy-$itemId'),
                      label: formatK(cost),
                      onTap: onBuy,
                    )
                  : DisabledPrice(label: formatK(cost)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name, picture and info line of an unlockable item.
({String name, String image, String line}) unlockInfo(Economy e, String id) {
  for (final f in e.flowers) {
    if (f.id == id) {
      return (
        name: f.nameVi,
        image: Art.flower(id),
        line: 'Bó ${f.bundleSize} cành · tươi ${f.freshnessDays} ngày',
      );
    }
  }
  for (final p in e.papers) {
    if (p.id == id) {
      return (
        name: p.nameVi,
        image: Art.paper(id),
        line: 'Giá bán ${formatK(p.sellPrice)} mỗi bó',
      );
    }
  }
  final r = e.ribbons.firstWhere((r) => r.id == id);
  return (
    name: r.nameVi,
    image: Art.ribbon(id),
    line: 'Giá bán ${formatK(r.sellPrice)} mỗi bó',
  );
}

/// Popup 296×272 (nang_cap_xac_nhan_v0.1.png), `popupIn`.
class _ConfirmPopup extends StatelessWidget {
  const _ConfirmPopup({
    required this.session,
    required this.pending,
    required this.onCancel,
    required this.onConfirm,
  });

  final ShopSession session;
  final _Pending pending;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = pending.unlock
        ? unlockConfirmContent(
            session.e,
            pending.id,
            session.unlockCostOf(pending.id) ?? 0,
          )
        : upgradeConfirmContent(session, pending.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCancel,
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Stack(
          children: [
            Positioned(
              left: 32,
              top: 184,
              width: 296,
              height: 272,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppMotion.slow,
                curve: Curves.easeOutBack,
                builder: (_, t, child) => Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
                ),
                child: GestureDetector(onTap: () {}, child: _popupCard(c)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _popupCard(ConfirmContent c) {
    return Container(
      key: const Key('upgrade-confirm'),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.surfaceBorderStrong,
            offset: Offset(0, AppSize.shadowOffset),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 116,
            top: 12,
            child: pending.unlock
                ? Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: ArtImage(c.image, size: 56),
                  )
                : _UpgradeIcon(id: pending.id, box: 64, image: 56),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 84,
            height: 28,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(c.title, style: AppText.heading(size: 18)),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 118,
            height: 64,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _row('Hiện tại', c.current, AppColors.textPrimary),
                  _row(c.afterLabel, c.after, AppColors.statusSuccess),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 190,
            child: Text(
              c.note,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(size: 11),
            ),
          ),
          Positioned(
            left: 16,
            top: 216,
            width: 104,
            height: 50,
            child: ChunkyButton(
              key: const Key('confirm-cancel'),
              label: 'Để sau',
              onPressed: onCancel,
              kind: ButtonKind.ghost,
              fontSize: 15,
            ),
          ),
          Positioned(
            left: 128,
            top: 216,
            width: 152,
            height: 50,
            child: ChunkyButton(
              key: const Key('confirm-buy'),
              label: c.button,
              onPressed: onConfirm,
              kind: ButtonKind.secondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) => Row(
    children: [
      Text(label, style: AppText.caption(size: 11)),
      const SizedBox(width: 8),
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            value,
            style: AppText.body(size: 12, weight: 800, color: color),
          ),
        ),
      ),
    ],
  );
}

class ConfirmContent {
  const ConfirmContent({
    required this.title,
    required this.current,
    required this.after,
    required this.note,
    required this.button,
    this.afterLabel = 'Sau khi nâng',
    this.image = '',
  });

  final String title;
  final String current;
  final String afterLabel;
  final String after;
  final String note;
  final String button;
  final String image;
}

/// Popup text for buying the next level of [id]: first effect part in the
/// comparison, the new upkeep (or the other effect parts) as the note.
ConfirmContent upgradeConfirmContent(ShopSession s, String id) {
  final u = s.e.upgrade(id);
  final st = s.statusOf(id);
  final next = st.next ?? u.levels.last;
  final lv = s.state.upgradeLevels[id] ?? 0;
  final nextParts = describeEffectParts(next.effect);
  final curLevel = u.consumable || lv <= 0
      ? null
      : u.levels[math.min(lv, u.maxLevel) - 1];
  final curParts = curLevel == null
      ? const <String>[]
      : describeEffectParts(curLevel.effect);
  final fee = next.dailyUpkeep + next.dailyWage;
  final String note;
  if (fee > 0) {
    // TODO(Phú): spec says "phí duy trì mới nếu có" without exact copy.
    note = next.dailyWage > 0
        ? 'Lương nhân viên ${formatK(fee)}/ngày'
        : 'Phí duy trì mới ${formatK(fee)}/ngày';
  } else if (nextParts.length > 1) {
    note = capitalize(nextParts.skip(1).join(', '));
  } else if (u.consumable) {
    note = 'Hiệu lực ${next.durationDays ?? 1} ngày';
  } else {
    note = '';
  }
  return ConfirmContent(
    title: u.consumable ? u.nameVi : '${u.nameVi} · cấp ${next.level}',
    current: curParts.isEmpty ? 'Chưa có' : capitalize(curParts.first),
    after: nextParts.isEmpty ? '' : capitalize(nextParts.first),
    note: note,
    button: 'Nâng · ${formatK(next.cost)}',
  );
}

/// Popup text for unlocking a flower, paper or ribbon.
/// TODO(Phú): the unlock congratulation popup is not in a spec yet; this
/// reuses the confirm layout.
ConfirmContent unlockConfirmContent(Economy e, String id, int cost) {
  final info = unlockInfo(e, id);
  final isFlower = e.flowers.any((f) => f.id == id);
  return ConfirmContent(
    title: info.name,
    current: 'Chưa có',
    afterLabel: 'Sau khi mở',
    after: info.line,
    note: isFlower ? 'Mua được ở Chợ hoa' : 'Dùng được ở Bàn bó hoa',
    button: 'Mở khóa · ${formatK(cost)}',
    image: info.image,
  );
}

/// A few coins flying out of the money pill (`coinGain`, 600 ms).
class _CoinBurst extends StatelessWidget {
  const _CoinBurst({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          builder: (_, _) {
            final t = Curves.easeOutCubic.transform(animation.value);
            return Stack(
              children: [
                for (var i = 0; i < 5; i++)
                  Positioned(
                    left: 28 + math.cos(-0.3 + i * 0.35) * 70 * t,
                    top: 20 + math.sin(-0.3 + i * 0.35) * 70 * t + 40 * t * t,
                    child: Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: const CoinIcon(size: 16),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
