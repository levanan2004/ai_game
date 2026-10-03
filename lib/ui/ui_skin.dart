import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// One piece of Phú's UI sheet (dot1_ui). Canvas size and fixed edges come
/// from `assets/images/ui_dot1/ui_9slice.json` (pixels on the full-res
/// canvas); `test/ui/ui_skin_test.dart` checks these numbers against it.
/// [padding] is the safe text area as distances from each edge (README_ui).
class SkinSlice {
  const SkinSlice(
    this.id, {
    required this.w,
    required this.h,
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.padding = EdgeInsets.zero,
  });

  final String id;
  final double w, h, left, top, right, bottom;
  final EdgeInsets padding;

  String get path => Art.uiSkin(id);

  /// Stretch area on the canvas, in canvas pixels.
  Rect get center => Rect.fromLTRB(left, top, w - right, h - bottom);

  /// Image scale that shows the canvas [height] dp tall.
  double scaleFor(double height) => h / height;
}

/// The pieces in use. Groups share one canvas and one set of edges, so
/// switching state (button pressed, tab selected) never jumps.
abstract final class UiSkin {
  static const popup = SkinSlice(
    'popup_khung',
    w: 689,
    h: 862,
    left: 180,
    top: 168,
    right: 178,
    bottom: 184,
    padding: EdgeInsets.fromLTRB(86, 123, 87, 134),
  );
  static const tray = SkinSlice(
    'the_nen',
    w: 696,
    h: 271,
    left: 125,
    top: 106,
    right: 121,
    bottom: 114,
    padding: EdgeInsets.fromLTRB(110, 52, 111, 40),
  );
  static const input = SkinSlice(
    'o_nhap',
    w: 732,
    h: 168,
    left: 91,
    top: 102,
    right: 85,
    bottom: 64,
    padding: EdgeInsets.fromLTRB(84, 45, 74, 29),
  );
  static const _button = EdgeInsets.fromLTRB(75, 43, 97, 43);
  static const primary = SkinSlice(
    'nut_chinh',
    w: 367,
    h: 150,
    left: 88,
    top: 74,
    right: 97,
    bottom: 74,
    padding: _button,
  );
  static const primaryPressed = SkinSlice(
    'nut_chinh_nhan',
    w: 367,
    h: 150,
    left: 88,
    top: 74,
    right: 97,
    bottom: 74,
    padding: _button,
  );
  static const secondary = SkinSlice(
    'nut_phu',
    w: 367,
    h: 150,
    left: 88,
    top: 74,
    right: 97,
    bottom: 74,
    padding: _button,
  );
  static const disabled = SkinSlice(
    'nut_tat',
    w: 367,
    h: 150,
    left: 88,
    top: 74,
    right: 97,
    bottom: 74,
    padding: _button,
  );
  static const _tab = EdgeInsets.fromLTRB(93, 73, 98, 62);
  static const tabOn = SkinSlice(
    'tab_chon',
    w: 357,
    h: 203,
    left: 107,
    top: 107,
    right: 98,
    bottom: 94,
    padding: _tab,
  );
  static const tabOff = SkinSlice(
    'tab_thuong',
    w: 357,
    h: 203,
    left: 107,
    top: 107,
    right: 98,
    bottom: 94,
    padding: _tab,
  );

  /// Ribbon in three pieces; the middle tiles every 36 px (stitches).
  static const ribbonLeft = SkinSlice('ruy_bang_trai', w: 199, h: 196);
  static const ribbonMiddle = SkinSlice('ruy_bang_giua', w: 36, h: 196);
  static const ribbonRight = SkinSlice('ruy_bang_phai', w: 184, h: 196);

  /// Title area of the whole ribbon (ruy_bang 743×196).
  static const ribbonText = EdgeInsets.fromLTRB(175, 34, 175, 68);

  /// Round buttons share a canvas and are only scaled evenly.
  static const back = SkinSlice('nut_quay_lai', w: 236, h: 262);
  static const close = SkinSlice('nut_dong', w: 236, h: 262);

  static const all = [
    popup,
    tray,
    input,
    primary,
    primaryPressed,
    secondary,
    disabled,
    tabOn,
    tabOff,
    ribbonLeft,
    ribbonMiddle,
    ribbonRight,
    back,
    close,
  ];
}

Widget _sliced(SkinSlice s, double scale) => SkinSliceImage(s, scale: scale);

/// Paints [slice] over its whole box with `drawImageNine`; the fixed edges
/// are drawn at canvas size ÷ [scale].
///
/// `Image(centerSlice:, scale:)` is not used: Flutter reads centerSlice in
/// logical pixels and, at scales like 150/48, rounding trips its
/// "sourceSize == inputSize" assert in debug builds.
class SkinSliceImage extends StatefulWidget {
  const SkinSliceImage(this.slice, {super.key, required this.scale});

  final SkinSlice slice;
  final double scale;

  @override
  State<SkinSliceImage> createState() => _SkinSliceImageState();
}

class _SkinSliceImageState extends State<SkinSliceImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final _listener = ImageStreamListener(_onImage);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(SkinSliceImage old) {
    super.didUpdateWidget(old);
    if (old.slice.path != widget.slice.path) _resolve();
  }

  void _resolve() {
    final stream = AssetImage(
      widget.slice.path,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  // Keeps the previous picture until the new one is ready (no flash when a
  // button swaps to its pressed art).
  void _onImage(ImageInfo info, bool _) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _SlicePainter(_info?.image, widget.slice, widget.scale),
      ),
    );
  }
}

class _SlicePainter extends CustomPainter {
  _SlicePainter(this.image, this.slice, this.scale);

  final ui.Image? image;
  final SkinSlice slice;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null || size.isEmpty) return;
    // Canvas pixels per image pixel (1 unless a resized file is dropped in).
    final k = img.width / slice.w;
    final s = scale * k;
    canvas.save();
    canvas.scale(1 / s);
    canvas.drawImageNine(
      img,
      Rect.fromLTRB(
        slice.left * k,
        slice.top * k,
        (slice.w - slice.right) * k,
        (slice.h - slice.bottom) * k,
      ),
      Offset.zero & (size * s),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SlicePainter old) =>
      old.image != image || old.slice != slice || old.scale != scale;
}

/// popup_khung, 9-slice. Sizes to its child (no empty bottom).
class SkinPanel extends StatelessWidget {
  const SkinPanel({super.key, required this.child, this.scale = 3});

  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: _sliced(UiSkin.popup, scale)),
        Padding(padding: UiSkin.popup.padding / scale, child: child),
      ],
    );
  }
}

/// the_nen: mint tray with a wooden rim, 9-slice.
class SkinTray extends StatelessWidget {
  const SkinTray({super.key, required this.child, this.scale = 4.5});

  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: _sliced(UiSkin.tray, scale)),
        Padding(padding: UiSkin.tray.padding / scale, child: child),
      ],
    );
  }
}

/// Title ribbon: left end, tiled middle, right end. Stitches never stretch.
class SkinRibbon extends StatelessWidget {
  const SkinRibbon({
    super.key,
    required this.title,
    this.width = 196,
    this.height = 46,
    this.fontSize = 18,
  });

  final String title;
  final double width, height, fontSize;

  @override
  Widget build(BuildContext context) {
    final s = UiSkin.ribbonLeft.scaleFor(height);
    Widget end(SkinSlice p) => Image.asset(
      p.path,
      width: p.w / s,
      height: height,
      fit: BoxFit.fill,
      excludeFromSemantics: true,
    );
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                end(UiSkin.ribbonLeft),
                Expanded(
                  child: Image.asset(
                    UiSkin.ribbonMiddle.path,
                    scale: s,
                    repeat: ImageRepeat.repeatX,
                    alignment: Alignment.centerLeft,
                    excludeFromSemantics: true,
                  ),
                ),
                end(UiSkin.ribbonRight),
              ],
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: UiSkin.ribbonText / s,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: AppText.button(size: fontSize, weight: 800).copyWith(
                      shadows: const [
                        Shadow(
                          color: Color(0x66204A2A),
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
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

enum SkinButtonKind { primary, secondary }

/// Long button (nut_chinh / nut_phu, nut_tat when disabled), 3-slice
/// horizontal: fixed [height], width from the parent or the label.
/// Primary shows nut_chinh_nhan while held, label moved down 4 px (canvas).
class SkinButton extends StatefulWidget {
  const SkinButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = SkinButtonKind.primary,
    this.height = 48,
    this.fontSize = 17,
    this.enabled = true,
    this.disabledHint,
  });

  final String label;
  final VoidCallback? onPressed;
  final SkinButtonKind kind;
  final double height;
  final double fontSize;
  final bool enabled;
  final String? disabledHint;

  @override
  State<SkinButton> createState() => _SkinButtonState();
}

class _SkinButtonState extends State<SkinButton> {
  bool _down = false;

  bool get _active => widget.enabled && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final pressed = _down && _active;
    final primary = widget.kind == SkinButtonKind.primary;
    final slice = !_active
        ? UiSkin.disabled
        : !primary
        ? UiSkin.secondary
        : pressed
        ? UiSkin.primaryPressed
        : UiSkin.primary;
    final scale = slice.scaleFor(widget.height);
    final sink = pressed ? 4 / scale : 0.0;
    final color = !_active
        ? const Color(0xFFF7F5EF)
        : primary
        ? AppColors.onPrimary
        : AppColors.textPrimary;
    final pad = slice.padding / scale;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _active ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: _active
          ? (_) {
              setState(() => _down = false);
              SoundScope.maybeOf(context)?.effect('ui_tap');
              widget.onPressed?.call();
            }
          : widget.disabledHint == null
          ? null
          : (_) => showTapHint(context, widget.disabledHint!),
      child: Semantics(
        button: true,
        enabled: _active,
        child: SizedBox(
          height: widget.height,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: pressed && !primary ? 0.85 : 1,
                  child: _sliced(slice, scale),
                ),
              ),
              Padding(
                padding: pad.copyWith(
                  top: pad.top + sink,
                  bottom: pad.bottom - sink,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      style: AppText.button(
                        size: widget.fontSize,
                        weight: 800,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// tab_chon / tab_thuong, 3-slice horizontal at a fixed [height].
class SkinTab extends StatelessWidget {
  const SkinTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 40,
    this.fontSize = 13,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height, fontSize;

  @override
  Widget build(BuildContext context) {
    final slice = selected ? UiSkin.tabOn : UiSkin.tabOff;
    final scale = slice.scaleFor(height);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(child: _sliced(slice, scale)),
              Padding(
                padding: slice.padding / scale,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: AppText.button(
                        size: fontSize,
                        weight: 800,
                        color: selected
                            ? AppColors.onPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// o_nhap behind a borderless TextField. No formatter, no length cap.
class SkinInput extends StatelessWidget {
  const SkinInput({super.key, required this.field, this.height = 44});

  /// Use [SkinInput.decoration] for the field.
  final Widget field;
  final double height;

  static InputDecoration decoration(String hint) => InputDecoration.collapsed(
    hintText: hint,
    hintStyle: AppText.body(size: 14, color: AppColors.textDisabled),
  );

  @override
  Widget build(BuildContext context) {
    final scale = UiSkin.input.scaleFor(height);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: _sliced(UiSkin.input, scale)),
          Padding(
            padding: UiSkin.input.padding / scale,
            child: Align(alignment: Alignment.centerLeft, child: field),
          ),
        ],
      ),
    );
  }
}

enum SkinRound { back, close }

/// nut_quay_lai / nut_dong: never stretched, only scaled evenly.
class SkinRoundButton extends StatelessWidget {
  const SkinRoundButton({
    super.key,
    required this.kind,
    required this.onTap,
    this.width = 42,
  });

  final SkinRound kind;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final s = kind == SkinRound.back ? UiSkin.back : UiSkin.close;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        SoundScope.maybeOf(context)?.effect('ui_tap');
        onTap();
      },
      child: Semantics(
        button: true,
        label: kind == SkinRound.back ? 'Quay lại' : 'Đóng',
        child: Image.asset(
          s.path,
          width: width,
          height: width * s.h / s.w,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

/// Popup frame with the title ribbon on its top edge and round back/close
/// buttons at the corners. Height follows the content.
class SkinPopup extends StatelessWidget {
  const SkinPopup({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.onClose,
    this.backKey,
    this.closeKey,
    this.ribbonWidth = 196,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack, onClose;
  final Key? backKey, closeKey;
  final double ribbonWidth;

  /// Room above the frame for the ribbon and round buttons.
  static const lift = 18.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: lift),
          child: SkinPanel(child: child),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Center(
            child: SkinRibbon(title: title, width: ribbonWidth),
          ),
        ),
        if (onBack != null)
          Positioned(
            left: 2,
            top: 0,
            child: SkinRoundButton(
              key: backKey,
              kind: SkinRound.back,
              onTap: onBack!,
            ),
          ),
        if (onClose != null)
          Positioned(
            right: 2,
            top: 0,
            child: SkinRoundButton(
              key: closeKey,
              kind: SkinRound.close,
              onTap: onClose!,
            ),
          ),
      ],
    );
  }
}
