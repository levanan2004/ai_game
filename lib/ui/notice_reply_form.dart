import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/game_notice.dart';
import '../logic/notice_reply.dart';
import '../logic/photo_uploads.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'notice_image.dart';

/// The inputs of one góp ý notice. One answer per account. After it
/// is sent, the fields stay visible and cannot be sent again.
class NoticeReplyForm extends StatefulWidget {
  const NoticeReplyForm({
    super.key,
    required this.notice,
    required this.replies,
    required this.signedIn,
    required this.uid,
    required this.email,
    required this.playerName,
    required this.shopName,
    required this.onSignIn,
    required this.onBack,
    this.photos,
  });

  /// Optional picture on the answer. Null hides the button.
  final PhotoUploads? photos;

  final GameNotice notice;
  final NoticeReplies? replies;
  final bool signedIn;
  final String uid;
  final String email;
  final String playerName;
  final String shopName;
  final Future<void> Function()? onSignIn;
  final VoidCallback onBack;

  @override
  State<NoticeReplyForm> createState() => _NoticeReplyFormState();
}

class _NoticeReplyFormState extends State<NoticeReplyForm> {
  late final Map<String, TextEditingController> _values = {
    for (final field in widget.notice.fields) field.id: TextEditingController(),
  };
  var _busy = false;
  var _locked = false;
  String? _error;
  String? _sent;
  String? _imageUrl;
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  @override
  void didUpdateWidget(NoticeReplyForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.signedIn && widget.signedIn) _loadMine();
  }

  @override
  void dispose() {
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMine() async {
    final replies = widget.replies;
    if (replies == null || !widget.signedIn || widget.uid.isEmpty) return;
    try {
      final mine = await replies.mine(widget.notice.id, widget.uid);
      if (!mounted || mine == null) return;
      for (final answer in mine.answers) {
        final controller = _values[answer.id];
        if (controller == null) continue;
        controller.text = answer.type == NoticeInputType.number
            ? noticeGroupedNumber(answer.value)
            : answer.value;
      }
      setState(() {
        _locked = true;
        _imageUrl = mine.imageUrl;
        _sent = 'Bạn đã gửi form này.';
      });
    } catch (_) {}
  }

  Future<void> _signIn() async {
    final signIn = widget.onSignIn;
    if (signIn == null) return;
    setState(() => _busy = true);
    try {
      await signIn();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa đăng nhập được, thử lại nhé.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Picks a photo, shrinks it under 512 KB (photoJpeg) and uploads it
  /// to `reply_photos/{uid}/…`. Only signed-in players can attach one.
  Future<void> _pickPhoto() async {
    final photos = widget.photos;
    if (photos == null || _busy || _locked || _uploading) return;
    if (!widget.signedIn || widget.uid.isEmpty) {
      setState(() => _error = 'Đăng nhập Google rồi mới thêm ảnh được.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final jpeg = await photos.pickPhotoJpeg();
      if (jpeg == null) return;
      final url = await photos.uploadReplyPhoto(
        uid: widget.uid,
        noticeId: widget.notice.id,
        jpeg: jpeg,
      );
      if (mounted) setState(() => _imageUrl = url);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa tải ảnh lên được, thử lại nhé.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _send() async {
    final values = {
      for (final field in widget.notice.fields)
        field.id: _values[field.id]?.text ?? '',
    };
    final error = noticeAnswersError(
      fields: widget.notice.fields,
      values: values,
    );
    if (error != null) {
      setState(() {
        _error = error;
        _sent = null;
      });
      return;
    }
    final replies = widget.replies;
    if (replies == null || !widget.signedIn || widget.uid.isEmpty) {
      setState(() => _error = 'Đăng nhập Google rồi mới gửi được.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await replies.submit(
        NoticeReply(
          noticeId: widget.notice.id,
          uid: widget.uid,
          email: widget.email,
          name: widget.playerName,
          shopName: widget.shopName,
          answers: noticeAnswersFor(
            fields: widget.notice.fields,
            values: values,
          ),
          imageUrl: _imageUrl,
        ),
      );
      if (!mounted) return;
      setState(() {
        _locked = true;
        _sent = 'Đã gửi. Cảm ơn bạn.';
      });
    } catch (e) {
      if (!mounted) return;
      final denied = '$e'.contains('permission-denied');
      setState(
        () => _error = denied
            ? 'Chưa gửi được. Firestore từ chối bản trả lời này.'
            : 'Chưa gửi được, thử lại nhé.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.notice.fields;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bar(),
          Expanded(
            child: fields.isEmpty
                ? Center(
                    child: Text(
                      'Thông báo này chưa có ô để điền.',
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 14, weight: 700),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final field in fields) _input(field),
                        if (widget.photos != null || _imageUrl != null)
                          _photo(),
                        if (_error != null)
                          Text(
                            _error!,
                            key: const Key('notice-reply-error'),
                            style: AppText.caption(
                              color: AppColors.statusDanger,
                            ),
                          ),
                        if (_sent != null)
                          Text(
                            _sent!,
                            key: const Key('notice-reply-sent'),
                            style: AppText.caption(
                              color: AppColors.primaryPressed,
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 44,
                          child: ChunkyButton(
                            key: const Key('notice-reply-send'),
                            label: _locked
                                ? 'Đã gửi'
                                : _busy
                                ? 'Đang gửi'
                                : widget.signedIn
                                ? 'Gửi'
                                : 'Đăng nhập Google để gửi',
                            fontSize: 15,
                            enabled: !_busy && !_locked,
                            onPressed: _busy || _locked
                                ? null
                                : widget.signedIn
                                ? _send
                                : _signIn,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bar() {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          BackButtonBox(
            key: const Key('notice-reply-back'),
            onTap: widget.onBack,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('Góp ý', style: AppText.heading(size: 18))),
        ],
      ),
    );
  }

  Widget _photo() {
    final url = _imageUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ảnh (không bắt buộc)',
            style: AppText.body(size: 12, weight: 800),
          ),
          const SizedBox(height: 4),
          if (url != null) ...[
            NoticeImage(
              key: const Key('notice-reply-photo'),
              url: url,
              height: 100,
            ),
            const SizedBox(height: 4),
          ],
          if (!_locked)
            Row(
              children: [
                OutlineButton(
                  key: const Key('notice-reply-photo-pick'),
                  label: _uploading
                      ? 'Đang tải…'
                      : url == null
                      ? 'Thêm ảnh'
                      : 'Đổi ảnh',
                  height: 32,
                  onTap: _pickPhoto,
                ),
                if (url != null) ...[
                  const SizedBox(width: 8),
                  OutlineButton(
                    key: const Key('notice-reply-photo-remove'),
                    label: 'Bỏ ảnh',
                    height: 32,
                    onTap: () => setState(() => _imageUrl = null),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _input(NoticeField field) {
    final controller = _values[field.id]!;
    final lines = field.type == NoticeInputType.note ? 3 : 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.required ? field.label : '${field.label} (không bắt buộc)',
            style: AppText.body(size: 12, weight: 800),
          ),
          const SizedBox(height: 2),
          TextField(
            key: Key('notice-reply-${field.id}'),
            controller: controller,
            readOnly: _locked,
            maxLines: lines,
            maxLength: field.type == NoticeInputType.number
                ? null
                : field.type == NoticeInputType.text
                ? maxNoticeTextChars
                : maxNoticeNoteChars,
            keyboardType: field.type == NoticeInputType.number
                ? TextInputType.number
                : TextInputType.text,
            inputFormatters: field.type == NoticeInputType.number
                ? const [_GroupedNumberFormatter()]
                : null,
            style: AppText.body(size: 14, weight: 700),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              hintText: noticeInputLimit(field.type),
              hintStyle: AppText.caption(),
              filled: true,
              fillColor: AppColors.surfaceSunken,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.surfaceBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows `100000` as `100.000` while the player types.
class _GroupedNumberFormatter extends TextInputFormatter {
  const _GroupedNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    var digitsBefore = 0;
    for (var i = 0; i < end; i++) {
      final unit = newValue.text.codeUnitAt(i);
      if (unit >= 48 && unit <= 57) digitsBefore++;
    }
    final shown = noticeGroupedNumber(newValue.text);
    if (digitsBefore > 9) digitsBefore = 9;
    var offset = 0;
    var seen = 0;
    while (offset < shown.length && seen < digitsBefore) {
      if (shown.codeUnitAt(offset) != 46) seen++;
      offset++;
    }
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
