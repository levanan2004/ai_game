import 'package:flutter/material.dart';

import '../data/avatar_frames.dart';
import '../logic/avatar_frames.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'game_toast.dart';
import 'player_avatar.dart';
import 'ui_skin.dart';

/// Texts of the frame sheet F1 (Nhất, chu_tinh_nang_moi.md 3a, verbatim).
abstract final class FrameText {
  static const title = 'Khung avatar'; // frame.title
  static const equip = 'Dùng khung này'; // frame.equip_btn
  static const equipped = 'Đang dùng'; // frame.equipped_btn
  static const equippedToast = 'Đã đổi khung avatar.'; // frame.equipped.toast
  static String lockedVip(int level) => 'Mở ở VIP $level'; // frame.locked.vip
  static const lockedSeason =
      'Thưởng top 3 mùa (giữ vĩnh viễn)'; // frame.locked.season
  static String lockedEvent(String event) =>
      'Sự kiện $event'; // frame.locked.event
  static const lockedBuy = 'Mua bằng Pha lê'; // frame.locked.buy
  static const defaultNote =
      'Khung mặc định khi đăng nhập'; // frame.default_note
  static const empty =
      'Bạn chưa có khung nào. Lên VIP, đua top mùa hoặc tham gia sự kiện '
      'để nhận khung nhé!'; // frame.empty
  static const vipNote =
      'Khung VIP chỉ để trang trí, không cộng Mị lực.'; // frame.vip.note
  static const seasonKeptNote =
      'Khung mùa bạn đã nhận được giữ mãi, kể cả khi sang mùa sau.';
  // frame.season.kept_note

  /// Spec 0.4 "Lỗi mạng" (no frame-specific failure text).
  static const failed = 'Mất kết nối rồi. Thử lại nhé!';

  /// `frame.name.{id}`. vuong_mien_mua is "Vương Miện Mùa {n}": [season] is
  /// the season number when known.
  static String name(String id, {int? season}) => switch (id) {
    'la_non' => 'Lá Non',
    'hoa_dao' => 'Hoa Đào',
    'vip_la_xanh' => 'VIP Lá xanh',
    'vip_hoa_dao' => 'VIP Hoa đào',
    'vip_bac' => 'VIP Bạc',
    'vip_vang' => 'VIP Vàng',
    'vip_ngoc_luc_bao' => 'VIP Ngọc lục bảo',
    'vuong_mien_mua' =>
      season == null ? 'Vương Miện Mùa' : 'Vương Miện Mùa $season',
    _ => id,
  };

  /// How a locked frame opens ("Mở ở VIP 3", "Sự kiện Tết", ...).
  static String locked(AvatarFrameDef f) => switch (f.source) {
    FrameOrigin.vip =>
      f.vipLevel == null ? lockedVip(0) : lockedVip(f.vipLevel!),
    FrameOrigin.seasonTop => lockedSeason,
    FrameOrigin.event => lockedEvent(f.event),
    FrameOrigin.buy => lockedBuy,
    FrameOrigin.standard => defaultNote,
  };

  /// The line under an owned frame's name.
  static String ownedNote(AvatarFrameDef f) => switch (f.source) {
    FrameOrigin.standard => defaultNote,
    FrameOrigin.vip => vipNote,
    FrameOrigin.seasonTop => seasonKeptNote,
    FrameOrigin.event => lockedEvent(f.event),
    FrameOrigin.buy => '',
  };
}

/// The season number in a period key like "season-3" (null otherwise).
int? seasonNumberOf(String periodKey) {
  final m = RegExp(r'(\d+)$').firstMatch(periodKey);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// "Khung avatar" (spec 3.4, F1): a 96 dp preview of your own avatar in the
/// selected frame with its name and how it opens, a 4-column grid of 72 dp
/// cells (worn: primary ring + ✓; locked: 50% + lock + how it opens) and
/// "Dùng khung này" / "Đang dùng". Wearing a frame goes through the server,
/// which checks you own it.
class AvatarFrameSheet extends StatelessWidget {
  const AvatarFrameSheet({super.key, required this.session});

  final ShopSession session;

  static const cell = 72.0;

  @override
  Widget build(BuildContext context) {
    final f = session.frames;
    final config = f.config;
    final owned = f.owned;
    final sel = config.byId(f.selected);
    final season = seasonNumberOf(session.board.period);
    final ownsSel = sel != null && owned.contains(sel.id);
    final worn = sel != null && f.equipped == sel.id;
    const r = 48.0;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('frame-sheet-scrim'),
            behavior: HitTestBehavior.opaque,
            onTap: f.closePicker,
            child: const ColoredBox(color: AppColors.bgOverlay),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            key: const Key('frame-sheet'),
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            decoration: const BoxDecoration(
              color: AppColors.bgBase,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorderStrong,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    FrameText.title,
                    style: AppText.title(size: 19, weight: 800),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: PlayerAvatar.frameSide(r),
                    height: PlayerAvatar.frameSide(r),
                    child: Center(
                      child: PlayerAvatar(
                        key: const Key('frame-sheet-preview'),
                        avatar: session.publishedAvatar,
                        name: session.state.shopName ?? '',
                        radius: r,
                        frameId: sel?.id ?? '',
                      ),
                    ),
                  ),
                  if (sel != null) ...[
                    Text(
                      FrameText.name(sel.id, season: season),
                      key: const Key('frame-sheet-name'),
                      style: AppText.title(size: 16, weight: 800),
                    ),
                    Text(
                      ownsSel
                          ? FrameText.ownedNote(sel)
                          : FrameText.locked(sel),
                      key: const Key('frame-sheet-source'),
                      textAlign: TextAlign.center,
                      style: AppText.caption(
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final frame in config.frames)
                            _cell(
                              frame,
                              owned.contains(frame.id),
                              f.equipped == frame.id,
                              f.selected == frame.id,
                              f,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (owned.length <= config.ownedBy().length) ...[
                    const SizedBox(height: 6),
                    Text(
                      FrameText.empty,
                      key: const Key('frame-sheet-empty'),
                      textAlign: TextAlign.center,
                      style: AppText.caption(
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SkinButton(
                    key: const Key('frame-sheet-equip'),
                    label: worn ? FrameText.equipped : FrameText.equip,
                    enabled: ownsSel && !worn && !f.busy,
                    onPressed: () async {
                      final res = await f.equip(sel!.id);
                      if (!context.mounted) return;
                      switch (res) {
                        case FrameEquipResult.done:
                          showGameToast(context, FrameText.equippedToast);
                        case FrameEquipResult.notOwned:
                          break;
                        case FrameEquipResult.failed:
                          showGameToast(context, FrameText.failed, error: true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(
    AvatarFrameDef frame,
    bool owned,
    bool worn,
    bool selected,
    AvatarFramesController f,
  ) {
    final art = Image.asset(
      Art.avatarFrame(frame.id),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    return GestureDetector(
      key: Key('frame-cell-${frame.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => f.select(frame.id),
      child: Container(
        width: cell,
        height: cell,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: worn || selected
                ? AppColors.primaryBase
                : AppColors.surfaceBorder,
            width: worn || selected ? AppBorder.thick : AppBorder.thin,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: owned
                  ? art
                  : Opacity(
                      key: Key('frame-cell-locked-${frame.id}'),
                      opacity: 0.5,
                      child: art,
                    ),
            ),
            if (!owned)
              Center(
                child: ArtImage(
                  Art.phucLoi('o_khoa'),
                  size: 28,
                  fallback: const Icon(Icons.lock, size: 22),
                ),
              ),
            if (worn)
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.check_circle,
                  key: Key('frame-cell-worn'),
                  size: 18,
                  color: AppColors.primaryBase,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
