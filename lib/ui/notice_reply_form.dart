import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sounds.dart';
import '../logic/game_notice.dart';
import '../logic/notice_reply.dart';
import '../logic/photo_uploads.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'game_toast.dart';
import 'notice_image.dart';
import 'ui_skin.dart';

/// Góp ý form of a form notice (SPEC_gop_y.md): kind chips, the note with
/// a 1000 counter (never blocks typing), "Tiến độ của bạn" for Báo lỗi,
/// an optional screenshot, and Gửi pinned at the bottom. One answer per
/// account and notice; after it is sent the form shows it read-only.
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
  final _message = TextEditingController();
  final _messageFocus = FocusNode();
  late final Map<String, TextEditingController> _progress = {
    for (final f in feedbackProgressFields) f.key: TextEditingController(),
  };
  var _type = FeedbackType.baoLoi;
  var _busy = false;
  var _locked = false;
  String? _error;
  String? _imageUrl;
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    _message.addListener(_changed);
    _messageFocus.addListener(_changed);
    _loadMine();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(NoticeReplyForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.signedIn && widget.signedIn) _loadMine();
  }

  @override
  void dispose() {
    _message.dispose();
    _messageFocus.dispose();
    for (final controller in _progress.values) {
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
      _message.text =
          mine.message ??
          [
            for (final a in mine.answers)
              if (a.value.isNotEmpty) '${a.label}: ${a.value}',
          ].join('\n');
      final progress = mine.progress;
      if (progress != null) {
        for (final f in feedbackProgressFields) {
          final n = progress[f.key];
          _progress[f.key]!.text = n == null ? '' : noticeGroupedNumber('$n');
        }
      }
      setState(() {
        _type = feedbackTypeOf(mine.feedbackType) ?? _type;
        _locked = true;
        _imageUrl = mine.imageUrl;
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

  void _pickType(FeedbackType type) {
    if (_locked || type == _type) return;
    SoundScope.maybeOf(context)?.effect('ui_tab');
    // The note and the numbers stay; only the kind changes.
    setState(() => _type = type);
  }

  Future<void> _send() async {
    final message = _message.text;
    if (!feedbackCanSend(message, busy: _busy)) return;
    final replies = widget.replies;
    if (replies == null || !widget.signedIn || widget.uid.isEmpty) {
      setState(() => _error = 'Đăng nhập Google rồi mới gửi được.');
      return;
    }
    final progress = feedbackProgress(_type, {
      for (final e in _progress.entries) e.key: e.value.text,
    });
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
          answers: feedbackAnswers(_type, progress),
          imageUrl: _imageUrl,
          feedbackType: _type.code,
          message: message.trim(),
          progress: progress,
        ),
      );
      if (!mounted) return;
      showGameToast(context, feedbackSentToast);
      // Sent: close the form; the draft goes with it.
      widget.onBack();
    } catch (_) {
      // Network or permission: one line for both. Everything typed stays.
      if (!mounted) return;
      showGameToast(context, feedbackFailedToast, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _message.text;
    final canSend = feedbackCanSend(message, busy: _busy);
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bar(),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _chips(),
                  const SizedBox(height: 16),
                  Text(
                    feedbackMessageLabel,
                    style: AppText.body(size: 13, weight: 800),
                  ),
                  const SizedBox(height: 6),
                  _messageBox(),
                  if (feedbackTooLongFor(message)) ...[
                    const SizedBox(height: 4),
                    Text(
                      feedbackTooLong,
                      key: const Key('feedback-too-long'),
                      style: AppText.body(
                        size: 11.5,
                        weight: 700,
                        color: AppColors.statusDanger,
                      ),
                    ),
                  ],
                  if (_type == FeedbackType.baoLoi) _progressGroup(),
                  if (widget.photos != null || _imageUrl != null) _photo(),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      key: const Key('notice-reply-error'),
                      style: AppText.caption(color: AppColors.statusDanger),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.surfaceBorder,
          ),
          const SizedBox(height: 14),
          _sendButton(canSend),
        ],
      ),
    );
  }

  Widget _sendButton(bool canSend) {
    if (_locked) {
      return const SkinButton(
        key: Key('notice-reply-send'),
        label: 'Đã gửi',
        height: 48,
        fontSize: 18,
        enabled: false,
        onPressed: null,
      );
    }
    if (!widget.signedIn) {
      return SkinButton(
        key: const Key('notice-reply-send'),
        label: _busy ? 'Đang gửi' : 'Đăng nhập Google để gửi',
        height: 48,
        fontSize: 16,
        enabled: !_busy,
        onPressed: _busy ? null : _signIn,
      );
    }
    return SkinButton(
      key: const Key('notice-reply-send'),
      label: _busy ? 'Đang gửi' : 'Gửi',
      height: 48,
      fontSize: 18,
      enabled: canSend,
      onPressed: canSend ? _send : null,
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

  Widget _chips() {
    return Row(
      children: [
        for (final t in FeedbackType.values) ...[
          if (t != FeedbackType.values.first) const SizedBox(width: 8),
          Expanded(child: _chip(t)),
        ],
      ],
    );
  }

  Widget _chip(FeedbackType t) {
    final on = t == _type;
    return GestureDetector(
      key: Key('feedback-type-${t.code}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _pickType(t),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.primaryBase : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: on
              ? null
              : Border.all(color: AppColors.primaryBase, width: AppBorder.thin),
        ),
        child: Text(
          t.label,
          style: AppText.button(
            size: 15,
            weight: 700,
            color: on ? AppColors.textInverse : AppColors.primaryPressed,
          ),
        ),
      ),
    );
  }

  Widget _messageBox() {
    final n = feedbackLength(_message.text);
    final over = n > maxFeedbackChars;
    final focused = _messageFocus.hasFocus;
    final border = over
        ? const BorderSide(color: AppColors.statusDanger, width: 1.5)
        : focused
        ? const BorderSide(color: AppColors.primaryBase, width: 1.5)
        : const BorderSide(color: AppColors.surfaceBorder);
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.fromBorderSide(border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            // No maxLength and no formatter: typing is never blocked; the
            // counter and Gửi carry the 1000 limit.
            child: TextField(
              key: const Key('feedback-message'),
              controller: _message,
              focusNode: _messageFocus,
              readOnly: _locked,
              expands: true,
              maxLines: null,
              minLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: AppText.body(size: 14, weight: 700),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                hintText: _type.hint,
                hintMaxLines: 3,
                hintStyle: AppText.body(
                  size: 13,
                  weight: 600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 9,
            child: Text(
              feedbackCounter(n),
              key: const Key('feedback-counter'),
              style: AppText.body(
                size: 11,
                weight: over ? 800 : 700,
                color: over ? AppColors.statusDanger : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressGroup() {
    Widget cell(FeedbackProgressField f) => _numberField(f);
    final f = feedbackProgressFields;
    return Column(
      key: const Key('feedback-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: AppColors.surfaceBorder),
        const SizedBox(height: 12),
        Text(feedbackProgressTitle, style: AppText.title(size: 16)),
        Text(
          feedbackProgressNote,
          style: AppText.body(
            size: 11.5,
            weight: 600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: cell(f[0])),
            const SizedBox(width: 10),
            Expanded(child: cell(f[1])),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: cell(f[2])),
            const SizedBox(width: 10),
            Expanded(child: cell(f[3])),
          ],
        ),
        const SizedBox(height: 10),
        cell(f[4]),
      ],
    );
  }

  Widget _numberField(FeedbackProgressField f) {
    final side = const BorderSide(color: AppColors.surfaceBorder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(f.label, style: AppText.body(size: 12, weight: 800)),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: TextField(
            key: Key('feedback-${f.key}'),
            controller: _progress[f.key],
            readOnly: _locked,
            keyboardType: TextInputType.number,
            // The grouping formatter the old form already used (50000 shows
            // as 50.000). It does not cap the length.
            inputFormatters: const [_GroupedNumberFormatter()],
            style: AppText.body(size: 14, weight: 700),
            decoration: InputDecoration(
              isDense: true,
              hintText: f.hint,
              hintStyle: AppText.caption(),
              filled: true,
              fillColor: AppColors.surfaceSunken,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: side,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: side,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photo() {
    final url = _imageUrl;
    final pickLabel = _uploading
        ? 'Đang tải…'
        : url == null
        ? 'Thêm ảnh'
        : 'Đổi ảnh';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(feedbackPhotoLabel, style: AppText.body(size: 12, weight: 800)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (url != null) ...[
                SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 4,
                        child: Container(
                          width: 64,
                          height: 64,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: NoticeImage(
                            key: const Key('notice-reply-photo'),
                            url: url,
                            height: 64,
                          ),
                        ),
                      ),
                      if (!_locked)
                        Positioned(
                          right: -9,
                          top: -5,
                          child: GestureDetector(
                            key: const Key('notice-reply-photo-remove'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _imageUrl = null),
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Center(
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.textPrimary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.textInverse,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: AppColors.textInverse,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (!_locked && widget.photos != null)
                OutlineButton(
                  key: const Key('notice-reply-photo-pick'),
                  label: pickLabel,
                  icon: Icons.photo_camera_outlined,
                  height: 36,
                  fontSize: 14,
                  onTap: _pickPhoto,
                ),
            ],
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
