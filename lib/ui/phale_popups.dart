import 'package:flutter/material.dart';

import '../data/phale_shop.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'pet_item_picker.dart' show PetItemConfirmShell;
import 'phale_text.dart';
import 'reward_bundle_view.dart' show PhaLeIcon;
import 'ui_skin.dart';

/// The pack picture on its soft ground, used by the confirm popup and the
/// order summary.
class PhalePackPicture extends StatelessWidget {
  const PhalePackPicture({
    super.key,
    required this.packId,
    required this.height,
  });

  final String packId;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
      child: Image.asset(
        Art.phale(packId),
        alignment: Alignment.bottomCenter,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _AmberBox extends StatelessWidget {
  const _AmberBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.statusWarning, width: 1.5),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.body(
          size: 12.5,
          weight: 800,
          color: const Color(0xFF8A5A12),
        ),
      ),
    );
  }
}

TextStyle _line() => AppText.body(
  size: 12.5,
  weight: 700,
  color: AppColors.textSecondary,
).copyWith(height: 18 / 12.5);

/// S2a: "Mua {n} Pha lê?".
class PhaleConfirmPopup extends StatelessWidget {
  const PhaleConfirmPopup({
    super.key,
    required this.session,
    required this.pack,
  });

  final ShopSession session;
  final PhaPack pack;

  @override
  Widget build(BuildContext context) {
    final c = session.phaleShop;
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppText.body(size: 13, weight: 800)),
          ),
          value,
        ],
      ),
    );
    return PetItemConfirmShell(
      dismissKey: const Key('phale-confirm-dismiss'),
      panelKey: const Key('phale-confirm'),
      onClose: c.later,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PhaleText.confirmTitle(pack.phaLe),
            key: const Key('phale-confirm-title'),
            textAlign: TextAlign.center,
            style: AppText.title(size: 20, weight: 800),
          ),
          const SizedBox(height: 10),
          PhalePackPicture(packId: pack.id, height: 96),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
            ),
            child: Column(
              children: [
                row(
                  PhaleText.confirmGet,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhaLeIcon(size: 18),
                      const SizedBox(width: 4),
                      Text(
                        coinFull(pack.phaLe),
                        style: AppText.number(size: 17, weight: 800),
                      ),
                      Text(
                        ' Pha lê',
                        style: AppText.body(
                          size: 11.5,
                          weight: 800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pack.hasBonus)
                  row(
                    PhaleText.confirmBonus,
                    Container(
                      key: const Key('phale-confirm-bonus'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusSuccess,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        PhaleText.bonus(pack.bonusPercent),
                        style: AppText.button(size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                row(
                  PhaleText.confirmPrice,
                  Text(
                    PhaleText.price(pack.priceVnd),
                    key: const Key('phale-confirm-price'),
                    style: AppText.number(size: 17, weight: 800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${PhaleText.confirmQr}\n${PhaleText.note}\n${PhaleText.confirmAge}',
            key: const Key('phale-confirm-lines'),
            textAlign: TextAlign.center,
            style: _line(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: SkinButton(
                    key: const Key('phale-confirm-later'),
                    label: PhaleText.confirmLater,
                    kind: SkinButtonKind.secondary,
                    height: 44,
                    fontSize: 14,
                    onPressed: c.later,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SkinButton(
                    key: const Key('phale-confirm-yes'),
                    label: PhaleText.confirmOk,
                    height: 44,
                    fontSize: 16,
                    onPressed: c.confirmBuy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// S2b: the order is being made. No button, cannot be dismissed.
class PhaleCreatingPopup extends StatelessWidget {
  const PhaleCreatingPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return PetItemConfirmShell(
      dismissKey: const Key('phale-creating-dismiss'),
      panelKey: const Key('phale-creating'),
      onClose: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: AppColors.primaryBase,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              PhaleText.createTitle,
              style: AppText.title(size: 20, weight: 800),
            ),
            const SizedBox(height: 4),
            Text(PhaleText.createL1, style: _line()),
            Text(PhaleText.createL2, style: _line()),
          ],
        ),
      ),
    );
  }
}

/// S2d: the order could not be made (nothing was charged).
class PhaleCreateFailPopup extends StatelessWidget {
  const PhaleCreateFailPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final c = session.phaleShop;
    return PetItemConfirmShell(
      dismissKey: const Key('phale-createfail-dismiss'),
      panelKey: const Key('phale-createfail'),
      onClose: c.later,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PhaleText.createFailTitle,
            textAlign: TextAlign.center,
            style: AppText.title(size: 20, weight: 800),
          ),
          const SizedBox(height: 8),
          Text(
            PhaleText.createFailBody,
            textAlign: TextAlign.center,
            style: _line(),
          ),
          const SizedBox(height: 14),
          _TwoButtons(
            leftKey: const Key('phale-createfail-later'),
            left: PhaleText.createFailLater,
            onLeft: c.later,
            rightKey: const Key('phale-createfail-retry'),
            right: PhaleText.createFailRetry,
            onRight: c.retry,
          ),
        ],
      ),
    );
  }
}

class _TwoButtons extends StatelessWidget {
  const _TwoButtons({
    required this.leftKey,
    required this.left,
    required this.onLeft,
    required this.rightKey,
    required this.right,
    required this.onRight,
  });

  final Key leftKey, rightKey;
  final String left, right;
  final VoidCallback onLeft, onRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: SkinButton(
              key: leftKey,
              label: left,
              kind: SkinButtonKind.secondary,
              height: 44,
              fontSize: 15,
              onPressed: onLeft,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SkinButton(
              key: rightKey,
              label: right,
              height: 44,
              fontSize: 15,
              onPressed: onRight,
            ),
          ),
        ],
      ),
    );
  }
}

/// S6f: "Hủy đơn này?". The main button keeps the order, so a wrong tap does
/// not lose it.
class PhaleCancelAskPopup extends StatelessWidget {
  const PhaleCancelAskPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final c = session.phaleShop;
    return PetItemConfirmShell(
      dismissKey: const Key('phale-cancelask-dismiss'),
      panelKey: const Key('phale-cancelask'),
      onClose: c.keepOrder,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PhaleText.cancelAskTitle,
            textAlign: TextAlign.center,
            style: AppText.title(size: 20, weight: 800),
          ),
          const SizedBox(height: 6),
          Text(
            PhaleText.cancelAskBody,
            textAlign: TextAlign.center,
            style: _line(),
          ),
          const SizedBox(height: 10),
          const _AmberBox(text: PhaleText.cancelAskHint),
          const SizedBox(height: 14),
          _TwoButtons(
            leftKey: const Key('phale-cancelask-yes'),
            left: PhaleText.cancelAskYes,
            onLeft: c.confirmCancel,
            rightKey: const Key('phale-cancelask-no'),
            right: PhaleText.cancelAskNo,
            onRight: c.keepOrder,
          ),
        ],
      ),
    );
  }
}

/// S2e: the order is cancelled; the old QR must not be paid.
class PhaleCancelledPopup extends StatelessWidget {
  const PhaleCancelledPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final c = session.phaleShop;
    return PetItemConfirmShell(
      dismissKey: const Key('phale-cancelled-dismiss'),
      panelKey: const Key('phale-cancelled'),
      onClose: c.closeOrder,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PhaleText.cancelledTitle,
            textAlign: TextAlign.center,
            style: AppText.title(size: 20, weight: 800),
          ),
          const SizedBox(height: 6),
          Text(
            PhaleText.cancelledBody,
            textAlign: TextAlign.center,
            style: _line(),
          ),
          const SizedBox(height: 10),
          const _AmberBox(text: PhaleText.cancelledHint),
          const SizedBox(height: 14),
          _TwoButtons(
            leftKey: const Key('phale-cancelled-close'),
            left: PhaleText.cancelledClose,
            onLeft: c.closeOrder,
            rightKey: const Key('phale-cancelled-new'),
            right: PhaleText.cancelledNew,
            onRight: c.newOrder,
          ),
        ],
      ),
    );
  }
}

/// S2c: the server confirmed the money and wrote the Pha lê. Both numbers are
/// the server's; nothing here changes the player's balance.
/// A second transfer for the same order: a short notice, no refund promised.
class _DuplicateNotice extends StatelessWidget {
  const _DuplicateNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('phale-duplicate'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.statusWarning, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            PhaleText.duplicateTitle,
            textAlign: TextAlign.center,
            style: AppText.title(size: 14, weight: 800),
          ),
          const SizedBox(height: 2),
          Text(
            PhaleText.duplicateBody,
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 12.5,
              weight: 700,
              color: const Color(0xFF8A5A12),
            ),
          ),
        ],
      ),
    );
  }
}

class PhaleDonePopup extends StatelessWidget {
  const PhaleDonePopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final c = session.phaleShop;
    final o = c.order!;
    final added = o.crystalsGranted ?? o.crystals;
    Widget row(Key key, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppText.body(size: 13, weight: 800)),
          ),
          const PhaLeIcon(size: 18),
          const SizedBox(width: 4),
          Text(value, key: key, style: AppText.number(size: 18, weight: 800)),
        ],
      ),
    );
    return PetItemConfirmShell(
      dismissKey: const Key('phale-done-dismiss'),
      panelKey: const Key('phale-done'),
      onClose: c.finish,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PhaleText.doneTitle,
            textAlign: TextAlign.center,
            style: AppText.title(size: 22, weight: 800),
          ),
          const SizedBox(height: 10),
          PhalePackPicture(packId: o.packId, height: 80),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
            ),
            child: Column(
              children: [
                row(
                  const Key('phale-done-added'),
                  PhaleText.doneAdded,
                  '+${coinFull(added)}',
                ),
                if (o.newBalance != null)
                  row(
                    const Key('phale-done-balance'),
                    PhaleText.doneBalance,
                    coinFull(o.newBalance!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(PhaleText.doneMsg, textAlign: TextAlign.center, style: _line()),
          if (o.duplicatePayment) ...[
            const SizedBox(height: 8),
            const _DuplicateNotice(),
          ],
          const SizedBox(height: 14),
          SkinButton(
            key: const Key('phale-done-ok'),
            label: PhaleText.doneBtn,
            height: 44,
            fontSize: 16,
            onPressed: c.finish,
          ),
        ],
      ),
    );
  }
}

/// S4b: a buy needs more Pha lê than the player has. "Nạp thêm Pha lê" opens
/// the shop on top; the buy popup underneath stays, so "Xong" returns to it.
class PhaleShortPopup extends StatelessWidget {
  const PhaleShortPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final short = session.phaleShort;
    if (short == null) return const SizedBox.shrink();
    Widget cell(String label, int n) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppText.caption(
              size: 12,
              weight: 800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PhaLeIcon(size: 18),
              const SizedBox(width: 4),
              Text(coinFull(n), style: AppText.number(size: 19, weight: 800)),
            ],
          ),
        ],
      ),
    );
    return PetItemConfirmShell(
      dismissKey: const Key('phale-short-dismiss'),
      panelKey: const Key('phale-short'),
      onClose: session.closePhaleShort,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mua ${short.name}?',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppText.title(size: 20, weight: 800),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.statusWarning, width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    cell(PhaleText.poorHave, short.have),
                    Container(
                      width: 1.5,
                      height: 38,
                      color: AppColors.statusWarning,
                    ),
                    cell(PhaleText.poorNeed, short.price),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  PhaleText.poorShort(short.need),
                  key: const Key('phale-short-need'),
                  style: AppText.title(
                    size: 15,
                    weight: 800,
                    color: AppColors.statusDanger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: SkinButton(
                    key: const Key('phale-short-later'),
                    label: PhaleText.poorLater,
                    kind: SkinButtonKind.secondary,
                    height: 44,
                    fontSize: 14,
                    onPressed: session.closePhaleShort,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SkinButton(
                    key: const Key('phale-short-cta'),
                    label: '+  ${PhaleText.poorCta}',
                    height: 44,
                    fontSize: 14,
                    onPressed: () => session.openPhaleShop(
                      need: short.need,
                      name: short.name,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
