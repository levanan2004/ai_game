import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/charm_board.dart';
import '../data/pet_items.dart';
import '../logic/charm_board_controller.dart';
import '../logic/mailbox.dart' show MailClaimResult;
import '../logic/pet.dart';
import '../logic/reward_rarity.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'pet_shop_grid.dart' show PetFrameImage;
import 'phuc_loi_art.dart';
import 'ui_skin.dart';

/// Texts of SPEC_bang_xep_hang.md section 11, keyed like Nhất's table
/// (`bxh.*`). Marked (placeholder) = not yet approved by Nhất.
abstract final class Bxh {
  static const title = 'Xếp hạng Mị lực'; // bxh.title
  static String seasonLeft(String t) =>
      'Mùa kết thúc sau $t'; // bxh.season.left
  static const seasonEnded = 'Mùa đã kết thúc'; // bxh.season.ended
  // The season is over and the server is closing the board (recomputing,
  // paying). Wording pending Nhất; the old "Đang chờ duyệt" no longer fits.
  static const seasonPending =
      'Đang chốt bảng'; // bxh.season.pending (placeholder)
  static const you = 'Hạng của bạn'; // bxh.you
  static const youTag = 'Bạn'; // bxh.you.tag
  static const charm = 'Mị lực'; // bxh.charm
  static const rewardsBtn = 'Xem phần thưởng'; // bxh.rewards.btn
  static String rankN(int n) => 'Hạng $n'; // bxh.rank.n
  static String rankRange(int a, int b) => 'Hạng $a-$b'; // bxh.rank.range
  static const unranked = 'Chưa xếp hạng'; // bxh.unranked
  static const noPetHint = 'Chọn thú vào ô Mị lực'; // bxh.noPet.hint
  static const noPetBtn = 'Chọn thú'; // bxh.noPet.btn
  static String minHint(int n) =>
      'Cần ít nhất $n Mị lực để lên bảng'; // bxh.min.hint
  static const outRank = '100+'; // bxh.out.rank
  static String outHint(int n) =>
      'Cần thêm $n Mị lực để vào top 100'; // bxh.out.hint
  static const guestTitle = 'Đăng nhập để vào bảng'; // bxh.guest.title
  static const guestBtn = 'Đăng nhập'; // bxh.guest.btn
  static const errorTitle = 'Không tải được bảng'; // bxh.error.title
  static const errorSub = 'Kiểm tra mạng rồi thử lại nhé.'; // bxh.error.sub
  static const retry = 'Thử lại'; // bxh.error.retry
  static const rewardsTitle = 'Phần thưởng mùa'; // bxh.rewards.title
  static const rewardsHead = 'Thưởng mỗi mùa'; // bxh.rewards.head
  static String minPower(int n) =>
      'Cần ít nhất $n Mị lực để lên bảng'; // bxh.minPower
  static const colPhaLe = 'Pha lê'; // bxh.col.phale
  static const colGiot = 'Giọt hoa'; // bxh.col.giot
  static const colItem = 'Đồ pet'; // bxh.col.item
  static String youAt(int n) => 'Bạn · hạng $n'; // bxh.you.at
  static const claimNotEnded = 'Chưa kết thúc'; // bxh.claim.notEnded
  static const claimPending =
      'Đang chốt bảng'; // bxh.claim.pending (placeholder, pending Nhất)
  static const claimReady = 'Nhận thưởng'; // bxh.claim.ready
  static const claimDone = 'Đã nhận'; // bxh.claim.done
  // Toasts after "Nhận thưởng" (placeholder wording, pending Nhất).
  static const claimedToast =
      'Quà bảng xếp hạng đã vào tiệm.'; // bxh.claim.toastOk
  static const claimAlreadyToast =
      'Quà này nhận rồi nhé.'; // bxh.claim.toastAlready
  static const claimFailedToast =
      'Chưa nhận được, thử lại nhé.'; // bxh.claim.toastFail
  static const profileSlot = 'Ô Mị lực'; // bxh.profile.slot
  static const profileItems = 'Đồ đang đeo'; // bxh.profile.items
  static const slotEmpty = 'Trống'; // bxh.slot.empty
  static const formulaBase = 'Gốc'; // bxh.formula.base
  static const formulaMult = 'Hệ số'; // bxh.formula.mult
  static const formulaItems = 'Đồ'; // bxh.formula.items
  static const formulaTotal = 'Tổng'; // bxh.formula.total
  static String formulaBaseLine(int a, String k) =>
      'Gốc $a · hệ số x$k'; // bxh.formula.baseLine
  static String refreshNote(int n) =>
      'Bảng cập nhật mỗi $n phút'; // bxh.refreshNote (placeholder: pending Nhất)
  static const entry = 'Xếp hạng'; // bxh.entry
  // The map row (Nhất approved 10/10): caption after the chip and the label
  // the screen reader reads, with a full-sentence state per chip.
  static String mapCharm(int n) => '$n Mị lực'; // bxh.map.charm
  static String mapA11y(String state) =>
      'Xếp hạng Mị lực, $state'; // bxh.map.a11y
  static String mapA11yRank(int n) => 'hạng $n';
  static String mapA11yTop3(int n) => 'hạng $n, nằm trong top 3';
  static const mapA11yOut = 'chưa vào top 100';
  static const mapA11yNone = 'chưa có hạng';
  static const mapA11yGuest = 'đăng nhập để xếp hạng';
  static const mapA11yClosing = 'đang chốt bảng';
  static const mapA11yReward = 'có thưởng đang chờ nhận';
  static const emptyBoard =
      'Chưa có ai trên bảng.'; // bxh.empty (placeholder, mine)
  static const back = 'Quay lại bảng'; // placeholder, mine

  static String slotName(String slot) => switch (slot) {
    'neck' => 'Cổ', // bxh.slot.neck
    'head' => 'Đầu', // bxh.slot.head
    _ => 'Phụ kiện', // bxh.slot.acc
  };

  static String tierName(String tier) => switch (tier) {
    'hiem' => 'Hiếm', // bxh.rar.hiem
    'suThi' => 'Sử thi', // bxh.rar.suThi
    'huyenThoai' => 'Huyền thoại', // bxh.rar.huyenThoai
    _ => 'Thường', // bxh.rar.thuong
  };
}

const _ink = Color(0xFF2F6340);
const _gold = Color(0xFFF6D77A);
const _silver = Color(0xFFD5DDE3);
const _bronze = Color(0xFFE0B08A);

/// Xếp hạng Mị lực (SPEC_bang_xep_hang.md): the board, the reward table and a
/// player's profile sheet, drawn in the 360 x 640 frame. Opened from the round
/// button in the title row of the slot picker ([ShopSession.openCharmBoard]).
class CharmBoardScreen extends StatelessWidget {
  const CharmBoardScreen({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final b = s.board;
    return ListenableBuilder(
      listenable: Listenable.merge([s, b]),
      builder: (context, _) {
        return OpaqueScreen(
          color: AppColors.bgBase,
          child: Stack(
            key: const Key('bxh-screen'),
            children: [
              if (b.rewardsOpen)
                _RewardsView(session: s)
              else
                _BoardView(session: s),
              Positioned(
                left: 0,
                top: 0,
                child: TopBar(
                  session: s,
                  showRating: false,
                  showDay: false,
                  showPhaLe: true,
                ),
              ),
              Positioned(
                left: 16,
                top: 54,
                child: SkinRoundButton(
                  key: const Key('bxh-back'),
                  kind: SkinRound.back,
                  width: 40,
                  onTap: b.rewardsOpen ? b.closeRewards : s.closeCharmBoard,
                ),
              ),
              Positioned(
                left: 70,
                right: 70,
                top: 54,
                child: Center(
                  child: SkinRibbon(
                    title: b.rewardsOpen ? Bxh.rewardsTitle : Bxh.title,
                    width: 220,
                    height: 46,
                    fontSize: 18,
                  ),
                ),
              ),
              if (b.profile != null && !b.rewardsOpen)
                _ProfileSheet(session: s, row: b.profile!),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// L1: the board
// ---------------------------------------------------------------------------

class _BoardView extends StatelessWidget {
  const _BoardView({required this.session});

  final ShopSession session;

  ShopSession get s => session;
  CharmBoardController get b => s.board;

  @override
  Widget build(BuildContext context) {
    final me = b.me;
    final band = b.hasSeasonClock;
    final cardTop = band ? 144.0 : 106.0;
    final listTop = cardTop + 76 + 8;
    final guest = me == BoardMe.guest;
    final showRows = !guest;
    final loading = showRows && b.load == BoardLoad.loading && b.rows.isEmpty;
    final error = showRows && b.load == BoardLoad.error && b.rows.isEmpty;
    final idle = showRows && b.load == BoardLoad.idle && b.rows.isEmpty;
    final ready = showRows && !loading && !error && !idle;
    final cannotRead = loading || error || idle;
    return Stack(
      children: [
        if (band)
          Positioned(
            left: 0,
            right: 0,
            top: 106,
            child: Center(child: _SeasonBand(controller: b)),
          ),
        Positioned(
          left: 12,
          right: 12,
          top: cardTop,
          height: 76,
          child: _MeCard(session: s),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: listTop,
          bottom: 82,
          child: guest
              ? const _GuestBody()
              : loading || idle
              ? const _Skeleton()
              : error
              ? _ErrorBody(onRetry: () => b.refresh(force: true))
              : ready && b.rows.isEmpty
              ? const _EmptyBody()
              : RefreshIndicator(
                  onRefresh: () => b.refresh(force: true),
                  child: _BoardList(session: s),
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 80,
          height: 36,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bgBase.withValues(alpha: 0),
                    AppColors.bgBase,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!guest && !cannotRead)
          Positioned(
            left: 0,
            right: 0,
            bottom: 62,
            height: 18,
            child: ColoredBox(
              color: AppColors.bgBase,
              child: Center(
                child: Text(
                  Bxh.refreshNote(b.config.refreshMinutes),
                  key: const Key('bxh-refresh-note'),
                  maxLines: 1,
                  style: AppText.caption(
                    size: 10.5,
                    color: AppColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          )
        else
          const Positioned(
            left: 0,
            right: 0,
            bottom: 62,
            height: 18,
            child: ColoredBox(color: AppColors.bgBase),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: SkinButton(
            key: const Key('bxh-rewards-btn'),
            label: Bxh.rewardsBtn,
            height: 44,
            fontSize: 16,
            enabled: !cannotRead,
            onPressed: b.openRewards,
          ),
        ),
      ],
    );
  }
}

class _SeasonBand extends StatelessWidget {
  const _SeasonBand({required this.controller});

  final CharmBoardController controller;

  @override
  Widget build(BuildContext context) {
    final b = controller;
    final ended = b.seasonEnded;
    final text = !ended
        ? Bxh.seasonLeft(b.seasonLeftText)
        : b.claim == BoardClaim.pending
        ? '${Bxh.seasonEnded} · ${Bxh.seasonPending}'
        : Bxh.seasonEnded;
    return Container(
      key: const Key('bxh-season'),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ended ? AppColors.accentSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ended ? AppColors.accentBase : AppColors.surfaceBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(Art.nav('dong_ho'), width: 20, height: 20),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppText.body(
              size: 12.5,
              weight: 800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Hạng của bạn": local Mị lực, rank from the latest read.
class _MeCard extends StatelessWidget {
  const _MeCard({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final b = s.board;
    final me = b.me;
    final state = s.state;
    final petId = state.petCharm;
    final owned = petId == null ? null : state.ownedPet(petId);
    final name = (state.shopName ?? '').trim().isEmpty
        ? charmBoardFallbackName
        : state.shopName!.trim();
    final rank = b.myRank;

    Widget? badge;
    String? hint;
    Widget? action;
    switch (me) {
      case BoardMe.guest:
        break;
      case BoardMe.noPet:
        hint = Bxh.noPetHint;
        action = _CardButton(
          key: const Key('bxh-pick-pet'),
          label: Bxh.noPetBtn,
          onTap: s.pickCharmPet,
        );
      case BoardMe.underMin:
        hint = Bxh.minHint(b.config.minCharm);
      case BoardMe.ranked:
        badge = RankBadge(rank: rank!, height: 44);
      case BoardMe.outside:
        badge = const RankBadge(rank: 100, height: 44, label: Bxh.outRank);
        hint = Bxh.outHint(b.outsideNeed);
      case BoardMe.pending:
        badge = const RankBadge(rank: 100, height: 44, label: '-');
    }

    return Container(
      key: const Key('bxh-card'),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: _cardDecoration(border: AppColors.primaryBase, thick: true),
      child: me == BoardMe.guest
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    Bxh.guestTitle,
                    key: const Key('bxh-guest-title'),
                    style: AppText.title(size: 15, weight: 800),
                  ),
                ),
                _CardButton(
                  key: const Key('bxh-guest-btn'),
                  label: Bxh.guestBtn,
                  onTap: s.signIn,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Bxh.you,
                  style: AppText.caption(
                    size: 11.5,
                    color: _ink,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                Expanded(
                  child: Row(
                    children: [
                      if (badge != null) ...[
                        SizedBox(width: 38, child: badge),
                        const SizedBox(width: 8),
                      ],
                      _AvatarCircle(
                        avatar: state.ownerAvatar,
                        name: name,
                        radius: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title(
                                size: 15,
                                weight: 800,
                              ).copyWith(height: 1.1),
                            ),
                            if (badge == null)
                              Text(
                                Bxh.unranked,
                                key: const Key('bxh-unranked'),
                                style:
                                    AppText.caption(
                                      size: 11,
                                      color: AppColors.textSecondary,
                                    ).copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                    ),
                              ),
                            if (hint != null)
                              Text(
                                hint,
                                key: const Key('bxh-card-hint'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    AppText.caption(
                                      size: 10.5,
                                      color: AppColors.textSecondary,
                                    ).copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                              )
                            else if (owned != null)
                              Row(
                                children: [
                                  _StageDots(stage: owned.stage),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      petStageName(owned.stage),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption(
                                        size: 10.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (action != null)
                        action
                      else ...[
                        _PetBox(
                          petId: petId ?? '',
                          stage: owned?.stage ?? 0,
                          size: 40,
                        ),
                        const SizedBox(width: 8),
                        _CharmNumber(
                          key: const Key('bxh-card-charm'),
                          value: owned == null ? 0 : b.myCharm,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryBase,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: AppColors.primaryPressed, offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          label,
          style: AppText.button(size: 14, weight: 800, color: Colors.white),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({
  Color border = AppColors.surfaceBorder,
  Color color = Colors.white,
  bool thick = false,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: border, width: thick ? 2.5 : 1.5),
  boxShadow: const [
    BoxShadow(color: AppColors.surfaceBorderStrong, offset: Offset(0, 4)),
  ],
);

class _BoardList extends StatelessWidget {
  const _BoardList({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final rows = session.board.rows;
    return ListView(
      key: const Key('bxh-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
      children: [
        _Podium(session: session, rows: rows),
        const SizedBox(height: 10),
        for (final row in rows.skip(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _BoardRow(session: session, row: row),
          ),
      ],
    );
  }
}

// ---- podium ----------------------------------------------------------------

class _Podium extends StatelessWidget {
  const _Podium({required this.session, required this.rows});

  final ShopSession session;
  final List<CharmBoardRow> rows;

  @override
  Widget build(BuildContext context) {
    CharmBoardRow? at(int rank) => rows.length >= rank ? rows[rank - 1] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final rank in const [2, 1, 3])
          Expanded(
            child: _PodiumColumn(session: session, rank: rank, row: at(rank)),
          ),
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.session,
    required this.rank,
    required this.row,
  });

  final ShopSession session;
  final int rank;
  final CharmBoardRow? row;

  @override
  Widget build(BuildContext context) {
    final entry = row?.entry;
    final first = rank == 1;
    final width = first ? 104.0 : 88.0;
    final base = switch (rank) {
      1 => _gold,
      2 => _silver,
      _ => _bronze,
    };
    final pedestal = switch (rank) {
      1 => 54.0,
      2 => 44.0,
      _ => 38.0,
    };
    final def = entry == null || entry.petId.isEmpty
        ? null
        : session.e.pet(entry.petId);
    return GestureDetector(
      key: Key('bxh-podium-$rank'),
      behavior: HitTestBehavior.opaque,
      onTap: row == null ? null : () => session.board.openProfile(row!),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                RankFrame(
                  rank: rank,
                  width: width,
                  child: entry == null
                      ? const ColoredBox(color: AppColors.surfaceSunken)
                      : Avatar(
                          name: entry.displayName,
                          avatarId: entry.avatar,
                          radius: 50,
                        ),
                ),
                if (first)
                  Positioned(
                    top: -10,
                    child: Image.asset(
                      Art.bxh('vuong_mien'),
                      width: 40,
                      excludeFromSemantics: true,
                    ),
                  ),
                if (entry != null && entry.petId.isNotEmpty)
                  Positioned(
                    right: first ? 6 : 4,
                    bottom: first ? 10 : 8,
                    child: _PetBox(
                      petId: entry.petId,
                      stage: entry.stage,
                      size: 28,
                      round: true,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          if (entry != null) ...[
            Text(
              entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title(size: first ? 14 : 13, weight: 800),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StageDots(stage: entry.stage, size: 5),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    def?.nameVi ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(
                      size: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            _CharmNumber(value: entry.charm, size: first ? 18 : 16),
          ] else
            const SizedBox(height: 50),
          const SizedBox(height: 4),
          Container(
            height: pedestal,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: base,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border.all(
                color: AppColors.surfaceBorderStrong,
                width: 1.5,
              ),
            ),
            child: RankBadge(rank: rank, height: pedestal - 8),
          ),
        ],
      ),
    );
  }
}

/// khung_hang_N (392 x 380 canvas, circle centre (196, 180)): the frame, the
/// avatar cut round, then the flower overlay on top.
class RankFrame extends StatelessWidget {
  const RankFrame({
    super.key,
    required this.rank,
    required this.width,
    required this.child,
  });

  final int rank;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final h = width * 380 / 392;
    final r = (rank == 1 ? 113 : 114) / 392 * width - 1;
    final cx = 196 / 392 * width;
    final cy = 180 / 380 * h;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(Art.bxh('khung_hang_$rank'), fit: BoxFit.fill),
          ),
          Positioned(
            left: cx - r,
            top: cy - r,
            width: 2 * r,
            height: 2 * r,
            child: ClipOval(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox.square(dimension: 100, child: child),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              Art.bxh('khung_hang_${rank}_phu'),
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }
}

/// A medal (1-3) or shield (4-10, 11-50, 51-100) with the rank written by
/// code into the empty face (README_xep_hang.md).
class RankBadge extends StatelessWidget {
  const RankBadge({
    super.key,
    required this.rank,
    required this.height,
    this.label,
  });

  final int rank;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final medal = rank <= 3;
    final asset = medal
        ? 'huy_chuong_$rank'
        : rank <= 10
        ? 'huy_hieu_4_10'
        : rank <= 50
        ? 'huy_hieu_11_50'
        : 'huy_hieu_51_100';
    final canvas = medal ? const Size(293, 415) : const Size(356, 395);
    final face = medal
        ? const Rect.fromLTWH(84, 160, 128, 102)
        : const Rect.fromLTWH(82, 106, 188, 128);
    final color = medal
        ? const Color(0xFF5C3E22)
        : rank <= 10
        ? _ink
        : rank <= 50
        ? const Color(0xFF204A78)
        : const Color(0xFF5C3E22);
    final w = height * canvas.width / canvas.height;
    final k = height / canvas.height;
    return SizedBox(
      width: w,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              Art.bxh(asset),
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            left: face.left * k,
            top: face.top * k,
            width: face.width * k,
            height: face.height * k,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label ?? '$rank',
                  key: Key('bxh-badge-${label ?? rank}'),
                  style:
                      AppText.title(
                        size: face.height * k * 1.15,
                        weight: 800,
                        color: color,
                      ).copyWith(
                        shadows: const [
                          Shadow(color: Color(0xCCFFFFFF), blurRadius: 1.5),
                          Shadow(
                            color: Color(0xCCFFFFFF),
                            offset: Offset(0, 1),
                          ),
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

// ---- list rows ---------------------------------------------------------------

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.session, required this.row});

  final ShopSession session;
  final CharmBoardRow row;

  @override
  Widget build(BuildContext context) {
    final entry = row.entry;
    final mine = entry.uid == session.accountUid;
    final def = entry.petId.isEmpty ? null : session.e.pet(entry.petId);
    return GestureDetector(
      key: Key('bxh-row-${row.rank}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => session.board.openProfile(row),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: _cardDecoration(
          color: mine ? AppColors.primarySoft : Colors.white,
          border: mine ? AppColors.primaryBase : AppColors.surfaceBorder,
          thick: mine,
        ),
        child: Row(
          children: [
            SizedBox(width: 36, child: RankBadge(rank: row.rank, height: 38)),
            const SizedBox(width: 6),
            _AvatarCircle(
              avatar: entry.avatar,
              name: entry.displayName,
              radius: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title(size: 14, weight: 800),
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBase,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            Bxh.youTag,
                            style: AppText.caption(
                              size: 9.5,
                              color: Colors.white,
                            ).copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      _StageDots(stage: entry.stage, size: 5),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          petStageName(entry.stage),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(
                            size: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (def != null)
              _PetBox(petId: entry.petId, stage: entry.stage, size: 38),
            const SizedBox(width: 8),
            _CharmNumber(value: entry.charm, size: 16),
          ],
        ),
      ),
    );
  }
}

// ---- pieces ------------------------------------------------------------------

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.avatar,
    required this.name,
    required this.radius,
  });

  final String avatar;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // An uploaded photo is a storage path (it has a '/'): the board does not
    // fetch it, the initial stands in.
    final preset = avatar.contains('/') ? '' : avatar;
    return Avatar(name: name, avatarId: preset, radius: radius);
  }
}

class _StageDots extends StatelessWidget {
  const _StageDots({required this.stage, this.size = 6});

  final int stage;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: size,
            height: size,
            margin: EdgeInsets.only(right: i < 2 ? 2 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= stage
                  ? AppColors.primaryBase
                  : AppColors.surfaceBorder,
            ),
          ),
      ],
    );
  }
}

class _PetBox extends StatelessWidget {
  const _PetBox({
    required this.petId,
    required this.stage,
    required this.size,
    this.round = false,
  });

  final String petId;
  final int stage;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: round ? 2 : 1.5),
      ),
      child: petId.isEmpty
          ? Center(
              child: Icon(
                Icons.favorite_border,
                size: size * 0.5,
                color: const Color(0xFFE8738A),
              ),
            )
          : PetFrameImage(id: petId, stage: stage, size: size - 4),
    );
  }
}

class _CharmNumber extends StatelessWidget {
  const _CharmNumber({super.key, required this.value, required this.size});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: AppText.title(
            size: size,
            weight: 800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        Image.asset(
          Art.bxh('mi_luc'),
          width: size * 0.9,
          excludeFromSemantics: true,
        ),
      ],
    );
  }
}

// ---- other body states ----------------------------------------------------

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('bxh-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      children: [
        for (var i = 0; i < 6; i++)
          Container(
            height: 52,
            margin: const EdgeInsets.only(bottom: 7),
            decoration: BoxDecoration(
              color: AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Bxh.errorTitle,
            key: const Key('bxh-error'),
            style: AppText.title(size: 17, weight: 800),
          ),
          const SizedBox(height: 4),
          Text(
            Bxh.errorSub,
            style: AppText.caption(size: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 150,
            child: SkinButton(
              key: const Key('bxh-retry'),
              label: Bxh.retry,
              kind: SkinButtonKind.secondary,
              height: 44,
              fontSize: 15,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestBody extends StatelessWidget {
  const _GuestBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: 0.55,
        child: Image.asset(
          Art.bxh('xep_hang_icon'),
          width: 96,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        Bxh.emptyBoard,
        key: const Key('bxh-empty'),
        style: AppText.caption(size: 12.5, color: AppColors.textSecondary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// L2: rewards
// ---------------------------------------------------------------------------

class _RewardsView extends StatelessWidget {
  const _RewardsView({required this.session});

  final ShopSession session;

  ShopSession get s => session;
  CharmBoardController get b => s.board;

  @override
  Widget build(BuildContext context) {
    final rewards = b.config.rewards;
    final rank = b.myRank;
    final band = b.hasSeasonClock;
    final headTop = band ? 144.0 : 106.0;
    return Stack(
      children: [
        if (band)
          Positioned(
            left: 0,
            right: 0,
            top: 106,
            child: Center(child: _SeasonBand(controller: b)),
          ),
        Positioned(
          left: 16,
          right: 16,
          top: headTop,
          height: 36,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Bxh.rewardsHead,
                style: AppText.title(size: 15, weight: 800),
              ),
              Text(
                Bxh.minPower(b.config.minCharm),
                key: const Key('bxh-min-power'),
                maxLines: 1,
                style: AppText.caption(
                  size: 11,
                  color: AppColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: headTop + 40,
          height: 18,
          child: Row(
            children: [
              const SizedBox(width: 96),
              for (final (label, w) in const [
                (Bxh.colPhaLe, 58.0),
                (Bxh.colGiot, 58.0),
                (Bxh.colItem, 108.0),
              ])
                SizedBox(
                  width: w,
                  child: Center(
                    child: Text(
                      label,
                      style: AppText.caption(
                        size: 11,
                        color: AppColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: headTop + 60,
          bottom: 68,
          child: ListView(
            key: const Key('bxh-reward-list'),
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              for (final r in rewards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: _RewardCard(
                    reward: r,
                    mine: rank != null && r.covers(rank),
                    rank: rank,
                    itemCharm: b.itemCharm(r.itemTier),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: _ClaimButton(controller: b),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.mine,
    required this.rank,
    required this.itemCharm,
  });

  final CharmBoardReward reward;
  final bool mine;
  final int? rank;
  final int itemCharm;

  @override
  Widget build(BuildContext context) {
    final r = reward;
    final single = r.rankFrom == r.rankTo;
    final label = single
        ? Bxh.rankN(r.rankFrom)
        : Bxh.rankRange(r.rankFrom, r.rankTo);
    Widget cell(double w, Widget child) => SizedBox(
      width: w,
      child: Center(child: child),
    );
    Widget amount(int n, Widget icon) => n <= 0
        ? Text(
            '-',
            style: AppText.title(size: 14, color: AppColors.textDisabled),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$n', style: AppText.title(size: 15, weight: 800)),
              const SizedBox(width: 3),
              icon,
            ],
          );
    final tier = PetItemTier.fromKey(r.itemTier);
    final tagged = mine && rank != null;
    // The "Bạn · hạng N" tag sticks out 9dp above the card; the room for it is
    // inside this widget so no scroll view or parent ever clips it.
    final card = Container(
      key: Key('bxh-reward-${r.rankFrom}'),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: _cardDecoration(
        color: mine ? AppColors.primarySoft : Colors.white,
        border: mine ? AppColors.primaryBase : AppColors.surfaceBorder,
        thick: mine,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Row(
                  children: [
                    RankBadge(
                      rank: single ? r.rankFrom : r.rankFrom,
                      height: 44,
                      label: r.rankFrom <= 3 ? null : '',
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      // "Hạng" over the range, so "11–50" never gets cut.
                      child: Text(
                        label.replaceFirst(' ', '\n'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(
                          size: 13,
                          weight: 800,
                        ).copyWith(height: 1.1),
                      ),
                    ),
                  ],
                ),
              ),
              cell(
                58,
                amount(r.phaLe, Image.asset(Art.nav('pha_le'), width: 16)),
              ),
              cell(
                58,
                amount(r.giotHoa, Image.asset(Art.pet('giat_hoa'), width: 16)),
              ),
              cell(
                108,
                tier == null
                    ? Text(
                        '-',
                        style: AppText.title(
                          size: 14,
                          color: AppColors.textDisabled,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RarityFrame(
                            rarity: _rarityOf(tier),
                            size: 34,
                            child: const Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Bxh.tierName(tier.key),
                                style: AppText.caption(
                                  size: 10.5,
                                  color: _tierColor(tier),
                                ).copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '+$itemCharm ${Bxh.charm}',
                                maxLines: 1,
                                style: AppText.caption(
                                  size: 9.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
          if (tagged)
            Positioned(
              left: 8,
              top: -9,
              child: Container(
                key: const Key('bxh-you-at'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primaryBase,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  Bxh.youAt(rank!),
                  style: AppText.caption(
                    size: 10,
                    color: Colors.white,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
    return tagged
        ? Padding(padding: const EdgeInsets.only(top: 12), child: card)
        : card;
  }
}

RewardRarity _rarityOf(PetItemTier tier) => switch (tier) {
  PetItemTier.thuong => RewardRarity.thuong,
  PetItemTier.hiem => RewardRarity.hiem,
  PetItemTier.suThi => RewardRarity.suThi,
  PetItemTier.huyenThoai => RewardRarity.huyenThoai,
};

Color _tierColor(PetItemTier tier) => switch (tier) {
  PetItemTier.thuong => const Color(0xFF8A5A3C),
  PetItemTier.hiem => const Color(0xFF2E6EA0),
  PetItemTier.suThi => const Color(0xFF7B5CB8),
  PetItemTier.huyenThoai => const Color(0xFFC98A2A),
};

/// "Nhận thưởng": claims through the gift mailbox and says what happened.
Future<void> _claim(BuildContext context, CharmBoardController b) async {
  final result = await b.claimReward();
  if (!context.mounted) return;
  switch (result) {
    case MailClaimResult.claimed:
      showGameToast(context, Bxh.claimedToast);
    case MailClaimResult.already:
      showGameToast(context, Bxh.claimAlreadyToast);
    case MailClaimResult.busy:
      break;
    case MailClaimResult.refused:
    case MailClaimResult.failed:
      showGameToast(context, Bxh.claimFailedToast, error: true);
  }
}

/// The one pinned button of the reward table (SPEC section 6): four states,
/// and only for a player who has a rank in the reward table. Anyone else gets
/// a way back to the board.
class _ClaimButton extends StatelessWidget {
  const _ClaimButton({required this.controller});

  final CharmBoardController controller;

  @override
  Widget build(BuildContext context) {
    final b = controller;
    final rank = b.myRank;
    final eligible = rank != null && b.config.rewardFor(rank) != null;
    if (!eligible) {
      return SkinButton(
        key: const Key('bxh-claim-back'),
        label: Bxh.back,
        kind: SkinButtonKind.secondary,
        height: 44,
        fontSize: 16,
        onPressed: b.closeRewards,
      );
    }
    final state = b.claim;
    final (label, icon) = switch (state) {
      BoardClaim.notEnded => (Bxh.claimNotEnded, Art.nav('dong_ho')),
      BoardClaim.pending => (Bxh.claimPending, Art.nav('dong_ho')),
      BoardClaim.ready => (Bxh.claimReady, Art.nav('qua')),
      BoardClaim.done => (Bxh.claimDone, ''),
    };
    switch (state) {
      case BoardClaim.ready:
        return SkinButton(
          key: const Key('bxh-claim'),
          label: label,
          height: 44,
          fontSize: 16,
          enabled: !b.claiming,
          onPressed: () => _claim(context, b),
        );
      case BoardClaim.notEnded:
        return SkinButton(
          key: const Key('bxh-claim'),
          label: label,
          height: 44,
          fontSize: 16,
          enabled: false,
          onPressed: null,
        );
      case BoardClaim.pending:
      case BoardClaim.done:
        final pending = state == BoardClaim.pending;
        return Container(
          key: const Key('bxh-claim'),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pending ? AppColors.accentSoft : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: pending ? AppColors.accentBase : AppColors.primaryBase,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pending)
                Image.asset(
                  icon,
                  width: 22,
                  height: 22,
                  color: AppColors.statusWarning,
                )
              else
                const Icon(
                  Icons.check_circle,
                  size: 22,
                  color: AppColors.statusSuccess,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppText.button(
                  size: 16,
                  weight: 800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// L4: profile sheet
// ---------------------------------------------------------------------------

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({required this.session, required this.row});

  final ShopSession session;
  final CharmBoardRow row;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final entry = row.entry;
    final def = entry.petId.isEmpty ? null : s.e.pet(entry.petId);
    final stage = entry.stage.clamp(0, 2);
    final mult = s.e.charmStageMultiplier.length > stage
        ? s.e.charmStageMultiplier[stage]
        : 1.0;
    final base = def?.charmBase ?? 0;
    final items = wornItemsCharm(entry.worn, s.e.petItemRules, s.e.petItem);
    final multText = mult == mult.roundToDouble()
        ? '${mult.round()}'
        : '$mult'.replaceAll('.', ',');
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('bxh-scrim'),
              behavior: HitTestBehavior.opaque,
              onTap: s.board.closeProfile,
              child: const ColoredBox(color: AppColors.bgOverlay),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 462,
            child: GestureDetector(
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 200) s.board.closeProfile();
              },
              child: Container(
                key: const Key('bxh-profile'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                decoration: const BoxDecoration(
                  color: AppColors.bgBase,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBorderStrong,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _AvatarCircle(
                            avatar: entry.avatar,
                            name: entry.displayName,
                            radius: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.title(size: 19, weight: 800),
                                ),
                                Text(
                                  Bxh.rankN(row.rank),
                                  key: const Key('bxh-profile-rank'),
                                  style: AppText.caption(
                                    size: 12,
                                    color: _ink,
                                  ).copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _CharmNumber(value: entry.charm, size: 24),
                              Text(
                                Bxh.charm,
                                style: AppText.caption(
                                  size: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _PetCard(
                        session: s,
                        entry: entry,
                        stage: stage,
                        base: base,
                        multText: multText,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Bxh.profileItems,
                          style: AppText.title(size: 14, weight: 800),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final slot in charmBoardSlots) ...[
                            if (slot != charmBoardSlots.first)
                              const SizedBox(width: 8),
                            Expanded(
                              child: _ItemSlot(
                                session: s,
                                slot: slot,
                                itemId: entry.worn[slot],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        key: const Key('bxh-formula'),
                        children: [
                          _FormulaCell(label: Bxh.formulaBase, value: '$base'),
                          const _FormulaOp('×'),
                          _FormulaCell(label: Bxh.formulaMult, value: multText),
                          const _FormulaOp('+'),
                          _FormulaCell(
                            label: Bxh.formulaItems,
                            value: '$items',
                          ),
                          const _FormulaOp('='),
                          _FormulaCell(
                            label: Bxh.formulaTotal,
                            value: '${entry.charm}',
                            total: true,
                          ),
                        ],
                      ),
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

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.session,
    required this.entry,
    required this.stage,
    required this.base,
    required this.multText,
  });

  final ShopSession session;
  final CharmBoardEntry entry;
  final int stage;
  final int base;
  final String multText;

  @override
  Widget build(BuildContext context) {
    final def = entry.petId.isEmpty ? null : session.e.pet(entry.petId);
    final border = switch (stage) {
      0 => AppColors.surfaceBorderStrong,
      1 => AppColors.primaryBase,
      _ => AppColors.accentBase,
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(border: AppColors.surfaceBorder),
      child: Row(
        children: [
          Container(
            key: Key('bxh-pet-frame-$stage'),
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: border,
                width: stage == 2
                    ? 3.5
                    : stage == 1
                    ? 2.5
                    : 1.5,
              ),
              boxShadow: stage == 2
                  ? [
                      BoxShadow(
                        color: AppColors.accentBase.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: entry.petId.isEmpty
                ? const Icon(Icons.favorite_border, color: Color(0xFFE8738A))
                : PetFrameImage(id: entry.petId, stage: stage, size: 98),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      size: 13,
                      color: Color(0xFFE8738A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Bxh.profileSlot,
                      style: AppText.caption(
                        size: 11,
                        color: AppColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Text(
                  def?.nameVi ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(size: 16, weight: 800),
                ),
                Row(
                  children: [
                    _StageDots(stage: stage),
                    const SizedBox(width: 5),
                    Text(
                      petStageName(stage),
                      style: AppText.caption(
                        size: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  Bxh.formulaBaseLine(base, multText),
                  style: AppText.caption(
                    size: 11,
                    color: AppColors.textSecondary,
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

class _ItemSlot extends StatelessWidget {
  const _ItemSlot({
    required this.session,
    required this.slot,
    required this.itemId,
  });

  final ShopSession session;
  final String slot;
  final String? itemId;

  @override
  Widget build(BuildContext context) {
    final def = itemId == null ? null : session.e.petItem(itemId!);
    final glyph = switch (slot) {
      'neck' => Icons.link,
      'head' => Icons.workspace_premium,
      _ => Icons.auto_awesome,
    };
    final name = Bxh.slotName(slot);
    final shown = def != null && def.slot == slot;
    return Column(
      key: Key('bxh-slot-$slot'),
      children: [
        Text(
          name,
          style: AppText.caption(
            size: 11,
            color: AppColors.textSecondary,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 64,
          height: 64,
          child: shown
              ? RarityFrame(
                  rarity: _rarityOf(def.tier),
                  size: 64,
                  child: Icon(glyph, size: 24, color: Colors.white),
                )
              : CustomPaint(
                  painter: _DashedBoxPainter(),
                  child: Center(
                    child: Icon(
                      glyph,
                      size: 22,
                      color: AppColors.surfaceBorderStrong,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 3),
        Text(
          shown ? def.nameVi : Bxh.slotEmpty,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption(
            size: 10.5,
            color: shown ? AppColors.textPrimary : AppColors.textDisabled,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        if (shown)
          Text(
            '+${session.e.petItemRules.charmOfTier(def.tier)}',
            style: AppText.caption(
              size: 11,
              color: _tierColor(def.tier),
            ).copyWith(fontWeight: FontWeight.w800),
          ),
      ],
    );
  }
}

class _DashedBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surfaceBorderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    ).deflate(1);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 6, metric.length)),
          paint,
        );
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBoxPainter old) => false;
}

class _FormulaCell extends StatelessWidget {
  const _FormulaCell({
    required this.label,
    required this.value,
    this.total = false,
  });

  final String label;
  final String value;
  final bool total;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: total ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: total ? AppColors.primaryBase : AppColors.surfaceBorder,
            width: total ? 2 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppText.caption(
                size: 10.5,
                color: AppColors.textSecondary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppText.title(
                  size: 17,
                  weight: 800,
                  color: total ? _ink : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormulaOp extends StatelessWidget {
  const _FormulaOp(this.op);

  final String op;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Text(
      op,
      style: AppText.title(size: 15, color: AppColors.textSecondary),
    ),
  );
}
