import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/charm_board.dart';
import '../data/pet_items.dart';
import '../logic/charm_board_controller.dart';
import '../logic/charm_rewards.dart'
    show seasonAmountText, seasonFallback, seasonTierName;
import '../logic/mailbox.dart' show MailClaimResult;
import '../logic/pet.dart';
import '../logic/profile_report.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'pet_item_art.dart' show PetItemIcon, PetItemPalette;
import 'player_avatar.dart';
import 'profile_card.dart' show ProfileText;
import 'rating_board_view.dart';
import 'pet_shop_grid.dart' show PetFrameImage;
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

  // Season reward mystery cell and its prize list (Nhất, verbatim).
  static String mysteryA11y(String rarity) =>
      'Đồ pet $rarity ngẫu nhiên'; // season.reward.mystery_a11y
  static String poolTitle(String rarity) =>
      'Đồ pet $rarity có thể nhận'; // season.pool.title
  static String poolDesc(String fallbackAmount) =>
      'Bạn sẽ nhận ngẫu nhiên 1 món bạn chưa có trong danh sách này. '
      'Nếu đã có đủ, bạn nhận $fallbackAmount thay thế.'; // season.pool.desc
  static const poolOwned = 'Đã có'; // season.pool.owned
  static String poolAllOwned(String rarity, String fallbackAmount) =>
      'Bạn đã có đủ đồ pet $rarity. '
      'Phần thưởng hạng này sẽ là $fallbackAmount.'; // season.pool.all_owned
  static const poolClose = 'Đóng'; // season.pool.close
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
  // Reporting a profile (Nhất, chu_ung_dung_v1.md mục 5; reasons in
  // ReportReason).
  static const report = 'Báo cáo'; // profile.report.btn
  static const reportTitle = 'Báo cáo hồ sơ này'; // report.dialog.title
  static const reportIntro =
      'Chọn lý do. Tiệm sẽ xem xét và không cho người kia biết ai báo cáo.'; // report.dialog.intro
  static const reportNoteHint =
      'Ghi thêm (không bắt buộc, tối đa 200 chữ)'; // report.dialog.note_hint
  static const reportSend = 'Gửi báo cáo'; // report.dialog.btn_send
  static const reportCancel = 'Hủy'; // report.dialog.btn_cancel
  static const reportSent =
      'Tiệm đã nhận báo cáo, cảm ơn bạn.'; // report.success.toast
  static const reportFailed =
      'Chưa gửi được báo cáo. Bạn thử lại nhé.'; // report.fail.toast
  static const reportAlready =
      'Bạn đã báo cáo hồ sơ này rồi. Tiệm đang xem.'; // report.already.toast
  // Hiding a player (Apple 1.2; per account since JOB C, else this device). Nhất, chu_tinh_nang_moi.md
  // mục 9.
  static const hide = 'Ẩn người chơi này'; // report.hide_btn
  static String hideConfirmTitle(String name) =>
      'Ẩn $name?'; // hide.confirm.title
  static const hideConfirmBody =
      'Bạn sẽ không thấy tên và avatar của người này trên bảng xếp hạng nữa. '
      'Người đó không nhận được thông báo nào.'; // hide.confirm.body
  static const hideConfirmOk = 'Ẩn'; // hide.confirm.ok
  static const hideConfirmCancel = 'Thôi'; // hide.confirm.cancel
  static String hidden(String name) =>
      'Đã ẩn $name. Bạn có thể bỏ ẩn trong mục Người chơi đã ẩn.'; // hide.toast.done
  static const hiddenName = 'Người chơi đã ẩn'; // hide.row.placeholder
  static const hiddenListTitle = 'Người chơi đã ẩn'; // hide.list.title
  static const hiddenListNote =
      'Danh sách này chỉ lưu trên máy này.'; // hide.list.note (signed out)
  static const hiddenListNoteAccount =
      'Danh sách này lưu theo tài khoản của bạn, đăng nhập máy nào cũng thấy. '
      'Xóa tài khoản thì danh sách cũng bị xóa.'; // hide.list.note (per account)
  static const hiddenListEmpty = 'Bạn chưa ẩn ai.'; // hide.list.empty
  static const unhide = 'Bỏ ẩn'; // hide.list.unhide_btn
  static String unhidden(String name) =>
      'Đã bỏ ẩn $name.'; // hide.toast.unhidden

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
      listenable: Listenable.merge([s, b, s.frames, s.ratingBoard]),
      builder: (context, _) {
        // Bảng Đánh giá (spec 2.2): two tabs under the title row, the ribbon
        // reads "Bảng xếp hạng". Hidden on the Mị lực reward table.
        final tabs = s.ratingBoard.enabled && !b.rewardsOpen;
        final ratingTab = tabs && s.ratingBoard.tab;
        return OpaqueScreen(
          color: AppColors.bgBase,
          child: Stack(
            key: const Key('bxh-screen'),
            children: [
              if (b.rewardsOpen)
                _RewardsView(session: s)
              else if (ratingTab)
                RatingBoardView(session: s)
              else
                _BoardView(session: s, shift: tabs ? 48 : 0),
              if (tabs)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 104,
                  child: BoardTabs(session: s),
                ),
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
                    title: b.rewardsOpen
                        ? Bxh.rewardsTitle
                        : tabs
                        ? RatingText.boardTitle
                        : Bxh.title,
                    width: 220,
                    height: 46,
                    fontSize: 18,
                  ),
                ),
              ),
              if (b.profile != null && !b.rewardsOpen && !ratingTab)
                b.reportOpen
                    ? _ReportSheet(session: s)
                    : _ProfileSheet(session: s, row: b.profile!),
              if (b.hiddenListOpen && !b.rewardsOpen && !ratingTab)
                _HiddenListSheet(session: s),
              if (b.rewardsOpen && b.poolTier != null)
                _PoolSheet(session: s, tierKey: b.poolTier!),
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
  const _BoardView({required this.session, this.shift = 0});

  final ShopSession session;

  /// Room for the Mị lực | Đánh giá tabs above the season band.
  final double shift;

  ShopSession get s => session;
  CharmBoardController get b => s.board;

  @override
  Widget build(BuildContext context) {
    final me = b.me;
    final band = b.hasSeasonClock;
    final cardTop = (band ? 144.0 : 106.0) + shift;
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
            top: 106 + shift,
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
                        avatar: session.publishedAvatar,
                        name: name,
                        radius: 17,
                        frameId: session.frames.equipped,
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
        // Where "Bỏ ẩn" lives, once someone is hidden.
        if (session.board.hidden.isNotEmpty)
          Center(
            child: GestureDetector(
              key: const Key('bxh-hidden-list-open'),
              behavior: HitTestBehavior.opaque,
              onTap: session.board.openHiddenList,
              child: SizedBox(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Bxh.hiddenListTitle,
                      style: AppText.body(
                        size: 14,
                        weight: 800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                      : PlayerAvatar(
                          key: Key('bxh-podium-avatar-$rank'),
                          name: _nameOf(session, entry),
                          avatar: _avatarOf(session, entry),
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
              _nameOf(session, entry),
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
              avatar: _avatarOf(session, entry),
              name: _nameOf(session, entry),
              radius: 19,
              frameId: _frameOf(session, entry),
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
                          _nameOf(session, entry),
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
    super.key,
    required this.avatar,
    required this.name,
    required this.radius,
    this.frameId = '',
    this.roomForFrame = false,
  });

  final String avatar;
  final String name;
  final double radius;
  final String frameId;

  /// Keeps the frame's spill inside this widget (the profile sheet).
  final bool roomForFrame;

  @override
  Widget build(BuildContext context) {
    final avatarWidget = PlayerAvatar(
      avatar: avatar,
      name: name,
      radius: radius,
      frameId: frameId,
    );
    if (!roomForFrame || frameId.isEmpty) return avatarWidget;
    return Padding(
      padding: EdgeInsets.all(PlayerAvatar.frameSide(radius) / 2 - radius),
      child: avatarWidget,
    );
  }
}

/// What a row shows for [entry]: the player's own row uses the portrait they
/// have now (the stored row is up to 15 minutes behind), everyone else the
/// pointer in their row. A player hidden by this player gets the default one.
String _avatarOf(ShopSession s, CharmBoardEntry entry) =>
    entry.uid == s.accountUid
    ? s.publishedAvatar
    : s.board.isHidden(entry.uid)
    ? ''
    : entry.avatar;

/// The frame on a row: own one as worn now, none for a player hidden by
/// this player, else what the server stored (player_avatars, read through
/// [AvatarFramesController]).
String _frameOf(ShopSession s, CharmBoardEntry entry) =>
    entry.uid == s.accountUid
    ? s.frames.equipped
    : s.board.isHidden(entry.uid)
    ? ''
    : s.frames.frameOf(entry.uid);

/// The shop name on a row, masked for a player this player hid.
String _nameOf(ShopSession s, CharmBoardEntry entry) =>
    s.board.isHidden(entry.uid) ? Bxh.hiddenName : entry.displayName;

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
                (Bxh.colPhaLe, _RewardCard.phaLeW),
                (Bxh.colGiot, _RewardCard.giotW),
                (Bxh.colItem, _RewardCard.itemW),
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
                    onItemTap: () => b.openPool(r.itemTier),
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
    this.onItemTap,
  });

  /// Column widths (header and rows): Pha lê fits 3 digits + icon ("200"),
  /// the item column one 56 dp cell and its tier line.
  static const phaLeW = 68.0;
  static const giotW = 50.0;
  static const itemW = 96.0;

  /// The single item cell (Phú): one 56 dp mystery cell on its tier frame.
  static const itemCell = 56.0;

  final CharmBoardReward reward;
  final bool mine;
  final int? rank;
  final int itemCharm;

  /// Opens the tier's prize list. Each rank wins exactly ONE item of the
  /// tier, picked on the server among those the player does not own yet, so
  /// the cell is a "?" (Nhất) and the list shows what it can be.
  final VoidCallback? onItemTap;

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
      height: 80,
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
                phaLeW,
                amount(r.phaLe, Image.asset(Art.nav('pha_le'), width: 16)),
              ),
              cell(
                giotW,
                amount(r.giotHoa, Image.asset(Art.pet('giat_hoa'), width: 16)),
              ),
              cell(
                itemW,
                tier == null
                    ? Text(
                        '-',
                        style: AppText.title(
                          size: 14,
                          color: AppColors.textDisabled,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            key: Key('bxh-reward-items-${r.rankFrom}'),
                            width: itemCell,
                            height: itemCell,
                            child: GestureDetector(
                              key: Key('bxh-reward-mystery-${r.rankFrom}'),
                              behavior: HitTestBehavior.opaque,
                              onTap: onItemTap,
                              child: SeasonMysteryCell(
                                tier: tier,
                                size: itemCell,
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${Bxh.tierName(tier.key)} +$itemCharm',
                            key: Key('bxh-reward-tier-${r.rankFrom}'),
                            maxLines: 1,
                            softWrap: false,
                            style: AppText.caption(
                              size: 10,
                              color: _tierColor(tier),
                            ).copyWith(fontWeight: FontWeight.w800),
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

/// The season prize cell (Nhất/Phú): the prize is a random item the player
/// does not own yet, so no picture, a "?" on the tier frame. Rarity border
/// and light rarity background, a bold cream "?" stroked in the rarity
/// colour, one small sparkle top-right.
class SeasonMysteryCell extends StatelessWidget {
  const SeasonMysteryCell({super.key, required this.tier, this.size = 56});

  static const cream = Color(0xFFFFF8E7);

  final PetItemTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = PetItemPalette.of(tier);
    final legendary = tier == PetItemTier.huyenThoai;
    final mark = size / 2;
    final style = TextStyle(
      fontFamily: AppText.title(size: mark).fontFamily,
      fontSize: mark,
      fontWeight: FontWeight.w900,
      height: 1,
    );
    return Semantics(
      label: Bxh.mysteryA11y(Bxh.tierName(tier.key)),
      button: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(
          color: p.frame,
          borderRadius: BorderRadius.circular(size * 0.2),
          boxShadow: legendary
              ? [
                  BoxShadow(
                    color: p.frame.withValues(alpha: 0.45),
                    blurRadius: size * 0.22,
                  ),
                ]
              : null,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.fill,
            borderRadius: BorderRadius.circular(size * 0.14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '?',
                key: const Key('season-mystery-stroke'),
                style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = size * 0.08
                    ..strokeJoin = StrokeJoin.round
                    ..color = p.frame,
                ),
              ),
              Text(
                '?',
                key: const Key('season-mystery-mark'),
                style: style.copyWith(color: cream),
              ),
              Positioned(
                top: size * 0.04,
                right: size * 0.04,
                child: CustomPaint(
                  key: const Key('season-mystery-sparkle'),
                  size: Size.square(size * 0.22),
                  painter: _SparklePainter(fill: cream, edge: p.frame),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A four-point sparkle.
class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final k = r * 0.28;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k * 0.3, c.dy - k * 0.3, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k * 0.3, c.dy + k * 0.3, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k * 0.3, c.dy + k * 0.3, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k * 0.3, c.dy - k * 0.3, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22
        ..strokeJoin = StrokeJoin.round
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_SparklePainter old) =>
      old.fill != fill || old.edge != edge;
}

/// "Đồ pet {rarity} có thể nhận": every pet item of the tier, the ones the
/// player owns dimmed and tagged "Đã có", and what comes instead once all
/// are owned (the same dice as the server payout).
class _PoolSheet extends StatelessWidget {
  const _PoolSheet({required this.session, required this.tierKey});

  final ShopSession session;
  final String tierKey;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final b = s.board;
    final tier = PetItemTier.fromKey(tierKey);
    final items = [
      for (final item in s.e.petItems)
        if (item.tier == tier) item,
    ];
    final rarity = seasonTierName(tierKey);
    final fallback = seasonFallback(
      s.e,
      tierKey,
      period: b.config.periodKey,
      uid: s.accountUid ?? '',
    );
    final amount = fallback == null ? '-' : seasonAmountText(fallback);
    final allOwned =
        items.isNotEmpty && items.every((i) => s.petItemOwned(i.id) > 0);
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('bxh-pool-scrim'),
              behavior: HitTestBehavior.opaque,
              onTap: b.closePool,
              child: const ColoredBox(color: AppColors.bgOverlay),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              key: const Key('bxh-pool'),
              constraints: const BoxConstraints(maxHeight: 520),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: const BoxDecoration(
                color: AppColors.bgBase,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorderStrong,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Bxh.poolTitle(rarity),
                    key: const Key('bxh-pool-title'),
                    style: AppText.title(size: 19, weight: 800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allOwned
                        ? Bxh.poolAllOwned(rarity, amount)
                        : Bxh.poolDesc(amount),
                    key: Key(allOwned ? 'bxh-pool-all-owned' : 'bxh-pool-desc'),
                    style: AppText.caption(
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final item in items)
                            _poolRow(item, s.petItemOwned(item.id) > 0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ChunkyButton(
                      key: const Key('bxh-pool-close'),
                      label: Bxh.poolClose,
                      kind: ButtonKind.ghost,
                      fontSize: 16,
                      onPressed: b.closePool,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _poolRow(PetItemDef item, bool owned) {
    final row = Row(
      children: [
        PetItemIcon(
          itemId: item.id,
          slot: item.slot,
          tier: item.tier,
          size: 44,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.nameVi,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 14, weight: 800),
          ),
        ),
        if (owned)
          Container(
            key: Key('bxh-pool-owned-${item.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceBorder,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              Bxh.poolOwned,
              style: AppText.caption(
                size: 11,
                color: AppColors.textSecondary,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
    return SizedBox(
      key: Key('bxh-pool-item-${item.id}'),
      height: 56,
      child: owned
          ? Opacity(
              key: Key('bxh-pool-dim-${item.id}'),
              opacity: 0.45,
              child: row,
            )
          : row,
    );
  }
}

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
                          // Spec 6.1: the avatar in its frame, 96 dp.
                          _AvatarCircle(
                            key: const Key('bxh-profile-avatar'),
                            avatar: _avatarOf(s, entry),
                            name: entry.displayName,
                            radius: 48,
                            frameId: _frameOf(s, entry),
                            roomForFrame: true,
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
                      // Spec 6.1 hàng phụ: hidden on your own row.
                      if (s.board.canReport) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          key: const Key('bxh-report'),
                          behavior: HitTestBehavior.opaque,
                          onTap: s.board.openReport,
                          child: SizedBox(
                            height: 44,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.flag_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  Bxh.report,
                                  style: AppText.body(
                                    size: 14,
                                    weight: 800,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      // Spec 6.1: your own card swaps them for the frames.
                      if (entry.uid == s.accountUid && s.frames.offered) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          key: const Key('bxh-change-frame'),
                          behavior: HitTestBehavior.opaque,
                          onTap: s.frames.openPicker,
                          child: SizedBox(
                            height: 44,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.filter_frames_outlined,
                                  size: 18,
                                  color: AppColors.primaryBase,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ProfileText.changeFrame,
                                  style: AppText.body(
                                    size: 14,
                                    weight: 800,
                                    color: AppColors.primaryBase,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

/// "Báo cáo" on another player's profile: a reason (radio rows 48 dp), an
/// optional note, then "Gửi báo cáo" and a toast (spec 6.1).
class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.session});

  final ShopSession session;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _note = TextEditingController();
  ReportReason? _reason;
  var _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _busy) return;
    setState(() => _busy = true);
    final out = await widget.session.board.sendReport(reason, _note.text);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (out) {
      case ReportSend.sent:
        showGameToast(context, Bxh.reportSent);
      case ReportSend.already:
        showGameToast(context, Bxh.reportAlready);
      case ReportSend.failed:
        showGameToast(context, Bxh.reportFailed, error: true);
    }
  }

  /// "Ẩn người chơi này" swaps the form for the confirm (hide.confirm.*).
  var _confirmHide = false;

  Future<void> _hide() async {
    final name = await widget.session.board.hideProfile();
    if (name == null || !mounted) return;
    showGameToast(context, Bxh.hidden(name));
  }

  List<Widget> _confirm(String name) => [
    Text(
      Bxh.hideConfirmTitle(name),
      key: const Key('bxh-hide-confirm'),
      style: AppText.title(size: 19, weight: 800),
    ),
    const SizedBox(height: 6),
    Text(Bxh.hideConfirmBody, style: AppText.body(size: 14, weight: 700)),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ChunkyButton(
              key: const Key('bxh-hide-cancel'),
              label: Bxh.hideConfirmCancel,
              kind: ButtonKind.ghost,
              fontSize: 15,
              onPressed: () => setState(() => _confirmHide = false),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SkinButton(
            key: const Key('bxh-hide-ok'),
            label: Bxh.hideConfirmOk,
            height: 48,
            fontSize: 16,
            onPressed: _hide,
          ),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final b = widget.session.board;
    final canSend = _reason != null && !_busy;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: b.closeReport,
              child: const ColoredBox(color: AppColors.bgOverlay),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.viewInsetsOf(context).bottom,
            // The note field needs a Material above it.
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                key: const Key('bxh-report-sheet'),
                constraints: const BoxConstraints(maxHeight: 520),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                decoration: const BoxDecoration(
                  color: AppColors.bgBase,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBorderStrong,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_confirmHide)
                        ..._confirm(b.profile?.entry.displayName ?? '')
                      else ...[
                        Text(
                          Bxh.reportTitle,
                          style: AppText.title(size: 19, weight: 800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Bxh.reportIntro,
                          style: AppText.caption(
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final r in ReportReason.values)
                          GestureDetector(
                            key: Key('bxh-report-${r.name}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _busy
                                ? null
                                : () => setState(() => _reason = r),
                            child: SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  Icon(
                                    r == _reason
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    size: 22,
                                    color: r == _reason
                                        ? AppColors.primaryBase
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      r.label,
                                      style: AppText.body(
                                        size: 14,
                                        weight: 700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSunken,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: TextField(
                            key: const Key('bxh-report-note'),
                            controller: _note,
                            maxLength: reportNoteMax,
                            minLines: 2,
                            maxLines: 3,
                            style: AppText.body(size: 14, weight: 700),
                            decoration: InputDecoration(
                              counterText: '',
                              isCollapsed: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              hintText: Bxh.reportNoteHint,
                              hintStyle: AppText.body(
                                size: 13,
                                weight: 600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ChunkyButton(
                                  key: const Key('bxh-report-cancel'),
                                  label: Bxh.reportCancel,
                                  kind: ButtonKind.ghost,
                                  fontSize: 15,
                                  onPressed: _busy ? null : b.closeReport,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SkinButton(
                                key: const Key('bxh-report-send'),
                                label: Bxh.reportSend,
                                height: 48,
                                fontSize: 16,
                                enabled: canSend,
                                onPressed: canSend ? _send : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: GestureDetector(
                            key: const Key('bxh-hide'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _busy
                                ? null
                                : () => setState(() => _confirmHide = true),
                            child: SizedBox(
                              height: 44,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.visibility_off_outlined,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    Bxh.hide,
                                    style: AppText.body(
                                      size: 14,
                                      weight: 800,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

/// "Người chơi đã ẩn" (hide.list.*): the players this account hid,
/// each with "Bỏ ẩn". Opened from the board's link or a hidden row.
class _HiddenListSheet extends StatelessWidget {
  const _HiddenListSheet({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final b = session.board;
    final players = b.hidden.entries.toList()
      ..sort((x, y) => x.value.compareTo(y.value));
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: b.closeHiddenList,
              child: const ColoredBox(color: AppColors.bgOverlay),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              key: const Key('bxh-hidden-list'),
              constraints: const BoxConstraints(maxHeight: 462),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: const BoxDecoration(
                color: AppColors.bgBase,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorderStrong,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Bxh.hiddenListTitle,
                    style: AppText.title(size: 19, weight: 800),
                  ),
                  // Signed in, the account keeps the list on the server
                  // (player_prefs); signed out it is only on this device.
                  ...[
                    const SizedBox(height: 4),
                    Text(
                      session.prefs.onServer
                          ? Bxh.hiddenListNoteAccount
                          : Bxh.hiddenListNote,
                      key: const Key('bxh-hidden-list-note'),
                      style: AppText.caption(
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (players.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        Bxh.hiddenListEmpty,
                        style: AppText.body(size: 14, weight: 700),
                      ),
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final p in players)
                              SizedBox(
                                key: Key('bxh-hidden-${p.key}'),
                                height: 52,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.body(
                                          size: 14,
                                          weight: 800,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 96,
                                      height: 40,
                                      child: ChunkyButton(
                                        key: Key('bxh-unhide-${p.key}'),
                                        label: Bxh.unhide,
                                        kind: ButtonKind.ghost,
                                        fontSize: 14,
                                        onPressed: () async {
                                          await b.unhide(p.key);
                                          if (context.mounted) {
                                            showGameToast(
                                              context,
                                              Bxh.unhidden(p.value),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
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
              ? PetItemIcon(
                  key: Key('bxh-slot-item-${def.id}'),
                  itemId: def.id,
                  slot: def.slot,
                  tier: def.tier,
                  size: 64,
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
