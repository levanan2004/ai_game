import 'package:flutter/material.dart';

import '../data/rating_board.dart';
import '../data/titles.dart';
import '../logic/avatar_frames.dart';
import '../logic/price_format.dart' show coinFull;
import '../logic/pet.dart' show petStageName;
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'game_toast.dart';
import 'pet_item_art.dart' show PetItemIcon;
import 'pet_shop_grid.dart' show PetFrameImage;
import 'player_avatar.dart';
import 'title_plate.dart';
import 'vip_badge.dart';
import '../data/chat_frames.dart';
import 'chat_bubble.dart';

/// Texts of the profile card (Nhất, chu_tinh_nang_moi.md 3b, verbatim).
/// Phú: the "×n" badge of a held title, #F2C94C 12 sp bold.
const _badgeGold = Color(0xFFF2C94C);
const _badgeBg = Color(0xFF2E5E3D);
const _ink = Color(0xFF2E5E3D);

abstract final class ProfileText {
  static String day(int n) => 'Ngày thứ $n'; // profile.card.day
  static String charm(int n) => 'Mị lực $n'; // profile.card.charm
  static String rating(String score, int n) =>
      '★ $score · $n đánh giá'; // profile.card.rating
  static const ratingNone = 'Chưa đủ đánh giá'; // profile.card.rating_none
  static String rankCharm(int n) =>
      'Hạng Mị lực #$n'; // profile.card.rank_charm
  static const petTitle = 'Pet đang mang'; // profile.card.pet_title
  static const petNone = 'Chưa mang pet'; // profile.card.pet_none
  static const visit = 'Ghé tiệm'; // profile.card.btn_visit
  static const visitSoon = 'Sắp ra mắt'; // profile.card.btn_visit.soon_label
  static const visitToast =
      'Tính năng ghé tiệm đang được làm, chờ nhé!'; // .btn_visit.toast
  static const report = 'Báo cáo'; // profile.card.btn_report
  static const block = 'Chặn'; // profile.card.btn_block
  static const unblock = 'Bỏ chặn'; // profile.card.btn_unblock
  static const blockedNote =
      'Bạn đã chặn người này'; // profile.card.blocked_note
  static const changeFrame =
      'Đổi khung avatar'; // profile.card.btn_change_frame
  static const official = 'Tài khoản của Tiệm'; // profile.card.official
  static const loadFail = 'Không tải được hồ sơ'; // profile.card.load_fail
  static const retry = 'Thử lại'; // profile.card.btn_retry
  static const title = 'Hồ sơ tiệm'; // profile.title
  static const statCustomers = 'Khách đã bán'; // profile.stat.customers
  static const statStars = 'Sao trung bình'; // profile.stat.avg_stars
  static const statChampion = 'Mùa giữ hạng 1'; // profile.stat.champion_seasons
  static const none = '—'; // profile.records.none
  static const editShopName = 'Sửa tên tiệm'; // profile.a11y.edit_shop_name
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

  /// The title row opened for its detail ('' none) and a pin in flight.
  String _openTitle = '';
  bool _pinning = false;

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
    if (_own && _s.frames.chatOffered) await _s.frames.refreshChat();
    // Bảng Đánh giá row (server-written), for the ★ cell.
    final rating = await _s.ratingBoard.entryOf(widget.uid);
    if (!mounted) return;
    setState(() {
      _profile = p;
      _rating = rating;
      _loading = false;
      _failed = p == null && _s.frames.source != null;
    });
    if (_own && p != null) await _announceUnlocks(p.titles);
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
            // Side padding inside the scroll view, so a 360 dp milestone plate
            // (Phú) may use the card's full width.
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
            decoration: const BoxDecoration(
              color: AppColors.bgBase,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    // Phú spec 2.2: header 48, ‹ left, "Hồ sơ tiệm" centred.
                    SizedBox(
                      key: const Key('profile-card-header'),
                      width: double.infinity,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            ProfileText.title,
                            style: AppText.title(
                              size: 18,
                              weight: 800,
                              color: _ink,
                            ),
                          ),
                          Positioned(
                            left: -8,
                            child: GestureDetector(
                              key: const Key('profile-card-back'),
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onClose,
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.chevron_left_rounded,
                                  size: 26,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(
                            frame.isEmpty
                                ? 0
                                : PlayerAvatar.frameSide(r) / 2 - r,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              PlayerAvatar(
                                key: const Key('profile-card-avatar'),
                                avatar: blocked ? '' : widget.avatar,
                                name: widget.name,
                                radius: r,
                                frameId: blocked ? '' : frame,
                              ),
                              // Own: ✎ opens the avatar picker (moved here
                              // from Cài đặt, Phú spec 2.2).
                              if (_own)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: _pencil(
                                    const Key('profile-card-avatar-edit'),
                                    _s.openAvatarPicker,
                                  ),
                                ),
                            ],
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
                    if (!_own) ...[_visit(), const SizedBox(height: 4)],
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
    if (_own) return _s.vip.shownLevel;
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
                child: VipBadge(level: vip, size: 32),
              ),
            ],
            if (_own) ...[
              const SizedBox(width: 4),
              Semantics(
                label: ProfileText.editShopName,
                button: true,
                child: _pencil(const Key('profile-card-rename'), _s.openRename),
              ),
            ],
          ],
        ),
        if (vip >= 10)
          const VipTitleLine(
            key: Key('profile-card-vip-title'),
            level: 10,
            size: 11.5,
          ),
        if (_titles.wearing case final id when id.isNotEmpty)
          Padding(
            key: const Key('profile-card-wearing'),
            padding: const EdgeInsets.only(top: 2),
            // Phú 20:50: next to names a compact chip.
            child: Align(
              alignment: Alignment.centerLeft,
              child: TitleChip(id: id, name: _s.e.titles.nameOf(id)),
            ),
          ),
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

  PlayerTitles get _titles => _profile?.titles ?? PlayerTitles.empty;

  /// The season clock of [id]'s board (for "mùa {month}/{year}").
  SeasonClock? _clockOf(String id) => id == TitleIds.rating
      ? _s.ratingBoard.config.clock
      : id == TitleIds.charm
      ? _s.board.config.clock
      : null;

  Future<void> _pin(String id, String name) async {
    if (_pinning) return;
    setState(() => _pinning = true);
    final r = await _s.frames.pinTitle(id);
    if (!mounted) return;
    _pinning = false;
    if (r == TitlePinResult.done && id.isNotEmpty) {
      showGameToast(context, TitleText.wearToast(name));
    }
    await _load();
  }

  /// Milestones reached that this device had not shown yet: their toast
  /// (title.customers.unlocked_toast, or retro_toast for old customers) and
  /// one sparkle burst; then they go in the device's seen record.
  Future<void> _announceUnlocks(PlayerTitles t) async {
    final uid = widget.uid;
    final store = _s.progressStore;
    final seen = await store.titlesSeen(uid);
    final fresh = newUnlocks(_s.e.titles, t, seen);
    if (fresh.isEmpty || !mounted) return;
    setState(() => _burst.addAll(fresh.map((u) => u.tier.id)));
    await store.saveTitlesSeen(uid, {...seen, ...fresh.map((u) => u.tier.id)});
    // One toast after the other (each stays 2 s).
    for (var i = 0; i < fresh.length; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 2200));
      if (!mounted) return;
      final u = fresh[i];
      final n = coinFull(u.tier.threshold);
      showGameToast(
        context,
        u.retro
            ? TitleText.retroToast(n, u.tier.name)
            : TitleText.unlockedToast(n, u.tier.name),
      );
    }
  }

  /// All 5 cells shown ("Xem tất cả").
  bool _allTitles = false;

  /// Milestone cells playing their one sparkle burst.
  final Set<String> _burst = {};

  /// Tủ danh hiệu (Phú): one cell per title, the two champion titles then
  /// the customers-served milestones. Champion: held = colour with every
  /// effect and "×n"; held before = 70 %, no effects, "Đã từng giữ {n} mùa";
  /// never = grey 40 % with a lock. Milestone: reached = colour, "Vĩnh viễn"
  /// (one sparkle burst the first time this device shows it); not reached =
  /// grey 40 % with the progress bar. Tap a cell for its detail and, on your
  /// own card, wear / take off.
  ///
  /// Folded by default: only the titles held now, "{n} danh hiệu" and "Xem
  /// tất cả" (Nhất's profile.titles.*) open the 5 cells, so Báo cáo / Chặn
  /// stay in reach.
  List<Widget> _titleSection() {
    final t = _titles;
    final all = _s.e.titles.cabinet;
    final held = [
      for (final id in all)
        if (t.holds(id)) id,
    ];
    final ids = _allTitles ? all : held;
    return [
      const SizedBox(height: 10),
      Row(
        children: [
          Text(
            TitleText.sectionTitles,
            style: AppText.title(size: 14, weight: 800),
          ),
          const SizedBox(width: 6),
          Text(
            TitleText.count(held.length),
            key: const Key('profile-card-title-count'),
            style: AppText.caption(size: 11.5, color: AppColors.textSecondary),
          ),
          const Spacer(),
          if (!_allTitles)
            TextButton(
              key: const Key('profile-card-title-see-all'),
              onPressed: () => setState(() => _allTitles = true),
              child: Text(
                TitleText.seeAll,
                style: AppText.caption(
                  size: 12.5,
                  color: AppColors.primaryPressed,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      if (ids.isEmpty)
        Text(
          _own ? TitleText.empty : TitleText.emptyOther,
          key: const Key('profile-card-title-empty'),
          style: AppText.caption(size: 11.5, color: AppColors.textSecondary),
        ),
      if (_own && t.note != MilestoneNote.none)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            t.note == MilestoneNote.short
                ? TitleText.customersNotCounted
                : TitleText.customersDailyCap,
            key: const Key('profile-card-title-note'),
            style: AppText.caption(size: 11.5, color: AppColors.textSecondary),
          ),
        ),
      for (final id in ids) _titleCell(t, id),
    ];
  }

  Widget _titleCell(PlayerTitles t, String id) {
    final config = _s.e.titles;
    final tier = config.milestone(id);
    final name = config.nameOf(id);
    final n = t.timesWon(id);
    final held = t.holds(id);
    final reached = tier != null && (t.stats[id]?.permanent ?? false);
    final look = tier != null
        ? (reached ? TitleLook.normal : TitleLook.locked)
        : held
        ? TitleLook.normal
        : n > 0
        ? TitleLook.faded
        : TitleLook.locked;
    final open = _openTitle == id;
    final caption = AppText.caption(size: 11.5, color: AppColors.textSecondary);
    final wearBtn = _own && held
        ? TextButton(
            key: Key('profile-card-title-wear-$id'),
            onPressed: _pinning
                ? null
                : () => _pin(t.wearing == id ? '' : id, name),
            child: Text(t.wearing == id ? TitleText.unwear : TitleText.wear),
          )
        : null;
    return GestureDetector(
      key: Key('profile-card-title-$id'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _openTitle = open ? '' : id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (tier != null)
                  // Phú 20:50: milestone plates 360 dp wide.
                  WideTitlePlate(
                    plate: (w) => TitlePlate(
                      key: Key('profile-card-title-plate-$id'),
                      id: id,
                      name: name,
                      width: w,
                      look: look,
                      burst: _burst.contains(id),
                    ),
                  )
                else
                  TitlePlate(
                    key: Key('profile-card-title-plate-$id'),
                    id: id,
                    name: name,
                    look: look,
                    burst: _burst.contains(id),
                  ),
                if (tier == null && held && n > 0)
                  Positioned(
                    right: 8,
                    top: 4,
                    child: Container(
                      // Phú 20:50: #2E5E3D, radius 8, text #F2C94C.
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        TitleText.timesBadge(n),
                        key: Key('profile-card-title-times-$id'),
                        style: AppText.caption(
                          size: 12,
                          weight: 800,
                          color: _badgeGold,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                if (tier == null && look == TitleLook.locked)
                  const Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.lock_rounded,
                        key: Key('profile-card-title-lock'),
                        size: 22,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            if (tier != null && !reached)
              _progress(id, tier, t.customers)
            else
              Text(
                tier != null
                    ? TitleText.permanent
                    : t.wearing == id
                    ? TitleText.wearing
                    : held
                    ? TitleText.held
                    : n > 0
                    ? TitleText.timesWon(n)
                    : TitleText.locked,
                key: Key('profile-card-title-state-$id'),
                style: caption,
              ),
            if (open) ...[
              if (tier != null) ...[
                Text(
                  reached
                      ? TitleText.customersDesc(coinFull(tier.threshold))
                      : TitleText.customersLockedHint(coinFull(tier.threshold)),
                  key: Key('profile-card-title-detail-$id'),
                  style: caption,
                ),
                Text(TitleText.customersOnline, style: caption),
              ] else ...[
                if (titleDetail(id, t, _clockOf(id)) case final d
                    when d.isNotEmpty && n > 0)
                  Text(
                    d,
                    key: Key('profile-card-title-detail-$id'),
                    style: caption,
                  ),
                if (held && n > 0) Text(TitleText.timesWon(n), style: caption),
                if (n == 0)
                  Text(
                    id == TitleIds.rating
                        ? TitleText.lockedHintRating
                        : TitleText.lockedHintCharm,
                    key: Key('profile-card-title-hint-$id'),
                    style: caption,
                  )
                else if (_own && !held)
                  Text(TitleText.wearLocked, style: caption),
              ],
              ?wearBtn,
            ],
          ],
        ),
      ),
    );
  }

  /// Phú: 6 dp bar, radius 3, #E6DFC8 behind #3F7F52; "Bán cho
  /// {current}/{target} khách" 12 sp #2E5E3D.
  Widget _progress(String id, MilestoneTier tier, int customers) {
    final current = customers.clamp(0, tier.threshold);
    return Column(
      key: Key('profile-card-title-progress-$id'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: current / tier.threshold,
              backgroundColor: const Color(0xFFE6DFC8),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF3F7F52)),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          TitleText.customersProgress(
            coinFull(current),
            coinFull(tier.threshold),
          ),
          style: AppText.caption(size: 12, color: const Color(0xFF2E5E3D)),
        ),
      ],
    );
  }

  List<Widget> _body() {
    final entry = _profile?.entry;
    final titles = _profile?.titles;
    final pet = entry == null || entry.petId.isEmpty
        ? null
        : _s.e.pet(entry.petId);
    return [
      // Phú spec 2.4: Khách đã bán | Sao trung bình | Mùa giữ hạng 1.
      Row(
        children: [
          _stat(
            coinFull(titles?.customers ?? 0),
            ProfileText.statCustomers,
            const Key('profile-card-customers'),
          ),
          _stat(
            switch (_rating) {
              final r?
                  when r.v >= _s.ratingBoard.config.minToRank &&
                      r.sortKey > 0 =>
                '${ratingScoreText(r.score)} ★',
              _ => ProfileText.none,
            },
            ProfileText.statStars,
            const Key('profile-card-rating'),
          ),
          _stat(
            '${(titles?.timesWon(TitleIds.rating) ?? 0) + (titles?.timesWon(TitleIds.charm) ?? 0)}',
            ProfileText.statChampion,
            const Key('profile-card-champion'),
          ),
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
      ..._titleSection(),
      if (_own && _s.frames.chatOffered) ..._chatFrameSection(),
    ];
  }

  /// Khung tin nhắn (block v2 chatBubbleFrames, Nhất's chat_frame.*): your
  /// own card only. VIP frames open at the highest VIP reached; title frames
  /// only while holding the title. The server checks again (chatFrameEquip).
  List<Widget> _chatFrameSection() {
    final f = _s.frames;
    final cfg = f.chatConfig;
    final vipMax = _s.vip.status?.max ?? 0;
    final hidden = _s.vip.badgeHidden;
    final chosen = cfg.byId(f.chat.chosen) != null
        ? f.chat.chosen
        : cfg.defaultId;
    final lost = f.chat.lostTitle;
    final caption = AppText.caption(size: 11.5, color: AppColors.textSecondary);
    return [
      const SizedBox(height: 12),
      Text(
        ChatFrameText.section,
        key: const Key('profile-card-chat-frames'),
        style: AppText.title(size: 14, weight: 800),
      ),
      if (lost.isNotEmpty)
        Text(
          ChatFrameText.lostTitleNote(_s.e.titles.nameOf(lost)),
          key: const Key('profile-card-chat-frame-lost'),
          style: caption,
        ),
      if (hidden && (cfg.byId(chosen)?.vip ?? 0) > 0)
        Text(
          ChatFrameText.hiddenVipNote,
          key: const Key('profile-card-chat-frame-hidden'),
          style: caption,
        ),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final frame in cfg.frames)
              _chatFrameCell(
                frame,
                using: frame.id == chosen,
                open:
                    frame.vip <= vipMax &&
                    (frame.title.isEmpty || _titles.holds(frame.title)),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _chatFrameCell(
    ChatFrame frame, {
    required bool using,
    required bool open,
  }) {
    final name = ChatFrameText.name(frame.id);
    final caption = AppText.caption(size: 10.5, color: AppColors.textSecondary);
    return Container(
      key: Key('profile-card-chat-frame-${frame.id}'),
      width: 140,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: open ? 1 : 0.4,
            child: ChatBubble(frameId: frame.id, text: name),
          ),
          const SizedBox(height: 2),
          if (using)
            Text(
              ChatFrameText.equipped,
              key: Key('profile-card-chat-frame-using-${frame.id}'),
              style: caption.copyWith(
                color: AppColors.primaryPressed,
                fontWeight: FontWeight.w800,
              ),
            )
          else if (open)
            SizedBox(
              height: 30,
              child: TextButton(
                key: Key('profile-card-chat-frame-equip-${frame.id}'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: _s.frames.busy ? null : () => _equipChat(frame.id),
                child: Text(
                  ChatFrameText.equip,
                  style: AppText.caption(
                    size: 11.5,
                    color: AppColors.primaryPressed,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            )
          else
            Text(
              frame.vip > 0
                  ? ChatFrameText.lockedVip(frame.vip)
                  : ChatFrameText.lockedTitle(_s.e.titles.nameOf(frame.title)),
              key: Key('profile-card-chat-frame-locked-${frame.id}'),
              style: caption,
            ),
        ],
      ),
    );
  }

  Future<void> _equipChat(String id) async {
    final r = await _s.frames.equipChat(id);
    if (!mounted) return;
    if (r == FrameEquipResult.done) {
      showGameToast(context, ChatFrameText.equipToast);
    }
    setState(() {});
  }

  Widget _stat(String value, String label, Key key) => Expanded(
    child: Container(
      key: key,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppText.title(size: 18, weight: 800, color: _ink),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption(
              size: 11,
              color: AppColors.textSecondary,
            ).copyWith(height: 1.1),
          ),
        ],
      ),
    ),
  );

  /// A 28 dp round ✎ (white, border surfaceBorder, icon 16 primaryPressed).
  Widget _pencil(Key key, VoidCallback onTap) => GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: const Icon(Icons.edit, size: 16, color: AppColors.primaryPressed),
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

  Widget _action(
    String label,
    Key key,
    IconData icon,
    VoidCallback? onTap, {
    Color color = AppColors.textSecondary,
  }) => GestureDetector(
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
