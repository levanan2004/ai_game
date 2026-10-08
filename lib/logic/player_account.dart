import 'format.dart';
import 'pet.dart';
import 'xu_grant.dart';

/// One signed-in player, joined from `profiles/{uid}` and `users/{uid}`.
class PlayerAccount {
  const PlayerAccount({
    required this.uid,
    this.name = '',
    this.email = '',
    this.shopName = '',
    this.money,
    this.day,
    this.bouquets = 0,
    this.joinedAt,
    this.updatedAt,
    this.grant,
    this.appliedGrantId,
    this.gift,
    this.appliedGiftId,
    this.pocket = const PetPocket(),
  });

  final String uid;
  final String name;
  final String email;
  final String shopName;

  /// Null when this account has no cloud save yet.
  final int? money;
  final int? day;
  final int bouquets;

  /// First Google sign-in, `users/{uid}.joinedAt`. Null when it was never
  /// stored. A morning at day 2 or later is already an established account.
  final DateTime? joinedAt;

  /// Last cloud save, not the first day they played.
  final DateTime? updatedAt;

  final XuGrant? grant;
  final String? appliedGrantId;
  final PetGiftBox? gift;
  final String? appliedGiftId;
  final PetPocket pocket;

  PlayerAccount withGift(PetGiftBox gift) => PlayerAccount(
    uid: uid,
    name: name,
    email: email,
    shopName: shopName,
    money: money,
    day: day,
    bouquets: bouquets,
    joinedAt: joinedAt,
    updatedAt: updatedAt,
    grant: grant,
    appliedGrantId: appliedGrantId,
    gift: gift,
    appliedGiftId: appliedGiftId,
    pocket: pocket,
  );

  bool get hasSave => money != null && day != null;
}

enum AccountSort { day, money, bouquets, updated, joined, shop }

/// Case-insensitive match on email, name, shop, or uid.
bool accountMatches(PlayerAccount account, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [
    account.uid,
    account.email,
    account.name,
    account.shopName,
  ].any((part) => part.toLowerCase().contains(q));
}

/// A new list. Missing numbers, dates, and names sort last either way.
/// [ascending] false is giảm dần: a higher day, more money, a newer
/// time, or a name later in the alphabet comes first. Equal rows stay
/// in uid order so the list does not jump.
List<PlayerAccount> sortAccounts(
  List<PlayerAccount> rows,
  AccountSort sort, {
  bool ascending = false,
}) {
  final copy = [...rows];
  copy.sort((a, b) {
    final c = switch (sort) {
      AccountSort.day => _num(a.day, b.day, ascending: ascending),
      AccountSort.money => _num(a.money, b.money, ascending: ascending),
      AccountSort.bouquets => _num(
        a.bouquets,
        b.bouquets,
        ascending: ascending,
      ),
      AccountSort.updated => _time(
        a.updatedAt,
        b.updatedAt,
        ascending: ascending,
      ),
      AccountSort.joined => _time(a.joinedAt, b.joinedAt, ascending: ascending),
      AccountSort.shop => _text(a.shopName, b.shopName, ascending: ascending),
    };
    if (c != 0) return c;
    return a.uid.compareTo(b.uid);
  });
  return copy;
}

int _num(int? a, int? b, {required bool ascending}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  final cmp = a.compareTo(b);
  return ascending ? cmp : -cmp;
}

int _time(DateTime? a, DateTime? b, {required bool ascending}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  final cmp = a.compareTo(b);
  return ascending ? cmp : -cmp;
}

int _text(String a, String b, {required bool ascending}) {
  if (a.trim().isEmpty && b.trim().isEmpty) return 0;
  if (a.trim().isEmpty) return 1;
  if (b.trim().isEmpty) return -1;
  final cmp = a.toLowerCase().compareTo(b.toLowerCase());
  return ascending ? cmp : -cmp;
}

/// `dd/MM/yyyy`, or with the clock. Null is "Chưa ghi".
String accountWhen(DateTime? time, {bool clock = false}) {
  if (time == null) return 'Chưa ghi';
  final local = time.toLocal();
  final date =
      '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year}';
  if (!clock) return date;
  final hm =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '$date $hm';
}

/// Digits only, so "50.000" and "50 000" are 50000. Empty is null.
int? readDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// Null when the form can be sent. [money] null means the field was empty.
String? grantFormError({
  required int? money,
  required int? day,
  required int? currentDay,
}) {
  final add = money ?? 0;
  if (add == 0 && day == null) {
    return 'Nhập số tiền hoặc màn muốn nâng.';
  }
  if (add < 0 || add > maxGrantMoney) {
    return 'Tiền tối đa 100.000.000 đồng.';
  }
  if (day != null && (day < 1 || day > maxGrantDay)) {
    return 'Màn từ 1 đến 9999.';
  }
  if (day != null && currentDay != null && day <= currentDay && add == 0) {
    return 'Màn trên cloud đã là $currentDay. Nhập màn cao hơn, hoặc nhập tiền.';
  }
  return null;
}

/// One line for the account card. A grant still on the document is
/// waiting until its id is stored in the save.
String grantStatus(PlayerAccount account) {
  final grant = account.grant;
  if (grant == null) return 'Chưa gửi khoản đền.';
  final parts = <String>[
    if (grant.money > 0) formatK(grant.money),
    if (grant.day != null) 'màn ${grant.day}',
  ];
  final what = parts.join(', ');
  if (grant.id == account.appliedGrantId) {
    return 'Đã vào save: $what.';
  }
  return 'Đang chờ lần đăng nhập sau: $what.';
}

const accountPageSize = 20;

/// How many cloud saves to read in one round. Each save is the whole
/// game, so the list must not wait on every account before the first page.
const accountSaveBatch = 10;

int accountPageCount(int total) {
  if (total <= 0) return 1;
  return (total + accountPageSize - 1) ~/ accountPageSize;
}

/// One page of an already filtered, already sorted list.
List<T> accountPage<T>(List<T> rows, int page) {
  if (rows.isEmpty || page < 0) return const [];
  final start = page * accountPageSize;
  if (start >= rows.length) return const [];
  final end = start + accountPageSize;
  return rows.sublist(start, end > rows.length ? rows.length : end);
}

/// Copies save fields from [saves] onto the matching profile. A profile
/// with no save is unchanged. A save with no profile is appended.
List<PlayerAccount> mergeAccountSaves(
  List<PlayerAccount> profiles,
  List<PlayerAccount> saves,
) {
  final byUid = {for (final save in saves) save.uid: save};
  final seen = <String>{};
  final merged = <PlayerAccount>[
    for (final profile in profiles)
      byUid[profile.uid] == null
          ? profile
          : _withSave(profile, byUid[profile.uid]!),
  ];
  for (final profile in profiles) {
    seen.add(profile.uid);
  }
  for (final save in saves) {
    if (seen.add(save.uid)) merged.add(save);
  }
  return merged;
}

PlayerAccount _withSave(PlayerAccount profile, PlayerAccount save) {
  final shop = save.shopName.trim();
  return PlayerAccount(
    uid: profile.uid,
    name: profile.name.isNotEmpty ? profile.name : save.name,
    email: profile.email.isNotEmpty ? profile.email : save.email,
    shopName: shop.isNotEmpty ? shop : profile.shopName,
    money: save.money,
    day: save.day,
    bouquets: save.bouquets,
    joinedAt: save.joinedAt ?? profile.joinedAt,
    updatedAt: save.updatedAt ?? profile.updatedAt,
    grant: save.grant ?? profile.grant,
    appliedGrantId: save.appliedGrantId ?? profile.appliedGrantId,
    gift: save.gift ?? profile.gift,
    appliedGiftId: save.appliedGiftId ?? profile.appliedGiftId,
    pocket:
        save.pocket.petIds.isNotEmpty ||
            save.pocket.biscuits > 0 ||
            save.pocket.drops > 0 ||
            save.pocket.seats.isNotEmpty ||
            save.pocket.bowls.isNotEmpty
        ? save.pocket
        : profile.pocket,
  );
}

/// Admin list and the one-shot compensation write.
abstract class AccountAdmin {
  /// Names and emails only. Fast enough to paint the first page.
  Future<List<PlayerAccount>> loadProfiles();

  /// Cloud save fields for these uids. Unknown uids are omitted.
  Future<List<PlayerAccount>> loadSaves(List<String> uids);

  /// Profiles whose email starts with [email], joined with that save.
  /// Empty when [email] is blank. At most a few rows.
  Future<List<PlayerAccount>> findByEmail(String email);

  /// Writes `joinedAt` for accounts at day 2 or later that do not have it.
  /// Returns the uids that were stamped.
  Future<List<String>> markEstablished(List<PlayerAccount> rows);

  /// Replaces any grant still waiting. [day] null leaves the morning as it is.
  Future<void> grant({
    required String uid,
    required int money,
    int? day,
    required String note,
  });

  /// Adds [items] onto a gift that is still waiting, or starts a new one
  /// when the last shipment is already in the save. Returns the box written.
  Future<PetGiftBox> sendGift({
    required String uid,
    required Map<String, int> items,
    required String note,
  });
}
