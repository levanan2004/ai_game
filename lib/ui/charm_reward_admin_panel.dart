import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/charm_board.dart';
import '../data/economy.dart';
import '../data/game_data.dart';
import '../data/pet_items.dart';
import '../logic/charm_payout.dart';
import '../logic/charm_rewards.dart';
import '../logic/pet.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// `/quan-tri`, Xếp hạng Mị lực. View first: the season reward is paid
/// automatically by the scheduled function (functions/payout.js) a few minutes
/// after the season ends, so this page shows what it did (sent / dropped /
/// held), has the kill switch, and keeps "Duyệt thưởng" for the HELD rows only
/// (an admin releases them one by one). Before the payout has run it shows a
/// preview of the live board with the Mị lực recomputed from every save.
class CharmRewardAdminPanel extends StatefulWidget {
  const CharmRewardAdminPanel({
    super.key,
    required this.board,
    required this.store,
    required this.payout,
    required this.onClose,
    this.economy,
    this.now,
  });

  final CharmBoardSource board;
  final CharmRewardStore store;
  final CharmPayoutStore payout;
  final VoidCallback onClose;

  /// The game's economy (tests pass it; the page loads the asset).
  final Economy? economy;
  final DateTime Function()? now;

  @override
  State<CharmRewardAdminPanel> createState() => _CharmRewardAdminPanelState();
}

class _CharmRewardAdminPanelState extends State<CharmRewardAdminPanel> {
  CharmReviewController? _review;
  CharmPayoutController? _pay;
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
      final period = economy.charmBoard.periodKey;
      _period.text = period;
      setState(() {
        _review = CharmReviewController(
          board: widget.board,
          store: widget.store,
          economy: economy,
          period: period,
        );
        _pay = CharmPayoutController(
          payout: widget.payout,
          rewards: widget.store,
          economy: economy,
          period: period,
        );
      });
      await _load(first: true);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  @override
  void dispose() {
    _review?.dispose();
    _pay?.dispose();
    _period.dispose();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    final review = _review, pay = _pay;
    if (review == null || pay == null) return;
    final period = first ? review.period : _period.text.trim();
    review.period = period;
    pay.period = period;
    await pay.load();
    // The preview is only worth the reads while the payout has not run.
    if (!pay.meta.ran) await review.loadBoard();
  }

  /// Season state of the period on screen: the meta doc's `endsAt` (the one
  /// the rules enforce, admin-editable) or else the config's end.
  SeasonPhase _phase() {
    final review = _review, pay = _pay;
    if (review == null || pay == null) return SeasonPhase.unknown;
    final end =
        pay.meta.endsAt ??
        (pay.period == review.config.periodKey
            ? review.config.seasonEnd
            : null);
    return seasonPhaseAt(end, _now());
  }

  DateTime? _end() =>
      _pay?.meta.endsAt ??
      (_pay?.period == _review?.config.periodKey
          ? _review?.config.seasonEnd
          : null);

  /// Warning shown while the season is running or inside the 5-minute grace
  /// after it. It never blocks a release.
  String? _seasonWarning() {
    switch (_phase()) {
      case SeasonPhase.running:
        final end = _end();
        return 'Mùa này chưa kết thúc${end == null ? '' : ' (${_dayLabel(end)})'}. '
            'Bảng còn thay đổi, thứ hạng có thể đổi sau khi duyệt.';
      case SeasonPhase.grace:
        return 'Mùa vừa kết thúc, còn trong ${charmBoardWriteGrace.inMinutes} '
            'phút chờ ghi nốt. Đợi hết thời gian này để bảng đứng yên rồi hãy '
            'duyệt.';
      case SeasonPhase.unknown:
      case SeasonPhase.ended:
        return null;
    }
  }

  Future<void> _release(PayoutLine line) async {
    final pay = _pay!;
    final warn = _seasonWarning();
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('cra-confirm'),
        title: const Text('Duyệt thưởng?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (warn != null) ...[
              Text(
                warn,
                key: const Key('cra-confirm-warn'),
                style: AppText.body(
                  size: 14,
                  weight: 800,
                  color: AppColors.statusDanger,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Gửi quà hạng ${line.rank} mùa ${pay.period} cho '
              '${line.displayName.isEmpty ? line.uid : line.displayName}, '
              'vào hộp thư của họ. Chỉ gửi một lần và không sửa được sau khi '
              'gửi.\n${line.why.join(' · ')}',
            ),
          ],
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
            child: const Text('Duyệt'),
          ),
        ],
      ),
    );
    if (sure == true) await pay.release(line);
  }

  @override
  Widget build(BuildContext context) {
    final pay = _pay, review = _review;
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
            child: pay == null || review == null
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
                    listenable: Listenable.merge([pay, review]),
                    builder: (context, _) => _body(pay, review),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _body(CharmPayoutController p, CharmReviewController c) {
    final warn = _seasonWarning();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
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
        _switchCard(p),
        if (warn != null)
          _note(warn, key: const Key('cra-season-warn'), warn: true),
        if (p.loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
          ),
        if (p.failed)
          _note(
            'Chưa tải được kết quả chốt. Kiểm tra mùa, mạng và rules rồi thử lại.',
            warn: true,
          ),
        if (!p.loading && !p.failed)
          if (p.meta.ran) ..._payoutView(p) else ..._preview(p, c),
      ],
    );
  }

  Widget _switchCard(CharmPayoutController p) {
    return Container(
      key: const Key('cra-auto-card'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      decoration: BoxDecoration(
        color: p.autoPayout ? Colors.white : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.autoPayout
              ? AppColors.surfaceBorder
              : AppColors.statusWarning,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tự động trả thưởng', style: AppText.title(size: 16)),
                Text(
                  p.autoPayout
                      ? 'Bật: hệ thống tự gửi quà sau khi hết mùa 5 phút.'
                      : 'Tắt: sẽ không ai được trả thưởng cho tới khi bật lại.',
                  key: const Key('cra-auto-text'),
                  style: AppText.caption(),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('cra-auto'),
            value: p.autoPayout,
            onChanged: p.savingSwitch ? null : p.setAutoPayout,
          ),
        ],
      ),
    );
  }

  // -- after the payout ran -----------------------------------------------------

  List<Widget> _payoutView(CharmPayoutController p) {
    final m = p.meta;
    return [
      Container(
        key: const Key('cra-payout-summary'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Đã chốt mùa ${p.period} · đã gửi ${p.sent.length} · '
          'giữ lại chờ duyệt ${p.held.length} · bỏ qua ${p.skipped.length}'
          '${p.failedLines.isEmpty ? '' : ' · lỗi ${p.failedLines.length} (sẽ tự thử lại)'}'
          '${m.status == 'partial' ? ' · chưa xong hết' : ''}',
          style: AppText.body(size: 14, weight: 800),
        ),
      ),
      _section('Giữ lại chờ duyệt (${p.held.length})'),
      if (p.held.isEmpty)
        _note('Không có dòng nào bị giữ lại.', key: const Key('cra-held-none'))
      else
        for (final l in p.held) _heldCard(p, l),
      _section('Đã gửi (${p.sent.length})'),
      for (final l in p.sent) _lineRow(l, key: Key('cra-sent-${l.uid}')),
      if (p.skipped.isNotEmpty) ...[
        _section('Bỏ qua, không có thưởng (${p.skipped.length})'),
        for (final l in p.skipped)
          _lineRow(l, key: Key('cra-skipped-${l.uid}')),
      ],
      if (p.failedLines.isNotEmpty) ...[
        _section('Gửi lỗi (${p.failedLines.length})'),
        for (final l in p.failedLines)
          _lineRow(l, key: Key('cra-failed-${l.uid}')),
      ],
    ];
  }

  Widget _heldCard(CharmPayoutController p, PayoutLine l) {
    final busy = p.releasing.contains(l.uid);
    return Container(
      key: Key('cra-held-${l.uid}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.statusWarning, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accentBase,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${l.rank}',
                  style: AppText.title(size: 16, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.displayName.isEmpty ? l.uid : l.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(size: 16),
                ),
              ),
              Text('${l.recomputed}', style: AppText.title(size: 20)),
            ],
          ),
          Text(
            'uid ${_short(l.uid)} · ${_petName(l.petId)} · '
            '${petStageName(l.stage)} · bảng ghi ${l.stored}, tính lại '
            '${l.recomputed}',
            style: AppText.caption(),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final f in l.flags)
                Container(
                  key: Key('cra-flag-${l.uid}-$f'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.statusWarning),
                  ),
                  child: Text(
                    payoutFlagText(f),
                    style: AppText.caption(
                      size: 12,
                      color: AppColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _rewardLine(l.rank),
            style: AppText.caption(
              color: AppColors.primaryPressed,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ChunkyButton(
              key: Key('cra-release-${l.uid}'),
              label: busy ? 'Đang gửi…' : 'Duyệt thưởng',
              enabled: !busy,
              onPressed: () => _release(l),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineRow(PayoutLine l, {required Key key}) {
    final released = l.status == PayoutStatus.released;
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              l.rank == 0 ? '-' : '${l.rank}',
              style: AppText.title(size: 14),
            ),
          ),
          Expanded(
            child: Text(
              l.displayName.isEmpty ? l.uid : l.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 14, weight: 800),
            ),
          ),
          if (l.status == PayoutStatus.skipped || released)
            Flexible(
              child: Text(
                released ? 'Admin đã duyệt' : l.why.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(),
              ),
            )
          else
            Text('${l.recomputed}', style: AppText.body(size: 14, weight: 800)),
        ],
      ),
    );
  }

  // -- before the payout: a preview of the live board ---------------------------

  List<Widget> _preview(CharmPayoutController p, CharmReviewController c) {
    return [
      _note(
        'Chưa chốt mùa này. Hệ thống tự chốt khi hết mùa 5 phút (nếu công tắc '
        'trên đang bật). Dưới đây chỉ là bản xem trước của bảng hiện tại.',
        key: const Key('cra-not-yet'),
      ),
      if (c.load == ReviewLoad.loading)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
        ),
      if (c.load == ReviewLoad.error)
        _note(
          'Chưa tải được bảng. Kiểm tra mùa, mạng và rules rồi thử lại.',
          warn: true,
        ),
      if (c.load == ReviewLoad.ready) ...[
        _previewSummary(c),
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
    ];
  }

  Widget _previewSummary(CharmReviewController c) {
    final drop = c.flagged.length;
    final hold = c.rows.where((r) => !c.underMin(r) && r.willHold).length;
    return Container(
      key: const Key('cra-summary'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${c.rows.length} người trên bảng · sẽ bị bỏ qua $drop (dưới '
        '${c.config.minCharm} Mị lực, không đọc được save hoặc không có thú) · '
        'sẽ bị giữ lại chờ duyệt $hold (bảng ghi cao hơn Mị lực tính lại, hoặc trên 600)',
        style: AppText.body(size: 14, weight: 800),
      ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(text, style: AppText.title(size: 17)),
  );

  Widget _note(String text, {bool warn = false, Key? key}) => Container(
    key: key,
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
    return '${_petName(id)} · ${petStageName(stage)}';
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

  String _rewardLine(int rank) {
    final line = _review!.config.rewardFor(rank);
    if (line == null) return 'Không có thưởng';
    final tier = PetItemTier.fromKey(line.itemTier);
    return [
      if (line.phaLe > 0) '${line.phaLe} Pha lê',
      if (line.giotHoa > 0) '${line.giotHoa} Giọt hoa',
      if (tier != null) 'đồ ${_tierName(tier)} ngẫu nhiên',
    ].join(' · ');
  }

  Widget _check(CharmReviewController c, CharmReviewRow r) {
    final ok = !r.willHold && !c.underMin(r);
    final text = r.recomputed == null
        ? 'Không đọc được save'
        : c.underMin(r)
        ? 'Tính lại ${r.recomputed}: dưới ${c.config.minCharm}'
        : r.recomputed == r.entry.charm
        ? 'Tính lại ${r.recomputed}: khớp'
        : ok
        ? 'Tính lại ${r.recomputed}, bảng ghi ${r.entry.charm}: trả theo ${r.recomputed}'
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

  /// What the payout will do with this row (preview only).
  Widget _fate(CharmReviewController c, CharmReviewRow r) {
    final text = c.underMin(r)
        ? 'Sẽ bị bỏ qua'
        : r.willHold
        ? 'Sẽ bị giữ lại chờ duyệt'
        : null;
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      key: Key('cra-fate-${r.rank}'),
      style: AppText.caption(
        color: AppColors.statusWarning,
      ).copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _bigRow(CharmReviewController c, CharmReviewRow r) {
    return Container(
      key: Key('cra-top-${r.rank}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: r.willHold || c.underMin(r)
              ? AppColors.statusWarning
              : AppColors.surfaceBorder,
          width: r.willHold ? 2 : 1,
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
                  children: [_check(c, r), _fate(c, r)],
                ),
                const SizedBox(height: 4),
                Text(
                  _rewardLine(r.rank),
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
          color: r.willHold || c.underMin(r)
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
            r.recomputed == null || !r.willHold
                ? '${r.entry.charm}'
                : '${r.entry.charm} ≠ ${r.recomputed}',
            style: AppText.body(
              size: 14,
              weight: 800,
              color: r.willHold
                  ? AppColors.statusWarning
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          _fate(c, r),
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
