import 'package:flutter/material.dart';

import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'popups.dart';

/// The random-event card. The day clock stays still until a choice is made.
class EventPopup extends StatelessWidget {
  const EventPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final offer = session.eventOffer;
    if (offer == null) return const SizedBox.shrink();
    return PopupFrame(
      key: const Key('event-popup'),
      rect: const Rect.fromLTWH(24, 78, 312, 500),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: AppColors.bgShop,
                child: Image.asset(
                  Art.event(offer.id),
                  height: 168,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              offer.title,
              textAlign: TextAlign.center,
              style: AppText.title(size: 20, weight: 800),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  offer.body,
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 14, weight: 700),
                ),
              ),
            ),
            for (final choice in offer.choices) ...[
              const SizedBox(height: 8),
              ChunkyButton(
                key: Key('event-${choice.id}'),
                label: choice.label,
                height: 48,
                fontSize: 17,
                radius: AppRadius.md,
                kind: choice == offer.choices.first
                    ? ButtonKind.primary
                    : ButtonKind.ghost,
                onPressed: () => session.chooseEvent(choice.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Day 5 summary: one stray kitten. Accepting is the only way this visit
/// gives a cat. Declining leaves the pet shop.
class StrayCatPopup extends StatelessWidget {
  const StrayCatPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return PopupFrame(
      key: const Key('stray-cat-popup'),
      onOutsideTap: () {},
      rect: const Rect.fromLTWH(24, 78, 312, 460),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: AppColors.bgShop,
                child: Image.asset(
                  Art.pet('meo_au_ngoi'),
                  height: 168,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Mèo đi lạc',
              textAlign: TextAlign.center,
              style: AppText.title(size: 20, weight: 800),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                'Một bé mèo đi lạc trước cửa tiệm. Nhận nuôi thì bé về phòng. '
                'Để bé đi thì lần này thôi.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 14, weight: 700),
              ),
            ),
            ChunkyButton(
              key: const Key('stray-adopt'),
              label: 'Nhận nuôi',
              height: 48,
              fontSize: 17,
              radius: AppRadius.md,
              onPressed: () => session.chooseStrayCat(true),
            ),
            const SizedBox(height: 8),
            ChunkyButton(
              key: const Key('stray-skip'),
              label: 'Để bé đi',
              kind: ButtonKind.ghost,
              height: 48,
              fontSize: 17,
              radius: AppRadius.md,
              onPressed: () => session.chooseStrayCat(false),
            ),
          ],
        ),
      ),
    );
  }
}
