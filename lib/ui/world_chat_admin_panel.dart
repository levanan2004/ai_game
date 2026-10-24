import 'package:flutter/material.dart';

import '../logic/game_notice.dart' show noticeDateLabel;
import '../logic/world_chat.dart';
import '../logic/world_chat_admin.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'world_chat_text.dart';

/// `/quan-tri` → Tin thế giới: the remote switch (config/worldChat), the
/// newest messages with "Gỡ tin" and the penalty ladder per sender.
class WorldChatAdminPanel extends StatefulWidget {
  const WorldChatAdminPanel({
    super.key,
    required this.admin,
    required this.onClose,
  });

  final WorldChatAdmin admin;
  final VoidCallback onClose;

  @override
  State<WorldChatAdminPanel> createState() => _WorldChatAdminPanelState();
}

class _WorldChatAdminPanelState extends State<WorldChatAdminPanel> {
  bool? _on;
  List<ChatMessage>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final on = await widget.admin.isEnabled();
      final list = await widget.admin.latest();
      if (mounted) {
        setState(() {
          _on = on;
          _list = list;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _list = const [];
          _error = 'Chưa tải được Tin thế giới.';
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa lưu được, thử lại nhé.');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Material(
      color: AppColors.bgBase,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('chat-admin-back'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(ChatText.title, style: AppText.title(size: 22)),
                ),
                IconButton(
                  key: const Key('chat-admin-reload'),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(
            child: list == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    children: [
                      if (_error != null)
                        Text(
                          _error!,
                          style: AppText.caption(color: AppColors.statusDanger),
                        ),
                      SwitchListTile(
                        key: const Key('chat-admin-switch'),
                        value: _on == true,
                        title: Text(
                          'Bật Tin thế giới (config/worldChat)',
                          style: AppText.body(weight: 800),
                        ),
                        subtitle: Text(
                          'Tắt: game ẩn ô nhập và máy chủ từ chối mọi tin.',
                          style: AppText.caption(size: 11),
                        ),
                        onChanged: (v) =>
                            _run(() => widget.admin.setEnabled(v)),
                      ),
                      if (list.isEmpty)
                        Text('Chưa có tin.', style: AppText.caption()),
                      for (final m in list)
                        ChatAdminMessageCard(
                          key: Key('chat-admin-msg-${m.id}'),
                          message: m,
                          admin: widget.admin,
                          onChanged: _load,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// One message with "Gỡ tin" and the penalty picker for its sender.
class ChatAdminMessageCard extends StatelessWidget {
  const ChatAdminMessageCard({
    super.key,
    required this.message,
    required this.admin,
    required this.onChanged,
    this.reason = '',
  });

  final ChatMessage message;
  final WorldChatAdmin admin;
  final VoidCallback onChanged;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CardBox(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${m.name} (${m.uid}) · ${noticeDateLabel(m.createdAt)}',
              style: AppText.caption(size: 11),
            ),
            Text(m.text, style: AppText.body(size: 14, weight: 700)),
            Wrap(
              spacing: 6,
              children: [
                if (m.id.isNotEmpty)
                  TextButton(
                    key: Key('chat-admin-delete-${m.id}'),
                    onPressed: () async {
                      try {
                        await admin.deleteMessage(m.id);
                      } catch (_) {}
                      onChanged();
                    },
                    child: const Text('Gỡ tin'),
                  ),
                ChatMutePicker(
                  key: Key('chat-admin-mute-${m.id}'),
                  uid: m.uid,
                  messageId: m.id,
                  reason: reason,
                  admin: admin,
                  onChanged: onChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The ladder of noi_quy_tin_the_gioi.md điều 9 (labels: worldchat.penalty.form.*)
/// plus "Bỏ khóa". The server works out the end from economy.json.
class ChatMutePicker extends StatelessWidget {
  const ChatMutePicker({
    super.key,
    required this.uid,
    required this.admin,
    required this.onChanged,
    this.messageId = '',
    this.reason = '',
  });

  final String uid;
  final String messageId;
  final String reason;
  final WorldChatAdmin admin;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Xử lý người gửi',
      onSelected: (level) async {
        try {
          if (level == '') {
            await admin.clearMute(uid);
          } else {
            await admin.setMute(
              uid,
              level,
              reason: reason,
              messageId: messageId,
            );
          }
        } catch (_) {}
        onChanged();
      },
      itemBuilder: (_) => [
        for (final e in ChatText.penalty.entries)
          PopupMenuItem(
            key: Key('chat-mute-${e.key}'),
            value: e.key,
            child: Text(e.value),
          ),
        const PopupMenuItem(
          key: Key('chat-mute-clear'),
          value: '',
          child: Text('Bỏ khóa'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          'Xử lý…',
          style: AppText.body(
            size: 14,
            weight: 800,
            color: AppColors.primaryPressed,
          ),
        ),
      ),
    );
  }
}

/// The chat reports inside /quan-tri → Báo cáo (same screen as the profile
/// reports): message copy with its neighbours, reason, note, and the actions.
class ChatReportsSection extends StatefulWidget {
  const ChatReportsSection({super.key, required this.admin});

  final WorldChatAdmin admin;

  @override
  State<ChatReportsSection> createState() => _ChatReportsSectionState();
}

class _ChatReportsSectionState extends State<ChatReportsSection> {
  List<ChatReport>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.admin.reports();
      if (mounted) {
        setState(() {
          _list = all;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _list = const [];
          _error = 'Chưa tải được báo cáo Tin thế giới.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            'Tin thế giới',
            style: AppText.title(size: 18),
          ),
        ),
        if (list == null) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: AppText.caption(color: AppColors.statusDanger)),
        if (list != null && list.isEmpty && _error == null)
          Text('Chưa có báo cáo tin nhắn.', style: AppText.caption()),
        for (final r in list ?? const <ChatReport>[]) _row(r),
      ],
    );
  }

  Widget _row(ChatReport r) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: CardBox(
      key: Key('chat-report-${r.id}'),
      padding: const EdgeInsets.all(10),
      color: r.done ? AppColors.surfaceSunken : AppColors.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.targetName} (${r.targetUid})',
            style: AppText.body(size: 14, weight: 800),
          ),
          Text('"${r.text}"', style: AppText.body(size: 14, weight: 700)),
          Text(r.reason.label, style: AppText.body(size: 13, weight: 700)),
          if (r.note.isNotEmpty)
            Text(r.note, style: AppText.body(size: 13, weight: 600)),
          Text(
            [
              noticeDateLabel(r.createdAt),
              'người báo cáo ${r.reporterUid}',
              if (r.done) 'đã xử lý',
            ].where((s) => s.isNotEmpty).join(' · '),
            style: AppText.caption(size: 11),
          ),
          if (r.context.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Tin xung quanh (${r.context.length})',
                style: AppText.caption(),
              ),
              children: [
                for (final c in r.context)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${c.name}: ${c.text}',
                      style: AppText.body(
                        size: 12,
                        weight: c.uid == r.targetUid ? 800 : 600,
                      ),
                    ),
                  ),
              ],
            ),
          Wrap(
            spacing: 6,
            children: [
              TextButton(
                key: Key('chat-report-delete-${r.id}'),
                onPressed: () async {
                  try {
                    await widget.admin.deleteMessage(r.messageId);
                  } catch (_) {}
                  await _load();
                },
                child: const Text('Gỡ tin'),
              ),
              ChatMutePicker(
                uid: r.targetUid,
                messageId: r.messageId,
                reason: r.reason.label,
                admin: widget.admin,
                onChanged: _load,
              ),
              if (!r.done)
                TextButton(
                  key: Key('chat-report-done-${r.id}'),
                  onPressed: () async {
                    try {
                      await widget.admin.markDone(r.id);
                    } catch (_) {}
                    await _load();
                  },
                  child: const Text('Đã xử lý'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
