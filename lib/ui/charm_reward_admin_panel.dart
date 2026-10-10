import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/charm_board.dart';
import '../data/economy.dart';
import '../data/game_data.dart';
import '../data/pet_items.dart';
import '../logic/charm_rewards.dart';
import '../logic/pet.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// `/quan-tri`, Xếp hạng Mị lực: review the board of one period and press
/// "Duyệt thưởng" (the season reward is written to every ranked player's
/// gift mailbox, once). The top 10 are shown big, with the Mị lực recomputed
/// from each player's saved game next to the stored one.
class CharmRewardAdminPanel extends StatefulWidget {
  const CharmRewardAdminPanel({
    super.key,
    required this.board,
    required this.store,
    required this.onClose,
    this.economy,
    this.now,
  });

  final CharmBoardSource board;
  final CharmRewardStore store;
  final VoidCallback onClose;

  /// The game's economy (tests pass it; the page loads the asset).
  final Economy? economy;
  final DateTime Function()? now;

  @override
  State<CharmRewardAdminPanel> createState() => _CharmRewardAdminPanelState();
}

class _CharmRewardAdminPanelState extends State<CharmRewardAdminPanel> {
  CharmReviewController? _review;
  final _period = TextEditingController();
  Object? _loadError;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final economy =
          widget.economy ??
          Economy.fromJson(
            jsonDecode(await rootBundle.loadString(GameData.economyAsset))
                as Map<String, dynamic>,
          );
      if (!mounted) return;
      _period.text = economy.charmBoard.periodKey;
      setState(() {
        _review = CharmReviewController(
          board: widget.board,
          store: widget.store,
          economy: economy,
          period: economy.charmBoard.periodKey,
        );
      });
      await _review!.loadBoard();
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  @override
  void dispose() {
    _review?.dispose();
    _period.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final review = _review;
    if (review == null) return;
    review.period = _period.text.trim();
    await review.loadBoard();
  }

  Future<void> _approve() async {
    final review = _review!;
    final n = review.payable.length;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('cra-confirm'),
        title: const Text('Duyệt thưởng?'),
        content: Text(
          'Gửi quà mùa ${review.period} cho $n người, vào hộp thư của họ. '
          'Mỗi người chỉ nhận một lần và không sửa được sau khi gửi.',
        ),
        actions: [
          TextButton(
            key: const Key('cra-confirm-no'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Để xem lại'),
          ),
          TextButton(
            key: const Key('cra-confirm-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Duyệt $n người'),
          ),
        ],
      ),
    );
    if (sure == true) await review.approve();
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    return Material(
      color: AppColors.bgBase,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('cra-back'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back),
                ),
                Text('Xếp hạng Mị lực', style: AppText.title(size: 22)),
              ],
            ),
          ),
          Expanded(
            child: review == null
                ? Center(
                    child: _loadError == null
                        ? const CircularProgressIndicator(strokeWidth: 3)
                        : Text(
                            'Chưa đọc được dữ liệu game.',
                            style: AppText.caption(
                              color: AppColors.statusDanger,
                            ),
                          ),
                  )
                : ListenableBuilder(
                    listenable: review,
                    builder: (context, _) => _body(review),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _body(CharmReviewController c) {
    final end = c.config.seasonEnd;
    final live = c.period == c.config.periodKey;
    final running = live && end != null && _now().isBefore(end);
    final apply = c.payable.length;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('cra-period'),
                      controller: _period,
                      decoration: const InputDecoration(
                        labelText: 'Mùa (periodKey)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlineButton(
                    key: const Key('cra-load'),
                    label: 'Tải bảng',
                    width: 96,
                    height: 40,
                    onTap: _load,
                  ),
                ],
              ),
              if (running)
                _note(
                  'Mùa này chưa kết thúc (${_dayLabel(end)}). Bảng còn thay '
                  'đổi: nên chờ hết mùa rồi mới duyệt.',
                  warn: true,
                ),
              if (c.load == ReviewLoad.loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              if (c.load == ReviewLoad.error)
                _note(
                  'Chưa tải được bảng. Kiểm tra mùa, mạng và rules rồi thử lại.',
                  warn: true,
                ),
              if (c.load == ReviewLoad.ready) ...[
                _summary(c),
                if (c.rows.isEmpty)
                  _note('Mùa này chưa có ai trên bảng.')
                else ...[
                  _section('Top 10'),
                  for (final r in c.top) _bigRow(c, r),
                  if (c.rest.isNotEmpty) ...[
                    _section('Hạng 11 đến ${c.rows.length}'),
                    for (final r in c.rest) _smallRow(c, r),
                  ],
                ],
              ],
            ],
          ),
        ),
        if (c.load == ReviewLoad.ready)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.lastApproval != null) _result(c.lastApproval!),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ChunkyButton(
                    key: const Key('cra-approve'),
                    label: c.approving
                        ? 'Đang gửi…'
                        : apply == 0
                        ? 'Không còn ai để duyệt'
                        : 'Duyệt thưởng ($apply người)',
                    enabled: apply > 0 && !c.approving,
                    onPressed: _approve,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _summary(CharmReviewController c) {
    final look = c.rows.where((r) => r.needsLook).length;
    return Container(
      key: const Key('cra-summary'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${c.rows.length} người trên bảng · sẽ duyệt ${c.payable.length} · '
        'đã duyệt ${c.alreadyPaid} · bỏ qua ${c.skipped.length}'
        '${look > 0 ? ' · cần xem lại $look' : ''}',
        style: AppText.body(size: 14, weight: 800),
      ),
    );
  }

  Widget _result(CharmApproval a) {
    final parts = [
      if (a.created > 0) 'đã gửi ${a.created}',
      if (a.already > 0) '${a.already} đã có từ trước',
      if (a.failed > 0) '${a.failed} lỗi, bấm lại để thử tiếp',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        parts.isEmpty ? 'Không có gì để gửi.' : parts.join(' · '),
        key: const Key('cra-result'),
        style: AppText.body(
          size: 14,
          weight: 800,
          color: a.failed > 0
              ? AppColors.statusDanger
              : AppColors.primaryPressed,
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(text, style: AppText.title(size: 17)),
  );

  Widget _note(String text, {bool warn = false}) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: warn ? AppColors.accentSoft : AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: AppText.caption(color: AppColors.textPrimary)),
  );

  String _petLine(CharmReviewRow r) {
    final id = r.savedPetId ?? r.entry.petId;
    final stage = r.savedStage ?? r.entry.stage;
    final name = _petName(id);
    return '$name · ${petStageName(stage)}';
  }

  String _petName(String id) {
    for (final p in _review!.economy.pets) {
      if (p.id == id) return p.nameVi;
    }
    return id.isEmpty ? '(chưa có)' : id;
  }

  String _wornLine(CharmReviewRow r) {
    final worn = r.save == null ? r.entry.worn : r.savedWorn;
    if (worn.isEmpty) return 'Không đeo đồ';
    return [
      for (final slot in charmBoardSlots)
        if (worn[slot] != null)
          _review!.economy.petItem(worn[slot]!)?.nameVi ?? worn[slot]!,
    ].join(', ');
  }

  String _rewardLine(CharmReviewController c, CharmReviewRow r) {
    final line = c.config.rewardFor(r.rank);
    if (line == null) return 'Không có thưởng';
    final tier = PetItemTier.fromKey(line.itemTier);
    return [
      if (line.phaLe > 0) '${line.phaLe} Pha lê',
      if (line.giotHoa > 0) '${line.giotHoa} Giọt hoa',
      if (tier != null) 'đồ ${_tierName(tier)} ngẫu nhiên',
    ].join(' · ');
  }

  Widget _check(CharmReviewRow r) {
    final ok = !r.needsLook;
    final text = r.recomputed == null
        ? 'Không đọc được save'
        : ok
        ? 'Tính lại ${r.recomputed}: khớp'
        : 'Tính lại ${r.recomputed}, bảng ghi ${r.entry.charm}';
    return Container(
      key: Key('cra-check-${r.rank}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? AppColors.primarySoft : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok ? AppColors.primaryBase : AppColors.statusWarning,
        ),
      ),
      child: Text(
        text,
        style: AppText.caption(
          size: 12,
          color: AppColors.textPrimary,
        ).copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _status(CharmReviewController c, CharmReviewRow r) {
    if (r.granted) {
      return Text(
        'Đã duyệt',
        key: Key('cra-paid-${r.rank}'),
        style: AppText.caption(
          color: AppColors.primaryPressed,
        ).copyWith(fontWeight: FontWeight.w800),
      );
    }
    if (!c.paysRank(r)) return const SizedBox.shrink();
    final skipped = c.skipped.contains(r.entry.uid);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          key: Key('cra-skip-${r.entry.uid}'),
          value: skipped,
          visualDensity: VisualDensity.compact,
          activeColor: AppColors.primaryBase,
          onChanged: (_) => c.toggleSkip(r.entry.uid),
        ),
        Text('Bỏ qua', style: AppText.caption()),
      ],
    );
  }

  Widget _bigRow(CharmReviewController c, CharmReviewRow r) {
    final skipped = c.skipped.contains(r.entry.uid);
    return Container(
      key: Key('cra-top-${r.rank}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: skipped ? const Color(0xFFF0EEE6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: r.needsLook
              ? AppColors.statusWarning
              : AppColors.surfaceBorder,
          width: r.needsLook ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: r.rank <= 3 ? AppColors.accentBase : AppColors.primaryBase,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${r.rank}',
              style: AppText.title(size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(size: 16),
                      ),
                    ),
                    Text('${r.entry.charm}', style: AppText.title(size: 20)),
                  ],
                ),
                Text(
                  'uid ${_short(r.entry.uid)} · ${_petLine(r)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(),
                ),
                Text(
                  _wornLine(r),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [_check(r), _status(c, r)],
                ),
                const SizedBox(height: 4),
                Text(
                  _rewardLine(c, r),
                  style: AppText.caption(
                    color: AppColors.primaryPressed,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallRow(CharmReviewController c, CharmReviewRow r) {
    return Container(
      key: Key('cra-row-${r.rank}'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: r.needsLook
              ? AppColors.statusWarning
              : AppColors.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('${r.rank}', style: AppText.title(size: 14)),
          ),
          Expanded(
            child: Text(
              r.entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 14, weight: 800),
            ),
          ),
          Text(
            r.recomputed == null || !r.needsLook
                ? '${r.entry.charm}'
                : '${r.entry.charm} ≠ ${r.recomputed}',
            style: AppText.body(
              size: 14,
              weight: 800,
              color: r.needsLook
                  ? AppColors.statusWarning
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          _status(c, r),
        ],
      ),
    );
  }
}

String _short(String uid) => uid.length <= 8 ? uid : uid.substring(0, 8);

String _dayLabel(DateTime end) {
  // The season ends at the stroke of Monday 00:00 Vietnam time.
  final d = end
      .toUtc()
      .add(const Duration(hours: 7))
      .subtract(const Duration(minutes: 1));
  return 'kết thúc ${d.day}/${d.month}/${d.year}';
}

String _tierName(PetItemTier tier) => switch (tier) {
  PetItemTier.thuong => 'thường',
  PetItemTier.hiem => 'hiếm',
  PetItemTier.suThi => 'sử thi',
  PetItemTier.huyenThoai => 'huyền thoại',
};
