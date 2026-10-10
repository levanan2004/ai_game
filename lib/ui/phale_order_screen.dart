import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/phale_shop.dart';
import '../logic/phale_shop_controller.dart';
import '../logic/price_format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'game_toast.dart';
import 'open_url.dart';
import 'phale_shop_screen.dart';
import 'phale_text.dart';
import 'png_download.dart';
import 'ui_skin.dart';

/// S6: "Chuyển khoản". Shows the order the server made: QR, bank, account,
/// amount and the transfer content (the order code), a countdown to
/// `expiresAt`, and the buttons pinned at the bottom. "Tôi đã chuyển" only asks
/// the server again; the Pha lê is written by the server alone.
class PhaleOrderScreen extends StatelessWidget {
  const PhaleOrderScreen({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final c = session.phaleShop;
    final o = c.order;
    if (o == null) return const SizedBox.shrink();
    return OpaqueScreen(
      color: AppColors.bgBase,
      child: SecondTicker(
        builder: (context) {
          final status = c.shownStatus;
          final live = status == PhaleOrderStatus.pending;
          return Stack(
            key: const Key('phale-order'),
            children: [
              Positioned.fill(
                top: 108,
                bottom: 104,
                child: SingleChildScrollView(
                  key: const Key('phale-order-scroll'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (c.offline && live) ...[
                        const _OfflineStrip(),
                        const SizedBox(height: 8),
                      ],
                      _Summary(order: o),
                      const SizedBox(height: 8),
                      _StatusRow(controller: c, status: status),
                      const SizedBox(height: 8),
                      if (status == PhaleOrderStatus.mismatch)
                        _MismatchBody(order: o)
                      else ...[
                        _QrFrame(order: o, dead: !live),
                        if (live) _SaveQr(order: o),
                        const SizedBox(height: 8),
                        if (live)
                          _BankCard(order: o)
                        else
                          _ExpiredCard(order: o),
                      ],
                      if (live) ...[
                        const SizedBox(height: 8),
                        _MemoBox(order: o),
                        const SizedBox(height: 8),
                        const _Rules(),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: TopBar(
                  session: session,
                  showRating: false,
                  showDay: false,
                  showPhaLe: true,
                  phaleAdd: false,
                ),
              ),
              Positioned(
                left: 16,
                top: 54,
                child: SkinRoundButton(
                  key: const Key('phale-order-back'),
                  kind: SkinRound.back,
                  width: 40,
                  onTap: c.backToShop,
                ),
              ),
              const Positioned(
                left: 70,
                right: 70,
                top: 54,
                child: Center(
                  child: SkinRibbon(
                    title: PhaleText.orderTitle,
                    width: 200,
                    height: 46,
                    fontSize: 18,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 104,
                child: _BottomBar(session: session, status: status),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('phale-offline'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.statusWarning, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: Color(0xFF8A5A12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              PhaleText.offlineBanner,
              style: AppText.body(
                size: 12.5,
                weight: 800,
                color: const Color(0xFF8A5A12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.order});

  final PhaleOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('phale-summary'),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: AppColors.surfaceBorderStrong, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              Art.phale(order.packId),
              alignment: Alignment.bottomCenter,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${coinFull(order.crystals)} Pha lê',
            style: AppText.title(size: 15, weight: 800),
          ),
          if (order.bonusPercent > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primaryPressed,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                PhaleText.bonus(order.bonusPercent),
                style: AppText.button(size: 12.5, color: Colors.white),
              ),
            ),
          ],
          const Spacer(),
          Text(
            vndLabel(order.amount),
            key: const Key('phale-summary-price'),
            style: AppText.number(
              size: 17,
              weight: 800,
              color: AppColors.primaryPressed,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.controller, required this.status});

  final PhaleShopController controller;
  final PhaleOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final String label;
    final Color fill;
    final Color fg;
    Widget? lead;
    switch (status) {
      case PhaleOrderStatus.expired:
        label = PhaleText.expiredChip;
        fill = const Color(0xFFFBE4E1);
        fg = AppColors.statusDanger;
      case PhaleOrderStatus.mismatch:
        label = PhaleText.mismatchChip;
        fill = AppColors.accentSoft;
        fg = const Color(0xFF8A5A12);
      case _:
        label = c.offline ? PhaleText.orderRetry : PhaleText.orderWait;
        fill = AppColors.primarySoft;
        fg = AppColors.primaryPressed;
        lead = SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
        );
    }
    final ended = status != PhaleOrderStatus.pending;
    return Row(
      children: [
        Container(
          key: const Key('phale-status'),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: fg, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?lead,
              if (lead != null) const SizedBox(width: 6),
              Text(label, style: AppText.button(size: 13, color: fg)),
            ],
          ),
        ),
        const Spacer(),
        Container(
          key: const Key('phale-timer'),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                ended || c.remaining == Duration.zero
                    ? PhaleText.orderTimerEnd
                    : PhaleText.orderTimer(PhaleText.clock(c.remaining)),
                style: AppText.number(size: 14, weight: 800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QrFrame extends StatelessWidget {
  const _QrFrame({required this.order, required this.dead});

  final PhaleOrder order;
  final bool dead;

  @override
  Widget build(BuildContext context) {
    final url = order.qrImageUrl;
    final fake = url == null;
    // A dead code is dimmed and smaller, so the expired card and its two
    // lines of hint fit at 360x640 without scrolling.
    final side = dead ? 112.0 : 164.0;
    final asset = Image.asset(
      Art.phaleQr,
      width: side,
      height: side,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => SizedBox(width: side, height: side),
    );
    return Center(
      child: Container(
        key: const Key('phale-qr'),
        width: 236,
        height: dead ? 136 : 188,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: dead ? 0.25 : 1,
              child: fake
                  ? asset
                  : Image.network(
                      url,
                      width: side,
                      height: side,
                      errorBuilder: (_, _, _) => asset,
                    ),
            ),
            if (fake || order.demo)
              Positioned(
                right: 8,
                top: 6,
                child: Text(
                  PhaleText.qrFake,
                  key: const Key('phale-qr-fake'),
                  style: AppText.caption(
                    size: 10,
                    weight: 800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (dead)
              Container(
                key: const Key('phale-qr-lock'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.statusDanger,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  PhaleText.expiredLock,
                  style: AppText.button(size: 15, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SaveQr extends StatelessWidget {
  const _SaveQr({required this.order});

  final PhaleOrder order;

  Future<void> _save() async {
    final url = order.qrImageUrl;
    if (url != null) {
      openUrl(url);
      return;
    }
    final data = await rootBundle.load(Art.phaleQr);
    await downloadPng(data.buffer.asUint8List(), '${order.orderId}.png');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('phale-saveqr'),
      behavior: HitTestBehavior.opaque,
      onTap: _save,
      child: SizedBox(
        height: 36,
        child: Center(
          child: Text(
            PhaleText.orderSaveQr,
            style: AppText.body(
              size: 13.5,
              weight: 800,
              color: AppColors.primaryPressed,
            ).copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ),
    );
  }
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showGameToast(context, PhaleText.orderCopied);
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.order});

  final PhaleOrder order;

  @override
  Widget build(BuildContext context) {
    Widget row(
      String key,
      String label,
      String value, {
      String? copy,
      Color? color,
      bool demo = false,
    }) {
      return SizedBox(
        height: 27,
        child: Row(
          children: [
            Text(
              label,
              style: AppText.body(
                size: 12,
                weight: 700,
                color: AppColors.textSecondary,
              ),
            ),
            if (demo) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  PhaleText.demoChip,
                  style: AppText.caption(
                    size: 9.5,
                    weight: 800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                key: Key(key),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.number(size: 15.5, weight: 800, color: color),
              ),
            ),
            if (copy != null)
              GestureDetector(
                key: Key('$key-copy'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _copy(context, copy),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    PhaleText.orderCopySmall,
                    style: AppText.button(
                      size: 12.5,
                      color: AppColors.primaryPressed,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('phale-bank'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
      ),
      child: Column(
        children: [
          row(
            'phale-bank-name',
            PhaleText.orderBank,
            order.bank,
            demo: order.demo,
          ),
          row('phale-bank-owner', PhaleText.orderName, order.accountName),
          row(
            'phale-bank-acc',
            PhaleText.orderAcc,
            order.accountNo,
            copy: order.accountNo,
          ),
          row(
            'phale-bank-amount',
            PhaleText.orderAmount,
            vndLabel(order.amount),
            copy: '${order.amount}',
            color: AppColors.primaryPressed,
          ),
        ],
      ),
    );
  }
}

/// The transfer content box (same look as the Đại thiện nhân one): the order
/// code, copied exactly.
class _MemoBox extends StatelessWidget {
  const _MemoBox({required this.order});

  final PhaleOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('phale-memo'),
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PhaleText.orderMemo,
                  style: AppText.caption(
                    size: 10.5,
                    weight: 700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  order.transferContent,
                  key: const Key('phale-memo-code'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.number(size: 19, weight: 800),
                ),
                Text(
                  PhaleText.orderMemoSub,
                  style: AppText.caption(
                    size: 10.5,
                    weight: 700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: const Key('phale-memo-copy'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _copy(context, order.transferContent),
            child: Container(
              width: 64,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.primaryBase, width: 1.5),
              ),
              child: Text(
                PhaleText.orderCopy,
                style: AppText.button(
                  size: 12.5,
                  color: AppColors.primaryPressed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) {
    final base = AppText.body(
      size: 11.5,
      weight: 700,
      color: AppColors.textSecondary,
    );
    return Column(
      children: [
        Text(PhaleText.orderRule1, textAlign: TextAlign.center, style: base),
        Text(
          PhaleText.orderRule2,
          textAlign: TextAlign.center,
          style: base.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.primaryPressed,
          ),
        ),
        Text(PhaleText.orderRule3, textAlign: TextAlign.center, style: base),
      ],
    );
  }
}

/// S6c: the order ran out (or was closed): no QR to pay, a support hint.
class _ExpiredCard extends StatelessWidget {
  const _ExpiredCard({required this.order});

  final PhaleOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('phale-expired'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            PhaleText.expiredTitle,
            style: AppText.title(size: 15, weight: 800),
          ),
          const SizedBox(height: 4),
          Text(
            PhaleText.expiredHint,
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 12,
              weight: 700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _MemoBox(order: order),
        ],
      ),
    );
  }
}

/// S6d: money came, but the amount or the content did not match.
class _MismatchBody extends StatelessWidget {
  const _MismatchBody({required this.order});

  final PhaleOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('phale-mismatch'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.statusWarning, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PhaleText.mismatchTitle,
            textAlign: TextAlign.center,
            style: AppText.title(size: 16, weight: 800),
          ),
          const SizedBox(height: 6),
          Text(
            PhaleText.mismatchBody,
            textAlign: TextAlign.center,
            style: AppText.body(size: 12.5, weight: 700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  PhaleText.mismatchNeed,
                  style: AppText.body(
                    size: 12,
                    weight: 700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                vndLabel(order.amount),
                key: const Key('phale-mismatch-amount'),
                style: AppText.number(size: 16, weight: 800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _MemoBox(order: order),
          const SizedBox(height: 8),
          Text(
            PhaleText.mismatchFoot,
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 12,
              weight: 700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar pinned to the bottom (104 tall): the main button and the text
/// button under it. They stay on screen while the content above scrolls.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.session, required this.status});

  final ShopSession session;
  final PhaleOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final c = session.phaleShop;
    final live = status == PhaleOrderStatus.pending;
    final String main;
    final String second;
    final VoidCallback? onMain;
    final VoidCallback onSecond;
    var busy = false;
    switch (status) {
      case PhaleOrderStatus.pending:
        main = c.checking ? PhaleText.orderCheck : PhaleText.orderPaid;
        busy = c.checking;
        second = PhaleText.orderCancel;
        onSecond = c.askCancel;
        onMain = (c.checking || c.offline)
            ? null
            : () async {
                final still = await c.tapPaid();
                if (still == true && context.mounted) {
                  showGameToast(context, PhaleText.orderNotYet);
                }
              };
      case PhaleOrderStatus.mismatch:
        main = PhaleText.mismatchSupport;
        second = PhaleText.cancelledClose;
        onSecond = c.closeOrder;
        onMain = () => _support(context, c.order!);
      case _:
        main = PhaleText.cancelledNew;
        second = PhaleText.cancelledClose;
        onSecond = c.closeOrder;
        onMain = c.newOrder;
    }
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgBase,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            width: double.infinity,
            child: Stack(
              children: [
                SkinButton(
                  key: const Key('phale-paid'),
                  label: main,
                  height: 48,
                  fontSize: 17,
                  enabled: onMain != null,
                  onPressed: onMain,
                ),
                if (busy)
                  const Positioned(
                    left: 24,
                    top: 14,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            key: const Key('phale-second'),
            behavior: HitTestBehavior.opaque,
            onTap: onSecond,
            child: SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  second,
                  style: AppText.title(
                    size: 15,
                    weight: 800,
                    color: live
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Liên hệ hỗ trợ": opens the server's support link when it gave one, else a
  /// mail to [PhaleText.supportEmail] with the order code in it.
  void _support(BuildContext context, PhaleOrder o) {
    openUrl(o.supportContact ?? PhaleText.supportMailto(o.orderId));
  }
}
