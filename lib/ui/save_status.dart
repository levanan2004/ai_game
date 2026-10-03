import 'package:flutter/material.dart';

import '../logic/cloud_merge.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';

/// SPEC_ban_luu.md (B): the thin row right under the main shop's TopBar.
/// Signed in: the account pill. Guest: the amber "not saved" strip.
/// While a remembered account is still opening, nothing is shown.
class SaveStatusRow extends StatelessWidget {
  const SaveStatusRow({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    if (s.signedIn) {
      return Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: AccountPill(label: s.saveLabel, onTap: s.openAccountSettings),
        ),
      );
    }
    if (!s.showGuestBanner) return const SizedBox.shrink();
    return GuestStrip(busy: s.authBusy, onSignIn: () => s.signIn());
  }
}

/// "Tài khoản: {tên}". Tapping opens Cài đặt at the account group.
class AccountPill extends StatelessWidget {
  const AccountPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('save-account-pill'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Container(
          height: 24,
          padding: const EdgeInsets.only(left: 5, right: 10),
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primarySoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBase,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 11,
                  color: AppColors.textInverse,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    size: 11,
                    weight: 800,
                    color: AppColors.primaryPressed,
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

/// Full-width amber strip: "Đang chơi thử, tiến độ không được lưu" and
/// "Đăng nhập để lưu". Min 42 tall; the text wraps to 2 lines at 360 dp.
class GuestStrip extends StatelessWidget {
  const GuestStrip({super.key, required this.onSignIn, this.busy = false});

  final VoidCallback onSignIn;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('save-guest-strip'),
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.accentSoft,
        border: Border(
          bottom: BorderSide(color: AppColors.accentBase, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.statusWarning,
              shape: BoxShape.circle,
            ),
            child: Text(
              '!',
              style: AppText.body(
                size: 11,
                weight: 900,
                color: AppColors.textInverse,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              guestSaveLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 11.5,
                weight: 800,
                color: AppColors.onSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: const Key('save-guest-sign-in'),
            behavior: HitTestBehavior.opaque,
            onTap: busy ? null : onSignIn,
            child: SizedBox(
              height: 44,
              child: Center(
                child: Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: busy
                        ? AppColors.textDisabled
                        : AppColors.primaryBase,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    guestSignInButton,
                    style: AppText.body(
                      size: 11.5,
                      weight: 800,
                      color: AppColors.textInverse,
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
