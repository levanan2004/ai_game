import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Màn mở đầu (spec_popup_va_mo_dau.md §5, man_mo_dau_v0.1.png).
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key, required this.session});

  final ShopSession session;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  bool _confirmNew = false;

  static const _version = 'v0.1';
  static const _titleLogo = 'assets/images/brand/logo_0_nen.png';

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final has = s.hasSave;
    return OpaqueScreen(
      color: AppColors.bgShop,
      child: Stack(
        children: [
          const Positioned(left: 0, top: 0, child: AwningStrip(height: 40)),
          Positioned(left: 316, top: 8, child: SettingsGear(session: s)),
          Positioned(
            left: 0,
            right: 0,
            top: 40,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.celebrate,
              curve: Curves.easeOutBack,
              builder: (_, t, c) =>
                  Transform.scale(scale: 0.6 + 0.4 * t, child: c),
              child: Center(
                child: Image.asset(
                  _titleLogo,
                  width: 320,
                  fit: BoxFit.contain,
                  semanticLabel: 'Tiệm Hoa Sớm Mai',
                ),
              ),
            ),
          ),
          Positioned(
            left: 56,
            top: 308,
            width: 248,
            height: 60,
            child: ChunkyButton(
              key: const Key('title-main'),
              label: has ? 'Chơi tiếp' : 'Bắt đầu',
              fontSize: 20,
              onPressed: has ? s.continueFromTitle : s.requestNewGame,
            ),
          ),
          if (has)
            Positioned(
              left: 0,
              right: 0,
              top: 372,
              child: Text(
                s.state.shopName == null
                    ? 'Ngày ${s.state.day} · ${s.rank.nameVi} · ${formatK(s.state.money)}'
                    : '${s.state.shopName} · Ngày ${s.state.day} · ${formatK(s.state.money)}',
                textAlign: TextAlign.center,
                style: AppText.caption(),
              ),
            ),
          if (has && s.renamedShopNote != null)
            Positioned(
              left: 24,
              right: 24,
              top: 456,
              child: Text(
                s.renamedShopNote!,
                textAlign: TextAlign.center,
                style: AppText.caption(color: AppColors.statusDanger),
              ),
            ),
          if (has)
            Positioned(
              left: 96,
              top: 404,
              width: 168,
              height: 44,
              child: ChunkyButton(
                key: const Key('title-new'),
                label: 'Chơi mới',
                kind: ButtonKind.ghost,
                fontSize: 15,
                onPressed: () {
                  s.sounds.effect('popup_open');
                  setState(() => _confirmNew = true);
                },
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 612,
            child: Text(
              _version,
              textAlign: TextAlign.center,
              style: AppText.caption(size: 10, color: AppColors.textDisabled),
            ),
          ),
          if (_confirmNew) _confirmDialog(s),
        ],
      ),
    );
  }

  Widget _confirmDialog(ShopSession s) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          s.sounds.effect('popup_close');
          setState(() => _confirmNew = false);
        },
        child: ColoredBox(
          color: AppColors.bgOverlay,
          child: Stack(
            children: [
              Positioned(
                left: 40,
                top: 230,
                width: 280,
                height: 170,
                child: GestureDetector(
                  onTap: () {},
                  child: CardBox(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      children: [
                        Text(
                          'Bắt đầu lại từ ngày 1? Tiến độ hiện tại sẽ mất.',
                          key: const Key('title-new-confirm'),
                          textAlign: TextAlign.center,
                          style: AppText.body(size: 15, weight: 800),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ChunkyButton(
                                  label: 'Hủy',
                                  kind: ButtonKind.ghost,
                                  fontSize: 15,
                                  onPressed: () {
                                    s.sounds.effect('popup_close');
                                    setState(() => _confirmNew = false);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: _DangerButton(
                                  key: const Key('title-new-yes'),
                                  label: 'Chơi mới',
                                  onTap: () {
                                    s.sounds.effect('popup_close');
                                    setState(() => _confirmNew = false);
                                    s.requestNewGame();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Chơi mới" in the confirm dialog: `status.danger`.
class _DangerButton extends StatelessWidget {
  const _DangerButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSize.shadowOffset),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.statusDanger,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(
                  AppColors.statusDanger,
                  AppColors.textPrimary,
                  0.3,
                )!,
                offset: const Offset(0, AppSize.shadowOffset),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.button(
              size: 15,
              weight: 800,
              color: AppColors.textInverse,
            ),
          ),
        ),
      ),
    );
  }
}
