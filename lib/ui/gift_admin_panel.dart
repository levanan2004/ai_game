import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/pet.dart';
import '../logic/player_account.dart';
import '../logic/xu_grant.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

Widget _giftPicture(GiftKind kind) {
  Widget image(String path) =>
      Image.asset(path, height: 64, fit: BoxFit.contain);
  return switch (kind.art) {
    GiftArt.pet => image(Art.pet(kind.asset)),
    GiftArt.pot => image(Art.pot(kind.asset)),
    GiftArt.coin => image(Art.nav(kind.asset)),
    GiftArt.phaLe => image(Art.nav(kind.asset)),
    GiftArt.item => image('assets/images/phuc_loi/${kind.asset}.webp'),
  };
}

String _ownedLine(String id, int owned) {
  if (id == giftXu) {
    return owned <= 0 ? 'Đang có 0' : 'Đang có ${formatK(owned)}';
  }
  return 'Đang có $owned';
}

/// Pick a player, tick one or more gifts, and send them together.
class GiftAdminPanel extends StatefulWidget {
  const GiftAdminPanel({super.key, required this.admin, required this.onClose});

  final AccountAdmin admin;
  final VoidCallback onClose;

  @override
  State<GiftAdminPanel> createState() => _GiftAdminPanelState();
}

class _GiftAdminPanelState extends State<GiftAdminPanel> {
  List<PlayerAccount> _rows = const [];
  Object? _error;
  final _users = TextEditingController();
  final _note = TextEditingController();
  final _xu = TextEditingController();
  final _counts = <String, int>{};
  String? _uid;
  var _busy = false;
  var _searching = false;
  var _searched = false;
  String? _formError;
  var _sent = false;

  @override
  void dispose() {
    _users.dispose();
    _note.dispose();
    _xu.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final email = _users.text.trim();
    if (email.length < 2) {
      setState(() {
        _rows = const [];
        _uid = null;
        _searched = false;
        _formError = 'Nhập email để tìm.';
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _formError = null;
      _error = null;
      _sent = false;
    });
    try {
      final rows = await widget.admin.findByEmail(email);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _searched = true;
        _uid = rows.length == 1 ? rows.first.uid : null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  PlayerAccount? get _selected {
    if (_uid == null) return null;
    for (final row in _rows) {
      if (row.uid == _uid) return row;
    }
    return null;
  }

  Future<void> _send() async {
    final row = _selected;
    final error = row == null
        ? 'Chọn một người chơi.'
        : giftFormError(_counts, note: _note.text);
    if (row == null || error != null) {
      setState(() => _formError = error);
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
      _sent = false;
    });
    try {
      final box = await widget.admin.sendGift(
        uid: row.uid,
        items: {..._counts},
        note: _note.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final item in _rows)
            if (item.uid == row.uid) item.withGift(box) else item,
        ];
        _counts.clear();
        _note.clear();
        _xu.clear();
        _sent = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _formError = 'Chưa gửi được, thử lại nhé.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(GiftKind kind) {
    setState(() {
      _sent = false;
      if (_counts.containsKey(kind.id)) {
        _counts.remove(kind.id);
      } else {
        _counts[kind.id] = 1;
      }
    });
  }

  void _setXu(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final n = int.tryParse(digits);
    setState(() {
      _sent = false;
      if (n == null || n <= 0) {
        _counts.remove(giftXu);
        _formError = digits.isEmpty ? null : 'Nhập số xu.';
      } else if (n > maxGrantMoney) {
        _counts.remove(giftXu);
        _formError = 'Xu tối đa 100.000.000.';
      } else {
        _counts[giftXu] = n;
        _formError = null;
      }
    });
  }

  void _setCount(GiftKind kind, int? count) {
    setState(() {
      _sent = false;
      if (count == null || count <= 0) {
        _counts.remove(kind.id);
      } else {
        _counts[kind.id] = count > kind.cap ? kind.cap : count;
        _formError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Material(
      color: AppColors.bgBase,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('gift-back'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back),
                ),
                Text('Quà tặng', style: AppText.title(size: 22)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('gift-user-search'),
                        controller: _users,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        style: AppText.body(size: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Email người chơi',
                          hintStyle: AppText.caption(),
                          filled: true,
                          fillColor: AppColors.surfaceCard,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: ChunkyButton(
                        key: const Key('gift-user-find'),
                        label: _searching ? '...' : 'Tìm',
                        height: 36,
                        fontSize: 14,
                        enabled: !_searching,
                        onPressed: _searching ? null : _search,
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Chưa tìm được.',
                    style: AppText.caption(color: AppColors.statusDanger),
                  ),
                ] else if (!_searched) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Nhập email rồi bấm Tìm.',
                    style: AppText.caption(size: 12),
                  ),
                ] else if (_rows.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Không thấy email này.',
                    key: const Key('gift-user-empty'),
                    style: AppText.caption(size: 12),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  for (final row in _rows)
                    GiftUserRow(
                      row: row,
                      selected: row.uid == _uid,
                      onTap: () => setState(() {
                        _uid = row.uid;
                        _sent = false;
                        _formError = null;
                      }),
                    ),
                ],
                if (selected != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    selected.pocket.line,
                    key: const Key('gift-pocket'),
                    style: AppText.body(size: 14, weight: 800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    giftStatus(
                      gift: selected.gift,
                      appliedId: selected.appliedGiftId,
                    ),
                    key: const Key('gift-status'),
                    style: AppText.caption(size: 12, weight: 700),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in giftCatalog)
                      if (kind.art == GiftArt.pet || kind.art == GiftArt.phaLe)
                        GiftPickCard(
                          kind: kind,
                          count: _counts[kind.id] ?? 0,
                          owned: selected?.pocket.countOf(kind.id),
                          onTap: () => _toggle(kind),
                          onCount: (count) => _setCount(kind, count),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Chậu', style: AppText.body(size: 15, weight: 800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in giftCatalog)
                      if (kind.art == GiftArt.pot)
                        GiftPickCard(
                          kind: kind,
                          count: _counts[kind.id] ?? 0,
                          owned: selected?.pocket.countOf(kind.id),
                          onTap: () => _toggle(kind),
                          onCount: (count) => _setCount(kind, count),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Đồ pet', style: AppText.body(size: 15, weight: 800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in giftCatalog)
                      if (kind.art == GiftArt.item)
                        GiftPickCard(
                          kind: kind,
                          count: _counts[kind.id] ?? 0,
                          owned: selected?.pocket.countOf(kind.id),
                          onTap: () => _toggle(kind),
                          onCount: (count) => _setCount(kind, count),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Xu', style: AppText.body(size: 15, weight: 800)),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('gift-xu'),
                  controller: _xu,
                  keyboardType: TextInputType.number,
                  onChanged: _setXu,
                  style: AppText.body(size: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Số xu, ví dụ 50000',
                    hintStyle: AppText.caption(),
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(10),
                      child: CoinIcon(size: 22),
                    ),
                  ),
                ),
                if (selected != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _ownedLine(giftXu, selected.pocket.countOf(giftXu)),
                    key: const Key('gift-owned-xu'),
                    style: AppText.caption(size: 11, weight: 700),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const Key('gift-note'),
                  controller: _note,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Lời nhắn, có thể để trống',
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formError!,
                    key: const Key('gift-error'),
                    style: AppText.caption(color: AppColors.statusDanger),
                  ),
                ],
                if (_sent) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Đã gửi. Quà vào tiệm ở lần đăng nhập sau.',
                    key: const Key('gift-sent'),
                    style: AppText.body(size: 14, weight: 800),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ChunkyButton(
                    key: const Key('gift-send'),
                    label: _busy ? 'Đang gửi...' : 'Gửi quà',
                    enabled: !_busy,
                    onPressed: _busy ? null : _send,
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

/// One player found by email. Also used by the Hộp thư composer.
class GiftUserRow extends StatelessWidget {
  const GiftUserRow({
    super.key,
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final PlayerAccount row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = row.shopName.trim().isEmpty ? row.email : row.shopName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.primaryBase : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          key: Key('gift-user-${row.uid}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? row.uid : title,
                  style: AppText.body(
                    size: 14,
                    weight: 800,
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                if (row.email.isNotEmpty && title != row.email)
                  Text(
                    row.email,
                    style: AppText.caption(
                      size: 11,
                      color: selected
                          ? AppColors.onPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One gift with its picture and amount. Also used by the Hộp thư composer.
class GiftPickCard extends StatelessWidget {
  const GiftPickCard({
    super.key,
    required this.kind,
    required this.count,
    required this.owned,
    required this.onTap,
    required this.onCount,
  });

  final GiftKind kind;
  final int count;

  /// Null until a player is chosen. Then the amount already in their save.
  final int? owned;
  final VoidCallback onTap;
  final ValueChanged<int?> onCount;

  @override
  Widget build(BuildContext context) {
    final on = count > 0;
    final picture = Column(
      children: [
        _giftPicture(kind),
        const SizedBox(height: 4),
        Text(
          kind.name,
          textAlign: TextAlign.center,
          style: AppText.caption(size: 12, weight: 800),
        ),
        if (owned != null)
          Text(
            _ownedLine(kind.id, owned!),
            key: Key('gift-owned-${kind.id}'),
            style: AppText.caption(size: 11, weight: 700),
          ),
      ],
    );
    return GestureDetector(
      key: Key('gift-card-${kind.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 108,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: on ? AppColors.primaryBase : AppColors.surfaceBorder,
            width: on ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            picture,
            if (!kind.unique)
              GestureDetector(
                onTap: () {},
                child: _QtyField(kind: kind, count: count, onChanged: onCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _QtyField extends StatefulWidget {
  const _QtyField({
    required this.kind,
    required this.count,
    required this.onChanged,
  });

  final GiftKind kind;
  final int count;
  final ValueChanged<int?> onChanged;

  @override
  State<_QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<_QtyField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.count > 0 ? '${widget.count}' : '',
  );

  @override
  void didUpdateWidget(_QtyField old) {
    super.didUpdateWidget(old);
    final digits = _text.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(digits);
    final shown = widget.count > 0 ? '${widget.count}' : '';
    if (parsed != widget.count && _text.text != shown) {
      _text.value = TextEditingValue(
        text: shown,
        selection: TextSelection.collapsed(offset: shown.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TextField(
        key: Key('gift-qty-${widget.kind.id}'),
        controller: _text,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: AppText.body(size: 13, weight: 800),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Số lượng',
          hintStyle: AppText.caption(size: 11),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 6,
          ),
          filled: true,
          fillColor: AppColors.bgBase,
        ),
        onChanged: (raw) {
          final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
          widget.onChanged(digits.isEmpty ? null : int.tryParse(digits));
        },
      ),
    );
  }
}
