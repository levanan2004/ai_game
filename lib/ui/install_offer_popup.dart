import 'package:flutter/material.dart';

import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'install_prompt.dart';

/// One-time web card: install the game after day 1, 3, 5, 7 or 9, or when
/// a shop already past day 1 is opened.
class InstallOfferPopup extends StatefulWidget {
  const InstallOfferPopup({super.key, required this.session});

  final ShopSession session;

  @override
  State<InstallOfferPopup> createState() => _InstallOfferPopupState();
}

class _InstallOfferPopupState extends State<InstallOfferPopup> {
  String? _guide;

  Future<void> _install() async {
    if (homeScreenCanPrompt) {
      final outcome = await promptHomeScreen();
      if (!mounted) return;
      if (outcome == 'unavailable') {
        setState(() => _guide = _manual);
        return;
      }
    } else {
      setState(() => _guide = _manual);
      return;
    }
    widget.session.closeInstallOffer();
  }

  String get _manual => homeScreenPlatform == 'ios'
      ? 'Bấm nút Chia sẻ của Safari, rồi chọn “Thêm vào Màn hình chính”.'
      : 'Bấm menu Chrome (⋮), rồi chọn “Cài đặt ứng dụng” hoặc “Thêm vào màn hình chính”.';

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    return Stack(
      key: const Key('install-offer'),
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.bgOverlay)),
        Center(
          child: SizedBox(
            width: 320,
            child: CardBox(
              radius: AppRadius.lg,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cài game về máy',
                    textAlign: TextAlign.center,
                    style: AppText.title(size: 20, weight: 800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chơi trên app đỡ phải mở trình duyệt mỗi lần. '
                    'Đăng nhập Google thì tiến trình vẫn còn.',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, weight: 700),
                  ),
                  if (guide != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      guide,
                      key: const Key('install-offer-guide'),
                      textAlign: TextAlign.center,
                      style: AppText.caption(size: 12, weight: 700),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ChunkyButton(
                      key: const Key('install-offer-install'),
                      label: 'Cài về máy',
                      onPressed: _install,
                    ),
                  ),
                  TextButton(
                    key: const Key('install-offer-later'),
                    onPressed: widget.session.closeInstallOffer,
                    child: Text(
                      'Để sau',
                      style: AppText.button(
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
