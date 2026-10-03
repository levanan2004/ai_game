import 'package:flutter/material.dart';

import '../logic/game_notice.dart';
import '../logic/notice_reply.dart';
import '../logic/photo_uploads.dart';
import '../logic/player_account.dart';
import '../theme/tokens.dart';
import 'admin_pager.dart';
import 'common.dart';
import 'notice_reply_panel.dart';

/// Create, edit, hide, and delete in-game announcements.
class NoticeAdminPanel extends StatefulWidget {
  const NoticeAdminPanel({
    super.key,
    required this.admin,
    required this.onClose,
    this.replies,
    this.photos,
  });

  final NoticeAdmin admin;

  /// "Tải ảnh" next to the picture link. Null: link only.
  final PhotoUploads? photos;
  final NoticeReplyAdmin? replies;
  final VoidCallback onClose;

  @override
  State<NoticeAdminPanel> createState() => _NoticeAdminPanelState();
}

class _NoticeAdminPanelState extends State<NoticeAdminPanel> {
  List<GameNotice>? _items;
  Object? _error;
  GameNotice? _editing;
  GameNotice? _repliesOf;
  var _isNew = false;
  final _query = TextEditingController();
  var _sort = NoticeListSort.created;
  var _ascending = false;
  var _page = 0;

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

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final all = await widget.admin.loadAll();
      if (!mounted) return;
      setState(() => _items = all);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _add() {
    setState(() {
      _isNew = true;
      _editing = GameNotice(
        id: widget.admin.newId(),
        title: '',
        body: '',
        visible: true,
      );
    });
  }

  void _done(bool changed) {
    setState(() => _editing = null);
    if (changed) _load();
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing;
    final repliesOf = _repliesOf;
    final replies = widget.replies;
    return Material(
      color: AppColors.bgBase,
      child: repliesOf != null && replies != null
          ? NoticeReplyPanel(
              notices: [
                for (final notice in _items ?? const <GameNotice>[])
                  if (notice.kind == NoticeKind.form) notice,
              ],
              initialId: repliesOf.id,
              admin: replies,
              onClose: () => setState(() => _repliesOf = null),
            )
          : editing != null
          ? _NoticeForm(
              key: ValueKey(editing.id),
              admin: widget.admin,
              initial: editing,
              isNew: _isNew,
              onDone: _done,
              photos: widget.photos,
            )
          : Column(
              children: [
                _Header(
                  title: 'Thông báo',
                  onBack: widget.onClose,
                  action: OutlineButton(
                    key: const Key('notice-add'),
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
      return _Message(
        text: '$_error'.contains('permission-denied')
            ? 'Firestore chưa cho đọc thông báo. Deploy rules rồi thử lại:\n'
                  'npx firebase deploy --only firestore:rules'
            : 'Chưa tải được thông báo.\n$_error',
        action: 'Thử lại',
        onAction: _load,
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const _Message(text: 'Chưa có thông báo. Bấm "+ Thêm".');
    }
    final visible = sortNotices(
      [
        for (final notice in items)
          if (noticeMatches(notice, _query.text)) notice,
      ],
      _sort,
      ascending: _ascending,
    );
    final pages = accountPageCount(visible.length);
    final page = _page >= pages ? pages - 1 : _page;
    final shown = accountPage(visible, page);
    return Column(
      children: [
        AdminFilterBar(
          search: AdminSearchField(
            key: const Key('notice-search'),
            controller: _query,
            hint: 'Tiêu đề, nội dung',
            onChanged: (_) => setState(() => _page = 0),
          ),
          sort: AdminSortMenu<NoticeListSort>(
            key: const Key('notice-sort'),
            value: _sort,
            items: NoticeListSort.values,
            label: _noticeSortLabel,
            onChanged: (sort) => setState(() {
              _sort = sort;
              _page = 0;
            }),
          ),
          direction: AdminDirectionButton(
            key: const Key('notice-sort-dir'),
            ascending: _ascending,
            onToggle: () => setState(() {
              _ascending = !_ascending;
              _page = 0;
            }),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const _Message(text: 'Không có thông báo khớp.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _noticeRow(shown[i]),
                ),
        ),
        if (pages > 1)
          AdminPager(
            page: page,
            pages: pages,
            total: visible.length,
            onPage: (next) => setState(() => _page = next),
            prevKey: const Key('notice-page-prev'),
            nextKey: const Key('notice-page-next'),
          ),
      ],
    );
  }

  Widget _noticeRow(GameNotice notice) {
    return GestureDetector(
      key: Key('notice-row-${notice.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _isNew = false;
        _editing = notice;
      }),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 15, weight: 800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (!notice.visible) 'Đang ẩn',
                      if (notice.kind == NoticeKind.form) 'Góp ý',
                      if (notice.kind == NoticeKind.read) 'Chỉ xem',
                      if (notice.link != null) 'Có link',
                      noticeDateLabel(notice.createdAt),
                    ].where((part) => part.isNotEmpty).join(' · '),
                    style: AppText.caption(
                      color: notice.visible ? null : AppColors.statusDanger,
                    ),
                  ),
                  if (notice.kind == NoticeKind.form &&
                      widget.replies != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlineButton(
                        key: Key('notice-replies-${notice.id}'),
                        label: 'Xem form',
                        height: 28,
                        onTap: () => setState(() => _repliesOf = notice),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _noticeSortLabel(NoticeListSort sort) => switch (sort) {
  NoticeListSort.created => 'Ngày',
  NoticeListSort.title => 'Tiêu đề',
};

class _NoticeForm extends StatefulWidget {
  const _NoticeForm({
    super.key,
    required this.admin,
    required this.initial,
    required this.isNew,
    required this.onDone,
    this.photos,
  });

  final NoticeAdmin admin;
  final PhotoUploads? photos;
  final GameNotice initial;
  final bool isNew;
  final ValueChanged<bool> onDone;

  @override
  State<_NoticeForm> createState() => _NoticeFormState();
}

class _NoticeFormState extends State<_NoticeForm> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _link;
  late final TextEditingController _label;
  late final TextEditingController _image;
  late var _visible = widget.initial.visible;
  late var _kind = widget.initial.kind;
  late final List<_InputDraft> _inputs;
  var _fieldSerial = 0;
  var _busy = false;
  var _confirmDelete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _body = TextEditingController(text: widget.initial.body);
    _link = TextEditingController(text: widget.initial.link ?? '');
    _label = TextEditingController(text: widget.initial.linkLabel ?? '');
    _image = TextEditingController(text: widget.initial.imageUrl ?? '');
    _inputs = [
      for (final field in widget.initial.fields)
        _InputDraft(
          id: field.id,
          label: field.label,
          type: field.type,
          required: field.required,
        ),
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    _label.dispose();
    _image.dispose();
    for (final input in _inputs) {
      input.dispose();
    }
    super.dispose();
  }

  String _newFieldId() {
    _fieldSerial += 1;
    final id = 'fld$_fieldSerial';
    if (_inputs.any((input) => input.id == id)) return _newFieldId();
    return id;
  }

  void _addInput() {
    if (_inputs.length >= maxNoticeFields) {
      setState(() => _error = 'Tối đa $maxNoticeFields ô.');
      return;
    }
    setState(() {
      _error = null;
      _inputs.add(_InputDraft(id: _newFieldId()));
    });
  }

  void _removeInput(_InputDraft input) {
    setState(() => _inputs.remove(input));
    WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || title.length > 80) {
      setState(() => _error = 'Tiêu đề cần từ 1 đến 80 ký tự.');
      return;
    }
    if (body.isEmpty || body.length > 1000) {
      setState(() => _error = 'Nội dung cần từ 1 đến 1000 ký tự.');
      return;
    }
    final rawLink = _link.text.trim();
    final link = rawLink.isEmpty ? null : normalizeNoticeLink(rawLink);
    if (rawLink.isNotEmpty && link == null) {
      setState(
        () => _error = 'Link cần bắt đầu bằng https://, http:// hoặc /.',
      );
      return;
    }
    final rawImage = _image.text.trim();
    final image = normalizeImageUrl(rawImage);
    if (rawImage.isNotEmpty && image == null) {
      setState(() => _error = 'Link ảnh cần bắt đầu bằng https://');
      return;
    }
    final label = _label.text.trim();
    if (label.length > 40) {
      setState(() => _error = 'Chữ trên nút tối đa 40 ký tự.');
      return;
    }
    final fields = _kind == NoticeKind.form
        ? [
            for (final input in _inputs)
              NoticeField(
                id: input.id,
                label: input.label.text,
                type: input.type,
                required: input.required,
              ),
          ]
        : const <NoticeField>[];
    if (_kind == NoticeKind.form) {
      final fieldsError = noticeFieldsError(fields);
      if (fieldsError != null) {
        setState(() => _error = fieldsError);
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.admin.save(
        GameNotice(
          id: widget.initial.id,
          title: title,
          body: body,
          link: link,
          linkLabel: label,
          createdAt: widget.initial.createdAt,
          visible: _visible,
          kind: _kind,
          fields: fields,
          imageUrl: image,
        ),
      );
      if (!mounted) return;
      widget.onDone(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _saveError(e);
      });
    }
  }

  Future<void> _uploadImage() async {
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

  Future<void> _delete() async {
    if (!_confirmDelete) {
      setState(() {
        _confirmDelete = true;
        _error = 'Bấm lần nữa để xoá hẳn';
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.admin.delete(widget.initial.id);
      if (!mounted) return;
      widget.onDone(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Chưa xoá được, thử lại nhé.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          title: widget.isNew ? 'Thông báo mới' : 'Sửa thông báo',
          onBack: () => widget.onDone(false),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    _KindChip(
                      chipKey: const Key('notice-kind-read'),
                      label: 'Chỉ xem',
                      selected: _kind == NoticeKind.read,
                      onTap: _busy
                          ? null
                          : () => setState(() => _kind = NoticeKind.read),
                    ),
                    const SizedBox(width: 8),
                    _KindChip(
                      chipKey: const Key('notice-kind-form'),
                      label: 'Có form',
                      selected: _kind == NoticeKind.form,
                      onTap: _busy
                          ? null
                          : () => setState(() => _kind = NoticeKind.form),
                    ),
                  ],
                ),
              ),
              if (_kind == NoticeKind.form) ...[
                for (final input in _inputs)
                  _InputEditor(
                    key: ValueKey(input.id),
                    draft: input,
                    onChanged: () => setState(() {}),
                    onRemove: () => _removeInput(input),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlineButton(
                      key: const Key('notice-field-add'),
                      label: '+ Thêm ô',
                      onTap: _busy ? () {} : _addInput,
                    ),
                  ),
                ),
              ],
              _Field(
                fieldKey: const Key('notice-title'),
                label: 'Tiêu đề',
                hint: 'Bảo trì tối nay',
                controller: _title,
                maxLength: 80,
              ),
              _Field(
                fieldKey: const Key('notice-body'),
                label: 'Nội dung',
                hint: 'Người chơi đọc đoạn này khi bấm vào thông báo.',
                controller: _body,
                maxLength: 1000,
                lines: 5,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _Field(
                      fieldKey: const Key('notice-image'),
                      label: 'Ảnh (không bắt buộc)',
                      hint: 'https://…',
                      controller: _image,
                    ),
                  ),
                  if (widget.photos != null) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlineButton(
                        key: const Key('notice-image-upload'),
                        label: 'Tải ảnh',
                        width: 80,
                        height: 40,
                        onTap: _uploadImage,
                      ),
                    ),
                  ],
                ],
              ),
              _Field(
                fieldKey: const Key('notice-link'),
                label: 'Link (không bắt buộc)',
                hint: 'https://… hoặc /about',
                controller: _link,
                maxLength: 300,
              ),
              _Field(
                fieldKey: const Key('notice-label'),
                label: 'Chữ trên nút link',
                hint: 'Mở liên kết',
                controller: _label,
                maxLength: 40,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hiện trong game',
                        style: AppText.body(size: 14, weight: 800),
                      ),
                    ),
                    Switch(
                      key: const Key('notice-visible'),
                      value: _visible,
                      activeThumbColor: AppColors.onPrimary,
                      activeTrackColor: AppColors.primaryBase,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _visible = value),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    key: const Key('notice-error'),
                    style: AppText.caption(color: AppColors.statusDanger),
                  ),
                ),
              SizedBox(
                height: 48,
                child: ChunkyButton(
                  key: const Key('notice-save'),
                  label: _busy ? 'Đang lưu…' : 'Lưu',
                  onPressed: _busy ? null : _save,
                ),
              ),
              if (!widget.isNew) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ChunkyButton(
                    key: const Key('notice-delete'),
                    label: 'Xoá thông báo',
                    kind: ButtonKind.ghost,
                    fontSize: 15,
                    onPressed: _busy ? null : _delete,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InputDraft {
  _InputDraft({
    required this.id,
    String label = '',
    this.type = NoticeInputType.number,
    this.required = true,
  }) : label = TextEditingController(text: label);

  final String id;
  final TextEditingController label;
  NoticeInputType type;
  bool required;

  void dispose() => label.dispose();
}

class _InputEditor extends StatelessWidget {
  const _InputEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final _InputDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('notice-field-label-${draft.id}'),
                    controller: draft.label,
                    maxLength: 40,
                    style: AppText.body(size: 14, weight: 700),
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: 'Nhãn hiện cho user, tối đa 40 ký tự',
                      hintStyle: AppText.caption(),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                GestureDetector(
                  key: Key('notice-field-remove-${draft.id}'),
                  onTap: onRemove,
                  child: Text(
                    'Xoá',
                    style: AppText.caption(color: AppColors.statusDanger),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                DropdownButton<NoticeInputType>(
                  key: Key('notice-field-type-${draft.id}'),
                  value: draft.type,
                  underline: const SizedBox.shrink(),
                  style: AppText.body(size: 13, weight: 800),
                  items: [
                    for (final type in NoticeInputType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(noticeInputLabel(type)),
                      ),
                  ],
                  onChanged: (type) {
                    if (type == null) return;
                    draft.type = type;
                    onChanged();
                  },
                ),
                const Spacer(),
                Text('Bắt buộc', style: AppText.caption()),
                Switch(
                  key: Key('notice-field-required-${draft.id}'),
                  value: draft.required,
                  activeThumbColor: AppColors.onPrimary,
                  activeTrackColor: AppColors.primaryBase,
                  onChanged: (value) {
                    draft.required = value;
                    onChanged();
                  },
                ),
              ],
            ),
            Text(noticeInputLimit(draft.type), style: AppText.caption()),
          ],
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: chipKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBase : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primaryBase : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: AppText.body(
            size: 13,
            weight: 800,
            color: selected ? AppColors.onPrimary : AppColors.textPrimary,
          ),
        ),
      ),
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
          BackButtonBox(key: const Key('notice-admin-back'), onTap: onBack),
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
    this.maxLength,
    this.lines = 1,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final int? maxLength;
  final int lines;

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
              maxLength: maxLength,
              maxLines: lines,
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

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});

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
            Text(text, textAlign: TextAlign.center, style: AppText.body()),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlineButton(label: action!, onTap: onAction ?? () {}),
            ],
          ],
        ),
      ),
    );
  }
}

String _saveError(Object error) {
  final text = '$error';
  if (text.contains('permission-denied')) {
    return 'Firestore từ chối lưu thông báo. Deploy rules rồi bấm Lưu lại:\n'
        'npx firebase deploy --only firestore:rules';
  }
  return 'Chưa lưu được, thử lại nhé.';
}
