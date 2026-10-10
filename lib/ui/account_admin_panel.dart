import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/player_account.dart';
import '../theme/tokens.dart';
import 'admin_pager.dart';
import 'common.dart';

/// Signed-in accounts: filter, sort, and send a one-shot compensation.
class AccountAdminPanel extends StatefulWidget {
  const AccountAdminPanel({
    super.key,
    required this.admin,
    required this.onClose,
  });

  final AccountAdmin admin;
  final VoidCallback onClose;

  @override
  State<AccountAdminPanel> createState() => _AccountAdminPanelState();
}

class _AccountAdminPanelState extends State<AccountAdminPanel> {
  List<PlayerAccount>? _rows;
  Object? _error;
  final _query = TextEditingController();
  var _sort = AccountSort.day;
  var _ascending = false;
  var _page = 0;
  var _filling = false;
  String? _saveNote;
  String? _openUid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load({bool keep = false}) async {
    if (!keep) {
      setState(() {
        _rows = null;
        _error = null;
        _page = 0;
        _filling = false;
        _saveNote = null;
      });
    }
    try {
      final profiles = await widget.admin.loadProfiles();
      if (!mounted) return;
      final ordered = sortAccounts(profiles, _sort, ascending: _ascending);
      setState(() {
        _rows = ordered;
        _error = null;
        _filling = ordered.isNotEmpty;
        _saveNote = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _filling = false;
        if (_rows == null) _error = e;
      });
      return;
    }
    final rows = _rows;
    if (rows == null) return;
    try {
      await _fillSaves([for (final row in rows) row.uid]);
      await _markEstablished();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _filling = false;
        _saveNote = _loadError(e);
      });
    }
  }

  Future<void> _fillSaves(List<String> uids) async {
    if (uids.isEmpty) {
      if (mounted) setState(() => _filling = false);
      return;
    }
    for (var i = 0; i < uids.length; i += accountSaveBatch) {
      final end = i + accountSaveBatch > uids.length
          ? uids.length
          : i + accountSaveBatch;
      final saves = await widget.admin.loadSaves(uids.sublist(i, end));
      if (!mounted) return;
      setState(() {
        _rows = mergeAccountSaves(_rows ?? const [], saves);
        _filling = end < uids.length;
      });
    }
  }

  Future<void> _markEstablished() async {
    final rows = _rows;
    if (rows == null || rows.isEmpty) return;
    final marked = await widget.admin.markEstablished(rows);
    if (!mounted || marked.isEmpty) return;
    final ids = marked.toSet();
    setState(() {
      _rows = [
        for (final row in _rows ?? const <PlayerAccount>[])
          if (!ids.contains(row.uid) || row.joinedAt != null)
            row
          else
            PlayerAccount(
              uid: row.uid,
              name: row.name,
              email: row.email,
              shopName: row.shopName,
              money: row.money,
              day: row.day,
              bouquets: row.bouquets,
              joinedAt: row.updatedAt ?? DateTime.now(),
              updatedAt: row.updatedAt,
              grant: row.grant,
              appliedGrantId: row.appliedGrantId,
            ),
      ];
    });
  }

  List<PlayerAccount> get _visible {
    final rows = _rows ?? const <PlayerAccount>[];
    return sortAccounts(
      [
        for (final row in rows)
          if (accountMatches(row, _query.text)) row,
      ],
      _sort,
      ascending: _ascending,
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = _open();
    return Material(
      color: AppColors.bgBase,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: open != null
              ? _AccountDetail(
                  account: open,
                  admin: widget.admin,
                  onBack: () => setState(() => _openUid = null),
                  onSent: () => _load(keep: true),
                )
              : Column(
                  children: [
                    _Bar(title: 'Tài khoản', onBack: widget.onClose),
                    AdminFilterBar(
                      search: AdminSearchField(
                        key: const Key('account-search'),
                        controller: _query,
                        hint: 'Email, tên, tiệm, uid',
                        onChanged: (_) => setState(() => _page = 0),
                      ),
                      sort: AdminSortMenu<AccountSort>(
                        key: const Key('account-sort'),
                        value: _sort,
                        items: AccountSort.values,
                        label: _sortLabel,
                        onChanged: (sort) => setState(() {
                          _sort = sort;
                          _page = 0;
                        }),
                      ),
                      direction: AdminDirectionButton(
                        key: const Key('account-sort-dir'),
                        ascending: _ascending,
                        onToggle: () => setState(() {
                          _ascending = !_ascending;
                          _page = 0;
                        }),
                      ),
                    ),
                    Expanded(child: _body()),
                  ],
                ),
        ),
      ),
    );
  }

  PlayerAccount? _open() {
    final uid = _openUid;
    final rows = _rows;
    if (uid == null || rows == null) return null;
    for (final row in rows) {
      if (row.uid == uid) return row;
    }
    return null;
  }

  Widget _body() {
    if (_error != null) {
      return _Note(
        text: _loadError(_error!),
        action: 'Thử lại',
        onAction: _load,
      );
    }
    final rows = _rows;
    if (rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final visible = _visible;
    if (rows.isEmpty) {
      return const _Note(text: 'Chưa có tài khoản nào đăng nhập Google.');
    }
    if (visible.isEmpty) {
      return const _Note(text: 'Không có tài khoản khớp.');
    }
    final pages = accountPageCount(visible.length);
    final page = _page >= pages ? pages - 1 : _page;
    final shown = accountPage(visible, page);
    return Column(
      children: [
        if (_saveNote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              _saveNote!,
              textAlign: TextAlign.center,
              style: AppText.caption(color: AppColors.statusDanger),
            ),
          )
        else if (_filling)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('Đang lấy màn và tiền…', style: AppText.caption()),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final account = shown[i];
              return GestureDetector(
                key: Key('account-row-${account.uid}'),
                onTap: () => setState(() => _openUid = account.uid),
                child: CardBox(
                  padding: const EdgeInsets.all(12),
                  child: _summary(account),
                ),
              );
            },
          ),
        ),
        if (pages > 1)
          AdminPager(
            page: page,
            pages: pages,
            total: visible.length,
            onPage: (next) => setState(() => _page = next),
            prevKey: const Key('account-page-prev'),
            nextKey: const Key('account-page-next'),
          ),
      ],
    );
  }

  Widget _summary(PlayerAccount account) {
    final title = account.shopName.trim().isNotEmpty
        ? account.shopName
        : (account.name.trim().isNotEmpty ? account.name : account.uid);
    final money = account.money == null
        ? 'Chưa có save'
        : formatK(account.money!);
    final day = account.day == null ? '—' : 'Ngày ${account.day}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.heading(size: 16)),
        const SizedBox(height: 2),
        Text(
          account.email.isEmpty ? account.uid : account.email,
          style: AppText.caption(),
        ),
        const SizedBox(height: 4),
        Text(
          '$day · $money · ${account.bouquets} bó',
          style: AppText.body(size: 13, weight: 800),
        ),
        Text(
          'Vào game: ${accountWhen(account.joinedAt)} · Lưu: ${accountWhen(account.updatedAt, clock: true)}',
          style: AppText.caption(),
        ),
      ],
    );
  }
}

class _AccountDetail extends StatefulWidget {
  const _AccountDetail({
    required this.account,
    required this.admin,
    required this.onBack,
    required this.onSent,
  });

  final PlayerAccount account;
  final AccountAdmin admin;
  final VoidCallback onBack;
  final Future<void> Function() onSent;

  @override
  State<_AccountDetail> createState() => _AccountDetailState();
}

class _AccountDetailState extends State<_AccountDetail> {
  final _money = TextEditingController();
  final _day = TextEditingController();
  final _note = TextEditingController();
  String? _error;
  String? _sent;
  var _busy = false;

  @override
  void dispose() {
    _money.dispose();
    _day.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final account = widget.account;
    final moneyText = _money.text.trim();
    final dayText = _day.text.trim();
    final money = moneyText.isEmpty ? null : readDigits(moneyText);
    final day = dayText.isEmpty ? null : readDigits(dayText);
    final error = grantFormError(
      money: money,
      day: day,
      currentDay: account.day,
    );
    if (error != null) {
      setState(() {
        _error = error;
        _sent = null;
      });
      return;
    }
    final raise = day != null && (account.day == null || day > account.day!)
        ? day
        : null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.admin.grant(
        uid: account.uid,
        money: money ?? 0,
        day: raise,
        note: _note.text,
      );
      if (!mounted) return;
      _money.clear();
      _day.clear();
      _note.clear();
      setState(() => _sent = 'Đã gửi. Họ nhận ở lần đăng nhập sau.');
      await widget.onSent();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Chưa gửi được, thử lại nhé.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final who = account.name.trim().isNotEmpty ? account.name : 'Chưa có tên';
    return Column(
      children: [
        _Bar(
          title: account.shopName.trim().isNotEmpty ? account.shopName : who,
          onBack: widget.onBack,
          backKey: const Key('account-detail-back'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _line('Tên Google', who),
              _line('Email', account.email.isEmpty ? 'Chưa có' : account.email),
              _line('Uid', account.uid),
              _line(
                'Tiền trên cloud',
                account.money == null
                    ? 'Chưa có save'
                    : formatK(account.money!),
              ),
              _line(
                'Màn',
                account.day == null ? 'Chưa có save' : 'Ngày ${account.day}',
              ),
              _line('Bó đã bán', '${account.bouquets}'),
              _line('Đăng nhập Google lần đầu', accountWhen(account.joinedAt)),
              if (account.joinedAt == null)
                Text(
                  'Chưa ghi. Ngày này là lúc tạo tài khoản Google trong game, '
                  'và chỉ hiện sau lần họ vào game bằng bản mới.',
                  style: AppText.caption(),
                ),
              _line(
                'Lưu cloud gần nhất',
                accountWhen(account.updatedAt, clock: true),
              ),
              const SizedBox(height: 8),
              Text(
                grantStatus(account),
                style: AppText.body(size: 13, weight: 800),
              ),
              const SizedBox(height: 12),
              Text(
                'Cộng thêm tiền và có thể nâng màn. Save trên máy họ không bị xoá. '
                'Màn chỉ được nâng, không bị hạ. Kho hoa cũ không tự trở lại.',
                style: AppText.caption(),
              ),
              const SizedBox(height: 12),
              _input(
                fieldKey: const Key('account-money'),
                controller: _money,
                label: 'Cộng thêm (đồng)',
                hint: '50000',
              ),
              const SizedBox(height: 8),
              _input(
                fieldKey: const Key('account-day'),
                controller: _day,
                label: 'Nâng lên màn (để trống nếu không đổi)',
                hint: account.day == null ? '10' : '${account.day! + 1}',
              ),
              const SizedBox(height: 8),
              _input(
                fieldKey: const Key('account-note'),
                controller: _note,
                label: 'Ghi chú (chỉ quản trị thấy)',
                hint: 'Đền reset ngày 29/09',
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('account-error'),
                  style: AppText.caption(color: AppColors.statusDanger),
                ),
              ],
              if (_sent != null) ...[
                const SizedBox(height: 8),
                Text(
                  _sent!,
                  key: const Key('account-sent'),
                  style: AppText.body(
                    size: 13,
                    weight: 800,
                    color: AppColors.primaryPressed,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ChunkyButton(
                  key: const Key('account-grant'),
                  label: _busy ? 'Đang gửi' : 'Gửi đền bù',
                  enabled: !_busy,
                  onPressed: _busy ? null : _send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 168, child: Text(label, style: AppText.caption())),
          Expanded(
            child: Text(value, style: AppText.body(size: 13, weight: 800)),
          ),
        ],
      ),
    );
  }

  Widget _input({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption()),
        const SizedBox(height: 4),
        TextField(
          key: fieldKey,
          controller: controller,
          style: AppText.body(size: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppText.caption(),
            filled: true,
            fillColor: AppColors.surfaceCard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: _fieldBorder(),
            enabledBorder: _fieldBorder(),
            focusedBorder: _fieldBorder(AppColors.primaryBase),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.title, required this.onBack, this.backKey});

  final String title;
  final VoidCallback onBack;
  final Key? backKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 8),
          BackButtonBox(
            key: backKey ?? const Key('account-admin-back'),
            onTap: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.heading(size: 18),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppText.body(size: 14, weight: 700),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlineButton(label: action!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

String _sortLabel(AccountSort sort) => switch (sort) {
  AccountSort.day => 'Màn',
  AccountSort.money => 'Tiền',
  AccountSort.bouquets => 'Bó',
  AccountSort.updated => 'Lưu gần nhất',
  AccountSort.joined => 'Vào game',
  AccountSort.shop => 'Tên tiệm',
};

String _loadError(Object error) {
  final text = '$error';
  if (text.contains('permission-denied')) {
    return 'Firestore chưa cho đọc tài khoản. Deploy rules rồi thử lại:\n'
        'npx firebase deploy --only firestore:rules';
  }
  return 'Chưa tải được danh sách.\n$text';
}

OutlineInputBorder _fieldBorder([Color? color]) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadius.md),
  borderSide: BorderSide(color: color ?? AppColors.surfaceBorder),
);
