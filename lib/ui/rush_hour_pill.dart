import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/rush_hour_status.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'game_toast.dart';
import 'gio_cao_diem_text.dart';

/// Giờ cao điểm pill (Phú's spec 25/10): 24 tall, radius 12, 8 side
/// padding, 16 icon, 12sp bold. Rush: #E26D5A with the hour's ×weight and a
/// 300 ms bounce when it starts. Lunch: #E8F0EA / #3F7F52. The hour before a
/// rush: the rush pill at 60% with a countdown. Normal hours: hidden. The
/// sub-line only shows as a 2 s toast when a rush or the lunch lull starts.
class RushHourPill extends StatefulWidget {
  const RushHourPill({super.key, required this.session});

  final ShopSession session;

  static const peakFill = Color(0xFFE26D5A);
  static const lunchFill = Color(0xFFE8F0EA);
  static const lunchText = Color(0xFF3F7F52);

  @override
  State<RushHourPill> createState() => _RushHourPillState();
}

class _RushHourPillState extends State<RushHourPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  RushStatus? _last;

  ShopSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _last = rushStatusOf(s);
    s.addListener(_changed);
  }

  @override
  void didUpdateWidget(RushHourPill old) {
    super.didUpdateWidget(old);
    if (!identical(old.session, widget.session)) {
      old.session.removeListener(_changed);
      widget.session.addListener(_changed);
      _last = rushStatusOf(s);
    }
  }

  @override
  void dispose() {
    s.removeListener(_changed);
    _bounce.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final now = rushStatusOf(s);
    final was = _last;
    _last = now;
    if (now == was) return;
    final started = now != null && now.kind != was?.kind;
    // The morning rush starts with the opening itself; the opening has its
    // own moment, so only rushes the clock runs into get the toast.
    final toast = started && s.state.elapsed > 0;
    if (started && now.kind == RushKind.peak) {
      _bounce.forward(from: 0);
      if (toast) {
        showGameToast(
          context,
          '${GioCaoDiemText.peakLabel}\n${GioCaoDiemText.peakSub}',
        );
      }
    } else if (toast && now.kind == RushKind.lunch) {
      showGameToast(
        context,
        '${GioCaoDiemText.lunchLull}\n${GioCaoDiemText.lunchSub}',
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = _last;
    if (r == null) return const SizedBox.shrink(key: Key('rush-pill-none'));
    final lunch = r.kind == RushKind.lunch;
    final fill = lunch ? RushHourPill.lunchFill : RushHourPill.peakFill;
    final ink = lunch ? RushHourPill.lunchText : Colors.white;
    final name = GioCaoDiemText.peakName(r.labelKey);
    final text = switch (r.kind) {
      RushKind.peak => '$name ×${formatMultiplier(r.multiplier)}',
      RushKind.lunch => GioCaoDiemText.lunchPill,
      RushKind.upcoming =>
        '${GioCaoDiemText.upcoming(name, formatClock(r.startHour, 0))}'
            ' · ${GioCaoDiemText.countdown(r.minutesLeft)}',
    };
    final pill = Container(
      key: Key('rush-pill-${r.kind.name}'),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            lunch
                ? Icons.emoji_food_beverage_rounded
                : Icons.local_fire_department_rounded,
            size: 16,
            color: ink,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            key: const Key('rush-pill-text'),
            maxLines: 1,
            style: AppText.body(size: 12, weight: 700, color: ink),
          ),
        ],
      ),
    );
    return IgnorePointer(
      child: Opacity(
        opacity: r.kind == RushKind.upcoming ? 0.6 : 1,
        child: ScaleTransition(
          scale: TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 1, end: 1.1), weight: 1),
            TweenSequenceItem(tween: Tween(begin: 1.1, end: 1), weight: 1),
          ]).animate(_bounce),
          child: FittedBox(fit: BoxFit.scaleDown, child: pill),
        ),
      ),
    );
  }
}
