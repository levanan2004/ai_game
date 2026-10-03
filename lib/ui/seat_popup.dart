import 'package:flutter/material.dart';

import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Shown when this tab signs into a Google account that another tab holds.
class SeatPopup extends StatelessWidget {
  const SeatPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final email = s.seatEmail;
    final error = s.authError;
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
                    'Tài khoản đang mở ở chỗ khác',
                    textAlign: TextAlign.center,
                    style: AppText.title(size: 18),
                  ),
                  if (email != null && email.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: AppText.caption(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Vào đây sẽ đăng xuất chỗ đang chơi và lấy tiệm đã lưu trên tài khoản.',
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: AppText.caption(color: AppColors.statusDanger),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ChunkyButton(
                    key: const Key('seat-takeover-confirm'),
                    label: 'Vào đây',
                    height: 44,
                    fontSize: 16,
                    enabled: !s.authBusy,
                    onPressed: () => s.confirmSeat(),
                  ),
                  const SizedBox(height: 8),
                  ChunkyButton(
                    key: const Key('seat-takeover-cancel'),
                    label: 'Để sau',
                    kind: ButtonKind.ghost,
                    height: 44,
                    fontSize: 16,
                    enabled: !s.authBusy,
                    onPressed: () => s.declineSeat(),
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
