import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../logic/game_notice.dart';
import '../logic/notice_reply.dart';
import '../logic/player_account.dart';
import '../theme/tokens.dart';
import 'admin_pager.dart';
import 'common.dart';
import 'notice_image.dart';

/// Answers grouped by the góp ý notice they belong to.
class NoticeReplyPanel extends StatefulWidget {
  const NoticeReplyPanel({
    super.key,
    required this.notices,
    required this.initialId,
    required this.admin,
    required this.onClose,
  });

  final List<GameNotice> notices;
  final String initialId;
  final NoticeReplyAdmin admin;
  final VoidCallback onClose;

  @override
  State<NoticeReplyPanel> createState() => _NoticeReplyPanelState();
}

class _NoticeReplyPanelState extends State<NoticeReplyPanel> {
  List<NoticeReply>? _rows;
  Object? _error;
  late String _noticeId = widget.initialId;
  final _query = TextEditingController();
  var _ascending = false;
  var _page = 0;
  var _review = _ReviewFilter.all;
  String? _statusError;
  String? _autoNote;
  var _autoBusy = false;
  final _saving = <String>{};
  final _cap = TextEditingController(
    text: noticeGroupedNumber('$compensationAutoSkipXu'),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    _cap.dispose();
    super.dispose();
  }

  bool get _compensation => noticeIsCompensation(_selected()?.title ?? '');

  int? get _skipAbove => int.tryParse(noticeDigits(_cap.text));

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    try {
      final all = await widget.admin.loadAll();
      if (!mounted) return;
      setState(() => _rows = all);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  List<NoticeReply> get _forNotice => [
    for (final row in _rows ?? const <NoticeReply>[])
      if (row.noticeId == _noticeId) row,
  ];

  List<NoticeReply> get _visible => sortReplies([
    for (final row in _forNotice)
      if (replyMatches(row, _query.text) && _reviewAllows(row)) row,
  ], ascending: _ascending);

  bool _reviewAllows(NoticeReply reply) => switch (_review) {
    _ReviewFilter.all => true,
    _ReviewFilter.pending => !reply.approved,
    _ReviewFilter.approved => reply.approved,
  };

  Future<void> _setApproved(NoticeReply reply, bool approved) async {
    if (reply.approved == approved || _saving.contains(reply.uid)) return;
    setState(() {
      _saving.add(reply.uid);
      _statusError = null;
    });
    try {
      await widget.admin.setApproved(
        noticeId: reply.noticeId,
        uid: reply.uid,
        approved: approved,
      );
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final row in _rows ?? const <NoticeReply>[])
            if (row.noticeId == reply.noticeId && row.uid == reply.uid)
              row.copyWith(approved: approved)
            else
              row,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      final denied = '$e'.contains('permission-denied');
      setState(() {
        _statusError = denied
            ? 'Firestore chưa cho sửa trạng thái. Deploy rules rồi thử lại.'
            : 'Chưa lưu được trạng thái.';
      });
    } finally {
      if (mounted) setState(() => _saving.remove(reply.uid));
    }
  }

  Future<void> _autoApprove() async {
    if (_autoBusy) return;
    final cap = _skipAbove;
    if (cap == null) {
      setState(
        () => _statusError = 'Nhập mức xu. Trên mức đó thì không duyệt.',
      );
      return;
    }
    final pending = [
      for (final row in _forNotice)
        if (compensationAutoApproves(row, skipAbove: cap)) row,
    ];
    final skipped = [
      for (final row in _forNotice)
        if (!row.approved && compensationAmount(row).total > cap) row,
    ];
    setState(() {
      _autoBusy = true;
      _statusError = null;
      _autoNote = null;
    });
    var approved = 0;
    var failed = 0;
    for (final row in pending) {
      try {
        await widget.admin.setApproved(
          noticeId: row.noticeId,
          uid: row.uid,
          approved: true,
        );
        approved++;
        if (!mounted) return;
        setState(() {
          _rows = [
            for (final item in _rows ?? const <NoticeReply>[])
              if (item.noticeId == row.noticeId && item.uid == row.uid)
                item.copyWith(approved: true)
              else
                item,
          ];
        });
      } catch (e) {
        failed++;
        if (!mounted) return;
        final denied = '$e'.contains('permission-denied');
        setState(() {
          _statusError = denied
              ? 'Firestore chưa cho sửa trạng thái. Deploy rules rồi thử lại.'
              : 'Chưa lưu được trạng thái.';
        });
        if (denied) break;
      }
    }
    if (!mounted) return;
    final capLabel = noticeGroupedNumber('$cap');
    final summary = failed > 0
        ? 'Đã duyệt $approved form. $failed form chưa lưu. Bỏ qua ${skipped.length} form vì trên $capLabel xu.'
        : 'Đã duyệt $approved form. Bỏ qua ${skipped.length} form vì trên $capLabel xu.';
    setState(() {
      _autoBusy = false;
      _autoNote = summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    final notice = _selected();
    return Material(
      color: AppColors.bgBase,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    BackButtonBox(
                      key: const Key('notice-reply-admin-back'),
                      onTap: widget.onClose,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notice?.title ?? 'Form đã gửi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.heading(size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              if (widget.notices.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _picker(),
                ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  GameNotice? _selected() {
    for (final notice in widget.notices) {
      if (notice.id == _noticeId) return notice;
    }
    return null;
  }

  Widget _picker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: DropdownButton<String>(
        key: const Key('notice-reply-filter'),
        isExpanded: true,
        value: widget.notices.any((n) => n.id == _noticeId) ? _noticeId : null,
        underline: const SizedBox.shrink(),
        style: AppText.body(size: 13, weight: 800),
        items: [
          for (final notice in widget.notices)
            DropdownMenuItem(value: notice.id, child: Text(notice.title)),
        ],
        onChanged: (id) {
          if (id == null) return;
          setState(() {
            _noticeId = id;
            _page = 0;
          });
        },
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      final denied = '$_error'.contains('permission-denied');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                denied
                    ? 'Firestore chưa cho đọc form. Deploy rules rồi thử lại.'
                    : 'Chưa tải được form.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 14, weight: 700),
              ),
              const SizedBox(height: 12),
              OutlineButton(label: 'Thử lại', onTap: _load),
            ],
          ),
        ),
      );
    }
    if (_rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_forNotice.isEmpty) {
      return Center(
        child: Text(
          'Chưa có ai gửi form này.',
          style: AppText.body(size: 14, weight: 700),
        ),
      );
    }
    final rows = _visible;
    final pages = accountPageCount(rows.length);
    final page = _page >= pages ? pages - 1 : _page;
    final shown = accountPage(rows, page);
    return Column(
      children: [
        AdminFilterBar(
          search: AdminSearchField(
            key: const Key('notice-reply-search'),
            controller: _query,
            hint: 'Email, tên, tiệm, nội dung',
            onChanged: (_) => setState(() => _page = 0),
          ),
          direction: AdminDirectionButton(
            key: const Key('notice-reply-sort-dir'),
            ascending: _ascending,
            onToggle: () => setState(() {
              _ascending = !_ascending;
              _page = 0;
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in _ReviewFilter.values)
                _ReviewButton(
                  key: Key('notice-reply-status-${filter.name}'),
                  label: _reviewLabel(filter),
                  selected: _review == filter,
                  fill: AppColors.primaryBase,
                  onTap: () => setState(() {
                    _review = filter;
                    _page = 0;
                  }),
                ),
            ],
          ),
        ),
        if (_compensation) _autoBar(),
        if (_statusError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              _statusError!,
              style: AppText.body(
                size: 13,
                weight: 800,
                color: AppColors.statusDanger,
              ),
            ),
          ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    'Không có form khớp.',
                    style: AppText.body(size: 14, weight: 700),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _replyCard(shown[i]),
                ),
        ),
        if (pages > 1)
          AdminPager(
            page: page,
            pages: pages,
            total: rows.length,
            onPage: (next) => setState(() => _page = next),
            prevKey: const Key('notice-reply-page-prev'),
            nextKey: const Key('notice-reply-page-next'),
          ),
      ],
    );
  }

  Widget _autoBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Không duyệt tự động nếu tổng xu trên',
            style: AppText.caption(),
          ),
          Text(
            'Chỉ đánh dấu Đã duyệt, chưa cộng xu vào tiệm.',
            style: AppText.caption(),
          ),
          const SizedBox(height: 4),
          TextField(
            key: const Key('notice-reply-auto-cap'),
            controller: _cap,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() => _autoNote = null),
            style: AppText.body(size: 14, weight: 800),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceCard,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: _capBorder(),
              enabledBorder: _capBorder(),
              focusedBorder: _capBorder(AppColors.primaryBase),
            ),
          ),
          const SizedBox(height: 8),
          OutlineButton(
            key: const Key('notice-reply-auto'),
            label: _autoBusy ? 'Đang duyệt...' : 'Duyệt tự động',
            height: 40,
            onTap: _autoBusy ? () {} : _autoApprove,
          ),
          if (_autoNote != null) ...[
            const SizedBox(height: 6),
            Text(_autoNote!, style: AppText.body(size: 13, weight: 800)),
          ],
        ],
      ),
    );
  }

  Widget _amountLine(NoticeReply reply) {
    final total = compensationAmount(reply).total;
    final cap = _skipAbove;
    final over = cap != null && total > cap;
    return Text(
      'Tính đền: ${noticeGroupedNumber('$total')} xu',
      style: AppText.body(
        size: 13,
        weight: 800,
        color: over ? AppColors.statusDanger : AppColors.primaryPressed,
      ),
    );
  }

  Widget _replyCard(NoticeReply reply) {
    final who = reply.email.isNotEmpty
        ? reply.email
        : (reply.name.isNotEmpty ? reply.name : reply.uid);
    return CardBox(
      key: Key('notice-reply-${reply.uid}'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(who, style: AppText.heading(size: 16)),
          if (reply.shopName.isNotEmpty)
            Text(reply.shopName, style: AppText.caption()),
          const SizedBox(height: 8),
          Row(
            children: [
              _ReviewButton(
                key: Key('notice-reply-approve-${reply.uid}'),
                label: 'Đã duyệt',
                selected: reply.approved,
                fill: AppColors.statusSuccess,
                onTap: () => _setApproved(reply, true),
              ),
              const SizedBox(width: 8),
              _ReviewButton(
                key: Key('notice-reply-pending-${reply.uid}'),
                label: 'Chưa duyệt',
                selected: !reply.approved,
                fill: AppColors.statusWarning,
                foreground: AppColors.onSecondary,
                onTap: () => _setApproved(reply, false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_compensation) _amountLine(reply),
          if (feedbackTypeOf(reply.feedbackType) case final kind?)
            Text(
              'Kiểu: ${kind.label}',
              key: Key('notice-reply-type-${reply.uid}'),
              style: AppText.body(size: 13, weight: 800),
            ),
          if (reply.message case final message? when message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                message,
                key: Key('notice-reply-message-${reply.uid}'),
                style: AppText.body(size: 13),
              ),
            ),
          for (final answer in reply.answers.where(
            (a) =>
                !(a.id == 'loai' && reply.feedbackType != null) &&
                !(a.id == 'loi_nhan' && (reply.message ?? '').isNotEmpty),
          ))
            Text(
              '${answer.label}: ${answer.value.isEmpty
                  ? '—'
                  : answer.type == NoticeInputType.number
                  ? noticeGroupedNumber(answer.value)
                  : answer.value}',
              style: AppText.body(size: 13, weight: 800),
            ),
          if (reply.imageUrl != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 220,
              child: NoticeImage(
                key: Key('notice-reply-image-${reply.uid}'),
                url: reply.imageUrl!,
                height: 120,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            accountWhen(reply.updatedAt ?? reply.createdAt, clock: true),
            style: AppText.caption(),
          ),
        ],
      ),
    );
  }
}

OutlineInputBorder _capBorder([Color? color]) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadius.md),
  borderSide: BorderSide(color: color ?? AppColors.surfaceBorder),
);

enum _ReviewFilter { all, pending, approved }

String _reviewLabel(_ReviewFilter filter) => switch (filter) {
  _ReviewFilter.all => 'Tất cả',
  _ReviewFilter.pending => 'Chưa duyệt',
  _ReviewFilter.approved => 'Đã duyệt',
};

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({
    super.key,
    required this.label,
    required this.selected,
    required this.fill,
    this.foreground = AppColors.onPrimary,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color fill;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundScope.maybeOf(context)?.effect('ui_tap');
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? fill : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? fill : AppColors.surfaceBorder),
        ),
        child: Text(
          label,
          style: AppText.button(
            size: 13,
            weight: 700,
            color: selected ? foreground : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
