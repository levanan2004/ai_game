import 'package:flutter/material.dart';

import '../data/account_admin.dart';
import '../data/account_gateway.dart';
import '../data/charm_board.dart';
import '../data/firestore_charm_board.dart';
import '../data/firestore_charm_rewards.dart';
import '../data/firebase_account.dart';
import '../data/firebase_photo_uploads.dart';
import '../data/mailbox_store.dart';
import '../data/player_directory.dart';
import '../data/supporter_admin.dart';
import '../data/welfare_store.dart';
import '../logic/charm_rewards.dart';
import '../logic/player_account.dart';
import '../logic/site_route_stub.dart'
    if (dart.library.js_interop) '../logic/site_route_web.dart';
import '../logic/supporters.dart';
import '../data/notice_board.dart';
import '../data/notice_replies.dart';
import '../theme/tokens.dart';
import 'account_admin_panel.dart';
import 'charm_reward_admin_panel.dart';
import 'gift_admin_panel.dart';
import 'mail_admin_panel.dart';
import 'common.dart';
import 'notice_admin_panel.dart';
import 'supporter_admin_panel.dart';
import 'welfare_admin_panel.dart';

/// `/quan-tri`. Google sign-in, then only the đại thiện nhân admin uid.
class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    this.account,
    this.admin,
    this.directory,
    this.accounts,
    this.charmBoard,
    this.charmRewards,
  });

  final AccountGateway? account;
  final SupporterAdmin? admin;
  final PlayerDirectory? directory;
  final AccountAdmin? accounts;

  /// Xếp hạng Mị lực review (tests pass fakes).
  final CharmBoardSource? charmBoard;
  final CharmRewardStore? charmRewards;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late final AccountGateway _account = widget.account ?? FirebaseAccount();
  late final SupporterAdmin _admin = widget.admin ?? FirestoreSupporterAdmin();
  late final PlayerDirectory _directory =
      widget.directory ?? FirestorePlayerDirectory();
  late final AccountAdmin _accounts =
      widget.accounts ?? FirestoreAccountAdmin();

  AccountProfile? _profile;
  var _busy = false;
  var _checking = true;
  var _isAdmin = false;
  var _section = _AdminSection.hub;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = _account.currentProfile();
    _refresh();
  }

  Future<void> _refresh() async {
    final profile = _profile;
    if (profile == null) {
      setState(() {
        _checking = false;
        _isAdmin = false;
      });
      return;
    }
    setState(() => _checking = true);
    final ok = await _admin.isAdmin();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _isAdmin = ok;
    });
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await _account.signIn();
      if (!mounted) return;
      _profile = profile ?? _account.currentProfile();
      if (_profile == null) {
        setState(() => _error = 'Chưa đăng nhập được, thử lại nhé.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa đăng nhập được, thử lại nhé.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<void> _signOut() async {
    await _account.signOut();
    if (!mounted) return;
    setState(() {
      _profile = null;
      _isAdmin = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Material(
        color: AppColors.bgBase,
        child: !_isAdmin
            ? _gate()
            : switch (_section) {
                _AdminSection.hub => _hub(),
                _AdminSection.gifts => GiftAdminPanel(
                  admin: _accounts,
                  onClose: () => setState(() => _section = _AdminSection.hub),
                ),
                _AdminSection.accounts => AccountAdminPanel(
                  admin: _accounts,
                  onClose: () => setState(() => _section = _AdminSection.hub),
                ),
                _AdminSection.donors => SupporterAdminPanel(
                  admin: _admin,
                  directory: _directory,
                  account: _account,
                  onClose: (_) => setState(() => _section = _AdminSection.hub),
                ),
                _AdminSection.notices => NoticeAdminPanel(
                  admin: FirestoreNoticeAdmin(),
                  replies: FirestoreNoticeReplyAdmin(),
                  photos: FirebasePhotoUploads(),
                  onClose: () => setState(() => _section = _AdminSection.hub),
                ),
                _AdminSection.welfare => WelfareAdminPanel(
                  admin: FirestoreWelfareAdmin(),
                  photos: FirebasePhotoUploads(),
                  onClose: () => setState(() => _section = _AdminSection.hub),
                ),
                _AdminSection.charm => CharmRewardAdminPanel(
                  board: widget.charmBoard ?? FirestoreCharmBoard(),
                  store: widget.charmRewards ?? FirestoreCharmRewardStore(),
                  onClose: () => setState(() => _section = _AdminSection.hub),
                ),
                _AdminSection.mails => MailAdminPanel(
                  mails: FirestoreMailAdmin(),
                  accounts: _accounts,
                  photos: FirebasePhotoUploads(),
                  onClose: () => setState(() => _section = _AdminSection.hub),
                ),
              },
      ),
    );
  }

  Widget _hub() {
    final profile = _profile;
    final who = profile == null
        ? ''
        : (profile.email.isNotEmpty ? profile.email : profile.uid);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Quản trị', style: AppText.title(size: 28)),
            if (who.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(who, style: AppText.caption()),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: 248,
              height: 52,
              child: ChunkyButton(
                key: const Key('admin-open-gifts'),
                label: 'Quà tặng',
                onPressed: () => setState(() => _section = _AdminSection.gifts),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 248,
              height: 52,
              child: ChunkyButton(
                key: const Key('admin-open-accounts'),
                label: 'Tài khoản',
                kind: ButtonKind.secondary,
                onPressed: () =>
                    setState(() => _section = _AdminSection.accounts),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 248,
              height: 52,
              child: ChunkyButton(
                key: const Key('admin-open-donors'),
                label: 'Đại thiện nhân',
                kind: ButtonKind.secondary,
                onPressed: () =>
                    setState(() => _section = _AdminSection.donors),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 248,
              height: 52,
              child: ChunkyButton(
                key: const Key('admin-open-notices'),
                label: 'Thông báo',
                kind: ButtonKind.secondary,
                onPressed: () =>
                    setState(() => _section = _AdminSection.notices),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 248,
              height: 52,
              child: ChunkyButton(
                key: const Key('admin-open-mails'),
                label: 'Hộp thư',
                kind: ButtonKind.secondary,
                onPressed: () => setState(() => _section = _AdminSection.mails),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 248,
              height: 52,
              child: ChunkyButton(
                key: const Key('admin-open-charm'),
                label: 'Xếp hạng Mị lực',
                kind: ButtonKind.secondary,
                onPressed: () => setState(() => _section = _AdminSection.charm),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 248,
              height: 52,
              child: ChunkyButton(
                key: const Key('admin-open-welfare'),
                label: 'Phúc lợi',
                kind: ButtonKind.secondary,
                onPressed: () =>
                    setState(() => _section = _AdminSection.welfare),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => leaveTo('/'),
              child: Text(
                'Về trang chủ',
                style: AppText.body(
                  size: 15,
                  weight: 800,
                  color: AppColors.primaryPressed,
                ),
              ),
            ),
            TextButton(
              onPressed: _signOut,
              child: Text(
                'Đăng xuất',
                style: AppText.body(size: 15, weight: 800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Quản trị', style: AppText.title(size: 28)),
            const SizedBox(height: 8),
            Text(
              _checking
                  ? 'Đang kiểm tra tài khoản.'
                  : _profile == null
                  ? 'Đăng nhập Google của tài khoản quản trị.'
                  : 'Đăng nhập bằng ${_who(_profile!)}.\nTài khoản này không phải quản trị.',
              textAlign: TextAlign.center,
              style: AppText.body(size: 15, weight: 700),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppText.caption(color: AppColors.statusDanger),
              ),
            ],
            const SizedBox(height: 16),
            if (_checking || _busy)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else if (_profile == null)
              SizedBox(
                width: 220,
                height: 48,
                child: ChunkyButton(
                  label: 'Đăng nhập Google',
                  onPressed: _signIn,
                ),
              )
            else
              SizedBox(
                width: 220,
                height: 48,
                child: ChunkyButton(
                  label: 'Đăng xuất',
                  kind: ButtonKind.ghost,
                  onPressed: _signOut,
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => leaveTo('/'),
              child: Text(
                'Về trang chủ',
                style: AppText.body(
                  size: 15,
                  weight: 800,
                  color: AppColors.primaryPressed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _who(AccountProfile profile) =>
    profile.email.isNotEmpty ? profile.email : profile.uid;

enum _AdminSection {
  hub,
  gifts,
  accounts,
  donors,
  notices,
  mails,
  charm,
  welfare,
}
