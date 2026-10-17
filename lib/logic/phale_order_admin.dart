import 'package:flutter/foundation.dart';

/// One paid bank (SePay) Pha lê order, as `/quan-tri` → Nạp Pha lê shows it
/// (`phale_orders/{code}`, written by functions/topup.js).
@immutable
class PhaleOrderRow {
  const PhaleOrderRow({
    required this.code,
    required this.uid,
    this.packId = '',
    this.amount = 0,
    this.crystals = 0,
    this.paidAt,
    this.refundedAt,
    this.refundedBy = '',
    this.clawback = '',
    this.phaleTaken = 0,
    this.phaleDebt = 0,
  });

  /// The transfer code, also the doc id.
  final String code;
  final String uid;
  final String packId;

  /// VND paid.
  final int amount;

  /// Pha lê granted (crystalsGranted).
  final int crystals;
  final DateTime? paidAt;

  /// Set by the admin's "Hoàn tiền"; the server then takes the Pha lê back
  /// and lowers the VIP tier (functions/bank_refund.js, vip.js).
  final DateTime? refundedAt;
  final String refundedBy;

  /// What the server did: 'mail_voided' | 'wallet' | 'balance' | 'none';
  /// empty while it has not run yet.
  final String clawback;
  final int phaleTaken;
  final int phaleDebt;

  bool get refunded => refundedAt != null;

  PhaleOrderRow copyWith({DateTime? refundedAt, String? refundedBy}) =>
      PhaleOrderRow(
        code: code,
        uid: uid,
        packId: packId,
        amount: amount,
        crystals: crystals,
        paidAt: paidAt,
        refundedAt: refundedAt ?? this.refundedAt,
        refundedBy: refundedBy ?? this.refundedBy,
        clawback: clawback,
        phaleTaken: phaleTaken,
        phaleDebt: phaleDebt,
      );
}

/// Reads the paid orders and marks one refunded (firestore.rules: admin
/// only, a paid order, once, only refundedAt / refundedBy).
abstract class PhaleOrderAdmin {
  /// The newest paid orders first.
  Future<List<PhaleOrderRow>> paidOrders({int limit = 200});

  /// "Hoàn tiền": sets refundedAt (server time) and refundedBy. Throws when
  /// it did not happen.
  Future<void> markRefunded(String code);
}

/// In memory (tests).
class MemoryPhaleOrderAdmin implements PhaleOrderAdmin {
  MemoryPhaleOrderAdmin({List<PhaleOrderRow>? orders, this.adminUid = 'admin'})
    : orders = orders ?? [];

  final List<PhaleOrderRow> orders;
  final String adminUid;
  bool fail = false;
  final List<String> marked = [];

  @override
  Future<List<PhaleOrderRow>> paidOrders({int limit = 200}) async {
    if (fail) throw StateError('offline');
    final out = [...orders]
      ..sort(
        (a, b) => (b.paidAt ?? DateTime(0)).compareTo(a.paidAt ?? DateTime(0)),
      );
    return out.take(limit).toList();
  }

  @override
  Future<void> markRefunded(String code) async {
    if (fail) throw StateError('offline');
    final i = orders.indexWhere((o) => o.code == code);
    if (i < 0 || orders[i].refunded) throw StateError('permission-denied');
    orders[i] = orders[i].copyWith(
      refundedAt: DateTime.now(),
      refundedBy: adminUid,
    );
    marked.add(code);
  }
}
