import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/giftcodes.dart';
import '../logic/login_rewards.dart';
import '../logic/mailbox.dart' show mailExpiryLabel;
import '../logic/photo_uploads.dart';
import '../logic/rewards.dart';
import '../logic/welfare.dart';
import '../logic/welfare_slides.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'notice_image.dart';
import 'reward_picker.dart';
import 'text_download.dart';
import 'welfare_slides_view.dart';

enum _Part { login, codes, slides }

/// /quan-tri → Phúc lợi: the Điểm danh table, giftcodes and slides.
class WelfareAdminPanel extends StatefulWidget {
  const WelfareAdminPanel({
    super.key,
    required this.admin,
    required this.onClose,
    this.photos,
    this.now,
  });

  final WelfareAdmin admin;
  final VoidCallback onClose;
  final PhotoUploads? photos;
  final DateTime Function()? now;

  @override
  State<WelfareAdminPanel> createState() => _WelfareAdminPanelState();
}

class _WelfareAdminPanelState extends State<WelfareAdminPanel> {
  var _part = _Part.login;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgBase,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
            child: Row(
              children: [
                IconButton(
                  key: const Key('welfare-admin-back'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back),
                ),
                Text('Phúc lợi', style: AppText.title(size: 22)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                _chip(_Part.login, 'Điểm danh 7 ngày'),
                _chip(_Part.codes, 'Giftcode'),
                _chip(_Part.slides, 'Bạn biết?'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: switch (_part) {
              _Part.login => _LoginAdmin(admin: widget.admin),
              _Part.codes => _CodeAdmin(
                admin: widget.admin,
                now: widget.now ?? DateTime.now,
              ),
              _Part.slides => _SlideAdmin(
                admin: widget.admin,
                photos: widget.photos,
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(_Part part, String label) => ChoiceChip(
    key: Key('welfare-admin-${part.name}'),
    label: Text(label),
    selected: _part == part,
    onSelected: (_) => setState(() => _part = part),
  );
}

String _firestoreError(Object e, String fallback) =>
    '$e'.contains('permission-denied')
    ? 'Firestore từ chối. Deploy rules mới rồi thử lại.'
    : fallback;

Widget _field(
  Key key,
  String hint,
  TextEditingController controller, {
  TextInputType? keyboard,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      key: key,
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(isDense: true, hintText: hint),
    ),
  );
}

Widget _errorText(String? error, Key key) => error == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          error,
          key: key,
          style: AppText.caption(color: AppColors.statusDanger),
        ),
      );

// ---------------------------------------------------------------------------
// Điểm danh

class _LoginAdmin extends StatefulWidget {
  const _LoginAdmin({required this.admin});

  final WelfareAdmin admin;

  @override
  State<_LoginAdmin> createState() => _LoginAdminState();
}

enum _LoginTable { newbie, weekly, milestones }

class _LoginAdminState extends State<_LoginAdmin> {
  LoginRewardConfig? _config;
  var _fromDefault = false;
  var _legacy = false;
  var _table = _LoginTable.newbie;
  var _day = 1;
  var _milestone = 0;
  var _busy = false;
  String? _error;
  String? _saved;
  var _version = 0;
  final _msDay = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msDay.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await widget.admin.loadLoginConfig();
      if (!mounted) return;
      setState(() {
        _config = c ?? defaultLoginRewards;
        _fromDefault = c == null;
      });
    } on LegacyLoginConfig {
      if (!mounted) return;
      setState(() {
        _config = defaultLoginRewards;
        _fromDefault = true;
        _legacy = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _config = defaultLoginRewards;
        _fromDefault = true;
        _error = 'Chưa tải được bảng, đang hiện bảng mặc định.';
      });
    }
    _syncMsDay();
  }

  void _syncMsDay() {
    final ms = _config?.milestones ?? const [];
    _msDay.text = _milestone < ms.length ? '${ms[_milestone].day}' : '';
  }

  String? _problem(LoginRewardConfig c) {
    for (final weekly in [false, true]) {
      final empty = [
        for (var n = 1; n <= loginRewardDays; n++)
          if (c.day(n, cycle: weekly ? 2 : 1).isEmpty) n,
      ];
      if (empty.isNotEmpty) {
        return '${weekly ? 'Từ tuần 2' : 'Tuần tân thủ'}: '
            'ngày ${empty.join(', ')} chưa có quà.';
      }
    }
    final days = <int>{};
    for (final m in c.milestones) {
      if (m.rewards.isEmpty) return 'Mốc ${m.day} ngày chưa có quà.';
      if (!days.add(m.day)) return 'Hai mốc cùng ${m.day} ngày.';
    }
    if (c.milestones.length > LoginRewardConfig.maxMilestones) {
      return 'Tối đa ${LoginRewardConfig.maxMilestones} mốc.';
    }
    return null;
  }

  Future<void> _save() async {
    final c = _config;
    if (c == null || _busy) return;
    final problem = _problem(c);
    if (problem != null) {
      setState(() {
        _error = problem;
        _saved = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _saved = null;
    });
    try {
      await widget.admin.saveLoginConfig(c);
      if (!mounted) return;
      setState(() {
        _fromDefault = false;
        _legacy = false;
        _saved = 'Đã lưu bảng điểm danh.';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = _firestoreError(e, 'Chưa lưu được.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMilestones(List<LoginMilestone> list, {LoginMilestone? select}) {
    final c = _config!.copyWith(milestones: list);
    _config = c;
    _saved = null;
    if (select != null) {
      final i = c.milestones.indexOf(select);
      if (i >= 0) _milestone = i;
    }
    if (_milestone >= c.milestones.length) {
      _milestone = c.milestones.isEmpty ? 0 : c.milestones.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _config;
    if (c == null) return const Center(child: CircularProgressIndicator());
    final weekly = _table == _LoginTable.weekly;
    final cycle = weekly ? 2 : 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        if (_legacy)
          Text(
            'config/loginRewards đang ở dạng cũ (1 bảng): game bỏ qua nó và '
            'dùng bảng mặc định mới. Bấm Lưu bảng để ghi dạng mới.',
            key: const Key('login-admin-legacy'),
            style: AppText.body(size: 13, weight: 800),
          )
        else if (_fromDefault)
          Text(
            'Chưa có config/loginRewards: đang dùng bảng mặc định. Bấm Lưu để ghi lên Firestore.',
            key: const Key('login-admin-default'),
            style: AppText.caption(),
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final t in _LoginTable.values)
              ChoiceChip(
                key: Key('login-admin-table-${t.name}'),
                label: Text(switch (t) {
                  _LoginTable.newbie => 'Tuần tân thủ',
                  _LoginTable.weekly => 'Từ tuần 2',
                  _LoginTable.milestones => 'Mốc tổng ngày',
                }),
                selected: t == _table,
                onSelected: (_) => setState(() {
                  _table = t;
                  _syncMsDay();
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_table == _LoginTable.milestones)
          ..._milestoneEditor(c)
        else ...[
          for (var n = 1; n <= loginRewardDays; n++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Ngày $n: ${c.day(n, cycle: cycle).isEmpty ? '(trống)' : c.day(n, cycle: cycle).label}',
                key: Key('login-admin-line-$n'),
                style: AppText.body(size: 13, weight: n == _day ? 800 : 600),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (var n = 1; n <= loginRewardDays; n++)
                ChoiceChip(
                  key: Key('login-admin-day-$n'),
                  label: Text('Ngày $n'),
                  selected: n == _day,
                  onSelected: (_) => setState(() => _day = n),
                ),
            ],
          ),
          const SizedBox(height: 8),
          RewardPicker(
            key: ValueKey('login-day-${_table.name}-$_day-$_version'),
            bundle: c.day(_day, cycle: cycle),
            xuKey: const Key('login-admin-xu'),
            onChanged: (b) => setState(() {
              _config = c.withDay(_day, b, weekly: weekly);
              _saved = null;
            }),
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('login-admin-repeat'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Lặp bảng "Từ tuần 2" mỗi tuần'),
          subtitle: const Text('Tắt: xong tuần tân thủ là dừng.'),
          value: c.repeat,
          onChanged: (v) => setState(() => _config = c.copyWith(repeat: v)),
        ),
        SwitchListTile(
          key: const Key('login-admin-consecutive'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Phải điểm danh liên tục'),
          subtitle: const Text('Bật: lỡ một ngày thì quay về ngày 1.'),
          value: c.consecutive,
          onChanged: (v) =>
              setState(() => _config = c.copyWith(consecutive: v)),
        ),
        _errorText(_error, const Key('login-admin-error')),
        if (_saved != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _saved!,
              key: const Key('login-admin-saved'),
              style: AppText.body(size: 14, weight: 800),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ChunkyButton(
                  key: const Key('login-admin-save'),
                  label: _busy ? 'Đang lưu...' : 'Lưu bảng',
                  enabled: !_busy,
                  onPressed: _busy ? null : _save,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlineButton(
              key: const Key('login-admin-reset'),
              label: 'Bảng mặc định',
              width: 120,
              height: 40,
              onTap: () => setState(() {
                _config = defaultLoginRewards.copyWith(
                  repeat: c.repeat,
                  consecutive: c.consecutive,
                );
                _milestone = 0;
                _syncMsDay();
                _version++;
              }),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _milestoneEditor(LoginRewardConfig c) {
    final ms = c.milestones;
    final current = _milestone < ms.length ? ms[_milestone] : null;
    return [
      Text(
        'Quà một lần khi tổng số ngày điểm danh (mọi tuần) đạt mốc.',
        style: AppText.caption(),
      ),
      const SizedBox(height: 4),
      for (var i = 0; i < ms.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Mốc ${ms[i].day} ngày: '
            '${ms[i].rewards.isEmpty ? '(trống)' : ms[i].rewards.label}',
            key: Key('login-admin-ms-line-$i'),
            style: AppText.body(size: 13, weight: i == _milestone ? 800 : 600),
          ),
        ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < ms.length; i++)
            ChoiceChip(
              key: Key('login-admin-ms-$i'),
              label: Text('Mốc ${ms[i].day}'),
              selected: i == _milestone,
              onSelected: (_) => setState(() {
                _milestone = i;
                _syncMsDay();
              }),
            ),
          if (ms.length < LoginRewardConfig.maxMilestones)
            ActionChip(
              key: const Key('login-admin-ms-add'),
              label: const Text('+ Thêm mốc'),
              onPressed: () => setState(() {
                final day = (ms.isEmpty ? 0 : ms.last.day) + 7;
                final added = LoginMilestone(day, RewardBundle.empty);
                _setMilestones([...ms, added], select: added);
                _syncMsDay();
                _version++;
              }),
            ),
        ],
      ),
      if (current != null) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('login-admin-ms-day'),
                controller: _msDay,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Số ngày điểm danh (tổng)',
                ),
                onChanged: (v) {
                  final day = int.tryParse(v.trim());
                  if (day == null || day < 1) return;
                  setState(() {
                    final edited = LoginMilestone(day, current.rewards);
                    _setMilestones([
                      for (final m in ms)
                        if (identical(m, current)) edited else m,
                    ], select: edited);
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            OutlineButton(
              key: const Key('login-admin-ms-remove'),
              label: 'Xoá mốc',
              width: 96,
              height: 40,
              onTap: () => setState(() {
                _setMilestones([
                  for (final m in ms)
                    if (!identical(m, current)) m,
                ]);
                _syncMsDay();
                _version++;
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RewardPicker(
          key: ValueKey('login-ms-$_milestone-$_version'),
          bundle: current.rewards,
          xuKey: const Key('login-admin-ms-xu'),
          onChanged: (b) => setState(() {
            _setMilestones([
              for (final m in ms)
                if (identical(m, current)) LoginMilestone(m.day, b) else m,
            ]);
          }),
        ),
      ],
    ];
  }
}

// ---------------------------------------------------------------------------
// Giftcode

class _CodeAdmin extends StatefulWidget {
  const _CodeAdmin({required this.admin, required this.now});

  final WelfareAdmin admin;
  final DateTime Function() now;

  @override
  State<_CodeAdmin> createState() => _CodeAdminState();
}

class _CodeAdminState extends State<_CodeAdmin> {
  final _title = TextEditingController();
  final _code = TextEditingController();
  final _maxUses = TextEditingController();
  final _prefix = TextEditingController();
  final _count = TextEditingController(text: '100');
  var _type = GiftcodeType.shared;
  var _rewards = RewardBundle.empty;
  DateTime? _starts;
  DateTime? _expires;
  var _busy = false;
  int? _written;
  int? _total;
  String? _error;
  String? _done;

  /// Codes of the last bulk batch, for Sao chép / Tải CSV.
  List<String>? _lastCodes;
  String _lastName = '';
  List<GiftcodeBatch>? _batches;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    _maxUses.dispose();
    _prefix.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await widget.admin.loadBatches();
      if (mounted) setState(() => _batches = list);
    } catch (_) {
      if (mounted) setState(() => _batches = const []);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final now = widget.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _starts : _expires) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _starts = DateTime(picked.year, picked.month, picked.day);
      } else {
        _expires = DateTime(picked.year, picked.month, picked.day, 23, 59);
      }
    });
  }

  void _fail(String message) => setState(() {
    _error = message;
    _done = null;
  });

  Future<void> _create() async {
    if (_busy) return;
    if (_rewards.isEmpty) {
      _fail('Chọn quà cho mã.');
      return;
    }
    if (_starts != null && _expires != null && !_expires!.isAfter(_starts!)) {
      {
        _fail('Ngày hết hạn phải sau ngày bắt đầu.');
        return;
      }
    }
    final id = widget.admin.newBatchId();
    if (_type == GiftcodeType.shared) {
      final code = normalizeGiftcode(_code.text);
      if (code == null) {
        _fail('Mã gồm 4–32 chữ A–Z hoặc số.');
        return;
      }
      final rawMax = _maxUses.text.trim();
      final maxUses = rawMax.isEmpty ? null : int.tryParse(rawMax);
      if (rawMax.isNotEmpty && (maxUses == null || maxUses <= 0)) {
        {
          _fail('Giới hạn lượt dùng là số lớn hơn 0, hoặc để trống.');
          return;
        }
      }
      setState(() {
        _busy = true;
        _error = null;
        _done = null;
      });
      try {
        if (await widget.admin.codeExists(code)) {
          _fail('Mã $code đã có rồi.');
          return;
        }
        await widget.admin.createShared(
          GiftcodeBatch(
            id: id,
            type: GiftcodeType.shared,
            title: _title.text,
            code: code,
            rewards: _rewards,
            startsAt: _starts,
            expiresAt: _expires,
            maxUses: maxUses,
          ),
        );
        if (!mounted) return;
        setState(() {
          _done = 'Đã tạo mã $code.';
          _code.clear();
        });
        _load();
      } catch (e) {
        if (mounted) _fail(_firestoreError(e, 'Chưa tạo được mã.'));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    final prefix = normalizeGiftcodePrefix(_prefix.text);
    if (prefix == null) {
      {
        _fail('Tiền tố tối đa $maxGiftcodePrefix chữ A–Z hoặc số.');
        return;
      }
    }
    final count = int.tryParse(_count.text.trim());
    if (count == null || count <= 0 || count > maxGiftcodeBatch) {
      {
        _fail('Số mã từ 1 đến $maxGiftcodeBatch.');
        return;
      }
    }
    final codes = generateGiftcodes(count, prefix: prefix);
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
      _written = 0;
      _total = count;
      _lastCodes = null;
    });
    try {
      await widget.admin.createBulk(
        GiftcodeBatch(
          id: id,
          type: GiftcodeType.single,
          title: _title.text,
          prefix: prefix,
          count: count,
          rewards: _rewards,
          startsAt: _starts,
          expiresAt: _expires,
        ),
        codes,
        onProgress: (n) {
          if (mounted) setState(() => _written = n);
        },
      );
      if (!mounted) return;
      setState(() {
        _done = 'Đã tạo $count mã.';
        _lastCodes = codes;
        _lastName = 'giftcode_${prefix.isEmpty ? id : prefix}_$count.csv';
      });
      _load();
    } catch (e) {
      if (mounted) {
        _fail(
          _firestoreError(
            e,
            'Dừng ở ${_written ?? 0}/$count mã. Các mã đã ghi vẫn dùng được.',
          ),
        );
        setState(() {
          final n = _written ?? 0;
          _lastCodes = codes.sublist(0, n);
          _lastName = 'giftcode_${id}_partial_$n.csv';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(List<String> codes) async {
    await Clipboard.setData(ClipboardData(text: codes.join('\n')));
    if (mounted) setState(() => _done = 'Đã sao chép ${codes.length} mã.');
  }

  Future<void> _export(GiftcodeBatch batch) async {
    try {
      if (batch.type == GiftcodeType.shared) {
        await downloadText(
          giftcodeCsv([GiftcodeRow(batch.code ?? '')]),
          'giftcode_${batch.code}.csv',
        );
        return;
      }
      final rows = await widget.admin.exportBatch(batch.id);
      await downloadText(
        giftcodeCsv(rows),
        'giftcode_${batch.prefix.isEmpty ? batch.id : batch.prefix}_${rows.length}.csv',
      );
      final used = rows.where((r) => r.usedBy != null).length;
      if (mounted) {
        setState(() => _done = '${rows.length} mã, $used đã dùng.');
      }
    } catch (e) {
      if (mounted) _fail(_firestoreError(e, 'Chưa tải được danh sách.'));
    }
  }

  Future<void> _toggle(GiftcodeBatch batch, bool on) async {
    try {
      await widget.admin.setBatchEnabled(batch.id, on);
      if (!mounted) return;
      setState(() {
        _batches = [
          for (final b in _batches ?? const <GiftcodeBatch>[])
            b.id == batch.id ? b.copyWith(enabled: on) : b,
        ];
      });
    } catch (e) {
      if (mounted) _fail(_firestoreError(e, 'Chưa đổi được.'));
    }
  }

  String _dateLabel(DateTime? d, String none) {
    if (d == null) return none;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final shared = _type == GiftcodeType.shared;
    final last = _lastCodes;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('gc-type-shared'),
              label: const Text('Mã chung'),
              selected: shared,
              onSelected: (_) => setState(() => _type = GiftcodeType.shared),
            ),
            ChoiceChip(
              key: const Key('gc-type-single'),
              label: const Text('Mã một lần (hàng loạt)'),
              selected: !shared,
              onSelected: (_) => setState(() => _type = GiftcodeType.single),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _field(
          const Key('gc-title'),
          'Ghi chú, ví dụ Livestream 10/10',
          _title,
        ),
        if (shared) ...[
          _field(const Key('gc-code'), 'Mã, ví dụ TIEMHOA2026', _code),
          _field(
            const Key('gc-max-uses'),
            'Tổng lượt dùng tối đa (trống: không giới hạn)',
            _maxUses,
            keyboard: TextInputType.number,
          ),
          Text('Mỗi người chơi nhập được một lần.', style: AppText.caption()),
        ] else ...[
          _field(
            const Key('gc-prefix'),
            'Tiền tố (không bắt buộc), ví dụ TET',
            _prefix,
          ),
          _field(
            const Key('gc-count'),
            'Số mã (tối đa $maxGiftcodeBatch)',
            _count,
            keyboard: TextInputType.number,
          ),
          Text(
            'Mỗi mã dùng một lần. Mỗi người chơi chỉ nhận một mã trong đợt.',
            style: AppText.caption(),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Bắt đầu: ${_dateLabel(_starts, 'ngay')}',
                key: const Key('gc-starts'),
                style: AppText.body(size: 13, weight: 800),
              ),
            ),
            OutlineButton(
              key: const Key('gc-starts-pick'),
              label: 'Chọn',
              width: 60,
              height: 30,
              onTap: () => _pickDate(start: true),
            ),
            if (_starts != null)
              OutlineButton(
                label: 'Bỏ',
                width: 44,
                height: 30,
                onTap: () => setState(() => _starts = null),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                'Hết hạn: ${_expires == null ? 'không' : mailExpiryLabel(_expires)}',
                key: const Key('gc-expires'),
                style: AppText.body(size: 13, weight: 800),
              ),
            ),
            OutlineButton(
              key: const Key('gc-expires-pick'),
              label: 'Chọn',
              width: 60,
              height: 30,
              onTap: () => _pickDate(start: false),
            ),
            if (_expires != null)
              OutlineButton(
                label: 'Bỏ',
                width: 44,
                height: 30,
                onTap: () => setState(() => _expires = null),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Quà của mã', style: AppText.body(size: 15, weight: 800)),
        const SizedBox(height: 6),
        RewardPicker(
          key: const ValueKey('gc-picker'),
          bundle: _rewards,
          xuKey: const Key('gc-xu'),
          onChanged: (b) => setState(() => _rewards = b),
        ),
        _errorText(_error, const Key('gc-error')),
        if (_busy && _total != null && !shared) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _total == 0 ? null : (_written ?? 0) / _total!,
          ),
          Text(
            'Đã ghi ${_written ?? 0}/$_total mã',
            key: const Key('gc-progress'),
            style: AppText.caption(),
          ),
        ],
        if (_done != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _done!,
              key: const Key('gc-done'),
              style: AppText.body(size: 14, weight: 800),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ChunkyButton(
            key: const Key('gc-create'),
            label: _busy ? 'Đang tạo...' : 'Tạo mã',
            enabled: !_busy,
            onPressed: _busy ? null : _create,
          ),
        ),
        if (last != null && last.isNotEmpty) ...[
          const SizedBox(height: 10),
          CardBox(
            key: const Key('gc-output'),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${last.length} mã vừa tạo'
                  '${last.length > 20 ? ' (hiện 20 mã đầu)' : ''}',
                  style: AppText.body(size: 13, weight: 800),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  last.take(20).join('\n'),
                  style: AppText.body(size: 13, weight: 700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlineButton(
                      key: const Key('gc-copy'),
                      label: 'Sao chép',
                      width: 96,
                      height: 34,
                      onTap: () => _copy(last),
                    ),
                    const SizedBox(width: 8),
                    OutlineButton(
                      key: const Key('gc-download'),
                      label: 'Tải CSV',
                      width: 96,
                      height: 34,
                      onTap: () => downloadText(
                        giftcodeCsv([for (final c in last) GiftcodeRow(c)]),
                        _lastName,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text('Các đợt mã', style: AppText.body(size: 15, weight: 800)),
        const SizedBox(height: 6),
        if (_batches == null)
          const Center(child: CircularProgressIndicator())
        else if (_batches!.isEmpty)
          Text('Chưa có mã.', style: AppText.caption())
        else
          for (final b in _batches!) _batchRow(b),
      ],
    );
  }

  Widget _batchRow(GiftcodeBatch b) {
    final now = widget.now();
    final what = b.type == GiftcodeType.shared
        ? 'Mã chung ${b.code ?? ''}'
              '${b.maxUses == null ? '' : ' · tối đa ${b.maxUses} lượt'}'
        : '${b.count} mã một lần${b.prefix.isEmpty ? '' : ' · ${b.prefix}…'}';
    final dates = [
      if (b.startsAt != null) 'Từ ${_dateLabel(b.startsAt, '')}',
      if (b.expiresAt != null) mailExpiryLabel(b.expiresAt),
      if (b.expiresAt != null && !b.expiresAt!.isAfter(now)) 'Đã hết hạn',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CardBox(
        key: Key('gc-batch-${b.id}'),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (b.title.isNotEmpty)
                    Text(b.title, style: AppText.body(size: 14, weight: 800)),
                  Text(what, style: AppText.caption(size: 12)),
                  if (dates.isNotEmpty)
                    Text(dates, style: AppText.caption(size: 11)),
                  Text(b.rewards.label, style: AppText.caption(size: 11)),
                ],
              ),
            ),
            Switch(
              key: Key('gc-enabled-${b.id}'),
              value: b.enabled,
              onChanged: (v) => _toggle(b, v),
            ),
            OutlineButton(
              key: Key('gc-export-${b.id}'),
              label: 'CSV',
              width: 48,
              height: 30,
              onTap: () => _export(b),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bạn biết?

class _SlideAdmin extends StatefulWidget {
  const _SlideAdmin({required this.admin, required this.photos});

  final WelfareAdmin admin;
  final PhotoUploads? photos;

  @override
  State<_SlideAdmin> createState() => _SlideAdminState();
}

class _SlideAdminState extends State<_SlideAdmin> {
  final _image = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _url = TextEditingController();
  final _order = TextEditingController(text: '0');
  String? _editing;
  var _linkType = SlideLinkType.none;
  String _route = welfareRoutes.keys.first;
  var _enabled = true;
  var _busy = false;
  String? _error;
  String? _done;
  List<WelfareSlide>? _slides;

  @override
  void initState() {
    super.initState();
    _image.addListener(_preview);
    _body.addListener(_preview);
    _title.addListener(_preview);
    _load();
  }

  void _preview() => setState(() {});

  @override
  void dispose() {
    _image.removeListener(_preview);
    _image.dispose();
    _title.removeListener(_preview);
    _title.dispose();
    _body.removeListener(_preview);
    _body.dispose();
    _url.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await widget.admin.loadSlides();
      if (mounted) setState(() => _slides = list);
    } catch (_) {
      if (mounted) setState(() => _slides = const []);
    }
  }

  void _edit(WelfareSlide? s) => setState(() {
    _editing = s?.id;
    _image.text = s?.imageUrl ?? '';
    _title.text = s?.title ?? '';
    _body.text = s?.body ?? '';
    _linkType = s?.linkType ?? SlideLinkType.none;
    _route = s != null && s.linkType == SlideLinkType.route
        ? s.link
        : welfareRoutes.keys.first;
    _url.text = s != null && s.linkType == SlideLinkType.url ? s.link : '';
    _order.text = '${s?.order ?? (_slides?.length ?? 0)}';
    _enabled = s?.enabled ?? true;
    _error = null;
    _done = null;
  });

  Future<void> _upload() async {
    final photos = widget.photos;
    if (photos == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final jpeg = await photos.pickPhotoJpeg();
      if (jpeg != null) _image.text = await photos.uploadSlideImage(jpeg);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa tải ảnh lên được.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final order = int.tryParse(_order.text.trim());
    if (order == null) {
      setState(() => _error = 'Thứ tự là một số, ví dụ 0, 1, 2.');
      return;
    }
    final slide = WelfareSlide(
      id: _editing ?? widget.admin.newSlideId(),
      imageUrl: _image.text.trim(),
      title: _title.text,
      body: _body.text,
      linkType: _linkType,
      link: switch (_linkType) {
        SlideLinkType.none => '',
        SlideLinkType.route => _route,
        SlideLinkType.url => _url.text.trim(),
      },
      order: order,
      enabled: _enabled,
    );
    final problem = slideFormError(slide);
    if (problem != null) {
      setState(() {
        _error = problem;
        _done = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.admin.saveSlide(slide);
      if (!mounted) return;
      _edit(null);
      setState(() => _done = 'Đã lưu slide.');
      _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = _firestoreError(e, 'Chưa lưu được.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(WelfareSlide s) async {
    try {
      await widget.admin.deleteSlide(s.id);
      if (_editing == s.id) _edit(null);
      _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = _firestoreError(e, 'Chưa xoá được.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image.text.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        Text(
          _editing == null
              ? 'Slide mới (ảnh 1080×480, hoặc chỉ chữ)'
              : 'Sửa slide',
          style: AppText.body(size: 15, weight: 800),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _field(
                const Key('slide-image'),
                'Link ảnh https:// (không bắt buộc)',
                _image,
              ),
            ),
            if (widget.photos != null) ...[
              const SizedBox(width: 8),
              OutlineButton(
                key: const Key('slide-upload'),
                label: 'Tải ảnh',
                width: 80,
                height: 36,
                onTap: _upload,
              ),
            ],
          ],
        ),
        if (!image.startsWith('https://') &&
            (_title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AspectRatio(
              aspectRatio: slideAspect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SlideTextCard(title: _title.text, body: _body.text),
              ),
            ),
          ),
        if (image.startsWith('https://'))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AspectRatio(
              aspectRatio: slideAspect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ImageMissing(),
                ),
              ),
            ),
          ),
        _field(const Key('slide-title'), 'Tiêu đề (không bắt buộc)', _title),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            key: const Key('slide-body'),
            controller: _body,
            maxLines: 3,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Chữ trên slide khi chưa có ảnh (không bắt buộc)',
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final t in SlideLinkType.values)
              ChoiceChip(
                key: Key('slide-link-${t.name}'),
                label: Text(switch (t) {
                  SlideLinkType.none => 'Không mở gì',
                  SlideLinkType.route => 'Màn hình trong game',
                  SlideLinkType.url => 'Link ngoài',
                }),
                selected: _linkType == t,
                onSelected: (_) => setState(() => _linkType = t),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_linkType == SlideLinkType.route)
          DropdownButton<String>(
            key: const Key('slide-route'),
            value: _route,
            isExpanded: true,
            items: [
              for (final e in welfareRoutes.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _route = v ?? _route),
          ),
        if (_linkType == SlideLinkType.url)
          _field(const Key('slide-url'), 'https://…', _url),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: _field(
                const Key('slide-order'),
                'Thứ tự',
                _order,
                keyboard: TextInputType.number,
              ),
            ),
            const Spacer(),
            Text('Hiện', style: AppText.body(size: 14, weight: 800)),
            Switch(
              key: const Key('slide-enabled'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
        ),
        _errorText(_error, const Key('slide-error')),
        if (_done != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _done!,
              key: const Key('slide-done'),
              style: AppText.body(size: 14, weight: 800),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ChunkyButton(
                  key: const Key('slide-save'),
                  label: _busy ? 'Đang lưu...' : 'Lưu slide',
                  enabled: !_busy,
                  onPressed: _busy ? null : _save,
                ),
              ),
            ),
            if (_editing != null) ...[
              const SizedBox(width: 8),
              OutlineButton(
                key: const Key('slide-new'),
                label: 'Slide mới',
                width: 96,
                height: 40,
                onTap: () => _edit(null),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Text('Các slide', style: AppText.body(size: 15, weight: 800)),
        const SizedBox(height: 6),
        if (_slides == null)
          const Center(child: CircularProgressIndicator())
        else if (_slides!.isEmpty)
          Text('Chưa có slide.', style: AppText.caption())
        else
          for (final s in _slides!) _row(s),
      ],
    );
  }

  Widget _row(WelfareSlide s) {
    final link = switch (s.linkType) {
      SlideLinkType.none => 'Không mở gì',
      SlideLinkType.route => 'Mở: ${welfareRoutes[s.link] ?? s.link}',
      SlideLinkType.url => s.link,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CardBox(
        key: Key('slide-row-${s.id}'),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: AspectRatio(
                aspectRatio: slideAspect,
                child: !s.hasImage
                    ? const ColoredBox(
                        color: Color(0xFFE3F1D8),
                        child: Icon(Icons.notes_rounded, size: 18),
                      )
                    : Image.network(
                        s.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.surfaceSunken,
                          child: Icon(Icons.broken_image_outlined, size: 18),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title.isNotEmpty
                        ? s.title
                        : s.body.isNotEmpty
                        ? s.body
                        : '(không tiêu đề)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 13, weight: 800),
                  ),
                  Text(
                    '#${s.order} · ${s.enabled ? 'Đang hiện' : 'Đang ẩn'} · $link',
                    style: AppText.caption(size: 11),
                  ),
                ],
              ),
            ),
            OutlineButton(
              key: Key('slide-edit-${s.id}'),
              label: 'Sửa',
              width: 48,
              height: 30,
              onTap: () => _edit(s),
            ),
            const SizedBox(width: 4),
            OutlineButton(
              key: Key('slide-delete-${s.id}'),
              label: 'Xoá',
              width: 48,
              height: 30,
              onTap: () => _delete(s),
            ),
          ],
        ),
      ),
    );
  }
}
