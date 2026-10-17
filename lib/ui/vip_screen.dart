import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../logic/shop_session.dart';
import '../logic/vip.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'player_avatar.dart';
import 'ui_skin.dart';
import 'vip_badge.dart';
import 'vip_text.dart';
import 'ui_chung.dart';

/// Màn VIP V1 (spec 4.4): tier card, 10-tier carousel and "Nạp Pha lê" on
/// the Quyền lợi tab; Bảng vinh danh (spec 4.6) on the second; Cài đặt VIP
/// from ⋯. Everything shown comes from the server wallet; nothing here
/// grants anything.
class VipScreen extends StatelessWidget {
  const VipScreen({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final v = session.vip;
    return ListenableBuilder(
      listenable: Listenable.merge([v, session]),
      builder: (context, _) => OpaqueScreen(
        color: AppColors.bgBase,
        child: Stack(
          key: const Key('vip-screen'),
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 100,
              child: Center(child: _Tabs(v: v)),
            ),
            Positioned.fill(
              top: 152,
              bottom: 72,
              child: v.tab == 0
                  ? _PerksTab(session: session)
                  : _HallTab(session: session),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SkinButton(
                key: const Key('vip-topup'),
                label: VipText.topUpBtn,
                onPressed: v.topUp,
              ),
            ),
            Positioned(
              left: 16,
              top: 46,
              child: LeafRoundButton(
                key: const Key('vip-back'),
                onTap: v.closeScreen,
              ),
            ),
            const Positioned(
              left: 70,
              right: 70,
              top: 46,
              child: Center(
                child: SkinRibbon(
                  title: VipText.screenTitle,
                  width: 210,
                  height: 46,
                  fontSize: 17,
                ),
              ),
            ),
            if (session.signedIn && v.source != null)
              Positioned(
                right: 12,
                top: 46,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    key: const Key('vip-settings-open'),
                    onPressed: v.openSettings,
                    icon: const Icon(Icons.more_horiz),
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (v.settingsOpen)
              Positioned.fill(child: _SettingsSheet(session: session)),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.v});

  final VipController v;

  @override
  Widget build(BuildContext context) {
    Widget tab(int i, String label, Key key) {
      final on = v.tab == i;
      return Expanded(
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: () => v.showTab(i),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: on ? AppColors.primaryBase : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppText.body(
                  size: 14,
                  weight: 800,
                  color: on ? AppColors.onPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 328,
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          tab(0, VipText.perksTitle, const Key('vip-tab-perks')),
          tab(1, VipText.hallTab, const Key('vip-tab-hall')),
        ],
      ),
    );
  }
}

// ---- Quyền lợi -------------------------------------------------------------

class _PerksTab extends StatelessWidget {
  const _PerksTab({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final v = session.vip;
    return ListView(
      key: const Key('vip-perks'),
      // The carousel runs edge to edge (its neighbours peek in); the rest
      // keeps the 16 dp sides.
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _TierCard(session: session),
        ),
        const SizedBox(height: 12),
        _Carousel(v: v),
        const SizedBox(height: 12),
        for (final r in const [
          VipText.rule1,
          VipText.rule2,
          VipText.rule3,
          VipText.rule4,
        ])
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '• $r',
              style: AppText.caption(
                size: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final v = session.vip;
    final st = v.status;
    final level = v.level;
    final next = v.next;
    final String line;
    if (!session.signedIn) {
      line = VipText.guestLocked;
    } else if (next == null) {
      line = VipText.max;
    } else if (level == 0) {
      line = VipText.firstTopUp;
    } else {
      line = VipText.next(v.toNext, next.level);
    }
    return CardBox(
      key: const Key('vip-tier-card'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          level > 0
              ? VipBadge(
                  key: const Key('vip-tier-badge'),
                  level: level,
                  size: 64,
                )
              : Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSunken,
                    shape: BoxShape.circle,
                  ),
                  child: Text(VipText.none, style: AppText.title(size: 14)),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.signedIn ? VipText.current(level) : VipText.none,
                  key: const Key('vip-current'),
                  style: AppText.title(size: 17, weight: 800),
                ),
                if (session.signedIn && session.phaleShop.hasPending) ...[
                  const SizedBox(height: 2),
                  Container(
                    key: const Key('vip-verifying'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      VipText.verifyingChip,
                      style: AppText.caption(
                        size: 11,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // Phú G2: thanh_tien_do, 8 dp #F2C94C fill.
                SliceProgress(
                  key: const Key('vip-progress'),
                  value: session.signedIn ? v.progress : 0,
                ),
                const SizedBox(height: 4),
                if (st != null && next != null)
                  Text(
                    VipText.progress(st.vnd, next.minVnd),
                    style: AppText.caption(
                      size: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  line,
                  key: const Key('vip-next'),
                  style: AppText.body(size: 12.5, weight: 700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Carousel extends StatefulWidget {
  const _Carousel({required this.v});

  final VipController v;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  late final PageController _page = PageController(
    initialPage: widget.v.card,
    // Phú: each card ~88% of the width, 12 dp between cards.
    viewportFraction: 0.88,
  );

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int i) {
    final n = widget.v.config.tiers.length;
    if (i < 0 || i >= n) return;
    _page.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final tiers = v.config.tiers;
    final first = v.card <= 0;
    final last = v.card >= tiers.length - 1;
    // Phú: ←/→ move the carousel while the screen has focus.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _go(v.card - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _go(v.card + 1),
      },
      child: Focus(
        key: const Key('vip-carousel-focus'),
        autofocus: true,
        child: Column(
          children: [
            SizedBox(
              height: 284,
              child: Stack(
                children: [
                  // Web/desktop: let a mouse (and trackpad) drag the pages;
                  // the app's default behaviour leaves mouse out.
                  ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.invertedStylus,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.unknown,
                      },
                    ),
                    child: PageView.builder(
                      key: const Key('vip-carousel'),
                      controller: _page,
                      itemCount: tiers.length,
                      onPageChanged: v.showCard,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _TierPage(v: v, level: tiers[i].level),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 2,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ArrowButton(
                        key: const Key('vip-prev'),
                        icon: Icons.chevron_left,
                        label: VipText.cardPrev,
                        onTap: first ? null : () => _go(v.card - 1),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ArrowButton(
                        key: const Key('vip-next'),
                        icon: Icons.chevron_right,
                        label: VipText.cardNextArrow,
                        onTap: last ? null : () => _go(v.card + 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < tiers.length; i++)
                  // Phú: a dot jumps to its level (20 dp tap area).
                  GestureDetector(
                    key: Key('vip-dot-$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _go(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 7,
                      ),
                      child: Container(
                        width: i == v.card ? 14 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == v.card
                              ? AppColors.primaryBase
                              : AppColors.surfaceBorderStrong,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Phú: nut_tron_la at 32 dp with a chevron; dimmed and off at the ends.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: on ? 1 : 0.4,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  UiChung.nutTronLa.path,
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                Icon(icon, size: 20, color: AppColors.primaryPressed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Cấp hiện tại" / "Cấp tiếp theo" / lock + "Còn thiếu {n}đ" (Nhất).
class _CardTag extends StatelessWidget {
  const _CardTag({required this.v, required this.level});

  final VipController v;
  final int level;

  @override
  Widget build(BuildContext context) {
    final mine = v.level;
    final String text;
    var locked = false;
    if (level == mine) {
      text = VipText.cardCurrent;
    } else if (level == mine + 1) {
      text = VipText.cardNext;
    } else if (level > mine + 1) {
      final need = (v.tier(level)?.minVnd ?? 0) - (v.status?.vnd ?? 0);
      text = VipText.cardLocked(need < 0 ? 0 : need);
      locked = true;
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      key: Key('vip-card-tag-$level'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: locked ? AppColors.surfaceSunken : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locked) ...[
            const Icon(Icons.lock, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: AppText.caption(
              size: 11,
              weight: 800,
              color: locked
                  ? AppColors.textSecondary
                  : AppColors.primaryPressed,
            ),
          ),
        ],
      ),
    );
  }
}

String vipPerkText(VipController v, int level, VipPerk p) => switch (p) {
  VipPerk.badge => VipText.perkBadge(VipText.tone(level)),
  VipPerk.nameColor => VipText.perkNameColor(level),
  VipPerk.frame => VipText.perkFrame(VipText.tone(level)),
  VipPerk.pot => VipText.perkPot(
    v.potsAt(level).map((id) => VipText.items[id] ?? id).join(', '),
  ),
  VipPerk.chatBubble => VipText.perkChatBubble,
  VipPerk.entryLine => VipText.perkEntryLine,
  VipPerk.petOutfit => VipText.perkPetOutfit(VipText.outfitAt(level) ?? ''),
  VipPerk.title => VipText.perkTitle,
  VipPerk.hall => VipText.perkHall,
};

class _TierPage extends StatelessWidget {
  const _TierPage({required this.v, required this.level});

  final VipController v;
  final int level;

  @override
  Widget build(BuildContext context) {
    final t = v.tier(level)!;
    final mine = level == v.level;
    final frame = t.frame;
    // Phú's vip/vip_nen_the.webp behind the card. The name sample and
    // perks sit on a white panel so the VIP name colours read as they do
    // everywhere else.
    return Container(
      key: Key('vip-card-$level'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          if (mine)
            const BoxShadow(color: AppColors.primaryBase, spreadRadius: 2)
          else
            const BoxShadow(
              color: AppColors.surfaceBorderStrong,
              offset: Offset(0, AppSize.shadowOffset),
            ),
        ],
      ),
      child: VipCardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VipBadge(level: level, size: 48),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        VipText.badge(level),
                        style: AppText.title(
                          size: 18,
                          weight: 800,
                          color: AppColors.onPrimary,
                        ),
                      ),
                      Text(
                        VipText.toneLabel(level),
                        style: AppText.caption(size: 11, color: vipCardText),
                      ),
                      Text(
                        VipText.cardThreshold(t.minVnd),
                        style: AppText.caption(size: 11, color: vipCardText),
                      ),
                    ],
                  ),
                ),
                if (frame.isNotEmpty)
                  PlayerAvatar(
                    avatar: '',
                    name: VipText.sampleName,
                    radius: 20,
                    frameId: frame,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _CardTag(v: v, level: level),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                key: Key('vip-card-panel-$level'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VipName(
                      name: VipText.sampleName,
                      level: level,
                      style: AppText.title(size: 15, weight: 800),
                      badgeSize: 18,
                    ),
                    VipTitleLine(level: level),
                    const SizedBox(height: 4),
                    Text(
                      VipText.cardNewPerks,
                      style: AppText.body(size: 12.5, weight: 800),
                    ),
                    for (final p in v.perksAt(level))
                      Text(
                        '• ${vipPerkText(v, level, p)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(size: 11.5),
                      ),
                    const Spacer(),
                    if (t.giftTickets > 0)
                      Text(
                        VipText.cardGift(t.giftTickets),
                        key: Key('vip-card-gift-$level'),
                        style: AppText.body(
                          size: 12,
                          weight: 800,
                          color: AppColors.primaryPressed,
                        ),
                      ),
                    Text(
                      VipText.cosmeticNote,
                      style: AppText.caption(
                        size: 10.5,
                        color: AppColors.textSecondary,
                      ),
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
}

/// [child] on Phú's card art: on a ~4:1 card the picture is stretched and
/// the text keeps ~22% of the width clear on each side (the flowers); on a
/// taller card the four flower corners stay as drawn (centerSlice, scaled
/// to the width), the green middle stretches and the text sits between the
/// corners.
class VipCardBackground extends StatelessWidget {
  const VipCardBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      // Too small for the scaled corners to fit: stretch the whole file.
      final cornersW = (vipCardArtWidth - vipCardSlice.width) / vipCardArtScale;
      final cornersH =
          (vipCardArtHeight - vipCardSlice.height) / vipCardArtScale;
      final wide =
          (h.isFinite && h > 0 && w / h >= 3.5) ||
          w <= cornersW ||
          (h.isFinite && h <= cornersH);
      final art = wide
          ? Image.asset(
              vipCardArt,
              key: const Key('vip-card-art'),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            )
          : Image.asset(
              vipCardArt,
              key: const Key('vip-card-art'),
              fit: BoxFit.fill,
              scale: vipCardArtScale,
              centerSlice: Rect.fromLTRB(
                vipCardSlice.left / vipCardArtScale,
                vipCardSlice.top / vipCardArtScale,
                vipCardSlice.right / vipCardArtScale,
                vipCardSlice.bottom / vipCardArtScale,
              ),
              filterQuality: FilterQuality.medium,
            );
      final pad = wide
          ? EdgeInsets.symmetric(horizontal: w * 0.22, vertical: h * 0.12)
          : const EdgeInsets.fromLTRB(12, 10, 12, 12);
      return Stack(
        children: [
          Positioned.fill(child: art),
          Padding(padding: pad, child: child),
        ],
      );
    },
  );
}

// ---- Bảng vinh danh ----------------------------------------------------------

class _HallTab extends StatelessWidget {
  const _HallTab({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final v = session.vip;
    final rows = v.hall;
    final me = session.accountUid;
    final children = <Widget>[
      Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            Art.vip('bang_vinh_danh_banner'),
            width: 328,
            height: 117,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox(height: 60),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 190,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  VipText.hallTitle,
                  style: AppText.title(
                    size: 15,
                    weight: 800,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      Text(VipText.hallSubtitle, style: AppText.caption(size: 11.5)),
      const SizedBox(height: 2),
      Text(
        VipText.hallPrivacyNote,
        style: AppText.caption(size: 11, color: AppColors.textSecondary),
      ),
      if (session.signedIn &&
          v.level >= VipController.hallLevel &&
          (v.hallHidden || v.badgeHidden))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            VipText.hallHiddenNote,
            key: const Key('vip-hall-hidden-note'),
            style: AppText.caption(size: 11, color: AppColors.statusSuccess),
          ),
        ),
      const SizedBox(height: 8),
    ];
    if (v.source == null) {
      children.add(Text(VipText.hallLoadFail, style: AppText.body(size: 13)));
    } else if (rows == null && (v.hallLoading || !v.hallFailed)) {
      children.add(
        const Padding(
          key: Key('vip-hall-loading'),
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (v.hallFailed) {
      children.addAll([
        Text(
          VipText.hallLoadFail,
          key: const Key('vip-hall-error'),
          style: AppText.body(size: 13, weight: 700),
        ),
        TextButton(
          key: const Key('vip-hall-retry'),
          onPressed: () => v.loadHall(page: v.hallPage),
          child: const Text('Thử lại'),
        ),
      ]);
    } else if (rows!.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            VipText.hallEmpty,
            key: const Key('vip-hall-empty'),
            textAlign: TextAlign.center,
            style: AppText.body(size: 13, weight: 700),
          ),
        ),
      );
    } else {
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        children.add(
          _HallRow(
            rank: v.hallPage * VipController.pageSize + i + 1,
            row: r,
            mine: r.uid == me,
            frame: session.frames.frameOf(r.uid),
          ),
        );
      }
      if (v.hallPages > 1) {
        children.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                key: const Key('vip-hall-prev'),
                onPressed: v.hallPage > 0 && !v.hallLoading
                    ? v.prevHallPage
                    : null,
                child: Text(VipText.hallPrev),
              ),
              Text(
                VipText.hallPage(v.hallPage + 1, v.hallPages),
                key: const Key('vip-hall-page'),
                style: AppText.caption(size: 12),
              ),
              TextButton(
                key: const Key('vip-hall-next'),
                onPressed: v.hallHasNext && !v.hallLoading
                    ? v.nextHallPage
                    : null,
                child: Text(VipText.hallNext),
              ),
            ],
          ),
        );
      }
    }
    return ListView(
      key: const Key('vip-hall'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: children,
    );
  }
}

class _HallRow extends StatelessWidget {
  const _HallRow({
    required this.rank,
    required this.row,
    required this.mine,
    required this.frame,
  });

  final int rank;
  final VipHallRow row;
  final bool mine;

  /// The frame the player wears (player_avatars, read with the page).
  final String frame;

  @override
  Widget build(BuildContext context) {
    final anon = row.hidden || row.name.isEmpty;
    return Container(
      key: Key('vip-hall-row-$rank'),
      height: 64,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: mine ? AppColors.primarySoft : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('#$rank', style: AppText.number(size: 14, weight: 800)),
          ),
          PlayerAvatar(
            avatar: anon ? '' : row.avatar,
            name: anon ? VipText.anonName : row.name,
            radius: 20,
            // A hidden row has the default avatar, no VIP frame (spec 4.6).
            frameId: anon ? '' : frame,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (anon)
                  Text(
                    VipText.anonName,
                    key: Key('vip-hall-anon-$rank'),
                    style: AppText.title(size: 15, weight: 800),
                  )
                else ...[
                  VipName(
                    name: row.name,
                    level: 10,
                    style: AppText.title(size: 15, weight: 800),
                    badgeSize: 18,
                  ),
                  const VipTitleLine(level: 10, size: 10.5),
                ],
              ],
            ),
          ),
          Text(
            VipText.date(row.at),
            style: AppText.caption(size: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---- Cài đặt VIP -------------------------------------------------------------

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final v = session.vip;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('vip-settings-scrim'),
            onTap: v.closeSettings,
            child: const ColoredBox(color: AppColors.bgOverlay),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          // Phú G2: trang_giay at 3 px per dp like the chat sub-pages;
          // content below the top-left flower, above the bottom-right one.
          child: UiSlice(
            key: const Key('vip-settings'),
            piece: UiChung.trangGiay,
            scale: 3,
            padding: EdgeInsets.fromLTRB(
              16,
              UiChung.padFor(UiChung.trangGiay, 3).top + 4,
              16,
              UiChung.padFor(UiChung.trangGiay, 3).bottom + 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SwitchRow(
                  title: VipText.hideBadgeTitle,
                  subtitle: VipText.hideBadgeSubtitle,
                  child: Switch(
                    key: const Key('vip-badge-hide'),
                    value: v.badgeHidden,
                    onChanged: v.hallBusy
                        ? null
                        : (on) async {
                            final ok = await v.setBadgeHidden(on);
                            if (!context.mounted) return;
                            showGameToast(
                              context,
                              !ok
                                  ? VipText.hideBadgeFail
                                  : on
                                  ? VipText.hideBadgeOnToast
                                  : VipText.hideBadgeOffToast,
                              error: !ok,
                            );
                          },
                  ),
                ),
                const SizedBox(height: 10),
                _SwitchRow(
                  title: VipText.hallHideTitle,
                  subtitle: VipText.hallHideSubtitle,
                  child: Switch(
                    key: const Key('vip-hall-hide'),
                    value: v.hallHidden,
                    onChanged: v.hallBusy
                        ? null
                        : (on) async {
                            final ok = await v.setHallHidden(on);
                            if (!context.mounted || !ok) return;
                            showGameToast(
                              context,
                              on
                                  ? VipText.hallHideOnToast
                                  : VipText.hallHideOffToast,
                            );
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One line of Cài đặt VIP: title, subtitle, the switch.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.body(size: 14, weight: 800)),
              Text(
                subtitle,
                style: AppText.caption(
                  size: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // The overlay has no Scaffold above it: Switch needs a Material
        // ancestor.
        Material(type: MaterialType.transparency, child: child),
      ],
    );
  }
}

// ---- Level-up popup -----------------------------------------------------------

/// "Chúc mừng! Bạn đã lên VIP {n}" (spec 4.4): the gift (already in Hộp
/// thư, sent by the server) and the perks just opened. "Nhận" closes it.
class VipLevelUpPopup extends StatelessWidget {
  const VipLevelUpPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final v = session.vip;
    final level = v.levelUp;
    if (level == null) return const SizedBox.shrink();
    final tickets = v.levelUpTickets;
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.bgOverlay)),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: AppMotion.celebrate,
            curve: Curves.easeOutBack,
            builder: (context, s, child) =>
                Transform.scale(scale: s, child: child),
            child: SizedBox(
              width: 320,
              child: SkinPopup(
                key: const Key('vip-levelup'),
                title: VipText.badge(level),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VipBadge(level: level, size: 64),
                      const SizedBox(height: 6),
                      Text(
                        VipText.levelUpTitle(level),
                        textAlign: TextAlign.center,
                        style: AppText.title(size: 18, weight: 800),
                      ),
                      if (tickets > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          VipText.levelUpBody(tickets),
                          key: const Key('vip-levelup-gift'),
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 13),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          VipText.levelUpNewPerks,
                          style: AppText.body(size: 13, weight: 800),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final (l, p) in v.levelUpPerks)
                                Text(
                                  '• ${vipPerkText(v, l, p)}',
                                  style: AppText.caption(size: 12),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SkinButton(
                        key: const Key('vip-levelup-ok'),
                        label: VipText.levelUpBtn,
                        onPressed: v.closeLevelUp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
