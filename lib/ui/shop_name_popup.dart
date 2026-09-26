import 'package:flutter/material.dart';

import '../logic/shop_name.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// Đặt tên tiệm (spec_popup_va_mo_dau.md §7, chữ của Nhất).
class ShopNamePopup extends StatefulWidget {
  const ShopNamePopup({super.key, required this.session});

  final ShopSession session;

  @override
  State<ShopNamePopup> createState() => _ShopNamePopupState();
}

class _ShopNamePopupState extends State<ShopNamePopup> {
  late final TextEditingController _text;
  late final FocusNode _focus;

  ShopSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    final initial = s.namePrompt == ShopNameMode.rename
        ? (s.state.shopName ?? '')
        : '';
    _text = TextEditingController(text: initial);
    _focus = FocusNode();
    _text.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _roll() {
    final next = rollShopName(_text.text, s.rng);
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _submit() {
    if (normalizeShopName(_text.text) == null) return;
    s.confirmShopName(_text.text);
  }

  String get _nameHint {
    final name = _text.text.trim().replaceAll(RegExp(r' +'), ' ');
    if (name.length < 2) return 'Tên tiệm cần ít nhất 2 chữ';
    if (name.length > 20) return 'Tên tiệm tối đa 20 chữ thôi';
    return 'Tên chỉ gồm chữ, số, dấu cách và & \' - .';
  }

  @override
  Widget build(BuildContext context) {
    final rename = s.namePrompt == ShopNameMode.rename;
    final ok = normalizeShopName(_text.text) != null;
    final focused = _focus.hasFocus;
    return ColoredBox(
      color: AppColors.bgOverlay,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppMotion.slow,
          curve: Curves.easeOutBack,
          builder: (_, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
          ),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              key: const Key('shop-name-popup'),
              width: 304,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.surfaceBorderStrong,
                    offset: Offset(0, AppSize.shadowOffset),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ArtImage(Art.upgrade('staff'), size: 72),
                  const SizedBox(height: 8),
                  Text(
                    rename ? 'Đổi tên tiệm' : 'Đặt tên cho tiệm',
                    textAlign: TextAlign.center,
                    style: AppText.title(size: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tên này sẽ treo trên biển trước tiệm.',
                    textAlign: TextAlign.center,
                    style: AppText.body(
                      size: 12,
                      weight: 600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: focused
                                  ? AppColors.primaryBase
                                  : AppColors.surfaceBorderStrong,
                              width: focused ? 2 : AppBorder.thin,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('shop-name-field'),
                                  controller: _text,
                                  focusNode: _focus,
                                  autofocus: true,
                                  style: AppText.make(
                                    AppFonts.display,
                                    17,
                                    700,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    isCollapsed: true,
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      10,
                                      12,
                                      4,
                                      12,
                                    ),
                                    border: InputBorder.none,
                                    hintText: 'Ví dụ: Tiệm Hoa Nhà Mây',
                                    hintStyle: AppText.make(
                                      AppFonts.display,
                                      15,
                                      600,
                                      color: AppColors.textDisabled,
                                    ),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '${_text.text.length}/20',
                                  style: AppText.caption(
                                    size: 11,
                                    color: AppColors.textDisabled,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        key: const Key('shop-name-dice'),
                        onTap: _roll,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 36,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.surfaceBorderStrong,
                              width: AppBorder.thin,
                            ),
                          ),
                          child: CustomPaint(
                            size: const Size(18, 18),
                            painter: _DicePainter(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chưa nghĩ ra? Bấm xúc xắc để lấy tên gợi ý.',
                    textAlign: TextAlign.center,
                    style: AppText.caption(),
                  ),
                  const SizedBox(height: 12),
                  if (rename)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ChunkyButton(
                              label: 'Hủy',
                              kind: ButtonKind.ghost,
                              fontSize: 15,
                              onPressed: s.cancelShopName,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ChunkyButton(
                              key: const Key('shop-name-save'),
                              label: 'Lưu tên',
                              enabled: ok,
                              onPressed: ok ? _submit : null,
                              disabledHint: _nameHint,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: 272,
                      height: 52,
                      child: ChunkyButton(
                        key: const Key('shop-name-save'),
                        label: 'Mở tiệm',
                        enabled: ok,
                        onPressed: ok ? _submit : null,
                        disabledHint: _nameHint,
                      ),
                    ),
                  if (!rename) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Có thể đổi tên sau trong Cài đặt.',
                      textAlign: TextAlign.center,
                      style: AppText.caption(
                        size: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DicePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.textSecondary,
    );
    final dot = Paint()..color = AppColors.primaryPressed;
    for (final p in const [
      Offset(0.28, 0.28),
      Offset(0.72, 0.28),
      Offset(0.5, 0.5),
      Offset(0.28, 0.72),
      Offset(0.72, 0.72),
    ]) {
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height),
        1.4,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_DicePainter oldDelegate) => false;
}
