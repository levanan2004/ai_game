import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/economy.dart';
import '../data/game_data.dart';
import '../logic/phale_order_admin.dart';
import '../logic/price_format.dart' show coinFull;
import '../theme/tokens.dart';
import 'common.dart';

/// Texts of the panel (Nhất, chu_tinh_nang_moi.md 10b, admin.topup.*).
class AdminTopupText {
  const AdminTopupText._();

  static const title = 'Nạp Pha lê'; // admin.topup.title
  static const filterAll = 'Tất cả'; // admin.topup.filter.all
  static const filterPaid = 'Đã trả tiền'; // admin.topup.filter.paid
  static const filterPending = 'Đang chờ'; // admin.topup.filter.pending
  static const filterRefunded = 'Đã hoàn tiền'; // admin.topup.filter.refunded
  static const colTime = 'Thời gian'; // admin.topup.col.time
  static const colOrder = 'Mã đơn'; // admin.topup.col.order
  static const colPlayer = 'Tiệm'; // admin.topup.col.player
  static const colAmount = 'Số tiền'; // admin.topup.col.amount
  static const colPhaLe = 'Pha lê'; // admin.topup.col.pha_le
  static const colStatus = 'Trạng thái'; // admin.topup.col.status
  static const search = 'Tìm theo mã đơn hoặc tên tiệm'; // admin.topup.search
  static const empty = 'Chưa có đơn nạp nào.'; // admin.topup.empty
  static const refundBtn = 'Hoàn tiền'; // admin.topup.refund_btn
  static String refundTitle(String orderId) =>
      'Đánh dấu đơn $orderId đã hoàn tiền?'; // admin.topup.refund.title
  static String refundBody(String amount, String phaLe, String player) =>
      'Chỉ bấm khi bạn đã chuyển trả $amount cho người chơi. Server sẽ thu lại '
      '$phaLe Pha lê của đơn này (thư chưa nhận thì hủy, đã nhận thì trừ vào '
      'số dư, thiếu thì ghi nợ) và tính lại cấp VIP của $player. Không hoàn '
      'tác được.'; // admin.topup.refund.body
  static String refundBodyNoClawback(String amount, String player) =>
      'Chỉ bấm khi bạn đã chuyển trả $amount cho người chơi. Server sẽ tính '
      'lại cấp VIP của $player. Pha lê của đơn này không bị thu lại vì đang '
      'tắt thu hồi. Không hoàn tác được.'; // admin.topup.refund.body_no_clawback
  static const noClawbackNote =
      'Không thu lại Pha lê (đang tắt thu hồi).'; // admin.topup.refund.no_clawback_note
  static const noteLabel =
      'Ghi chú (không bắt buộc)'; // admin.topup.refund.note_label
  static const noteHint =
      'Ví dụ: đã chuyển trả qua Vietcombank lúc 15:20'; // admin.topup.refund.note_hint
  static const confirm = 'Đã hoàn tiền'; // admin.topup.refund.confirm
  static const cancel = 'Thôi'; // admin.topup.refund.cancel
  static String done(String player, int vipLevel) =>
      'Đã đánh dấu hoàn tiền. $player giờ là VIP $vipLevel.'; // admin.topup.refund.done
  static String doneNoVip(String player) =>
      'Đã đánh dấu hoàn tiền. $player không còn cấp VIP.'; // admin.topup.refund.done_no_vip
  static const fail =
      'Chưa đánh dấu được. Bạn thử lại nhé.'; // admin.topup.refund.fail
  static const already =
      'Đơn này đã được đánh dấu hoàn tiền rồi.'; // admin.topup.refund.already
  static String statusRefunded(DateTime? at) =>
      'Đã hoàn tiền ${phaleAdminDate(at)}'; // admin.topup.status.refunded

  static String filter(PhaleOrderFilter f) => switch (f) {
    PhaleOrderFilter.all => filterAll,
    PhaleOrderFilter.paid => filterPaid,
    PhaleOrderFilter.pending => filterPending,
    PhaleOrderFilter.refunded => filterRefunded,
  };

  /// The "Trạng thái" cell.
  static String status(PhaleOrderRow o) => o.refunded
      ? statusRefunded(o.refundedAt)
      : o.pending
      ? filterPending
      : filterPaid;
}

/// dd/MM/yyyy HH:mm in local time ('' without a time).
String phaleAdminDate(DateTime? t) {
  if (t == null) return '';
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// `/quan-tri` → Nạp Pha lê: the bank orders (paid and open), newest first,
/// with "Hoàn tiền" for a paid one refunded by hand at the bank. Marking sets
/// refundedAt; the server then takes the order's Pha lê back (unclaimed mail
/// voided, else from the balance, the rest as debt that blocks spending),
/// lowers the VIP tier and writes the new tier on the order (vipAfter), which
/// the panel waits for to say "{player} giờ là VIP {n}". Once, no undo.
class PhaleOrderAdminPanel extends StatefulWidget {
  const PhaleOrderAdminPanel({
    super.key,
    required this.orders,
    required this.onClose,
    this.pollEvery = const Duration(seconds: 1),
    this.pollTries = 15,
    this.loadClawBack = economyClawBack,
  });

  final PhaleOrderAdmin orders;

  /// economy.json `vip.refund.clawBackPhaLe` (tests pass their own): picks
  /// the confirm text (admin.topup.refund.body or body_no_clawback).
  final Future<bool> Function() loadClawBack;
  final VoidCallback onClose;

  /// How often and how long the panel looks for the server's answer.
  final Duration pollEvery;
  final int pollTries;

  @override
  State<PhaleOrderAdminPanel> createState() => _PhaleOrderAdminPanelState();
}

/// `vip.refund.clawBackPhaLe` of the bundled economy.json (true if the file
/// cannot be read: the server's default too).
Future<bool> economyClawBack() async {
  try {
    final raw = jsonDecode(await rootBundle.loadString(GameData.economyAsset));
    return Economy.fromJson(raw).vip.clawBackPhaLe;
  } catch (_) {
    return true;
  }
}

/// What the server did on a refund, for the row.
String phaleClawbackLabel(PhaleOrderRow o) {
  if (!o.refunded) return '';
  final debt = o.phaleDebt > 0 ? ', còn nợ ${coinFull(o.phaleDebt)}' : '';
  return switch (o.clawback) {
    '' => 'Đang thu hồi Pha lê…',
    'mail_voided' => 'Thư Pha lê chưa nhận đã bị huỷ',
    'none' => 'Không có tài khoản để thu hồi',
    // economy.json vip.refund.clawBackPhaLe is false (functions/apple_iap.js).
    'off' => AdminTopupText.noClawbackNote,
    _ => 'Đã thu hồi ${coinFull(o.phaleTaken)} Pha lê$debt',
  };
}

class _PhaleOrderAdminPanelState extends State<PhaleOrderAdminPanel> {
  List<PhaleOrderRow>? _list;
  String? _error;
  String? _loadError;
  String? _notice;
  String _query = '';
  PhaleOrderFilter _filter = PhaleOrderFilter.all;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final all = await widget.orders.orders();
      if (mounted) setState(() => _list = all);
    } catch (_) {
      if (mounted) {
        setState(() {
          _list = const [];
          _loadError = 'Chưa tải được đơn nạp.';
        });
      }
    }
  }

  Future<void> _refund(PhaleOrderRow o) async {
    final clawBack = await widget.loadClawBack();
    if (!mounted) return;
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _RefundDialog(order: o, clawBack: clawBack),
    );
    if (text == null || !mounted) return;
    setState(() {
      _busy.add(o.code);
      _notice = null;
      _error = null;
    });
    String? error;
    String? notice;
    try {
      await widget.orders.markRefunded(o.code, note: text);
      notice = await _waitForTier(o);
    } catch (_) {
      // Already marked (another tab, a double tap) or refused.
      PhaleOrderRow? now;
      try {
        now = await widget.orders.order(o.code);
      } catch (_) {}
      error = now != null && now.refunded
          ? AdminTopupText.already
          : AdminTopupText.fail;
    }
    if (!mounted) return;
    setState(() {
      _busy.remove(o.code);
      _error = error;
      _notice = notice;
    });
    await _load();
  }

  /// Waits for the server's new tier on the order; null if it is slow (the
  /// row then shows the refund and "Đang thu hồi Pha lê…").
  Future<String?> _waitForTier(PhaleOrderRow o) async {
    for (var i = 0; i < widget.pollTries; i++) {
      PhaleOrderRow? now;
      try {
        now = await widget.orders.order(o.code);
      } catch (_) {}
      final level = now?.vipAfter;
      if (level != null) {
        final player = now!.player;
        return level > 0
            ? AdminTopupText.done(player, level)
            : AdminTopupText.doneNoVip(player);
      }
      if (!mounted) return null;
      await Future<void>.delayed(widget.pollEvery);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final q = _query.trim().toLowerCase();
    final shown = list == null
        ? null
        : [
            for (final o in list)
              if (phaleOrderShown(o, _filter) &&
                  (q.isEmpty ||
                      o.code.toLowerCase().contains(q) ||
                      o.shopName.toLowerCase().contains(q) ||
                      o.uid.toLowerCase().contains(q)))
                o,
          ];
    return Material(
      color: AppColors.bgBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  child: Text(
                    AdminTopupText.title,
                    style: AppText.title(size: 22),
                  ),
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Wrap(
              spacing: 6,
              children: [
                for (final f in PhaleOrderFilter.values)
                  ChoiceChip(
                    key: Key('phale-filter-${f.name}'),
                    label: Text(AdminTopupText.filter(f)),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              key: const Key('phale-admin-search'),
              decoration: const InputDecoration(
                hintText: AdminTopupText.search,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                _notice!,
                key: const Key('phale-admin-notice'),
                style: AppText.body(size: 13, weight: 800),
              ),
            ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                _loadError!,
                key: const Key('phale-admin-load-error'),
                style: AppText.caption(color: AppColors.statusDanger),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                _error!,
                key: const Key('phale-admin-error'),
                style: AppText.caption(color: AppColors.statusDanger),
              ),
            ),
          Expanded(
            child: shown == null
                ? const Center(child: CircularProgressIndicator())
                : shown.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      AdminTopupText.empty,
                      key: const Key('phale-admin-empty'),
                      style: AppText.caption(),
                    ),
                  )
                : _table(shown),
          ),
        ],
      ),
    );
  }

  Widget _table(List<PhaleOrderRow> rows) {
    final head = AppText.caption(size: 12, weight: 800);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: const Key('phale-admin-table'),
          columnSpacing: 16,
          headingRowHeight: 36,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 72,
          columns: [
            DataColumn(label: Text(AdminTopupText.colTime, style: head)),
            DataColumn(label: Text(AdminTopupText.colOrder, style: head)),
            DataColumn(label: Text(AdminTopupText.colPlayer, style: head)),
            DataColumn(
              numeric: true,
              label: Text(AdminTopupText.colAmount, style: head),
            ),
            DataColumn(
              numeric: true,
              label: Text(AdminTopupText.colPhaLe, style: head),
            ),
            DataColumn(label: Text(AdminTopupText.colStatus, style: head)),
            const DataColumn(label: SizedBox.shrink()),
          ],
          rows: [for (final o in rows) _row(o)],
        ),
      ),
    );
  }

  DataRow _row(PhaleOrderRow o) {
    final busy = _busy.contains(o.code);
    final cell = AppText.body(size: 13, weight: 700);
    return DataRow(
      cells: [
        DataCell(Text(phaleAdminDate(o.time), style: cell)),
        DataCell(Text(o.code, key: Key('phale-order-${o.code}'), style: cell)),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.player, style: cell),
              if (o.shopName.isNotEmpty)
                Text(o.uid, style: AppText.caption(size: 10.5)),
            ],
          ),
        ),
        DataCell(Text('${coinFull(o.amount)}đ', style: cell)),
        DataCell(Text(coinFull(o.crystals), style: cell)),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AdminTopupText.status(o),
                key: o.refunded
                    ? Key('phale-refunded-${o.code}')
                    : Key('phale-status-${o.code}'),
                style: o.refunded
                    ? AppText.body(
                        size: 12.5,
                        weight: 800,
                        color: AppColors.statusDanger,
                      )
                    : cell,
              ),
              if (o.refunded)
                Text(phaleClawbackLabel(o), style: AppText.caption(size: 11)),
              if (o.refunded && o.refundNote.isNotEmpty)
                Text(
                  o.refundNote,
                  key: Key('phale-note-${o.code}'),
                  style: AppText.caption(size: 11),
                ),
            ],
          ),
        ),
        DataCell(
          o.paid && !o.refunded
              ? SizedBox(
                  width: 110,
                  height: 36,
                  child: ChunkyButton(
                    key: Key('phale-refund-${o.code}'),
                    label: AdminTopupText.refundBtn,
                    kind: ButtonKind.secondary,
                    onPressed: busy ? null : () => _refund(o),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// The confirm (admin.topup.refund.*): pops the note ('' none), or null.
class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.order, this.clawBack = true});

  final PhaleOrderRow order;

  /// False: economy.json vip.refund.clawBackPhaLe is off.
  final bool clawBack;

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return AlertDialog(
      key: const Key('phale-refund-confirm'),
      title: Text(AdminTopupText.refundTitle(o.code)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.clawBack
                  ? AdminTopupText.refundBody(
                      '${coinFull(o.amount)}đ',
                      coinFull(o.crystals),
                      o.player,
                    )
                  : AdminTopupText.refundBodyNoClawback(
                      '${coinFull(o.amount)}đ',
                      o.player,
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('phale-refund-note'),
              controller: _note,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: AdminTopupText.noteLabel,
                hintText: AdminTopupText.noteHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('phale-refund-no'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AdminTopupText.cancel),
        ),
        TextButton(
          key: const Key('phale-refund-yes'),
          onPressed: () => Navigator.of(context).pop(_note.text),
          child: const Text(AdminTopupText.confirm),
        ),
      ],
    );
  }
}
