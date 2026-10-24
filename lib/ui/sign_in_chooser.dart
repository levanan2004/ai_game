import 'package:flutter/material.dart';

import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';

/// iOS login sheet: Sign in with Apple first, then Google (guideline 4.8).
class SignInChooser extends StatelessWidget {
  const SignInChooser({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final busy = session.authBusy;
    return Stack(
      children: [
        GestureDetector(
          key: const Key('sign-in-chooser-dismiss'),
          onTap: busy ? null : session.closeSignInChooser,
          child: const ColoredBox(color: AppColors.bgOverlay),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Material(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  key: const Key('sign-in-chooser'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Đăng nhập để lưu',
                      textAlign: TextAlign.center,
                      style: AppText.title(size: 18, weight: 800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Apple chỉ dùng tên và email. Google còn dùng ảnh đại diện.',
                      textAlign: TextAlign.center,
                      style: AppText.caption(size: 11),
                    ),
                    const SizedBox(height: 14),
                    AppleSignInButton(
                      busy: busy,
                      onPressed: session.signInWithApple,
                    ),
                    const SizedBox(height: 8),
                    _GoogleChoice(
                      busy: busy,
                      onPressed: session.signInWithGoogle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
  });

  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('sign-in-apple'),
      onTap: busy ? null : onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF000000),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textInverse,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.apple, color: AppColors.textInverse, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Đăng nhập với Apple',
                    style: AppText.button(
                      size: 14,
                      color: AppColors.textInverse,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleChoice extends StatelessWidget {
  const _GoogleChoice({required this.onPressed, required this.busy});

  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('sign-in-google'),
      onTap: busy ? null : onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primaryBase, width: AppBorder.thin),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArtImage(Art.nav('google'), size: 20),
            const SizedBox(width: 8),
            Text(
              'Đăng nhập Google',
              style: AppText.button(size: 14, color: AppColors.primaryPressed),
            ),
          ],
        ),
      ),
    );
  }
}
