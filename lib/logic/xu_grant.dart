/// Money and an optional day floor an admin attaches to `users/{uid}`.
/// The game adds it once, on the next sign-in, then stores [XuGrant.id]
/// in the save so a later login does not pay it again.
class XuGrant {
  const XuGrant({
    required this.id,
    required this.money,
    this.day,
    this.note = '',
  });

  final String id;

  /// Đồng to add. Zero is allowed when [day] raises the morning.
  final int money;

  /// Morning to raise the player to. Never lowers a higher day.
  final int? day;

  final String note;
}

/// What one grant changes on the save that is open now.
class GrantEffect {
  const GrantEffect({required this.grantId, required this.money, this.day});

  final String grantId;
  final int money;
  final int? day;
}

/// Keep in sync with `grantShape()` in firestore.rules.
const maxGrantMoney = 100000000;
const maxGrantDay = 9999;

/// Null when [grant] was already applied, is empty, or does not change
/// this morning. [day] is set only when it is higher than [currentDay].
GrantEffect? grantEffect({
  required String? appliedId,
  required int currentDay,
  required XuGrant? grant,
}) {
  if (grant == null || grant.id.isEmpty || grant.id == appliedId) return null;
  if (grant.money < 0 || grant.money > maxGrantMoney) return null;
  final raise =
      grant.day != null &&
      grant.day! >= 1 &&
      grant.day! <= maxGrantDay &&
      grant.day! > currentDay;
  if (grant.money == 0 && !raise) return null;
  return GrantEffect(
    grantId: grant.id,
    money: grant.money,
    day: raise ? grant.day : null,
  );
}

/// Reads the `grant` map on a user document. Null when it is missing
/// or not shaped like a grant.
XuGrant? grantFromMap(Object? raw) {
  if (raw is! Map) return null;
  final id = raw['id'];
  final money = raw['money'];
  if (id is! String || id.isEmpty || money is! num) return null;
  final day = raw['day'];
  final note = raw['note'];
  return XuGrant(
    id: id,
    money: money.toInt(),
    day: day is num ? day.toInt() : null,
    note: note is String ? note : '',
  );
}
