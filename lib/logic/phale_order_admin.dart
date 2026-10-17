import 'package:flutter/foundation.dart';

/// One bank (SePay) Pha lê order, as `/quan-tri` → Nạp Pha lê shows it
/// (`phale_orders/{code}`, written by functions/topup.js).
@immutable
class PhaleOrderRow {
  const PhaleOrderRow({
    required this.code,
    required this.uid,
    this.status = 'paid',
    this.shopName = '',
    this.packId = '',
    this.amount = 0,
    this.crystals = 0,
    this.createdAt,
    this.paidAt,
    this.refundedAt,
    this.refundedBy = '',
    this.refundNote = '',
    this.clawback = '',
    this.phaleTaken = 0,
    this.phaleDebt = 0,
    this.vipAfter,
  });

  /// The transfer code, also the doc id.
  final String code;
  final String uid;

  /// `paid` or `pending` (the panel lists only these two).
  final String status;

  /// The account's shop name (users/{uid}.progress.shopName), '' unknown.
  final String shopName;
  final String packId;

  /// VND paid (or to pay, while pending).
  final int amount;

  /// Pha lê granted (crystalsGranted), or of the pack while pending.
  final int crystals;
  final DateTime? createdAt;
  final DateTime? paidAt;

  /// Set by the admin's "Hoàn tiền"; the server then takes the Pha lê back
  /// and lowers the VIP tier (functions/bank_refund.js, vip.js).
  final DateTime? refundedAt;
  final String refundedBy;

  /// The admin's optional note (admin.topup.refund.note_label).
  final String refundNote;

  /// What the server did: 'mail_voided' | 'wallet' | 'balance' | 'none';
  /// empty while it has not run yet.
  final String clawback;
  final int phaleTaken;
  final int phaleDebt;

  /// The player's VIP tier after the refund (functions/bank_refund.js
  /// recordVipAfter); null until the server wrote it.
  final int? vipAfter;

  bool get refunded => refundedAt != null;
  bool get paid => status == 'paid';
  bool get pending => status == 'pending';

  /// The "Thời gian" column: when it was paid, else when it was made.
  DateTime? get time => paidAt ?? createdAt;

  /// Shop name, or the uid when the name is unknown.
  String get player => shopName.isNotEmpty ? shopName : uid;

  PhaleOrderRow copyWith({
    DateTime? refundedAt,
    String? refundedBy,
    String? refundNote,
    String? clawback,
    int? vipAfter,
  }) => PhaleOrderRow(
    code: code,
    uid: uid,
    status: status,
    shopName: shopName,
    packId: packId,
    amount: amount,
    crystals: crystals,
    createdAt: createdAt,
    paidAt: paidAt,
    refundedAt: refundedAt ?? this.refundedAt,
    refundedBy: refundedBy ?? this.refundedBy,
    refundNote: refundNote ?? this.refundNote,
    clawback: clawback ?? this.clawback,
    phaleTaken: phaleTaken,
    phaleDebt: phaleDebt,
    vipAfter: vipAfter ?? this.vipAfter,
  );
}

/// The filter chips of the panel (admin.topup.filter.*).
enum PhaleOrderFilter { all, paid, pending, refunded }

bool phaleOrderShown(PhaleOrderRow o, PhaleOrderFilter f) => switch (f) {
  PhaleOrderFilter.all => true,
  PhaleOrderFilter.paid => o.paid && !o.refunded,
  PhaleOrderFilter.pending => o.pending,
  PhaleOrderFilter.refunded => o.refunded,
};

/// Reads the orders and marks one refunded (firestore.rules: admin only, a
/// paid order, once, only refundedAt / refundedBy / refundNote).
abstract class PhaleOrderAdmin {
  /// Paid and open (pending) orders, the newest first.
  Future<List<PhaleOrderRow>> orders({int limit = 200});

  /// One order as it is now (to see the server's answer after a refund).
  Future<PhaleOrderRow?> order(String code);

  /// "Đã hoàn tiền": sets refundedAt (server time), refundedBy and the
  /// optional [note]. Throws when it did not happen.
  Future<void> markRefunded(String code, {String note = ''});
}

/// In memory (tests). [vipAfterRefund] plays the server: the tier it
/// writes on an order once the refund ran (none: the server is slow).
class MemoryPhaleOrderAdmin implements PhaleOrderAdmin {
  MemoryPhaleOrderAdmin({
    List<PhaleOrderRow>? orders,
    this.adminUid = 'admin',
    this.vipAfterRefund,
  }) : rows = orders ?? [];

  final List<PhaleOrderRow> rows;
  final String adminUid;
  int? vipAfterRefund;
  bool fail = false;
  final List<String> marked = [];
  final Map<String, String> notes = {};

  @override
  Future<List<PhaleOrderRow>> orders({int limit = 200}) async {
    if (fail) throw StateError('offline');
    final out = [
      ...rows,
    ]..sort((a, b) => (b.time ?? DateTime(0)).compareTo(a.time ?? DateTime(0)));
    return out.take(limit).toList();
  }

  @override
  Future<PhaleOrderRow?> order(String code) async {
    if (fail) throw StateError('offline');
    for (final o in rows) {
      if (o.code == code) return o;
    }
    return null;
  }

  @override
  Future<void> markRefunded(String code, {String note = ''}) async {
    if (fail) throw StateError('offline');
    final i = rows.indexWhere((o) => o.code == code);
    if (i < 0 || rows[i].refunded || !rows[i].paid) {
      throw StateError('permission-denied');
    }
    rows[i] = rows[i].copyWith(
      refundedAt: DateTime.now(),
      refundedBy: adminUid,
      refundNote: note,
    );
    if (vipAfterRefund != null) {
      rows[i] = rows[i].copyWith(clawback: 'wallet', vipAfter: vipAfterRefund);
    }
    marked.add(code);
    if (note.isNotEmpty) notes[code] = note;
  }
}
