import 'package:flame/components.dart';
import 'package:flame/events.dart';

/// Plain rectangle that receives the same tap on mouse and touch.
///
/// Size and position are placeholder geometry, not a layout spec.
class TapTarget extends RectangleComponent with TapCallbacks {
  TapTarget({required this.onPressed})
    : super(
        size: Vector2(200, 100),
        anchor: Anchor.center,
        position: Vector2.zero(),
      );

  final void Function() onPressed;

  @override
  void onTapUp(TapUpEvent event) {
    onPressed();
  }
}
