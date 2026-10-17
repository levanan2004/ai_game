import 'package:flutter/material.dart';

import '../data/rating_board.dart';
import '../logic/price_format.dart' show coinFull;
import '../logic/rating_board_controller.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'charm_board_screen.dart' show Bxh, RankBadge;
import 'common.dart' show StarIcon;
import 'player_avatar.dart';
import 'profile_card.dart';
import 'ui_skin.dart';
import 'vip_badge.dart';

/// Texts of Bảng Đánh giá (Nhất, chu_tinh_nang_moi.md mục 4, verbatim; the
/// numbers come from economy.json `ratingBoard`).
abstract final class RatingText {
  static const boardTitle = 'Bảng xếp hạng'; // board.title
  static const tabCharm = 'Mị lực'; // board.tab.charm
  static const tabRating = 'Đánh giá'; // board.tab.rating
  static const explain =
      'Tiệm càng nhiều lượt đánh giá thì điểm càng sát điểm thật.'; // board.rating.explain
  static const howTitle = 'Cách tính điểm'; // board.rating.how_title
  static String howBody(int seasonDays, String ratingC) =>
      'Điểm đã cân theo số lượng đánh giá trong mùa $seasonDays ngày: tiệm '
      'mới có ít lượt sẽ ở gần $ratingC ★, càng nhiều lượt thì càng ra đúng '
      'điểm của tiệm.'; // board.rating.how_body
  static String seasonEnd(int d, int h) =>
      'Mùa kết thúc sau $d ngày $h giờ'; // board.rating.season_end
  static String myCard(String score, int n) =>
      '★ $score · $n đánh giá'; // board.rating.my_card
  static String rowCount(int n) => '$n đánh giá'; // board.rating.row_count
  static const outOfTop = '100+'; // board.rating.out_of_top
  static String minThreshold(int k) =>
      'Chưa xếp hạng · cần thêm $k đánh giá trong mùa này'; // board.rating.min_threshold
  static String minRule(int n) =>
      'Cần ít nhất $n đánh giá trong mùa để lên bảng.'; // board.rating.min_rule
  static const empty =
      'Mùa mới vừa bắt đầu. Phục vụ khách thật tốt để lên bảng nhé!'; // board.rating.empty
  static String notStarted(int season, String date) =>
      'Bảng Đánh giá mở từ mùa $season, ngày $date.'; // board.rating.not_started
  static const rewardsBtn = 'Xem phần thưởng'; // board.rating.rewards_btn
  static String rewardRow(int from, int to, String gifts) =>
      from == to
      ? '${Bxh.rankN(from)}: $gifts' // one rank: bxh.rank.n + gifts
      : 'Hạng $from–$to: $gifts'; // board.rating.reward.row
  static const rewardPending = 'Đang chờ duyệt'; // board.rating.reward.pending
  static const fairNote =
      'Ngày trong game có quá nhiều lượt đánh giá hoặc xong quá nhanh sẽ không được tính.'; // board.rating.fair_note
  static const guestLocked = 'Đăng nhập để tham gia'; // board.rating.guest.locked
}

/// "4,0" for {rating_c}.
String _oneDecimal(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// "09/11/2026" (Vietnam day of a UTC instant).
String _vnDate(DateTime utc) {
  final d = utc.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// "100 Pha lê + 20 Giọt hoa + 10.000.000 xu" (the order of Nhất 0c).
String ratingRewardText(RatingBoardReward r) => [
  if (r.phaLe > 0) '${r.phaLe} Pha lê',
  if (r.giotHoa > 0) '${r.giotHoa} Giọt hoa',
  if (r.coins > 0) '${coinFull(r.coins)} xu',
].join(' + ');

/// The two tabs under the title row (spec 2.2: 44 high, pill, chosen tab
/// on primary.base with white text).
class BoardTabs extends StatelessWidget {
  const BoardTabs({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final rating = session.ratingBoard.tab;
    Widget tab(String label, bool on, bool toRating) => Expanded(
      child: Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          key: Key(toRating ? 'board-tab-rating' : 'board-tab-charm'),
          behavior: HitTestBehavior.opaque,
          onTap: () => session.selectBoardTab(ratingTab: toRating),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: on ? AppColors.primaryBase : Colors.transparent,
              borderRadius: BorderRadius.circular(19),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppText.button(
                size: 15,
                weight: 800,
                color: on ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      key: const Key('board-tabs'),
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
      ),
      child: Row(
        children: [
          tab(RatingText.tabCharm, !rating, false),
          tab(RatingText.tabRating, rating, true),
        ],
      ),
    );
  }
}

/// Bảng Đánh giá (spec R1), below the tabs: season clock with ⓘ, the
/// one-line explanation, "Hạng của bạn", the top 100, "Xem phần thưởng".
/// [top] is where it starts (under the tabs).
class RatingBoardView extends StatelessWidget {
  const RatingBoardView({super.key, required this.session, this.top = 154});

  final ShopSession session;
  final double top;

  RatingBoardController get r => session.ratingBoard;

  @override
  Widget build(BuildContext context) {
    final phase = r.phase;
    final guest = r.me == RatingMe.guest;
    final open = phase != RatingPhase.notStarted;
    final loading =
        open && !guest && r.rows.isEmpty && r.load != RatingLoad.ready &&
        r.load != RatingLoad.error;
    final error = open && !guest && r.rows.isEmpty && r.load == RatingLoad.error;
    return Stack(
      key: const Key('rating-board'),
      children: [
        Positioned(
          left: 12,
          right: 12,
          top: top,
          height: 32,
          child: Row(
            children: [
              Expanded(
                child: Center(child: _SeasonChip(controller: r)),
              ),
              Semantics(
                button: true,
                label: RatingText.howTitle,
                child: GestureDetector(
                  key: const Key('rating-how-btn'),
                  behavior: HitTestBehavior.opaque,
                  onTap: r.openHow,
                  child: const SizedBox(
                    width: 44,
                    height: 32,
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 22,
                      color: AppColors.primaryBase,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: top + 36,
          height: 30,
          child: Center(
            child: Text(
              RatingText.explain,
              key: const Key('rating-explain'),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppText.caption(size: 11, color: AppColors.textSecondary)
                  .copyWith(fontWeight: FontWeight.w700, height: 1.2),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: top + 70,
          height: 72,
          child: _MyCard(session: session),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: top + 150,
          bottom: 66,
          child: !open
              ? _Note(
                  key: const Key('rating-not-started'),
                  text: RatingText.notStarted(
                    r.config.seasonNumber,
                    _vnDate(r.config.seasonStart ?? DateTime.now()),
                  ),
                )
              : guest
              ? const _Note(
                  key: Key('rating-guest'),
                  text: RatingText.guestLocked,
                )
              : loading
              ? const Center(
                  key: Key('rating-loading'),
                  child: CircularProgressIndicator(),
                )
              : error
              ? _Error(onRetry: () => r.refresh(force: true))
              : r.rows.isEmpty
              ? const _Note(key: Key('rating-empty'), text: RatingText.empty)
              : RefreshIndicator(
                  onRefresh: () => r.refresh(force: true),
                  child: ListView(
                    key: const Key('rating-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    children: [
                      for (final row in r.rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _Row(session: session, row: row),
                        ),
                    ],
                  ),
                ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: SkinButton(
            key: const Key('rating-rewards-btn'),
            label: RatingText.rewardsBtn,
            height: 44,
            fontSize: 16,
            onPressed: r.openRewards,
          ),
        ),
        if (r.howOpen) _HowSheet(controller: r),
        if (r.rewardsOpen) _RewardsSheet(controller: r),
        if (r.profile case final row?)
          Positioned.fill(
            child: PlayerProfileCard(
              key: Key('rating-profile-${row.entry.uid}'),
              session: session,
              uid: row.entry.uid,
              name: _name(session, row.entry),
              avatar: _avatar(session, row.entry),
              frameId: _frame(session, row.entry),
              onBlock: () => session.board.hidePlayer(
                row.entry.uid,
                row.entry.displayName,
              ),
              onUnblock: () => session.board.unhide(row.entry.uid),
              onClose: r.closeSheets,
            ),
          ),
      ],
    );
  }
}

String _name(ShopSession s, RatingEntry e) => e.uid == s.accountUid
    ? ((s.state.shopName ?? '').trim().isEmpty
          ? e.displayName
          : s.state.shopName!.trim())
    : s.board.isHidden(e.uid)
    ? Bxh.hiddenName
    : e.displayName;

String _avatar(ShopSession s, RatingEntry e) => e.uid == s.accountUid
    ? s.publishedAvatar
    : s.board.isHidden(e.uid)
    ? ''
    : e.avatar;

int _vip(ShopSession s, RatingEntry e) => e.uid == s.accountUid
    ? s.vip.level
    : s.board.isHidden(e.uid)
    ? 0
    : s.frames.vipOf(e.uid);

String _frame(ShopSession s, RatingEntry e) => e.uid == s.accountUid
    ? s.frames.equipped
    : s.board.isHidden(e.uid)
    ? ''
    : s.frames.frameOf(e.uid);

class _SeasonChip extends StatelessWidget {
  const _SeasonChip({required this.controller});

  final RatingBoardController controller;

  @override
  Widget build(BuildContext context) {
    final r = controller;
    final String text;
    switch (r.phase) {
      case RatingPhase.notStarted:
        return const SizedBox.shrink();
      case RatingPhase.running:
        final left = r.seasonLeft;
        text = RatingText.seasonEnd(left.inDays, left.inHours % 24);
      case RatingPhase.ended:
        text = Bxh.seasonEnded;
    }
    return Container(
      key: const Key('rating-season'),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.body(size: 12.5, weight: 800),
      ),
    );
  }
}

/// ★ 16 + "4,72" (Baloo 800, 18) over "{n} đánh giá" (spec 2.3).
class _Score extends StatelessWidget {
  const _Score({required this.entry});

  final RatingEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ratingScoreText(entry.score),
              style: AppText.title(size: 18, weight: 800).copyWith(height: 1),
            ),
            const SizedBox(width: 3),
            const StarIcon(radius: 8),
          ],
        ),
        Text(
          RatingText.rowCount(entry.v),
          style: AppText.caption(size: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MyCard extends StatelessWidget {
  const _MyCard({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final r = s.ratingBoard;
    final me = r.me;
    final mine = r.mine;
    final name = (s.state.shopName ?? '').trim().isEmpty
        ? (mine?.displayName ?? 'Chủ tiệm')
        : s.state.shopName!.trim();
    Widget? badge;
    String? line;
    switch (me) {
      case RatingMe.guest:
        line = RatingText.guestLocked;
      case RatingMe.underMin:
        line = RatingText.minThreshold(r.reviewsToRank);
      case RatingMe.ranked:
        badge = RankBadge(rank: r.myRank!, height: 44);
      case RatingMe.outside:
        badge = const RankBadge(rank: 100, height: 44, label: RatingText.outOfTop);
    }
    return Container(
      key: const Key('rating-card'),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBase, width: 2.5),
        boxShadow: const [
          BoxShadow(color: AppColors.surfaceBorderStrong, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          if (badge != null) ...[
            SizedBox(width: 38, child: badge),
            const SizedBox(width: 8),
          ],
          if (me != RatingMe.guest) ...[
            PlayerAvatar(
              avatar: s.publishedAvatar,
              name: name,
              radius: 18,
              frameId: s.frames.equipped,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Bxh.you,
                  style: AppText.caption(size: 11, color: AppColors.primaryPressed)
                      .copyWith(fontWeight: FontWeight.w800, height: 1.1),
                ),
                if (me != RatingMe.guest)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(size: 15, weight: 800)
                        .copyWith(height: 1.15),
                  ),
                if (line != null)
                  Text(
                    line,
                    key: const Key('rating-card-line'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(
                      size: 10.5,
                      color: AppColors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.w700, height: 1.1),
                  )
                else if (mine != null)
                  Text(
                    RatingText.myCard(ratingScoreText(mine.score), mine.v),
                    key: const Key('rating-card-score'),
                    maxLines: 1,
                    style: AppText.caption(size: 11.5)
                        .copyWith(fontWeight: FontWeight.w800, height: 1.1),
                  ),
              ],
            ),
          ),
          if (me == RatingMe.guest)
            GestureDetector(
              key: const Key('rating-guest-btn'),
              onTap: s.signIn,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryBase,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  Bxh.guestBtn,
                  style: AppText.button(size: 14, weight: 800, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.session, required this.row});

  final ShopSession session;
  final RatingRow row;

  @override
  Widget build(BuildContext context) {
    final e = row.entry;
    final mine = e.uid == session.accountUid;
    return GestureDetector(
      key: Key('rating-row-${row.rank}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => session.ratingBoard.openProfile(row),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: mine ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: mine ? AppColors.primaryBase : AppColors.surfaceBorder,
            width: mine ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 32, child: RankBadge(rank: row.rank, height: 38)),
            const SizedBox(width: 8),
            PlayerAvatar(
              avatar: _avatar(session, e),
              name: _name(session, e),
              radius: 20,
              frameId: _frame(session, e),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // VIP colour + 18 dp badge, "Chủ Tiệm Ngọc" below for a
                  // VIP 10 (spec 4.3, 4.5).
                  VipName(
                    name: _name(session, e),
                    level: _vip(session, e),
                    style: AppText.title(size: 15, weight: 800),
                    badgeKey: Key('rating-row-vip-${row.rank}'),
                  ),
                  if (_vip(session, e) >= 10)
                    VipTitleLine(
                      key: Key('rating-row-vip-title-${row.rank}'),
                      level: 10,
                      size: 10,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _Score(entry: e),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, weight: 700, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('rating-error'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Bxh.errorTitle, style: AppText.title(size: 16, weight: 800)),
          const SizedBox(height: 4),
          Text(
            Bxh.errorSub,
            style: AppText.caption(size: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          SkinButton(
            key: const Key('rating-retry'),
            label: Bxh.retry,
            height: 40,
            fontSize: 15,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// A bottom sheet over the tab with a scrim.
class _Sheet extends StatelessWidget {
  const _Sheet({
    super.key,
    required this.title,
    required this.children,
    required this.onClose,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: const ColoredBox(color: AppColors.bgOverlay),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 480),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              decoration: const BoxDecoration(
                color: AppColors.bgBase,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBorderStrong,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(title, style: AppText.title(size: 18, weight: 800)),
                      const SizedBox(height: 8),
                      ...children,
                    ],
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

class _HowSheet extends StatelessWidget {
  const _HowSheet({required this.controller});

  final RatingBoardController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller.config;
    final body = AppText.body(size: 14, weight: 600);
    return _Sheet(
      key: const Key('rating-how'),
      title: RatingText.howTitle,
      onClose: controller.closeSheets,
      children: [
        Text(RatingText.howBody(c.cycleDays, _oneDecimal(c.cFallback)), style: body),
        const SizedBox(height: 8),
        Text(RatingText.minRule(c.minToRank), style: body),
        const SizedBox(height: 8),
        Text(
          RatingText.fairNote,
          style: AppText.caption(size: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _RewardsSheet extends StatelessWidget {
  const _RewardsSheet({required this.controller});

  final RatingBoardController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller.config;
    return _Sheet(
      key: const Key('rating-rewards'),
      title: RatingText.rewardsBtn,
      onClose: controller.closeSheets,
      children: [
        for (final r in c.rewards)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              RatingText.rewardRow(r.rankFrom, r.rankTo, ratingRewardText(r)),
              key: Key('rating-reward-${r.rankFrom}'),
              style: AppText.body(size: 14, weight: 700),
            ),
          ),
        if (controller.phase == RatingPhase.ended) ...[
          const SizedBox(height: 4),
          Text(
            RatingText.rewardPending,
            key: const Key('rating-reward-pending'),
            style: AppText.caption(size: 12.5, color: AppColors.textSecondary)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ],
    );
  }
}
