import 'dart:async';

import 'package:flutter/material.dart';

import '../data/economy.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'game_toast.dart';
import 'pet_slots_screen.dart' show DashedRRectPainter;
import 'pot_shop_screen.dart' show potLeftLine;
import 'pot_text.dart';
import 'pot_widgets.dart';
import 'ui_skin.dart';

String _pad2(int n) => n < 10 ? '0$n' : '$n';

/// Sổ sưu tầm (SPEC_C_final.md): one page per set with a progress bar and
/// numbered cells, a detail page per pot, and the reward for a full set.
/// Opened with [ShopSession.openPotBook].
class PotBookScreen extends StatefulWidget {
  const PotBookScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<PotBookScreen> createState() => _PotBookScreenState();
}

class _PotBookScreenState extends State<PotBookScreen> {
  String? _selected;
  String? _lastDetail;
  PageController? _pages;
  final _cellKeys = <String, GlobalKey>{};

  ShopSession get s => widget.session;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  void _back() => s.closePotBook();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final detail = s.potBookDetailId;
        final group = s.potBookTab;
        final pots = s.potGroupPots(group);
        if (detail == null && _lastDetail != null) {
          // Back from a detail page: that pot's cell is selected and scrolled
          // into view.
          _selected = _lastDetail;
          final id = _lastDetail!;
          _lastDetail = null;
          _pages?.dispose();
          _pages = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _cellKeys[id]?.currentContext;
            if (ctx != null && ctx.mounted) {
              Scrollable.ensureVisible(ctx, alignment: 0.5);
            }
          });
        }
        if (detail != null) _lastDetail = detail;
        return OpaqueScreen(
          color: AppColors.bgBase,
          child: Stack(
            key: const Key('pot-book'),
            children: [
              if (detail == null)
                _list(group, pots)
              else
                _detail(group, pots, detail),
              ...potScreenHeader(
                s,
                title: 'Sổ sưu tầm chậu',
                backKey: const Key('book-back'),
                onBack: _back,
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- list ---------------------------------------------------------------

  Widget _list(String group, List<PotDef> pots) {
    final owned = s.groupOwned(group);
    final total = s.groupTotal(group);
    final done = total > 0 && owned >= total;
    final missing = total - owned;
    return Stack(
      children: [
        Positioned(
          left: 16,
          right: 16,
          top: 106,
          height: 44,
          child: PotGroupTabs(
            session: s,
            selected: group,
            keyPrefix: 'book-tab',
            onSelect: (g) {
              _selected = null;
              s.selectPotBookTab(g);
            },
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 160,
          bottom: 0,
          child: SingleChildScrollView(
            key: const Key('book-scroll'),
            padding: EdgeInsets.only(bottom: done ? 24 : 82),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.surfaceBorderStrong,
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.surfaceBorderStrong,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bộ ${s.potGroupName(group)}',
                          key: const Key('book-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title(
                            size: 21,
                            weight: 800,
                            color: AppColors.primaryPressed,
                          ),
                        ),
                      ),
                      if (done) ...[
                        const SizedBox(width: 10),
                        Container(
                          key: const Key('book-done-chip'),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accentBase,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.statusWarning),
                          ),
                          child: Text(
                            'Đủ bộ!',
                            style: AppText.title(
                              size: 12,
                              weight: 800,
                              color: AppColors.onSecondary,
                            ).copyWith(height: 1),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '$owned/$total',
                        key: const Key('book-count'),
                        style: AppText.title(size: 21, weight: 800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CollectionProgress(
                    value: owned,
                    total: total,
                    done: done,
                    height: 12,
                  ),
                  const SizedBox(height: 10),
                  _rewardRow(group, done),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, box) {
                      const gap = 8.0;
                      final w = (box.maxWidth - gap * 2) / 3;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final pot in pots)
                            SizedBox(
                              width: w,
                              height: 106,
                              child: _PotCell(
                                key: _cellKeys.putIfAbsent(
                                  pot.id,
                                  () => GlobalKey(),
                                ),
                                session: s,
                                pot: pot,
                                selected: _selected == pot.id,
                                onTap: () {
                                  _selected = pot.id;
                                  s.sounds.effect('popup_open');
                                  s.openPotBookDetail(pot.id);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!done)
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Container(
              key: const Key('book-bar'),
              height: 58,
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.surfaceBorderStrong,
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x222E3A2C), blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Còn $missing chậu chưa có',
                          key: const Key('book-bar-left'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title(size: 15, weight: 800),
                        ),
                        Text(
                          'Mua thêm để đủ bộ.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 11.5,
                            weight: 700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 124,
                    child: SkinButton(
                      key: const Key('book-bar-go'),
                      label: 'Tiệm Chậu Hoa',
                      height: 42,
                      fontSize: 14,
                      onPressed: () => s.openPotShop(group: group),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _rewardRow(String group, bool done) {
    final reward = s.collectionReward(group);
    if (done && reward > 0) {
      if (s.collectionClaimed(group)) {
        return Container(
          key: const Key('book-claimed'),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check,
                size: 18,
                color: AppColors.primaryPressed,
              ),
              const SizedBox(width: 6),
              Text(
                'Đã nhận thưởng',
                style: AppText.title(
                  size: 14,
                  weight: 800,
                  color: AppColors.primaryPressed,
                ),
              ),
            ],
          ),
        );
      }
      return SkinButton(
        key: const Key('book-claim'),
        label: 'Nhận thưởng ${potRewardText(reward)}',
        height: 40,
        fontSize: 15,
        onPressed: () => _claim(group),
      );
    }
    return Container(
      key: const Key('book-reward'),
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentBase, width: 1.2),
      ),
      child: Row(
        children: [
          const RewardGiftIcon(size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reward > 0
                  ? 'Đủ bộ nhận ${potRewardText(reward)}'
                  : 'Đủ bộ có quà',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 12,
                weight: 800,
                color: AppColors.onSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _claim(String group) {
    final reward = s.collectionReward(group);
    if (s.claimCollection(group)) {
      showGameToast(context, 'Nhận ${potRewardText(reward)}!');
    }
  }

  // ---- detail -------------------------------------------------------------

  Widget _detail(String group, List<PotDef> pots, String id) {
    final index = pots.indexWhere((p) => p.id == id);
    if (index < 0) {
      scheduleMicrotask(s.closePotBook);
      return const SizedBox.shrink();
    }
    final pages = _pages ??= PageController(initialPage: index);
    if (pages.hasClients && (pages.page?.round() ?? index) != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pages.hasClients) {
          pages.animateToPage(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    final pot = pots[index];
    final owned = s.groupOwned(group);
    final total = s.groupTotal(group);
    final done = total > 0 && owned >= total;
    final has = s.potHas(pot.id);
    final frameH = (0.34 * 640).clamp(180.0, 270.0);
    return Positioned(
      left: 12,
      right: 12,
      top: 106,
      bottom: 0,
      child: Column(
        children: [
          Expanded(
            child: Container(
              key: const Key('book-detail'),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.surfaceBorderStrong,
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.surfaceBorderStrong,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bộ ${s.potGroupName(group)} · '
                            '${_pad2(index + 1)}/${pots.length}',
                            key: const Key('book-detail-page'),
                            style: AppText.body(
                              size: 12.5,
                              weight: 800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        _arrow(
                          '‹',
                          const Key('book-prev'),
                          index > 0,
                          () => s.openPotBookDetail(pots[index - 1].id),
                        ),
                        const SizedBox(width: 6),
                        _arrow(
                          '›',
                          const Key('book-next'),
                          index < pots.length - 1,
                          () => s.openPotBookDetail(pots[index + 1].id),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
                      child: Column(
                        children: [
                          SizedBox(
                            height: frameH + 14 + 20 + 34 + 8 + 24 + 14 + 66,
                            child: PageView.builder(
                              key: const Key('book-pages'),
                              controller: pages,
                              itemCount: pots.length,
                              onPageChanged: (i) {
                                if (pots[i].id != s.potBookDetailId) {
                                  s.openPotBookDetail(pots[i].id);
                                }
                              },
                              itemBuilder: (context, i) =>
                                  _page(pots[i], frameH),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: _strip(group, pots, id, owned, total, done),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
            child: _action(pot, has),
          ),
        ],
      ),
    );
  }

  Widget _arrow(String label, Key key, bool on, VoidCallback onTap) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: on ? onTap : null,
      child: Opacity(
        opacity: on ? 1 : 0.4,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryBase, width: 1.5),
          ),
          child: Text(
            label,
            style: AppText.title(
              size: 20,
              weight: 800,
              color: AppColors.primaryPressed,
            ).copyWith(height: 1),
          ),
        ),
      ),
    );
  }

  Widget _page(PotDef pot, double frameH) {
    final has = s.potHas(pot.id);
    final desc = has
        ? (s.data.cosmetics.find(pot.id)?.description ?? '')
        : 'Cách nhận: ${potHowText(pot)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Container(
            key: Key('book-frame-${pot.id}'),
            height: frameH,
            width: double.infinity,
            alignment: Alignment.bottomCenter,
            decoration: BoxDecoration(
              color: has ? AppColors.primarySoft : AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: PotArt(pot: pot, base: (frameH - 20) / 1.1, gray: !has),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                s.potFullName(pot),
                key: Key('book-name-${pot.id}'),
                style: AppText.title(
                  size: 26,
                  weight: 800,
                  color: has ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: Key('book-status-${pot.id}'),
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: has ? AppColors.primaryBase : const Color(0xFFE3DED0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              has ? 'Đã có' : 'Chưa có',
              style: AppText.body(
                size: 12,
                weight: 800,
                color: has ? AppColors.textInverse : AppColors.textSecondary,
              ).copyWith(height: 1),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 66,
            child: Text(
              desc,
              key: Key('book-desc-${pot.id}'),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 14,
                weight: 700,
                color: AppColors.textSecondary,
              ).copyWith(height: 21 / 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _strip(
    String group,
    List<PotDef> pots,
    String current,
    int owned,
    int total,
    bool done,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Cả bộ',
              style: AppText.title(
                size: 15,
                weight: 800,
                color: AppColors.primaryPressed,
              ),
            ),
            const Spacer(),
            Text(
              '$owned/$total',
              style: AppText.body(
                size: 12,
                weight: 800,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final p in pots)
              Expanded(
                child: GestureDetector(
                  key: Key('book-mini-${p.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => s.openPotBookDetail(p.id),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Container(
                        height: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: s.potHas(p.id)
                              ? Colors.white
                              : const Color(0xFFFBF9F0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: p.id == current
                                ? AppColors.accentBase
                                : AppColors.surfaceBorder,
                            width: p.id == current ? 2.5 : 1,
                          ),
                        ),
                        child: OverflowBox(
                          maxWidth: 38,
                          maxHeight: 38,
                          child: PotArt(
                            pot: p,
                            base: 34 / 1.1,
                            gray: !s.potHas(p.id),
                            shadow: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        CollectionProgress(value: owned, total: total, done: done, height: 10),
        const SizedBox(height: 8),
        Text(
          potLeftLine(s, group),
          key: const Key('book-left'),
          textAlign: TextAlign.center,
          style: AppText.body(
            size: 12,
            weight: 800,
            color: AppColors.onSecondary,
          ),
        ),
      ],
    );
  }

  Widget _action(PotDef pot, bool has) {
    if (!has) {
      return SkinButton(
        key: const Key('book-buy'),
        label: 'Mua ở Tiệm Chậu Hoa',
        height: 44,
        fontSize: 16,
        onPressed: () => s.openPotShop(group: s.potGroupOf(pot), focus: pot.id),
      );
    }
    if (!s.potHasSpare(pot.id) && pot.purchasable) {
      // Every copy is on a shelf: buy another one (so.cta.buyMore).
      return SkinButton(
        key: const Key('book-buy-more'),
        label: PotText.bookBuyMore,
        height: 44,
        fontSize: 16,
        onPressed: () => s.openPotShop(group: s.potGroupOf(pot), focus: pot.id),
      );
    }
    final label = !s.potPlaceAllowed
        ? 'Đặt sau khi đóng cửa'
        : !s.potHasSpare(pot.id)
        ? 'Đã đặt hết'
        : 'Đặt vào tiệm';
    final can = s.potPlaceable(pot.id);
    return SkinButton(
      key: const Key('book-place'),
      label: label,
      height: 44,
      fontSize: 16,
      enabled: can,
      onPressed: can ? () => s.startPlaceMode(pot.id) : null,
    );
  }
}

/// One cell of the book: number, picture, short name, and a tick when owned.
class _PotCell extends StatefulWidget {
  const _PotCell({
    super.key,
    required this.session,
    required this.pot,
    required this.selected,
    required this.onTap,
  });

  final ShopSession session;
  final PotDef pot;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PotCell> createState() => _PotCellState();
}

class _PotCellState extends State<_PotCell> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final pot = widget.pot;
    final has = s.potHas(pot.id);
    final frame = 78 * pot.potScale;
    return GestureDetector(
      key: Key('book-cell-${pot.id}'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: Transform.translate(
        offset: Offset(0, _down ? 2 : 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: has
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.surfaceBorder,
                          width: 1.5,
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF9F0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: CustomPaint(
                        painter: const DashedRRectPainter(
                          color: AppColors.surfaceBorderStrong,
                          strokeWidth: 1.3,
                          radius: 14,
                        ),
                      ),
                    ),
            ),
            Positioned(
              left: 9,
              top: 5,
              child: Text(
                _pad2(s.potNumber(pot)),
                style: AppText.title(
                  size: 11,
                  weight: 800,
                  color: has ? AppColors.primaryBase : AppColors.textDisabled,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 78 - frame * 0.95,
              child: Center(
                child: PotArt(pot: pot, base: 78, gray: !has),
              ),
            ),
            Positioned(
              left: 4,
              right: 4,
              bottom: 3,
              child: Text(
                s.potShortName(pot),
                key: Key('book-cell-name-${pot.id}'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title(
                  size: 12,
                  weight: 700,
                  color: has ? AppColors.textPrimary : AppColors.textDisabled,
                ).copyWith(height: 1.2),
              ),
            ),
            if (has)
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  key: Key('book-tick-${pot.id}'),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBase,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
            if (_down)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primaryBase.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            if (widget.selected)
              Positioned(
                left: -2,
                top: -2,
                right: -2,
                bottom: -2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: Key('book-selected-${pot.id}'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accentBase, width: 3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
