import 'package:flutter/material.dart';

import '../logic/phale_order_admin.dart';
import '../logic/price_format.dart' show coinFull;
import '../theme/tokens.dart';
import 'common.dart';

/// `/quan-tri` → Nạp Pha lê: the paid bank transfers, newest first, with
/// "Hoàn tiền" for one refunded by hand at the bank. Marking sets refundedAt;
/// the server then takes the order's Pha lê back (unclaimed mail voided,
/// else from the balance, the rest as debt) and lowers the VIP tier at once,
/// as for an App Store refund. Once per order, no undo.
class PhaleOrderAdminPanel extends StatefulWidget {
  const PhaleOrderAdminPanel({
    super.key,
    required this.orders,
    required this.onClose,
  });

  final PhaleOrderAdmin orders;
  final VoidCallback onClose;

  @override
  State<PhaleOrderAdminPanel> createState() => _PhaleOrderAdminPanelState();
}

/// What the server did on a refund, for the row.
String phaleClawbackLabel(PhaleOrderRow o) {
  if (!o.refunded) return '';
  final debt = o.phaleDebt > 0 ? ', còn nợ ${coinFull(o.phaleDebt)}' : '';
  return switch (o.clawback) {
    '' => 'Đang thu hồi Pha lê…',
    'mail_voided' => 'Thư Pha lê chưa nhận đã bị huỷ',
    'none' => 'Không có tài khoản để thu hồi',
    _ => 'Đã thu hồi ${coinFull(o.phaleTaken)} Pha lê$debt',
  };
}

String _date(DateTime? t) {
  if (t == null) return '';
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

class _PhaleOrderAdminPanelState extends State<PhaleOrderAdminPanel> {
  List<PhaleOrderRow>? _list;
  String? _error;
  String _query = '';
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final all = await widget.orders.paidOrders();
      if (mounted) setState(() => _list = all);
    } catch (_) {
      if (mounted) {
        setState(() {
          _list = const [];
          _error = 'Chưa tải được đơn nạp.';
        });
      }
    }
  }

  Future<void> _refund(PhaleOrderRow o) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('phale-refund-confirm'),
        title: const Text('Đánh dấu hoàn tiền?'),
        content: Text(
          'Đơn ${o.code}: ${coinFull(o.amount)}đ, ${coinFull(o.crystals)} '
          'Pha lê, tài khoản ${o.uid}.\nChỉ đánh dấu khi đã chuyển trả tiền ở '
          'ngân hàng. Máy chủ sẽ thu hồi số Pha lê của đơn và tính lại cấp '
          'VIP ngay. Chỉ một lần, không hoàn tác được.',
        ),
        actions: [
          TextButton(
            key: const Key('phale-refund-no'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Để xem lại'),
          ),
          TextButton(
            key: const Key('phale-refund-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hoàn tiền'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy.add(o.code));
    String? error;
    try {
      await widget.orders.markRefunded(o.code);
    } catch (_) {
      error = 'Không đánh dấu được đơn ${o.code}.';
    }
    if (!mounted) return;
    setState(() {
      _busy.remove(o.code);
      _error = error;
    });
    if (error == null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final q = _query.trim().toLowerCase();
    final shown = list == null || q.isEmpty
        ? list
        : [
            for (final o in list)
              if (o.code.toLowerCase().contains(q) ||
                  o.uid.toLowerCase().contains(q))
                o,
          ];
    return Material(
      color: AppColors.bgBase,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  key: const Key('phale-admin-back'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text('Nạp Pha lê', style: AppText.title(size: 22)),
                ),
                IconButton(
                  key: const Key('phale-admin-reload'),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              key: const Key('phale-admin-search'),
              decoration: const InputDecoration(
                hintText: 'Tìm mã chuyển khoản hoặc uid',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: shown == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    children: [
                      if (_error != null)
                        Text(
                          _error!,
                          key: const Key('phale-admin-error'),
                          style: AppText.caption(color: AppColors.statusDanger),
                        ),
                      if (shown.isEmpty && _error == null)
                        Text('Chưa có đơn nạp.', style: AppText.caption()),
                      for (final o in shown) _row(o),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(PhaleOrderRow o) {
    final busy = _busy.contains(o.code);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CardBox(
        key: Key('phale-order-${o.code}'),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.code, style: AppText.body(size: 14, weight: 800)),
                  Text(
                    '${coinFull(o.amount)}đ · ${coinFull(o.crystals)} Pha lê'
                    '${o.packId.isEmpty ? '' : ' · ${o.packId}'}',
                    style: AppText.body(size: 13, weight: 700),
                  ),
                  Text(
                    [
                      _date(o.paidAt),
                      o.uid,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: AppText.caption(size: 11),
                  ),
                  if (o.refunded) ...[
                    Text(
                      'Đã hoàn tiền ${_date(o.refundedAt)}',
                      key: Key('phale-refunded-${o.code}'),
                      style: AppText.body(
                        size: 12.5,
                        weight: 800,
                        color: AppColors.statusDanger,
                      ),
                    ),
                    Text(
                      phaleClawbackLabel(o),
                      style: AppText.caption(size: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (!o.refunded)
              SizedBox(
                width: 120,
                height: 40,
                child: ChunkyButton(
                  key: Key('phale-refund-${o.code}'),
                  label: 'Hoàn tiền',
                  kind: ButtonKind.secondary,
                  onPressed: busy ? null : () => _refund(o),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
