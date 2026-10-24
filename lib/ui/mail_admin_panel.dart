import 'package:flutter/material.dart';

import '../logic/game_notice.dart';
import '../logic/mailbox.dart';
import '../logic/pet.dart';
import '../logic/photo_uploads.dart';
import '../logic/player_account.dart';
import '../logic/rewards.dart';
import '../logic/xu_grant.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'gift_admin_panel.dart';
import 'reward_bundle_view.dart';

/// Compose a Hộp thư mail (one player or everyone), and see or delete the
/// mails already sent. Gifts use the same picker as Quà tặng.
class MailAdminPanel extends StatefulWidget {
  const MailAdminPanel({
    super.key,
    required this.mails,
    required this.accounts,
    required this.onClose,
    this.photos,
    this.now,
  });

  final MailAdmin mails;
  final AccountAdmin accounts;
  final PhotoUploads? photos;
  final VoidCallback onClose;
  final DateTime Function()? now;

  @override
  State<MailAdminPanel> createState() => _MailAdminPanelState();
}

class _MailAdminPanelState extends State<MailAdminPanel> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _image = TextEditingController();
  final _users = TextEditingController();
  final _xu = TextEditingController();
  final _counts = <String, int>{};
  var _toAll = false;
  List<PlayerAccount> _rows = const [];
  String? _uid;
  DateTime? _expires;
  var _busy = false;
  var _searching = false;
  String? _error;
  String? _sent;
  List<GameMail>? _list;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _image.dispose();
    _users.dispose();
    _xu.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all = await widget.mails.loadAll();
      if (mounted) setState(() => _list = all);
    } catch (_) {
      if (mounted) setState(() => _list = const []);
    }
  }

  Future<void> _search() async {
    final email = _users.text.trim();
    if (email.length < 2) {
      setState(() => _error = 'Nhập email để tìm.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final rows = await widget.accounts.findByEmail(email);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _uid = rows.length == 1 ? rows.first.uid : null;
        if (rows.isEmpty) _error = 'Không thấy email này.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa tìm được.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickExpiry() async {
    final now = _now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expires ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 366)),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _expires = DateTime(picked.year, picked.month, picked.day, 23, 59),
    );
  }

  Future<void> _upload() async {
    final photos = widget.photos;
    if (photos == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final jpeg = await photos.pickPhotoJpeg();
      if (jpeg != null) _image.text = await photos.uploadBoardImage(jpeg);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa tải ảnh lên được.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setXu(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final n = int.tryParse(digits);
    setState(() {
      if (n == null || n <= 0) {
        _counts.remove(giftXu);
      } else {
        _counts[giftXu] = n > maxGrantMoney ? maxGrantMoney : n;
      }
    });
  }

  void _toggle(GiftKind kind) => setState(() {
    if (_counts.containsKey(kind.id)) {
      _counts.remove(kind.id);
    } else {
      _counts[kind.id] = 1;
    }
  });

  void _setCount(GiftKind kind, int? count) => setState(() {
    if (count == null || count <= 0) {
      _counts.remove(kind.id);
    } else {
      _counts[kind.id] = count > kind.cap ? kind.cap : count;
    }
  });

  RewardBundle get _bundle =>
      RewardBundle.fromGiftItems(sanitizeGiftItems(_counts));

  Future<void> _send() async {
    final target = _toAll ? mailToAll : (_uid ?? '');
    final mail = GameMail(
      id: widget.mails.newId(),
      title: _title.text,
      body: _body.text,
      target: target,
      rewards: _bundle,
      imageUrl: normalizeImageUrl(_image.text),
      expiresAt: _expires,
    );
    final problem = target.isEmpty
        ? 'Chọn một người chơi hoặc Tất cả.'
        : mailFormError(mail, rawImageUrl: _image.text);
    if (problem != null) {
      setState(() {
        _error = problem;
        _sent = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _sent = null;
    });
    try {
      await widget.mails.send(mail);
      if (!mounted) return;
      setState(() {
        _sent = _toAll ? 'Đã gửi thư cho mọi người.' : 'Đã gửi thư.';
        _title.clear();
        _body.clear();
        _image.clear();
        _xu.clear();
        _counts.clear();
        _expires = null;
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = '$e'.contains('permission-denied')
            ? 'Firestore từ chối. Deploy rules mới rồi thử lại.'
            : 'Chưa gửi được, thử lại nhé.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(GameMail mail) async {
    try {
      await widget.mails.delete(mail.id);
      _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa xoá được thư.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgBase,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('mail-admin-back'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back),
                ),
                Text('Hộp thư', style: AppText.title(size: 22)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                Row(
                  children: [
                    _chip('Một người chơi', !_toAll, () => _toAll = false),
                    const SizedBox(width: 8),
                    _chip('Tất cả người chơi', _toAll, () => _toAll = true),
                  ],
                ),
                const SizedBox(height: 8),
                if (!_toAll) ..._picker(),
                _field(const Key('mail-title'), 'Tiêu đề', _title),
                _field(
                  const Key('mail-body-input'),
                  'Nội dung',
                  _body,
                  lines: 4,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        const Key('mail-image'),
                        'Link ảnh https:// (không bắt buộc)',
                        _image,
                      ),
                    ),
                    if (widget.photos != null) ...[
                      const SizedBox(width: 8),
                      OutlineButton(
                        key: const Key('mail-image-upload'),
                        label: 'Tải ảnh',
                        width: 80,
                        height: 36,
                        onTap: _upload,
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _expires == null
                            ? 'Không hết hạn'
                            : mailExpiryLabel(_expires),
                        key: const Key('mail-expiry'),
                        style: AppText.body(size: 14, weight: 800),
                      ),
                    ),
                    OutlineButton(
                      key: const Key('mail-expiry-pick'),
                      label: 'Chọn ngày',
                      width: 96,
                      height: 32,
                      onTap: _pickExpiry,
                    ),
                    if (_expires != null) ...[
                      const SizedBox(width: 6),
                      OutlineButton(
                        key: const Key('mail-expiry-clear'),
                        label: 'Bỏ',
                        width: 48,
                        height: 32,
                        onTap: () => setState(() => _expires = null),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Quà kèm (không bắt buộc)',
                  style: AppText.body(size: 15, weight: 800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in giftCatalog)
                      if (kind.art != GiftArt.coin)
                        GiftPickCard(
                          kind: kind,
                          count: _counts[kind.id] ?? 0,
                          owned: null,
                          onTap: () => _toggle(kind),
                          onCount: (count) => _setCount(kind, count),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('mail-xu'),
                  controller: _xu,
                  keyboardType: TextInputType.number,
                  onChanged: _setXu,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Xu kèm theo, ví dụ 50000',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(10),
                      child: CoinIcon(size: 22),
                    ),
                  ),
                ),
                if (_bundle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  RewardBundleView(
                    key: const Key('mail-admin-preview'),
                    bundle: _bundle,
                    iconSize: 24,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    key: const Key('mail-admin-error'),
                    style: AppText.caption(color: AppColors.statusDanger),
                  ),
                ],
                if (_sent != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _sent!,
                    key: const Key('mail-admin-sent'),
                    style: AppText.body(size: 14, weight: 800),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ChunkyButton(
                    key: const Key('mail-send'),
                    label: _busy ? 'Đang gửi...' : 'Gửi thư',
                    enabled: !_busy,
                    onPressed: _busy ? null : _send,
                  ),
                ),
                const SizedBox(height: 20),
                Text('Thư đã gửi', style: AppText.body(size: 15, weight: 800)),
                const SizedBox(height: 6),
                if (_list == null)
                  const Center(child: CircularProgressIndicator())
                else if (_list!.isEmpty)
                  Text('Chưa có thư.', style: AppText.caption())
                else
                  for (final mail in _list!) _sentRow(mail),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _picker() => [
    Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('mail-user-search'),
            controller: _users,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _search(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Email người chơi',
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: ChunkyButton(
            key: const Key('mail-user-find'),
            label: _searching ? '...' : 'Tìm',
            height: 36,
            fontSize: 14,
            enabled: !_searching,
            onPressed: _searching ? null : _search,
          ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    for (final row in _rows)
      GiftUserRow(
        row: row,
        selected: row.uid == _uid,
        onTap: () => setState(() => _uid = row.uid),
      ),
    const SizedBox(height: 4),
  ];

  Widget _chip(String label, bool on, VoidCallback pick) {
    return ChoiceChip(
      key: Key('mail-target-${on ? 'on' : 'off'}-$label'),
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(pick),
    );
  }

  Widget _field(
    Key key,
    String hint,
    TextEditingController controller, {
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        key: key,
        controller: controller,
        maxLines: lines,
        decoration: InputDecoration(isDense: true, hintText: hint),
      ),
    );
  }

  Widget _sentRow(GameMail mail) {
    final who = mail.toAll ? 'Tất cả' : mail.target;
    final parts = [
      who,
      noticeDateLabel(mail.createdAt),
      mailExpiryLabel(mail.expiresAt),
      if (mail.expired(_now())) 'Đã hết hạn',
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CardBox(
        key: Key('mail-sent-${mail.id}'),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mail.title, style: AppText.body(size: 14, weight: 800)),
                  Text(parts, style: AppText.caption(size: 11)),
                  if (mail.hasGift)
                    Text(mail.rewards.label, style: AppText.caption(size: 11)),
                ],
              ),
            ),
            OutlineButton(
              key: Key('mail-delete-${mail.id}'),
              label: 'Xoá',
              width: 56,
              height: 30,
              onTap: () => _delete(mail),
            ),
          ],
        ),
      ),
    );
  }
}
