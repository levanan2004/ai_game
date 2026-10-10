import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'pet_shop_grid.dart' show CurrencyButton, petGroupedCount, shortfallText;
import 'pot_widgets.dart';
import 'ui_skin.dart';

String _pad2(int n) => n < 10 ? '0$n' : '$n';

/// "Mua 150.000 xu" / "Mua 300 Pha lê".
String potBuyText(PotDef pot) =>
    'Mua ${petGroupedCount(pot.cost)} ${pot.paysPhaLe ? 'Pha lê' : 'xu'}';

/// "Còn 3 chậu nữa là nhận 300 Pha lê", or "Bạn đã đủ bộ!" once nothing is
/// left. [extra] pots count as owned already (the one being bought).
String potLeftLine(ShopSession s, String group, {int extra = 0}) {
  final left = s.groupTotal(group) - s.groupOwned(group) - extra;
  if (left <= 0) return 'Bạn đã đủ bộ!';
  final reward = s.collectionReward(group);
  return reward > 0
      ? 'Còn $left chậu nữa là nhận ${potRewardText(reward)}'
      : 'Còn $left chậu nữa là đủ bộ';
}

/// Tiệm Chậu Hoa (SPEC_tiem_chau_hoa.md): three tabs, a set strip, a grid
/// of pot cards with buy buttons. Buying asks first, then offers to place
/// the pot. Opened with [ShopSession.openPotShop].
class PotShopScreen extends StatefulWidget {
  const PotShopScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<PotShopScreen> createState() => _PotShopScreenState();
}

class _PotShopScreenState extends State<PotShopScreen> {
  final _scroll = ScrollController();
  PotDef? _confirm;
  PotDef? _bought;
  String? _scrolledTo;

  ShopSession get s => widget.session;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _focusScroll(List<PotDef> pots) {
    final focus = s.potShopFocusId;
    if (focus == null || focus == _scrolledTo) return;
    final i = pots.indexWhere((p) => p.id == focus);
    if (i < 0) return;
    _scrolledTo = focus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final row = i ~/ 2;
      final view = _scroll.position.viewportDimension;
      final target = row * (218 + 12) - (view - 218) / 2;
      _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final group = s.potShopTab;
        final pots = s.potShopList(group);
        if (s.potShopFocusId == null) _scrolledTo = null;
        _focusScroll(pots);
        return OpaqueScreen(
          color: AppColors.bgBase,
          child: Stack(
            key: const Key('pot-shop'),
            children: [
              Positioned(
                left: 16,
                right: 16,
                top: 106,
                bottom: 0,
                child: Column(
                  children: [
                    PotGroupTabs(
                      session: s,
                      selected: group,
                      keyPrefix: 'potshop-tab',
                      onSelect: s.selectPotShopTab,
                    ),
                    const SizedBox(height: 8),
                    _Strip(session: s, group: group),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        key: const Key('potshop-grid'),
                        controller: _scroll,
                        padding: const EdgeInsets.only(bottom: 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              mainAxisExtent: 230,
                            ),
                        itemCount: pots.length,
                        itemBuilder: (context, i) => PotShopCard(
                          key: Key('potshop-card-${pots[i].id}'),
                          session: s,
                          pot: pots[i],
                          focused: s.potShopFocusId == pots[i].id,
                          onBuy: () => setState(() => _confirm = pots[i]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...potScreenHeader(
                s,
                title: 'Tiệm Chậu Hoa',
                backKey: const Key('potshop-back'),
                onBack: s.closePotShop,
              ),
              if (_confirm != null)
                Positioned.fill(
                  child: PotConfirmPopup(
                    session: s,
                    pot: _confirm!,
                    onClose: () => setState(() => _confirm = null),
                    onBought: (pot) => setState(() {
                      _confirm = null;
                      _bought = pot;
                    }),
                  ),
                ),
              if (_bought != null)
                Positioned.fill(
                  child: PotBoughtPopup(
                    session: s,
                    pot: _bought!,
                    onClose: () => setState(() => _bought = null),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The set strip under the tabs: name, count, progress, the reward line and
/// the Sổ sưu tầm button.
class _Strip extends StatelessWidget {
  const _Strip({required this.session, required this.group});

  final ShopSession session;
  final String group;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final owned = s.groupOwned(group);
    final total = s.groupTotal(group);
    final reward = s.collectionReward(group);
    return Container(
      key: const Key('potshop-strip'),
      height: 68,
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorderStrong, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bộ ${s.potGroupName(group)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(
                          size: 15,
                          weight: 800,
                          color: AppColors.primaryPressed,
                        ).copyWith(height: 1.15),
                      ),
                    ),
                    Text(
                      '$owned/$total',
                      key: const Key('potshop-count'),
                      style: AppText.title(
                        size: 13,
                        weight: 800,
                      ).copyWith(height: 1.15),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                CollectionProgress(
                  value: owned,
                  total: total,
                  done: total > 0 && owned >= total,
                  height: 8,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const RewardGiftIcon(size: 15),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        reward > 0
                            ? 'mỗi bộ: Đủ bộ nhận ${potRewardText(reward)}'
                            : 'mỗi bộ: Đủ bộ có quà',
                        key: const Key('potshop-reward'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                          size: 11,
                          weight: 800,
                          color: AppColors.onSecondary,
                        ).copyWith(height: 1.2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: SkinButton(
              key: const Key('potshop-book'),
              label: 'Sổ sưu tầm',
              kind: SkinButtonKind.secondary,
              height: 36,
              fontSize: 12,
              onPressed: () => s.openPotBook(group: group),
            ),
          ),
        ],
      ),
    );
  }
}

/// One pot of the shop (173×218 in the spec; 158 wide at 360).
class PotShopCard extends StatelessWidget {
  const PotShopCard({
    super.key,
    required this.session,
    required this.pot,
    required this.onBuy,
    this.focused = false,
  });

  final ShopSession session;
  final PotDef pot;
  final VoidCallback onBuy;
  final bool focused;

  String _sub(ShopSession s) {
    final group = s.potGroupOf(pot);
    final how = pot.howVi ?? '';
    // A pot that also comes as a gift says so ("Quà ngày 2 hoặc mua 300 Pha
    // lê", up to two lines); a pure buy shows its place in the set.
    if (how.isNotEmpty && !how.startsWith('Mua ')) return how;
    return 'Bộ ${s.potGroupName(group)} · '
        '${_pad2(s.potNumber(pot))}/${s.groupTotal(group)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final amber = pot.paysPhaLe;
    final owned = s.potHas(pot.id);
    final missing = s.potShortfall(pot);
    final canPay = !owned && missing == 0;
    final accent = amber ? AppColors.statusWarning : AppColors.primaryBase;
    final card = CardBox(
      radius: 16,
      borderWidth: 1.5,
      borderColor: amber ? AppColors.accentBase : AppColors.surfaceBorder,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 108,
            decoration: BoxDecoration(
              color: amber ? const Color(0xFFFDEFC6) : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 8,
                  top: 6,
                  child: Text(
                    _pad2(s.potNumber(pot)),
                    style: AppText.title(size: 11, weight: 800, color: accent),
                  ),
                ),
                if (owned)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      key: Key('potshop-tick-${pot.id}'),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBase,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 10,
                  child: PotArt(pot: pot, base: 84 / 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                s.potFullName(pot),
                key: Key('potshop-name-${pot.id}'),
                maxLines: 1,
                style: AppText.title(size: 16, weight: 700),
              ),
            ),
          ),
          SizedBox(
            height: 28,
            child: Text(
              _sub(s),
              key: Key('potshop-sub-${pot.id}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 11,
                weight: 700,
                color: AppColors.textSecondary,
              ).copyWith(height: 1.2),
            ),
          ),
          const Spacer(),
          if (owned)
            Builder(
              builder: (context) => GestureDetector(
                key: Key('potshop-owned-${pot.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => showTapHint(context, 'Mỗi chậu chỉ mua một lần'),
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryBase,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: AppColors.primaryPressed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Đã có',
                        style: AppText.title(
                          size: 15,
                          weight: 800,
                          color: AppColors.primaryPressed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            CurrencyButton(
              key: Key('potshop-buy-${pot.id}'),
              phaLe: amber,
              priceText: potBuyText(pot),
              enabled: canPay,
              height: 36,
              fontSize: 14,
              onTap: onBuy,
              onBlocked: (context) => showTapHint(
                context,
                shortfallText(phaLe: amber, missing: missing),
              ),
            ),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: card),
        if (focused)
          Positioned(
            left: -3,
            top: -3,
            right: -3,
            bottom: -3,
            child: IgnorePointer(
              child: DecoratedBox(
                key: Key('potshop-focus-${pot.id}'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: AppColors.accentBase, width: 3),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.onClose, required this.child, this.keyName});

  final VoidCallback onClose;
  final Widget child;
  final String? keyName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: keyName == null ? null : Key('$keyName-dismiss'),
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: SizedBox(
              key: keyName == null ? null : Key(keyName!),
              width: 320,
              child: SkinPanel(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Mua chậu {tên}?" (T3, T3b): shows the full price; tapping outside is
/// "Để sau". A pot is only ever bought from this popup, so one tap on a card
/// never spends Pha lê.
class PotConfirmPopup extends StatelessWidget {
  const PotConfirmPopup({
    super.key,
    required this.session,
    required this.pot,
    required this.onClose,
    required this.onBought,
  });

  final ShopSession session;
  final PotDef pot;
  final VoidCallback onClose;
  final void Function(PotDef pot) onBought;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final group = s.potGroupOf(pot);
    final amber = pot.paysPhaLe;
    return _Backdrop(
      keyName: 'potshop-confirm',
      onClose: onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mua chậu ${s.potShortName(pot)}?',
            key: const Key('potshop-confirm-title'),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppText.title(size: 20, weight: 800),
          ),
          const SizedBox(height: 10),
          Container(
            height: 130,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: amber ? const Color(0xFFFDEFC6) : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: PotArt(pot: pot, base: 112 / 1.1),
          ),
          const SizedBox(height: 10),
          Text(
            'Bộ ${s.potGroupName(group)} · '
            '${_pad2(s.potNumber(pot))}/${s.groupTotal(group)}',
            textAlign: TextAlign.center,
            style: AppText.body(size: 13, weight: 800),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentBase),
            ),
            child: Row(
              children: [
                const RewardGiftIcon(size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    potLeftLine(s, group, extra: 1),
                    key: const Key('potshop-confirm-left'),
                    style: AppText.body(
                      size: 12,
                      weight: 800,
                      color: AppColors.onSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: SkinButton(
                    key: const Key('potshop-confirm-later'),
                    label: 'Để sau',
                    kind: SkinButtonKind.secondary,
                    height: 44,
                    fontSize: 16,
                    onPressed: onClose,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Builder(
                    builder: (context) => CurrencyButton(
                      key: const Key('potshop-confirm-yes'),
                      phaLe: amber,
                      priceText: potBuyText(pot),
                      enabled: true,
                      height: 44,
                      fontSize: 14,
                      onTap: () {
                        final missing = s.potShortfall(pot);
                        if (missing > 0 || !s.potCanBuy(pot)) {
                          showTapHint(
                            context,
                            missing > 0
                                ? shortfallText(phaLe: amber, missing: missing)
                                : 'Mỗi chậu chỉ mua một lần',
                          );
                          onClose();
                          return;
                        }
                        if (s.buyPot(pot.id)) onBought(pot);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Đã có chậu {tên}!" (T4, T4b): place it, open the book, or later.
/// While the shop serves, placing is grey and does nothing.
class PotBoughtPopup extends StatelessWidget {
  const PotBoughtPopup({
    super.key,
    required this.session,
    required this.pot,
    required this.onClose,
  });

  final ShopSession session;
  final PotDef pot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final group = s.potGroupOf(pot);
    final owned = s.groupOwned(group);
    final total = s.groupTotal(group);
    final canPlace = s.potPlaceAllowed;
    return _Backdrop(
      keyName: 'potshop-bought',
      onClose: onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Đã có chậu ${s.potShortName(pot)}!',
            key: const Key('potshop-bought-title'),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppText.title(size: 20, weight: 800),
          ),
          const SizedBox(height: 10),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final p in const [
                  Offset(24, 22),
                  Offset(262, 30),
                  Offset(40, 98),
                  Offset(246, 92),
                ])
                  Positioned(
                    left: p.dx - 8,
                    top: p.dy - 8,
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: AppColors.accentBase,
                    ),
                  ),
                PotArt(pot: pot, base: 122 / 1.1),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Bộ ${s.potGroupName(group)}: $owned/$total',
            key: const Key('potshop-bought-count'),
            textAlign: TextAlign.center,
            style: AppText.body(size: 13, weight: 800),
          ),
          const SizedBox(height: 6),
          CollectionProgress(
            value: owned,
            total: total,
            done: owned >= total,
            height: 10,
          ),
          const SizedBox(height: 6),
          Text(
            potLeftLine(s, group),
            key: const Key('potshop-bought-left'),
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 12,
              weight: 800,
              color: AppColors.onSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SkinButton(
            key: const Key('potshop-bought-place'),
            label: canPlace ? 'Đặt vào tiệm' : 'Đặt sau khi đóng cửa',
            height: 44,
            fontSize: 16,
            enabled: canPlace,
            onPressed: canPlace
                ? () {
                    s.startPlaceMode(pot.id);
                  }
                : null,
          ),
          const SizedBox(height: 8),
          SkinButton(
            key: const Key('potshop-bought-book'),
            label: 'Sổ sưu tầm',
            kind: SkinButtonKind.secondary,
            height: 40,
            fontSize: 15,
            onPressed: () => s.openPotBook(detail: pot.id),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            key: const Key('potshop-bought-later'),
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: SizedBox(
              height: 34,
              child: Center(
                child: Text(
                  'Để sau',
                  style: AppText.title(
                    size: 16,
                    weight: 800,
                    color: AppColors.textSecondary,
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
