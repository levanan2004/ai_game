import 'package:flutter/widgets.dart';

/// How the 360×640 frame is placed on the real window.
///
/// [bottomGap] is the empty screen pixels under the frame. The phone layout
/// leaves it at 0, so the reply sheet still lifts by the whole keyboard
/// inset. The desktop box sets the real gap.
class FrameMetrics extends InheritedWidget {
  const FrameMetrics({
    super.key,
    required this.scale,
    required this.topInset,
    required this.bottomGap,
    required super.child,
  });

  /// Screen pixels per logical frame pixel.
  final double scale;

  /// Notch overlap inside the frame, in logical pixels.
  final double topInset;

  /// Screen pixels between the frame bottom and the window bottom.
  final double bottomGap;

  static FrameMetrics? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrameMetrics>();

  @override
  bool updateShouldNotify(FrameMetrics old) =>
      old.scale != scale ||
      old.topInset != topInset ||
      old.bottomGap != bottomGap;
}
