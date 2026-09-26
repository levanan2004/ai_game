import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/preset_avatars.dart';
import '../logic/shop_session.dart';
import '../logic/supporters.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'donors_screen.dart';

/// Admin list + form for the Đại thiện nhân board. Only opened when
/// [SupporterAdmin.isAdmin] is true; the rules still guard every write.
class SupporterAdminPanel extends StatefulWidget {
  const SupporterAdminPanel({
    super.key,
    required this.session,
    required this.onClose,
  });

  final ShopSession session;

  /// Called with true when something was saved or deleted.
  final ValueChanged<bool> onClose;

  @override
  State<SupporterAdminPanel> createState() => _SupporterAdminPanelState();
}

class _SupporterAdminPanelState extends State<SupporterAdminPanel> {
  List<Supporter>? _people;
  Object? _error;
  Supporter? _editing;
  var _isNew = false;
  var _changed = false;

  SupporterAdmin get _admin => widget.session.supporterAdmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _people = null;
      _error = null;
    });
    try {
      final all = await _admin.loadAll();
      all.sort((a, b) {
        final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      if (!mounted) return;
      setState(() => _people = all);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _add() {
    setState(() {
      _isNew = true;
      _editing = Supporter(
        id: _admin.newId(),
        name: '',
        message: '',
        date: DateTime.now(),
        visible: true,
        avatar: '',
        amount: null,
      );
    });
  }

  void _formDone(bool changed) {
    setState(() {
      _editing = null;
      if (changed) _changed = true;
    });
    if (changed) _load();
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing;
    return Material(
      color: AppColors.bgBase,
      child: editing != null
          ? _SupporterForm(
              key: ValueKey(editing.id),
              session: widget.session,
              initial: editing,
              isNew: _isNew,
              onDone: _formDone,
            )
          : Column(
              children: [
                _Header(
                  title: 'Quản lý bảng',
                  onBack: () => widget.onClose(_changed),
                  action: OutlineButton(
                    key: const Key('admin-add'),
                    label: '+ Thêm',
                    width: 72,
                    height: 32,
                    onTap: _add,
                  ),
                ),
                Expanded(child: _list()),
              ],
            ),
    );
  }

  Widget _list() {
    if (_error != null) {
      return _Centered(
        text: 'Chưa tải được danh sách.\n$_error',
        action: 'Thử lại',
        onAction: _load,
      );
    }
    final people = _people;
    if (people == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (people.isEmpty) {
      return const _Centered(text: 'Chưa có ai. Bấm "+ Thêm" để thêm người.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: people.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = people[i];
        final chip = formatSupportAmount(p.amount);
        final date = p.date;
        return GestureDetector(
          key: Key('admin-row-${p.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _isNew = false;
            _editing = p;
          }),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.surfaceBorder,
                width: AppBorder.thin,
              ),
            ),
            child: Row(
              children: [
                Opacity(
                  opacity: p.visible ? 1 : 0.4,
                  child: SupporterAvatar(avatar: p.avatar),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.heading(size: 14),
                      ),
                      Text(
                        [
                          if (date != null) formatDayMonthYear(date),
                          if (!p.visible) 'Đang ẩn',
                          if (p.message.trim().isNotEmpty) p.message.trim(),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(size: 11),
                      ),
                    ],
                  ),
                ),
                if (chip != null)
                  Text(
                    chip,
                    style: AppText.number(
                      size: 14,
                      color: AppColors.primaryPressed,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SupporterForm extends StatefulWidget {
  const _SupporterForm({
    super.key,
    required this.session,
    required this.initial,
    required this.isNew,
    required this.onDone,
  });

  final ShopSession session;
  final Supporter initial;
  final bool isNew;
  final ValueChanged<bool> onDone;

  @override
  State<_SupporterForm> createState() => _SupporterFormState();
}

class _SupporterFormState extends State<_SupporterForm> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _amount = TextEditingController(
    text: widget.initial.hasAmount ? '${widget.initial.amount}' : '',
  );
  late final _message = TextEditingController(text: widget.initial.message);
  final _phone = TextEditingController();
  late final _date = TextEditingController(
    text: formatDayMonthYear(widget.initial.date ?? DateTime.now()),
  );
  late bool _visible = widget.initial.visible;
  late String _avatar = widget.initial.avatar;

  /// Photos uploaded in this form that are not saved yet.
  final _uploads = <String>[];
  var _busy = false;
  var _confirmDelete = false;
  String? _error;

  SupporterAdmin get _admin => widget.session.supporterAdmin;

  @override
  void initState() {
    super.initState();
    if (!widget.isNew) _loadPhone();
  }

  Future<void> _loadPhone() async {
    try {
      final phone = await _admin.loadPhone(widget.initial.id);
      if (mounted && _phone.text.isEmpty) _phone.text = phone;
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa tải được số điện thoại.');
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _amount, _message, _phone, _date]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final jpeg = await widget.session.account.pickAvatarJpeg();
      if (jpeg != null) {
        final path = await _admin.uploadAvatar(widget.initial.id, jpeg);
        _uploads.add(path);
        _avatar = path;
      }
    } catch (e) {
      _error = 'Chưa tải ảnh lên được: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    for (final path in _uploads) {
      await _admin.deleteAvatar(path);
    }
    widget.onDone(false);
  }

  Future<void> _save() async {
    final amount = parseSupportAmount(_amount.text);
    final phone = normalizePhone(_phone.text);
    final date = parseDayMonthYear(_date.text);
    final problem = amount == null
        ? 'Số tiền chưa đúng. Ví dụ: 200000, 200k, 1,5tr.'
        : phone == null
        ? 'Số điện thoại chưa đúng (9–15 số).'
        : date == null
        ? 'Ngày chưa đúng. Ví dụ: 26/09/2026.'
        : null;
    if (problem != null) {
      widget.session.sounds.effect('error');
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final old = widget.initial.date;
    final keepTime =
        old != null &&
        old.year == date!.year &&
        old.month == date.month &&
        old.day == date.day;
    final s = Supporter(
      id: widget.initial.id,
      name: _name.text,
      message: _message.text,
      date: keepTime ? old : date,
      visible: _visible,
      avatar: _avatar,
      amount: amount == 0 ? null : amount,
    );
    try {
      await _admin.save(s, phone: phone!);
      for (final path in [widget.initial.avatar, ..._uploads]) {
        if (path != _avatar) await _admin.deleteAvatar(path);
      }
      widget.session.sounds.effect('avatar_saved');
      widget.onDone(true);
    } catch (e) {
      if (!mounted) return;
      widget.session.sounds.effect('error');
      setState(() {
        _busy = false;
        _error = 'Chưa lưu được: $e';
      });
    }
  }

  Future<void> _delete() async {
    if (!_confirmDelete) {
      setState(() => _confirmDelete = true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _admin.delete(widget.initial);
      for (final path in _uploads) {
        await _admin.deleteAvatar(path);
      }
      widget.onDone(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Chưa xoá được: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          title: widget.isNew ? 'Thêm người' : 'Sửa thông tin',
          onBack: _busy ? () {} : _cancel,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _avatarPicker(),
                const SizedBox(height: 12),
                _Field(
                  fieldKey: const Key('admin-name'),
                  label: 'Tên hiện trên bảng',
                  hint: 'Để trống = Một người ẩn danh',
                  controller: _name,
                  maxLength: 40,
                ),
                _Field(
                  fieldKey: const Key('admin-amount'),
                  label: 'Số tiền',
                  hint: '200000, 200k, 1,5tr. Để trống = ẩn số tiền',
                  controller: _amount,
                  keyboard: TextInputType.text,
                ),
                _Field(
                  fieldKey: const Key('admin-message'),
                  label: 'Lời nhắn (công khai)',
                  hint: 'Không ghi số điện thoại vào đây',
                  controller: _message,
                  maxLength: 80,
                ),
                _Field(
                  fieldKey: const Key('admin-phone'),
                  label: 'Số điện thoại (chỉ admin thấy)',
                  hint: '0901234567',
                  controller: _phone,
                  keyboard: TextInputType.phone,
                ),
                _Field(
                  fieldKey: const Key('admin-date'),
                  label: 'Ngày ủng hộ',
                  hint: 'dd/mm/yyyy',
                  controller: _date,
                  keyboard: TextInputType.datetime,
                ),
                GestureDetector(
                  key: const Key('admin-visible'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _visible = !_visible),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _visible
                                ? 'Đang hiện trên bảng'
                                : 'Đang ẩn khỏi bảng',
                            style: AppText.body(size: 14, weight: 700),
                          ),
                        ),
                        _Toggle(on: _visible),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      _error!,
                      key: const Key('admin-error'),
                      style: AppText.body(
                        size: 12,
                        weight: 700,
                        color: AppColors.statusDanger,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: ChunkyButton(
                    key: const Key('admin-save'),
                    label: _busy ? 'Đang lưu…' : 'Lưu',
                    enabled: !_busy,
                    onPressed: _busy ? null : _save,
                  ),
                ),
                if (!widget.isNew) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ChunkyButton(
                      key: const Key('admin-delete'),
                      label: _confirmDelete ? 'Bấm lần nữa để xoá hẳn' : 'Xoá',
                      kind: ButtonKind.ghost,
                      fontSize: 15,
                      textColor: AppColors.statusDanger,
                      enabled: !_busy,
                      onPressed: _busy ? null : _delete,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarPicker() {
    final uploaded = _avatar.contains('/');
    Widget choice(String code, Widget child, {Key? key}) {
      final selected = _avatar == code;
      return GestureDetector(
        key: key,
        onTap: () => setState(() => _avatar = code),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.primaryBase : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ảnh đại diện', style: AppText.body(size: 12, weight: 800)),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (uploaded) choice(_avatar, SupporterAvatar(avatar: _avatar)),
              choice(
                '',
                const SupporterAvatar(avatar: ''),
                key: const Key('admin-avatar-none'),
              ),
              for (final id in presetAvatarIds)
                choice(
                  id,
                  SupporterAvatar(avatar: id),
                  key: Key('admin-avatar-$id'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        OutlineButton(
          key: const Key('admin-upload'),
          label: _busy ? 'Đang tải…' : 'Tải ảnh từ máy',
          height: 32,
          onTap: _pickPhoto,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack, this.action});

  final String title;
  final VoidCallback onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 8),
          BackButtonBox(key: const Key('admin-back'), onTap: onBack),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: AppText.heading(size: 18))),
          ?action,
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboard,
    this.maxLength,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 12, weight: 800)),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.surfaceBorderStrong,
                width: AppBorder.thin,
              ),
            ),
            child: TextField(
              key: fieldKey,
              controller: controller,
              keyboardType: keyboard,
              maxLength: maxLength,
              style: AppText.body(size: 14, weight: 700),
              decoration: InputDecoration(
                counterText: '',
                isCollapsed: true,
                contentPadding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppText.body(
                  size: 13,
                  weight: 600,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? AppColors.primaryBase : AppColors.surfaceBorderStrong,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text, this.action, this.onAction});

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
              style: AppText.body(size: 13, weight: 700),
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              OutlineButton(label: action!, width: 96, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}
