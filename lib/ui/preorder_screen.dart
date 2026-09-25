import 'package:flutter/material.dart';

import '../logic/delivery.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Morning board of preorders, before the market (spec_giao_hang §2).
class PreorderScreen extends StatelessWidget {
  const PreorderScreen({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final cards =
        [
          for (final o in s.onlineOrders)
            if (o.kind == OrderKind.preorder) o,
        ]..sort((a, b) {
          final ad = a.status == OrderStatus.declined ? 1 : 0;
          final bd = b.status == OrderStatus.declined ? 1 : 0;
          return ad.compareTo(bd);
        });
    return OpaqueScreen(
      key: const Key('preorder-board'),
      color: AppColors.bgBase,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: TopBar(session: s, dayLabel: '${dayName(s)} · Sáng'),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 56,
            child: Text(
              'Đơn đặt trước hôm nay',
              textAlign: TextAlign.center,
              style: AppText.heading(size: 18),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: 82,
            child: Text(
              'Hoa cho đơn đã nhận sẽ tự vào giỏ đi chợ',
              textAlign: TextAlign.center,
              style: AppText.caption(size: 11),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 112,
            bottom: 76,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _PreorderCard(session: s, order: cards[i]),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            height: 48,
            child: ChunkyButton(
              key: const Key('preorder-done'),
              label: 'Đi chợ hoa',
              onPressed: s.leavePreorderBoard,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreorderCard extends StatelessWidget {
  const _PreorderCard({required this.session, required this.order});

  final ShopSession session;
  final OnlineOrder order;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final o = order;
    final accepted = o.status == OrderStatus.accepted;
    final declined = o.status == OrderStatus.declined;
    final onTime = s.orderOnTime(o);
    final occ = s.e.occasion(o.request.occasionId);
    return Opacity(
      opacity: declined ? 0.4 : 1,
      child: Container(
        key: Key('preorder-${o.id}'),
        height: 112,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: accepted ? AppColors.secondaryBase : AppColors.surfaceBorder,
            width: accepted ? 2 : AppBorder.thin,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(name: o.customerName, avatarId: o.avatarId, radius: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    o.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(size: 13, weight: 800),
                  ),
                ),
                const SizedBox(width: 4),
                OccasionChip(
                  occasionId: occ.id,
                  label: occ.nameVi,
                  height: 16,
                  fontSize: 9,
                ),
                const Spacer(),
                Text(
                  'Giao trước ${deadlineClock(s.e, o.deadline)}',
                  style: AppText.heading(size: 13),
                ),
                if (accepted) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.secondaryBase,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              o.line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 12, weight: 700),
            ),
            const SizedBox(height: 2),
            _HintChip(onTime: onTime),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (accepted)
                  GestureDetector(
                    key: Key('preorder-cancel-${o.id}'),
                    onTap: () => s.unacceptPreorder(o),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        'Hủy nhận',
                        style: AppText.button(
                          size: 13,
                          weight: 800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else if (!declined) ...[
                  SizedBox(
                    width: 96,
                    height: 32,
                    child: ChunkyButton(
                      key: Key('preorder-skip-${o.id}'),
                      label: 'Bỏ qua',
                      kind: ButtonKind.ghost,
                      fontSize: 13,
                      onPressed: () => s.declinePreorder(o),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    height: 32,
                    child: ChunkyButton(
                      key: Key('preorder-take-${o.id}'),
                      label: 'Nhận',
                      kind: ButtonKind.secondary,
                      fontSize: 13,
                      onPressed: () => s.acceptPreorder(o),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.onTime});

  final bool onTime;

  @override
  Widget build(BuildContext context) {
    final bg = onTime
        ? AppColors.secondarySoft
        : Color.alphaBlend(
            AppColors.statusDanger.withValues(alpha: 0.2),
            const Color(0xFFFFFFFF),
          );
    final fg = onTime ? AppColors.secondaryPressed : AppColors.statusDanger;
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        onTime ? 'Kịp giờ' : 'Dễ bị trễ',
        style: AppText.caption(size: 10, weight: 800, color: fg),
      ),
    );
  }
}
