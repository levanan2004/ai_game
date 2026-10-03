import 'package:flutter/material.dart';

import '../logic/cloud_merge.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Shown after another tab or device opened this Google account. The newest
/// session holds the account; this tab stopped saving and is back on its
/// guest save.
class SeatLostPopup extends StatelessWidget {
  const SeatLostPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: AppColors.bgOverlay,
        child: Center(
          child: SizedBox(
            width: 320,
            child: CardBox(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    seatLostTitle,
                    textAlign: TextAlign.center,
                    style: AppText.title(size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    seatLostBody,
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14),
                  ),
                  const SizedBox(height: 14),
                  ChunkyButton(
                    key: const Key('seat-lost-ok'),
                    label: seatLostButton,
                    height: 44,
                    fontSize: 16,
                    onPressed: session.dismissSeatLost,
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
