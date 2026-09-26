import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/preset_avatars.dart';
import '../logic/shop_session.dart';
import '../logic/supporters.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';

/// Nhất's line under the Google button (spec_cai_dat.md v0.3). Up to 3 lines.
const signInFootnote =
    'Đăng nhập để lưu tiến độ, đổi máy vẫn chơi tiếp. '
    'Game chỉ dùng tên, email và ảnh đại diện Google của bạn.';

/// Cài đặt (spec_cai_dat.md). Replaces the old pause popup.
class SettingsPopup extends StatelessWidget {
  const SettingsPopup({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Stack(
      children: [
        const ColoredBox(color: AppColors.bgOverlay),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: AppMotion.slow,
                      curve: Curves.easeOutBack,
                      builder: (_, t, child) => Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * t,
                          child: child,
                        ),
                      ),
                      child: s.avatarPickerOpen
                          ? _AvatarPicker(session: s)
                          : _SettingsCard(session: s),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 316,
          top: 8,
          child: SettingsGear(session: s, keyed: false),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final signedIn = s.signedIn;
    final saved = s.lastSavedAt;
    final onTitle = s.screen == Screen.title;
    // A Listener, not a GestureDetector: an empty onTap joins the arena and
    // can swallow the avatar tap (the pencil sits on the corner of the circle).
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: const Key('settings-popup'),
        width: 304,
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cài đặt',
                textAlign: TextAlign.center,
                style: AppText.title(size: 22),
              ),
              if (!onTitle) ...[
                const SizedBox(height: 2),
                Text(
                  'Game đang tạm dừng',
                  textAlign: TextAlign.center,
                  style: AppText.caption(),
                ),
              ],
              const SizedBox(height: 12),
              const _GroupLabel('TÀI KHOẢN'),
              _Sunken(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _AccountAvatar(session: s),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                signedIn
                                    ? (s.accountName ?? 'Chủ tiệm')
                                    : 'Chủ tiệm',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.heading(size: 16),
                              ),
                              Text(
                                signedIn
                                    ? (s.accountEmail ?? '')
                                    : 'Chưa đăng nhập',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (signedIn) ...[
                      GestureDetector(
                        key: const Key('settings-sign-out'),
                        onTap: s.authBusy ? null : () => s.signOut(),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Đăng xuất',
                            textAlign: TextAlign.center,
                            style: AppText.body(
                              size: 14,
                              weight: 800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      if (saved != null)
                        Text(
                          'Đã lưu lúc ${formatClock(saved.hour, saved.minute)}',
                          textAlign: TextAlign.center,
                          style: AppText.caption(size: 11),
                        ),
                    ] else
                      _GoogleButton(session: s),
                    if (s.authError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          s.authError!,
                          textAlign: TextAlign.center,
                          style: AppText.caption(
                            size: 11,
                            color: AppColors.statusDanger,
                          ),
                        ),
                      ),
                    if (!signedIn)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          signInFootnote,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          style: AppText.caption(size: 11),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _GroupLabel('TÊN TIỆM'),
              _Sunken(
                child: SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.state.shopName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(size: 14, weight: 800),
                        ),
                      ),
                      GestureDetector(
                        key: const Key('settings-rename'),
                        onTap: s.openRename,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: AppColors.primaryPressed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _GroupLabel('ÂM THANH'),
              _Sunken(
                child: SizedBox(
                  key: const Key('settings-music-row'),
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nhạc nền',
                          style: AppText.body(size: 14, weight: 800),
                        ),
                      ),
                      _SoundSwitch(
                        switchKey: const Key('settings-music'),
                        on: s.state.musicOn,
                        onTap: () => s.setMusic(!s.state.musicOn),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _Sunken(
                child: SizedBox(
                  key: const Key('settings-sfx-row'),
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hiệu ứng âm thanh',
                          style: AppText.body(size: 14, weight: 800),
                        ),
                      ),
                      _SoundSwitch(
                        switchKey: const Key('settings-sfx'),
                        on: s.state.sfxOn,
                        onTap: () => s.setSfx(!s.state.sfxOn),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _GroupLabel('KHÁC'),
              _Sunken(
                child: GestureDetector(
                  key: const Key('settings-donate'),
                  onTap: s.openDonors,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        ArtImage(Art.nav('sen'), size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ủng hộ',
                            style: AppText.body(size: 14, weight: 800),
                          ),
                        ),
                        Text('›', style: AppText.heading(size: 18)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: ChunkyButton(
                  key: const Key('settings-resume'),
                  label: onTitle ? 'Đóng' : 'Tiếp tục',
                  onPressed: s.resumeFromPause,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(text, style: AppText.caption(size: 10, weight: 800)),
    );
  }
}

class _Sunken extends StatelessWidget {
  const _Sunken({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: child,
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            key: const Key('settings-avatar'),
            behavior: HitTestBehavior.opaque,
            onTap: session.openAvatarPicker,
            child: Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryBase,
                  width: AppBorder.thick,
                ),
              ),
              child: ClipOval(
                child: _AvatarFace(
                  id: session.state.ownerAvatar,
                  photoUrl: session.accountPhotoUrl,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              key: const Key('settings-avatar-edit'),
              behavior: HitTestBehavior.opaque,
              onTap: session.openAvatarPicker,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: const Icon(
                  Icons.edit,
                  size: 14,
                  color: AppColors.primaryPressed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFace extends StatelessWidget {
  const _AvatarFace({required this.id, this.photoUrl});

  final String id;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (id == 'google' && photoUrl != null && photoUrl!.isNotEmpty) {
      return Image.network(
        photoUrl!,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) => const _SoftLotus(),
      );
    }
    final storage = storageAvatarUrl(id);
    if (storage != null) {
      return Image.network(
        storage,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) => const _SoftLotus(),
      );
    }
    if (id.isEmpty || id == 'google') return const _SoftLotus();
    return Image.asset(
      Art.customer(id),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _SoftLotus(),
    );
  }
}

class _SoftLotus extends StatelessWidget {
  const _SoftLotus();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primarySoft,
      child: Center(child: ArtImage(Art.nav('sen'), size: 28)),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final busy = session.authBusy;
    return GestureDetector(
      key: const Key('settings-sign-in'),
      onTap: busy ? null : () => session.signIn(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.primaryBase,
            width: AppBorder.thin,
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ArtImage(Art.nav('google'), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Đăng nhập bằng Google',
                      style: AppText.button(
                        size: 14,
                        color: AppColors.primaryPressed,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SoundSwitch extends StatelessWidget {
  const _SoundSwitch({
    required this.switchKey,
    required this.on,
    required this.onTap,
  });

  final Key switchKey;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: switchKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: on ? AppColors.secondaryBase : AppColors.freshnessTrack,
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: AppMotion.fast,
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final current = s.state.ownerAvatar;
    final canUpload = s.signedIn;
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: const Key('avatar-picker'),
        width: 320,
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              SizedBox(
                height: 32,
                child: Stack(
                  children: [
                    Center(
                      child: Text('Đổi avatar', style: AppText.title(size: 20)),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        key: const Key('avatar-close'),
                        onTap: s.closeAvatarPicker,
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Icon(Icons.close, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryBase, width: 3),
                ),
                child: ClipOval(
                  child: _AvatarFace(id: current, photoUrl: s.accountPhotoUrl),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chọn một avatar',
                  style: AppText.caption(size: 11, weight: 800),
                ),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final id in presetAvatarIds)
                    _Preset(
                      id: id,
                      selected: id == current,
                      onTap: () => s.setOwnerAvatar(id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Hoặc dùng ảnh riêng',
                  style: AppText.caption(size: 11, weight: 800),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PhotoButton(
                      key: const Key('avatar-google'),
                      label: 'Ảnh Google',
                      enabled: canUpload,
                      onTap: s.useGooglePhoto,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PhotoButton(
                      key: const Key('avatar-upload'),
                      label: 'Tải ảnh lên',
                      enabled: canUpload && !s.uploadBusy,
                      busy: s.uploadBusy,
                      onTap: () => s.uploadOwnerPhoto(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Cần đăng nhập Google. Ảnh được cắt vuông và thu nhỏ trước khi lưu.',
                textAlign: TextAlign.center,
                style: AppText.caption(size: 11),
              ),
              if (s.uploadError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    s.uploadError!,
                    textAlign: TextAlign.center,
                    style: AppText.caption(
                      size: 11,
                      color: AppColors.statusDanger,
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

class _Preset extends StatelessWidget {
  const _Preset({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('avatar-$id'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft,
                border: selected
                    ? Border.all(color: AppColors.primaryBase, width: 3)
                    : null,
              ),
              child: ClipOval(child: _AvatarFace(id: id)),
            ),
            if (selected)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBase,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 12,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: enabled || busy ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: busy
            ? Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.primaryBase,
                    width: AppBorder.thin,
                  ),
                ),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : OutlineButton(
                label: label,
                height: 36,
                fontSize: 13,
                onTap: onTap,
              ),
      ),
    );
    if (enabled || busy) return button;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTapHint(context, 'Đăng nhập Google trước nhé'),
      child: button,
    );
  }
}
