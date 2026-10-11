import 'package:flutter/material.dart';

import '../data/account_gateway.dart';
import '../logic/platform_flags.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'delete_account_text.dart';
import 'open_url.dart';

/// "Xóa tài khoản và dữ liệu?" (chu_ung_dung_v1.md §2 and §4): what is lost,
/// the typed XÓA, then the server call, the wait, and what went wrong.
/// Over Cài đặt; there is no tap-outside close.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.session});

  final ShopSession session;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _text = TextEditingController();

  ShopSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _typedOk => DeleteText.typedOk(_text.text);

  @override
  Widget build(BuildContext context) {
    final failure = s.deleteFailure;
    return ColoredBox(
      color: AppColors.bgOverlay,
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 320,
              maxHeight: (box.maxHeight - 24).clamp(200.0, double.infinity),
            ),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                key: const Key('delete-dialog'),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.surfaceBorderStrong,
                      offset: Offset(0, AppSize.shadowOffset),
                    ),
                  ],
                ),
                child: s.deleteBusy
                    ? _busy()
                    : failure != null
                    ? _failed(failure)
                    : _confirm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: AppText.title(size: 20, weight: 800),
  );

  Widget _busy() {
    return Column(
      key: const Key('delete-busy'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 14),
        Text(
          DeleteText.progress,
          textAlign: TextAlign.center,
          style: AppText.body(weight: 800),
        ),
        const SizedBox(height: 4),
        Text(
          DeleteText.progressSub,
          textAlign: TextAlign.center,
          style: AppText.caption(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _confirm() {
    final phale = s.state.phaLe;
    final showPhale = phale > 0 && !isIosApp;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(DeleteText.title),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(DeleteText.intro, style: AppText.body(weight: 800)),
                const SizedBox(height: 6),
                for (final line in DeleteText.list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 7, right: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.statusDanger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(line, style: AppText.body(size: 13)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  DeleteText.outro,
                  key: const Key('delete-outro'),
                  style: AppText.body(
                    size: 13,
                    weight: 800,
                    color: AppColors.statusDanger,
                  ),
                ),
                if (showPhale) ...[
                  const SizedBox(height: 8),
                  Container(
                    key: const Key('delete-phale'),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      DeleteText.phale(phale),
                      style: AppText.body(size: 13, weight: 800),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  DeleteText.kept,
                  key: const Key('delete-kept'),
                  style: AppText.caption(size: 11),
                ),
                GestureDetector(
                  key: const Key('delete-more'),
                  onTap: () => openUrl(DeleteText.moreUrl),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: AppSize.touchMin,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        DeleteText.more,
                        style:
                            AppText.body(
                              size: 13,
                              weight: 800,
                              color: AppColors.primaryBase,
                            ).copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primaryBase,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Text(DeleteText.typedHint, style: AppText.caption(weight: 800)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _typedOk
                  ? AppColors.statusDanger
                  : AppColors.surfaceBorderStrong,
              width: _typedOk ? 2 : AppBorder.thin,
            ),
          ),
          alignment: Alignment.center,
          child: TextField(
            key: const Key('delete-field'),
            controller: _text,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            style: AppText.make(AppFonts.display, 17, 700),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: DeleteText.typedPlaceholder,
              hintStyle: AppText.make(
                AppFonts.display,
                15,
                600,
                color: AppColors.textDisabled,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ChunkyButton(
                  key: const Key('delete-cancel'),
                  label: DeleteText.cancel,
                  fontSize: 15,
                  onPressed: s.closeDeleteAccount,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ChunkyButton(
                  key: const Key('delete-confirm'),
                  label: DeleteText.confirm,
                  kind: ButtonKind.ghost,
                  textColor: AppColors.statusDanger,
                  fontSize: 15,
                  enabled: _typedOk,
                  onPressed: _typedOk ? () => s.deleteAccount() : null,
                  disabledHint: DeleteText.typedHint,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _failed(DeleteFailure failure) {
    final message = switch (failure) {
      DeleteFailure.network => DeleteText.failNetwork,
      DeleteFailure.partial => DeleteText.failPartial,
      DeleteFailure.blocked => DeleteText.blocked,
      DeleteFailure.generic => DeleteText.failGeneric,
    };
    final canEmail =
        failure == DeleteFailure.partial || failure == DeleteFailure.generic;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(DeleteText.title),
        const SizedBox(height: 10),
        Text(
          message,
          key: const Key('delete-error'),
          textAlign: TextAlign.center,
          style: AppText.body(weight: 800, color: AppColors.statusDanger),
        ),
        if (failure == DeleteFailure.blocked) ...[
          const SizedBox(height: 6),
          Text(
            DeleteText.blockedHint,
            key: const Key('delete-blocked-hint'),
            textAlign: TextAlign.center,
            style: AppText.caption(),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ChunkyButton(
            key: const Key('delete-retry'),
            label: DeleteText.retry,
            onPressed: () => s.deleteAccount(),
          ),
        ),
        if (canEmail) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ChunkyButton(
              key: const Key('delete-email'),
              label: DeleteText.email,
              kind: ButtonKind.ghost,
              fontSize: 15,
              onPressed: () =>
                  openUrl(DeleteText.mailto(s.accountEmail ?? '')),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: ChunkyButton(
            key: const Key('delete-cancel'),
            label: failure == DeleteFailure.partial
                ? DeleteText.close
                : DeleteText.cancel,
            kind: ButtonKind.ghost,
            fontSize: 15,
            onPressed: s.closeDeleteAccount,
          ),
        ),
      ],
    );
  }
}

/// "Đã xóa xong": over the title, after the account was deleted.
class DeleteDoneDialog extends StatelessWidget {
  const DeleteDoneDialog({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgOverlay,
      child: Center(
        child: Container(
          key: const Key('delete-done'),
          width: 288,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: const [
              BoxShadow(
                color: AppColors.surfaceBorderStrong,
                offset: Offset(0, AppSize.shadowOffset),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DeleteText.doneTitle,
                textAlign: TextAlign.center,
                style: AppText.title(size: 20, weight: 800),
              ),
              const SizedBox(height: 8),
              Text(
                DeleteText.doneBody,
                textAlign: TextAlign.center,
                style: AppText.body(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: ChunkyButton(
                  key: const Key('delete-done-close'),
                  label: DeleteText.doneButton,
                  onPressed: session.closeDeleteDone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
