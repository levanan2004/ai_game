import 'package:flutter/widgets.dart';

/// How the 360×640 frame is placed on the real window.
///
/// [bottomGap] is the empty screen pixels under the frame. The phone layout
/// leaves it at 0, so the reply sheet still lifts by the whole keyboard
/// inset. The desktop box sets the real gap.
///
/// On a tall phone the logical canvas is the window's aspect, so nothing is
/// letterboxed. The 640-tall stage sits in the middle ([stageGapTop] /
/// [stageGapBottom]). A screen that paints from the window edge, such as the
/// market, uses [edgeTop] and [edgeBottom] for the status and gesture bars.
class FrameMetrics extends InheritedWidget {
  const FrameMetrics({
    super.key,
    required this.scale,
    required this.topInset,
    required this.bottomGap,
    this.stageGapTop = 0,
    this.stageGapBottom = 0,
    this.edgeTop = 0,
    this.edgeBottom = 0,
    required super.child,
  });

  /// Screen pixels per logical frame pixel.
  final double scale;

  /// Notch overlap inside the 640 stage, in logical pixels.
  final double topInset;

  /// Screen pixels between the frame bottom and the window bottom.
  final double bottomGap;

  /// Logical pixels above the 640 stage on a tall phone. 0 on desktop.
  final double stageGapTop;

  /// Logical pixels below the 640 stage on a tall phone. 0 on desktop.
  final double stageGapBottom;

  /// Status-bar inset for a screen that starts at the top of the window.
  final double edgeTop;

  /// Gesture-bar inset for a screen that ends at the bottom of the window.
  final double edgeBottom;

  static FrameMetrics? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrameMetrics>();

  @override
  bool updateShouldNotify(FrameMetrics old) =>
      old.scale != scale ||
      old.topInset != topInset ||
      old.bottomGap != bottomGap ||
      old.stageGapTop != stageGapTop ||
      old.stageGapBottom != stageGapBottom ||
      old.edgeTop != edgeTop ||
      old.edgeBottom != edgeBottom;
}
