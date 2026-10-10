import 'package:flutter/material.dart';

import '../logic/cloud_merge.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'ui_skin.dart';

/// SPEC_ban_luu.md (A): another tab or device took the account. The game
/// is paused and writes nothing; the only way on is "Mở lại tiệm ở đây".
/// No X, and a tap on the backdrop does not close it.
class SeatLostPopup extends StatelessWidget {
  const SeatLostPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final busy = session.authBusy;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Center(
          child: SizedBox(
            width: 300,
            child: CardBox(
              radius: 20,
              borderWidth: 1.5,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _PauseBadge()),
                  const SizedBox(height: 16),
                  Text(
                    seatLostTitle,
                    key: const Key('seat-lost-title'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: AppText.title(size: 18),
                  ),
                  if (session.authError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      session.authError!,
                      textAlign: TextAlign.center,
                      style: AppText.caption(color: AppColors.statusDanger),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SkinButton(
                    key: const Key('seat-reopen'),
                    label: seatLostButton,
                    height: 48,
                    enabled: !busy,
                    onPressed: busy ? null : session.reopenHere,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseBadge extends StatelessWidget {
  const _PauseBadge();

  @override
  Widget build(BuildContext context) {
    Widget bar() => Container(
      width: 7,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.primaryBase,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [bar(), const SizedBox(width: 7), bar()],
      ),
    );
  }
}
