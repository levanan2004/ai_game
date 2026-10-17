import 'package:flutter/material.dart';

import '../data/rating_board.dart';
import '../logic/avatar_frames.dart';
import '../logic/pet.dart' show petStageName;
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'game_toast.dart';
import 'pet_item_art.dart' show PetItemIcon;
import 'pet_shop_grid.dart' show PetFrameImage;
import 'player_avatar.dart';
import 'vip_badge.dart';

/// Texts of the profile card (Nhất, chu_tinh_nang_moi.md 3b, verbatim).
abstract final class ProfileText {
  static String day(int n) => 'Ngày thứ $n'; // profile.card.day
  static String charm(int n) => 'Mị lực $n'; // profile.card.charm
  static String rating(String score, int n) =>
      '★ $score · $n đánh giá'; // profile.card.rating
  static const ratingNone = 'Chưa đủ đánh giá'; // profile.card.rating_none
  static String rankCharm(int n) => 'Hạng Mị lực #$n'; // profile.card.rank_charm
  static const petTitle = 'Pet đang mang'; // profile.card.pet_title
  static const petNone = 'Chưa mang pet'; // profile.card.pet_none
  static const visit = 'Ghé tiệm'; // profile.card.btn_visit
  static const visitSoon = 'Sắp ra mắt'; // profile.card.btn_visit.soon_label
  static const visitToast =
      'Tính năng ghé tiệm đang được làm, chờ nhé!'; // .btn_visit.toast
  static const report = 'Báo cáo'; // profile.card.btn_report
  static const block = 'Chặn'; // profile.card.btn_block
  static const unblock = 'Bỏ chặn'; // profile.card.btn_unblock
  static const blockedNote = 'Bạn đã chặn người này'; // profile.card.blocked_note
  static const changeFrame = 'Đổi khung avatar'; // profile.card.btn_change_frame
  static const official = 'Tài khoản của Tiệm'; // profile.card.official
  static const loadFail = 'Không tải được hồ sơ'; // profile.card.load_fail
  static const retry = 'Thử lại'; // profile.card.btn_retry
}

/// Thẻ hồ sơ (spec 6.1) of a player seen in Tin thế giới or on Bảng Đánh giá: avatar in its
/// frame (96 dp), shop name, game day, Mị lực and board rank, the pet worn,
/// "Ghé tiệm" (coming soon), then Báo cáo / Chặn, or "Đổi khung avatar" on
/// your own card. The frame comes from the server (stamped on the message or
/// read from player_avatars), never from the other player's app.
class PlayerProfileCard extends StatefulWidget {
  const PlayerProfileCard({
    super.key,
    required this.session,
    required this.uid,
    required this.name,
    required this.avatar,
    this.frameId = '',
    this.vip = 0,
    this.official = false,
    this.onReport,
    this.onBlock,
    this.onUnblock,
    required this.onClose,
  });

  final ShopSession session;
  final String uid;
  final String name;
  final String avatar;
  final String frameId;

  /// The VIP tier stamped on the chat message (0 none); player_avatars wins
  /// once read.
  final int vip;
  final bool official;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final VoidCallback? onUnblock;
  final VoidCallback onClose;

  /// The avatar's diameter on the card (spec 6.1).
  static const avatarSize = 96.0;

  @override
  State<PlayerProfileCard> createState() => _PlayerProfileCardState();
}

class _PlayerProfileCardState extends State<PlayerProfileCard> {
  PublicProfile? _profile;
  RatingEntry? _rating;
  bool _loading = true;
  bool _failed = false;

  ShopSession get _s => widget.session;
  bool get _own => widget.uid == _s.accountUid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    // Frame and VIP tier (player_avatars), with the profile.
    await _s.frames.prefetch([widget.uid]);
    final p = await _s.frames.profile(widget.uid);
    // Bảng Đánh giá row (server-written), for the ★ cell.
    final rating = await _s.ratingBoard.entryOf(widget.uid);
    if (!mounted) return;
    setState(() {
      _profile = p;
      _rating = rating;
      _loading = false;
      _failed = p == null && _s.frames.source != null;
    });
  }

  int? get _rank {
    for (final r in _s.board.rows) {
      if (r.entry.uid == widget.uid) return r.rank;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final blocked = !_own && _s.board.isHidden(widget.uid);
    final frame = _own ? _s.frames.equipped : widget.frameId;
    const r = PlayerProfileCard.avatarSize / 2;
    // A Stack filling its parent (put it in a Positioned.fill).
    return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('profile-card-scrim'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: const ColoredBox(color: AppColors.bgOverlay),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              key: const Key('profile-card'),
              constraints: const BoxConstraints(maxHeight: 520),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(
                              frame.isEmpty
                                  ? 0
                                  : PlayerAvatar.frameSide(r) / 2 - r,
                            ),
                            child: PlayerAvatar(
                              key: const Key('profile-card-avatar'),
                              avatar: blocked ? '' : widget.avatar,
                              name: widget.name,
                              radius: r,
                              frameId: blocked ? '' : frame,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _head()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_loading)
                        _skeleton()
                      else if (_failed)
                        _error()
                      else
                        ..._body(),
                      const SizedBox(height: 10),
                      _visit(),
                      const SizedBox(height: 4),
                      _actions(blocked),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
    );
  }

  /// The VIP tier shown (spec 4.3): own from the wallet, others from
  /// player_avatars (or the chat stamp before it is read). None if blocked.
  int get _vip {
    if (_own) return _s.vip.level;
    if (_s.board.isHidden(widget.uid)) return 0;
    final read = _s.frames.vipOf(widget.uid);
    return read > 0 ? read : widget.vip;
  }

  Widget _head() {
    final day = _profile?.day;
    final vip = _vip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                widget.name,
                key: const Key('profile-card-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title(
                  size: 20,
                  weight: 800,
                  color: vipNameColor(vip),
                ),
              ),
            ),
            if (vip > 0) ...[
              const SizedBox(width: 4),
              GestureDetector(
                key: const Key('profile-card-vip'),
                behavior: HitTestBehavior.opaque,
                // Your own badge opens Màn VIP (spec 4.4).
                onTap: _own && _s.vip.offered ? _s.vip.openScreen : null,
                child: VipBadge(level: vip, size: 24),
              ),
            ],
          ],
        ),
        if (vip >= 10)
          const VipTitleLine(key: Key('profile-card-vip-title'), level: 10, size: 11.5),
        if (widget.official)
          Container(
            key: const Key('profile-card-official'),
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              ProfileText.official,
              style: AppText.caption(
                size: 11,
                color: AppColors.primaryPressed,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        if (day != null && day > 0)
          Text(
            ProfileText.day(day),
            key: const Key('profile-card-day'),
            style: AppText.caption(size: 12, color: AppColors.textSecondary),
          ),
      ],
    );
  }

  List<Widget> _body() {
    final entry = _profile?.entry;
    final rank = _rank;
    final pet = entry == null || entry.petId.isEmpty
        ? null
        : _s.e.pet(entry.petId);
    return [
      Row(
        children: [
          if (entry != null)
            _stat(ProfileText.charm(entry.charm), const Key('profile-card-charm')),
          _stat(
            switch (_rating) {
              final r? when r.v >= _s.ratingBoard.config.minToRank && r.sortKey > 0 =>
                ProfileText.rating(ratingScoreText(r.score), r.v),
              _ => ProfileText.ratingNone,
            },
            const Key('profile-card-rating'),
          ),
          if (rank != null)
            _stat(ProfileText.rankCharm(rank), const Key('profile-card-rank')),
        ],
      ),
      const SizedBox(height: 10),
      Text(ProfileText.petTitle, style: AppText.title(size: 14, weight: 800)),
      const SizedBox(height: 4),
      if (entry == null || pet == null)
        Text(
          ProfileText.petNone,
          key: const Key('profile-card-pet-none'),
          style: AppText.caption(size: 12, color: AppColors.textSecondary),
        )
      else
        Container(
          key: const Key('profile-card-pet'),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              PetFrameImage(id: entry.petId, stage: entry.stage, size: 56),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.nameVi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title(size: 15, weight: 800),
                    ),
                    Text(
                      petStageName(entry.stage),
                      style: AppText.caption(
                        size: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              for (final itemId in entry.worn.values) ...[
                const SizedBox(width: 4),
                if (_s.e.petItem(itemId) case final item?)
                  PetItemIcon(
                    itemId: item.id,
                    slot: item.slot,
                    tier: item.tier,
                    size: 36,
                  ),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _stat(String text, Key key) => Expanded(
    child: Container(
      key: key,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: AppText.body(size: 13, weight: 800),
      ),
    ),
  );

  Widget _skeleton() => Column(
    key: const Key('profile-card-loading'),
    children: [
      Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Container(
                height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ],
  );

  Widget _error() => Column(
    key: const Key('profile-card-error'),
    children: [
      Text(ProfileText.loadFail, style: AppText.body(size: 14, weight: 700)),
      TextButton(
        key: const Key('profile-card-retry'),
        onPressed: _load,
        child: Text(ProfileText.retry),
      ),
    ],
  );

  Widget _visit() => GestureDetector(
    key: const Key('profile-card-visit'),
    behavior: HitTestBehavior.opaque,
    onTap: () => showGameToast(context, ProfileText.visitToast),
    child: Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ProfileText.visit,
            style: AppText.button(size: 16, color: AppColors.textDisabled),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ProfileText.visitSoon,
              style: AppText.caption(
                size: 10,
                color: AppColors.textSecondary,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _action(String label, Key key, IconData icon, VoidCallback? onTap,
      {Color color = AppColors.textSecondary}) =>
      GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(label, style: AppText.body(size: 14, weight: 800, color: color)),
            ],
          ),
        ),
      );

  Widget _actions(bool blocked) {
    if (_own) {
      if (!_s.frames.offered) return const SizedBox.shrink();
      return Center(
        child: _action(
          ProfileText.changeFrame,
          const Key('profile-card-change-frame'),
          Icons.filter_frames_outlined,
          _s.frames.openPicker,
          color: AppColors.primaryBase,
        ),
      );
    }
    if (blocked) {
      return Row(
        children: [
          Expanded(
            child: Text(
              ProfileText.blockedNote,
              key: const Key('profile-card-blocked'),
              style: AppText.body(size: 13, weight: 700),
            ),
          ),
          _action(
            ProfileText.unblock,
            const Key('profile-card-unblock'),
            Icons.undo,
            widget.onUnblock,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (widget.onReport != null)
          _action(
            ProfileText.report,
            const Key('profile-card-report'),
            Icons.flag_outlined,
            widget.onReport,
          ),
        if (!widget.official && widget.onBlock != null)
          _action(
            ProfileText.block,
            const Key('profile-card-block'),
            Icons.block,
            widget.onBlock,
            color: AppColors.statusDanger,
          ),
      ],
    );
  }
}
