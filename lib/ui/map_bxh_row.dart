import 'package:flutter/material.dart';

import '../logic/charm_board_controller.dart';
import '../logic/shop_session.dart';
import '../logic/pet.dart' show strayCatDay;
import '../theme/tokens.dart';
import 'art.dart';
import 'charm_board_screen.dart' show Bxh;
import 'common.dart';
import 'map_popup.dart';

/// The "Xếp hạng Mị lực" row of the map, between Tiệm Chậu Hoa and Vườn nhà
/// (SPEC_gia_ban_va_bxh_ban_do.md section 3). The whole row opens the board.
///
/// The second line is a status chip, not a sentence: "Hạng 12" (colour by
/// shield band) with "{n} Mị lực" after it, "100+", "Chưa xếp hạng",
/// "Đăng nhập" with a lock, "Đang chốt bảng" with an hourglass; a red dot on
/// the picture when the season reward waits. When the map opens it asks the
/// board for one read (the controller reuses a read under 15 minutes old).
class MapBxhRow extends StatefulWidget {
  const MapBxhRow({super.key, required this.session, required this.height});

  final ShopSession session;
  final double height;

  @override
  State<MapBxhRow> createState() => _MapBxhRowState();
}

class _MapBxhRowState extends State<MapBxhRow> {
  ShopSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void didUpdateWidget(MapBxhRow old) {
    super.didUpdateWidget(old);
    if (!identical(old.session, widget.session)) _ask();
  }

  /// One cached read when the map opens. Not during build: refresh()
  /// notifies at once.
  void _ask() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && s.signedIn && s.petsUnlocked) s.board.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([s, s.board]),
      builder: (context, _) {
        if (!s.petsUnlocked) {
          // Same lock as the Thú cưng rows.
          return MapPlace(
            key: const Key('map-bxh'),
            height: widget.height,
            icon: 'xep_hang_icon',
            image: Art.bxh('xep_hang_icon'),
            title: Bxh.title,
            subtitle: 'Mở vào ngày $strayCatDay',
            onTap: () => showTapHint(context, 'Mở vào ngày $strayCatDay'),
          );
        }
        final b = s.board;
        final view = MapBxhView.of(b);
        return Semantics(
          button: true,
          label: view.a11y,
          excludeSemantics: true,
          child: MapPlace(
            key: const Key('map-bxh'),
            height: widget.height,
            icon: 'xep_hang_icon',
            image: Art.bxh('xep_hang_icon'),
            title: Bxh.title,
            subtitle: '',
            subtitleWidget: view.chip == BoardMapChip.hidden
                ? null
                : MapRankChip(view: view, charm: b.myCharm),
            iconDot: view.chip == BoardMapChip.rewardReady,
            onTap: s.openCharmBoard,
          ),
        );
      },
    );
  }
}

/// What the chip says, drawn from the controller (kept apart so tests read it
/// without pumping a widget).
class MapBxhView {
  const MapBxhView(this.chip, this.rank);

  final BoardMapChip chip;
  final int? rank;

  factory MapBxhView.of(CharmBoardController b) =>
      MapBxhView(b.mapChip, b.mapRank);

  bool get _hasRank =>
      rank != null &&
      (chip == BoardMapChip.ranked || chip == BoardMapChip.rewardReady);

  /// Text on the chip (short, as in the mock).
  String get label => switch (chip) {
    BoardMapChip.guest => Bxh.guestBtn,
    BoardMapChip.closing => Bxh.claimPending,
    BoardMapChip.outside => Bxh.outRank,
    BoardMapChip.unranked => Bxh.unranked,
    BoardMapChip.ranked ||
    BoardMapChip.rewardReady => _hasRank ? Bxh.rankN(rank!) : Bxh.unranked,
    _ => '',
  };

  /// Shown after the chip for the states that have a rank on the board.
  bool get showsCharm => switch (chip) {
    BoardMapChip.ranked || BoardMapChip.rewardReady => _hasRank,
    BoardMapChip.outside => true,
    _ => false,
  };

  /// Screen-reader sentence (`bxh.map.a11y` with the full-sentence state).
  String get a11y {
    final state = switch (chip) {
      BoardMapChip.guest => Bxh.mapA11yGuest,
      BoardMapChip.closing => Bxh.mapA11yClosing,
      BoardMapChip.rewardReady => Bxh.mapA11yReward,
      BoardMapChip.outside => Bxh.mapA11yOut,
      BoardMapChip.ranked when _hasRank =>
        rank! <= 3 ? Bxh.mapA11yTop3(rank!) : Bxh.mapA11yRank(rank!),
      BoardMapChip.unranked || BoardMapChip.ranked => Bxh.mapA11yNone,
      _ => null,
    };
    return state == null ? Bxh.title : Bxh.mapA11y(state);
  }

  /// Chip colours: gold 1-3, green 4-10, blue 11-50, brown 51-100 (the shield
  /// colours of the board), grey for 100+ and unranked, amber for the two
  /// states that wait on something.
  (Color, Color) get colors {
    switch (chip) {
      case BoardMapChip.guest || BoardMapChip.closing:
        return (AppColors.accentSoft, const Color(0xFF8A5A12));
      case BoardMapChip.ranked || BoardMapChip.rewardReady:
        final r = rank;
        if (r == null) return _grey;
        if (r <= 3) return (const Color(0xFFFDEFC6), const Color(0xFF7A5410));
        if (r <= 10) return (const Color(0xFFDCEFD9), const Color(0xFF2F6340));
        if (r <= 50) return (const Color(0xFFE1EDF5), const Color(0xFF2E6EA0));
        return (const Color(0xFFF3E6DC), const Color(0xFF8A5A3C));
      default:
        return _grey;
    }
  }

  static const _grey = (Color(0xFFF1F4E8), Color(0xFF6E6455));
}

/// 22 dp high pill (radius 11), 9 dp side padding, 14 dp glyph.
class MapRankChip extends StatelessWidget {
  const MapRankChip({super.key, required this.view, required this.charm});

  final MapBxhView view;
  final int charm;

  @override
  Widget build(BuildContext context) {
    if (view.chip == BoardMapChip.loading) {
      return Container(
        key: const Key('map-bxh-skeleton'),
        width: 64,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EDE0),
          borderRadius: BorderRadius.circular(11),
        ),
      );
    }
    final (bg, fg) = view.colors;
    final glyph = switch (view.chip) {
      BoardMapChip.guest => Icons.lock_outline,
      BoardMapChip.closing => Icons.hourglass_top,
      _ => null,
    };
    return Row(
      children: [
        Container(
          key: const Key('map-bxh-chip'),
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) ...[
                Icon(glyph, size: 14, color: fg),
                const SizedBox(width: 3),
              ],
              Text(
                view.label,
                maxLines: 1,
                softWrap: false,
                style: AppText.make(
                  AppFonts.display,
                  12.5,
                  800,
                  height: 1,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
        if (view.showsCharm) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              Bxh.mapCharm(charm),
              key: const Key('map-bxh-charm'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(
                size: 11.5,
                weight: 700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
