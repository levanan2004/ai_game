import 'package:flutter/material.dart';

import '../data/vip_recompute.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// `/quan-tri` hub (Đại 18/10): "Tính lại VIP" runs vipRecompute {all: true}
/// after a confirm dialog and shows how many players it recomputed. The hub
/// is admin-only and the server checks the admin again.
class VipRecomputeButton extends StatefulWidget {
  const VipRecomputeButton({super.key, required this.recompute});

  final VipRecompute recompute;

  static const label = 'Tính lại VIP';
  static const confirmTitle = 'Tính lại cấp VIP';
  static const confirmBody =
      'Tính lại cấp VIP của tất cả người đã nạp theo các mốc hiện tại. '
      'Cấp có thể tăng hoặc giảm, quà lên cấp đã nhận vẫn giữ nguyên. '
      'Có thể mất vài phút.';
  static const cancel = 'Hủy';
  static const confirm = 'Tính lại';
  static String done(int n) => 'Đã tính lại $n người.';
  static String failed(String e) => 'Chưa tính lại được ($e).';

  @override
  State<VipRecomputeButton> createState() => _VipRecomputeButtonState();
}

class _VipRecomputeButtonState extends State<VipRecomputeButton> {
  var _busy = false;
  String? _result;
  var _error = false;

  Future<void> _run() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('admin-vip-recompute-confirm'),
        title: const Text(VipRecomputeButton.confirmTitle),
        content: const Text(VipRecomputeButton.confirmBody),
        actions: [
          TextButton(
            key: const Key('admin-vip-recompute-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(VipRecomputeButton.cancel),
          ),
          TextButton(
            key: const Key('admin-vip-recompute-go'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(VipRecomputeButton.confirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _result = null;
      _error = false;
    });
    try {
      final r = await widget.recompute.recomputeAll();
      if (!mounted) return;
      setState(() => _result = VipRecomputeButton.done(r.count));
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : 'server';
      setState(() {
        _error = true;
        _result = VipRecomputeButton.failed(msg);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 248,
          height: 52,
          child: _busy
              ? const Center(
                  key: Key('admin-vip-recompute-busy'),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              : ChunkyButton(
                  key: const Key('admin-vip-recompute'),
                  label: VipRecomputeButton.label,
                  kind: ButtonKind.secondary,
                  onPressed: _run,
                ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: 248,
            child: Text(
              _result!,
              key: const Key('admin-vip-recompute-result'),
              textAlign: TextAlign.center,
              style: AppText.caption(
                color: _error ? AppColors.statusDanger : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
