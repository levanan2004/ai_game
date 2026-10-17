import 'package:flutter/material.dart';

import '../logic/game_notice.dart' show noticeDateLabel;
import '../logic/profile_report.dart';
import '../logic/world_chat_admin.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'world_chat_admin_panel.dart';

/// `/quan-tri` → Báo cáo: the newest profile reports (Apple 1.2), read only.
/// Acting on one (renaming a shop, hiding an avatar) is done by hand for now.
/// Below them, the Tin thế giới reports with "Gỡ tin", the penalty ladder
/// and "Đã xử lý" ([chat]).
class ReportAdminPanel extends StatefulWidget {
  const ReportAdminPanel({
    super.key,
    required this.reports,
    required this.onClose,
    this.chat,
  });

  final ProfileReports reports;

  /// Tin thế giới reports (chat_reports); null hides that part.
  final WorldChatAdmin? chat;
  final VoidCallback onClose;

  @override
  State<ReportAdminPanel> createState() => _ReportAdminPanelState();
}

class _ReportAdminPanelState extends State<ReportAdminPanel> {
  List<ProfileReport>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final all = await widget.reports.latest();
      if (mounted) setState(() => _list = all);
    } catch (_) {
      if (mounted) {
        setState(() {
          _list = const [];
          _error = 'Chưa tải được báo cáo.';
        });
      }
    }
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
                  key: const Key('report-admin-back'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text('Báo cáo', style: AppText.title(size: 22)),
                ),
                IconButton(
                  key: const Key('report-admin-reload'),
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
                      if (list.isEmpty && _error == null)
                        Text('Chưa có báo cáo.', style: AppText.caption()),
                      for (final r in list) _row(r),
                      if (widget.chat != null)
                        ChatReportsSection(admin: widget.chat!),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(ProfileReport r) {
    final meta = [
      noticeDateLabel(r.createdAt),
      'người báo cáo ${r.reporterUid}',
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CardBox(
        key: Key('report-${r.reporterUid}_${r.targetUid}'),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.targetName} (${r.targetUid})',
              style: AppText.body(size: 14, weight: 800),
            ),
            Text(r.reason.label, style: AppText.body(size: 13, weight: 700)),
            if (r.note.isNotEmpty)
              Text(r.note, style: AppText.body(size: 13, weight: 600)),
            Text(meta, style: AppText.caption(size: 11)),
          ],
        ),
      ),
    );
  }
}
