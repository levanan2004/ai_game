import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/logic/avatar_jpeg.dart';
import 'package:ai_game/logic/game_notice.dart';
import 'package:ai_game/logic/inbox.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/notice_feed.dart';
import 'package:ai_game/logic/notice_reply.dart';
import 'package:ai_game/logic/photo_uploads.dart';
import 'package:ai_game/logic/player_account.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/welfare_text.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/mail_admin_panel.dart';
import 'package:ai_game/ui/corner_menu.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/mailbox_sheet.dart';
import 'package:ai_game/ui/notice_admin_panel.dart';
import 'package:ai_game/ui/notice_sheet.dart';
import 'package:ai_game/ui/phuc_loi_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;

import '../helpers.dart';

final _now = DateTime(2026, 10, 3, 15);

/// One Firestore in memory: mails plus every player's marks. Claims are
/// atomic like the transaction in FirestoreMailbox.
class _Server implements MailService {
  _Server(this.mails);

  final List<GameMail> mails;
  final marks = <String, Map<String, MailState>>{};
  var claimCalls = 0;
  var readCalls = 0;
  Completer<void>? gate;

  @override
  Future<List<GameMail>> inbox(String uid) async => [
    for (final mail in mails)
      if (mail.target == mailToAll || mail.target == uid) mail,
  ];

  @override
  Future<Map<String, MailState>> states(String uid) async => {...?marks[uid]};

  @override
  Future<void> markRead(String uid, String mailId) async {
    readCalls++;
    final mine = marks.putIfAbsent(uid, () => {});
    mine[mailId] = (mine[mailId] ?? MailState.fresh).copyWith(read: true);
  }

  @override
  Future<MailClaimResult> claim(String uid, String mailId) async {
    claimCalls++;
    final wait = gate;
    if (wait != null) await wait.future;
    final mine = marks.putIfAbsent(uid, () => {});
    if (mine[mailId]?.claimed == true) return MailClaimResult.already;
    mine[mailId] = const MailState(read: true, claimed: true);
    return MailClaimResult.claimed;
  }
}

GameMail _gift({String id = 'm1', String target = mailToAll, DateTime? ends}) =>
    GameMail(
      id: id,
      title: 'Quà khai trương',
      body: 'Cảm ơn bạn đã ghé tiệm.',
      target: target,
      rewards: RewardBundle(const [
        RewardItem.phaLe(5),
        RewardItem.coins(20000),
        RewardItem.pot('crane'),
      ]),
      createdAt: DateTime(2026, 10, 2),
      expiresAt: ends,
    );

GameMail _letter({String id = 'm2', DateTime? at}) => GameMail(
  id: id,
  title: 'Bảo trì xong',
  body: 'Tiệm mở lại rồi.',
  target: mailToAll,
  createdAt: at ?? DateTime(2026, 10, 1),
);

MailboxFeed _feed(_Server server) =>
    MailboxFeed(service: server, now: () => _now);

void main() {
  group('mail data', () {
    test('a mail map round-trips and skips unknown reward kinds', () {
      final map = mailToMap(_gift(ends: DateTime(2026, 11, 1)));
      expect(map['target'], mailToAll);
      expect(map.containsKey('imageUrl'), isFalse);
      final rewards = map['rewards'] as Map<String, Object?>;
      final items = [
        ...(rewards['items'] as List),
        {'kind': 'starDust', 'amount': 3},
      ];
      final back = mailFromMap('m1', {
        ...map,
        'rewards': {'items': items},
        'imageUrl': 'javascript:alert(1)',
      })!;
      expect(back.rewards, _gift().rewards);
      expect(back.expiresAt, DateTime(2026, 11, 1));
      expect(back.imageUrl, isNull);
      expect(mailFromMap('x', {'title': '', 'target': 'all'}), isNull);
      expect(mailFromMap('x', {'title': 'Hi'}), isNull);
    });

    test('only https pictures are kept', () {
      expect(normalizeImageUrl(' https://a.b/c.jpg '), 'https://a.b/c.jpg');
      expect(normalizeImageUrl('http://a.b/c.jpg'), isNull);
      expect(normalizeImageUrl('/about'), isNull);
      expect(normalizeImageUrl('https://${'a' * 600}'), isNull);
      expect(
        mailFormError(_letter(), rawImageUrl: 'ftp://x'),
        'Link ảnh cần bắt đầu bằng https://',
      );
      expect(mailFormError(_letter(), rawImageUrl: ''), isNull);
    });

    test('the rules know mails, claim marks and pictures', () {
      final rules = File('firestore.rules').readAsStringSync();
      expect(rules, contains('match /mails/{mailId}'));
      expect(rules, contains('match /mailState/{mailId}'));
      expect(rules, contains("resource.data.claimed != true"));
      expect(rules, contains('imageUrlOk(request.resource.data)'));
      expect(rules, contains("'createdAt', 'updatedAt', 'imageUrl'"));
      final storage = File('storage.rules').readAsStringSync();
      expect(storage, contains('match /board_images/{file}'));
      expect(storage, contains('match /reply_photos/{uid}/{file}'));
    });

    test('a big photo is shrunk under the Storage limit', () {
      final src = im.Image(width: 3000, height: 1500);
      for (final p in src) {
        p
          ..r = (p.x * 7) % 256
          ..g = (p.y * 13) % 256
          ..b = (p.x * p.y) % 256;
      }
      final jpeg = photoJpeg(Uint8List.fromList(im.encodePng(src)))!;
      expect(jpeg.length, lessThan(maxPhotoBytes));
      final out = im.decodeJpg(jpeg)!;
      expect(out.width, lessThanOrEqualTo(1280));
      expect((out.width / out.height - 2).abs(), lessThan(0.02));
      expect(photoJpeg(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('MailboxFeed', () {
    test('a guest sees nothing and cannot claim', () async {
      final server = _Server([_gift()]);
      final feed = _feed(server);
      expect(feed.unread, 0);
      expect(feed.mails, isEmpty);
      var granted = 0;
      final r = await feed.claim(
        'm1',
        allowed: true,
        grant: (_) {
          granted++;
          return RewardBundle.empty;
        },
      );
      expect(r, MailClaimResult.refused);
      expect(granted, 0);
      expect(server.claimCalls, 0);
    });

    test('newest first, expired hidden, one target only', () async {
      final server = _Server([
        _letter(id: 'old', at: DateTime(2026, 9, 1)),
        _letter(id: 'new', at: DateTime(2026, 10, 2)),
        _gift(id: 'gone', ends: DateTime(2026, 10, 1)),
        _gift(id: 'later', ends: DateTime(2026, 10, 9)),
        _gift(id: 'other', target: 'someone-else'),
        _gift(id: 'mine', target: 'u1'),
      ]);
      final feed = _feed(server);
      await feed.bindUser('u1');
      expect(
        [for (final m in feed.mails) m.id],
        ['later', 'mine', 'new', 'old'],
      );
      expect(feed.unread, 4);
      final r = await feed.claim(
        'gone',
        allowed: true,
        grant: (_) => RewardBundle.empty,
      );
      expect(r, MailClaimResult.refused);
    });

    test('a letter is read on open; a gift waits for Nhận quà', () async {
      final server = _Server([_letter(), _gift()]);
      final feed = _feed(server);
      await feed.bindUser('u1');
      expect(feed.unread, 2);
      await feed.openMail('m2');
      expect(feed.stateOf('m2').read, isTrue);
      expect(server.marks['u1']!['m2']!.read, isTrue);
      await feed.openMail('m1');
      expect(feed.stateOf('m1').read, isFalse);
      expect(feed.unread, 1);
      await feed.claim('m1', allowed: true, grant: (m) => m.rewards);
      expect(feed.unread, 0);
      expect(feed.stateOf('m1').claimed, isTrue);
    });

    test('a double tap, a second tab and a re-sign-in claim once', () async {
      final server = _Server([_gift()]);
      final feed = _feed(server);
      await feed.bindUser('u1');
      var granted = 0;
      RewardBundle grant(GameMail m) {
        granted++;
        return m.rewards;
      }

      server.gate = Completer<void>();
      final first = feed.claim('m1', allowed: true, grant: grant);
      final second = await feed.claim('m1', allowed: true, grant: grant);
      expect(second, MailClaimResult.busy);
      expect(feed.claiming('m1'), isTrue);
      server.gate!.complete();
      expect(await first, MailClaimResult.claimed);
      expect(
        await feed.claim('m1', allowed: true, grant: grant),
        MailClaimResult.already,
      );
      expect(granted, 1);

      // A second session (another tab or device) on the same account.
      final second2 = _feed(server);
      await second2.bindUser('u1');
      expect(second2.stateOf('m1').claimed, isTrue);
      expect(
        await second2.claim('m1', allowed: true, grant: grant),
        MailClaimResult.already,
      );
      expect(granted, 1);

      await feed.bindUser(null);
      expect(feed.unread, 0);
      await feed.bindUser('u1');
      expect(feed.stateOf('m1').claimed, isTrue);
      expect(granted, 1);
      expect(server.claimCalls, 1);
    });

    test('a claim on a stale tab asks the server and gets already', () async {
      final server = _Server([_gift()]);
      final stale = _feed(server);
      await stale.bindUser('u1');
      // The claim lands from another device after this tab loaded.
      await server.claim('u1', 'm1');
      var granted = 0;
      final r = await stale.claim(
        'm1',
        allowed: true,
        grant: (m) {
          granted++;
          return m.rewards;
        },
      );
      expect(r, MailClaimResult.already);
      expect(granted, 0);
      expect(stale.stateOf('m1').claimed, isTrue);
    });

    test('a tab that may not write the account claims nothing', () async {
      final server = _Server([_gift()]);
      final feed = _feed(server);
      await feed.bindUser('u1');
      final r = await feed.claim('m1', allowed: false, grant: (m) => m.rewards);
      expect(r, MailClaimResult.refused);
      expect(server.claimCalls, 0);
    });

    test('the gift reaches the shop and its morning save once', () async {
      final backing = <String, String>{};
      final s = newSession(backing: backing);
      s.startNewGame();
      await s.pendingSaves;
      final money = s.state.money;
      final server = _Server([_gift()]);
      final feed = _feed(server);
      await feed.bindUser('u1');
      RewardBundle grant(GameMail m) =>
          s.grantRewards(m.rewards, source: RewardSource.mailbox);
      await feed.claim('m1', allowed: true, grant: grant);
      await feed.claim('m1', allowed: true, grant: grant);
      await s.pendingSaves;
      expect(s.state.phaLe, 5);
      expect(s.state.money, money + 20000);
      expect(s.state.potCounts['crane'], 1);
      final stored = GameState.decode(backing[ProgressStore.storageKey])!;
      expect(stored.phaLe, 5);
      expect(stored.potCounts['crane'], 1);
    });
  });

  group('Hộp thư screen', () {
    Future<List<String>> pumpSheet(
      WidgetTester tester,
      MailboxFeed feed, {
      bool signedIn = true,
      RewardBundle Function(GameMail)? grant,
    }) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final heard = <String>[];
      final inbox = Inbox(mail: feed);
      addTearDown(inbox.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SoundScope(
            sounds: Sounds(heard: heard),
            child: Material(
              child: Stack(
                children: [
                  Positioned(
                    left: 52,
                    top: 8,
                    child: MailboxButton(inbox: inbox),
                  ),
                  Positioned.fill(
                    child: MailboxSheet(
                      inbox: inbox,
                      signedIn: signedIn,
                      canClaim: () => true,
                      grant: grant ?? (m) => m.rewards,
                      onSignIn: () async {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return heard;
    }

    testWidgets('a guest is asked to sign in', (tester) async {
      final feed = _feed(_Server([_gift()]));
      await pumpSheet(tester, feed, signedIn: false);
      expect(find.byKey(const Key('mailbox-badge')), findsNothing);
      await tester.tap(find.byKey(const Key('mailbox-button')));
      await tester.pump();
      expect(find.byKey(const Key('mailbox-guest')), findsOneWidget);
      expect(find.byKey(const Key('mailbox-sign-in')), findsOneWidget);
      expect(find.byKey(const Key('mail-item-m1')), findsNothing);
    });

    testWidgets('open, claim once, then Đã nhận', (tester) async {
      final server = _Server([_gift(), _letter()]);
      final feed = _feed(server);
      var granted = 0;
      final heard = await pumpSheet(
        tester,
        feed,
        grant: (m) {
          granted++;
          return m.rewards;
        },
      );
      await feed.bindUser('u1');
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(find.byKey(const Key('mailbox-closed')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mailbox-button')));
      await tester.pump();
      expect(find.byKey(const Key('mail-unread-m1')), findsOneWidget);
      expect(find.byKey(const Key('mail-unread-m2')), findsOneWidget);
      expect(find.byKey(const Key('mail-closed-m1')), findsOneWidget);
      expect(find.byKey(const Key('mail-closed-m2')), findsOneWidget);
      // The list has only the X; a letter adds the back arrow.
      expect(find.byKey(const Key('mailbox-back')), findsNothing);
      expect(find.byKey(const Key('mailbox-close')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mail-item-m2')));
      await tester.pump();
      expect(heard, contains('mo_thu.mp3'));
      expect(find.byKey(const Key('mail-claim')), findsNothing);
      await tester.tap(find.byKey(const Key('mailbox-back')));
      await tester.pump();
      expect(find.byKey(const Key('mail-read-m2')), findsOneWidget);
      // Read row: no red dot, no fading.
      expect(
        find.descendant(
          of: find.byKey(const Key('mail-item-m2')),
          matching: find.byKey(const Key('unread-dot')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('mail-item-m1')),
          matching: find.byKey(const Key('unread-dot')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('mail-item-m2')),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('mail-open-m2')), findsOneWidget);
      expect(find.byKey(const Key('mail-closed-m1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mail-item-m1')));
      await tester.pump();
      expect(find.byKey(const Key('mail-gift')), findsOneWidget);
      expect(find.byKey(const Key('reward-phaLe')), findsOneWidget);
      expect(find.byKey(const Key('reward-frame-hiem')), findsOneWidget);
      expect(find.byKey(const Key('reward-frame-thuong')), findsOneWidget);
      expect(find.byKey(const Key('reward-frame-suThi')), findsOneWidget);
      expect(find.text('Nhận quà'), findsOneWidget);
      expect(find.byKey(const Key('mail-detail-icon')), findsOneWidget);
      // Gifts right under the letter, the button right under the gifts.
      final body = tester.getRect(find.byKey(const Key('mail-body')));
      final gift = tester.getRect(find.byKey(const Key('mail-gift')));
      final button = tester.getRect(find.byKey(const Key('mail-claim')));
      expect(gift.top - body.bottom, inInclusiveRange(0, 30));
      expect(button.top - gift.bottom, inInclusiveRange(0, 30));
      // One row of frames, each amount under its frame.
      final frames = find.descendant(
        of: find.byKey(const Key('mail-gift')),
        matching: find.byType(RarityFrame),
      );
      final tops = {
        for (var i = 0; i < frames.evaluate().length; i++)
          tester.getRect(frames.at(i)).top,
      };
      expect(tops, hasLength(1));
      final phaLe = find.byKey(const Key('reward-phaLe'));
      final frame = tester.getRect(
        find.descendant(of: phaLe, matching: find.byType(RarityFrame)),
      );
      final amount = tester.getRect(
        find.descendant(of: phaLe, matching: find.byType(Text)),
      );
      expect(amount.top, greaterThanOrEqualTo(frame.bottom - 0.5));
      expect(amount.center.dx, closeTo(frame.center.dx, 1));
      await tester.tap(find.byKey(const Key('mail-claim')));
      await tester.tap(
        find.byKey(const Key('mail-claim')),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Đã nhận'), findsOneWidget);
      expect(granted, 1);
      expect(heard.where((s) => s == 'ad_reward.mp3'), hasLength(1));
      expect(find.byKey(const Key('mailbox-badge')), findsNothing);
      expect(find.byKey(const Key('mailbox-open')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mailbox-back')));
      await tester.pump();
      expect(find.byKey(const Key('mail-open-m1')), findsOneWidget);
    });
  });

  group('Hộp thư tabs (Thư, Tin tức)', () {
    const news = GameNotice(
      id: 'n1',
      title: 'Tiệm mở thêm giờ',
      body: 'Cuối tuần tiệm mở tới khuya.',
      createdAt: null,
    );

    Future<Inbox> pumpInbox(
      WidgetTester tester,
      MailboxFeed mail,
      NoticeFeed notices,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final inbox = Inbox(mail: mail, news: notices);
      addTearDown(inbox.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CornerMenu(
                    left: 272,
                    top: 4,
                    listenable: inbox,
                    entries: menuEntries(inbox: inbox),
                  ),
                ),
                Positioned.fill(
                  child: MailboxSheet(
                    inbox: inbox,
                    signedIn: true,
                    canClaim: () => true,
                    grant: (m) => m.rewards,
                    news: NewsTab(feed: notices),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return inbox;
    }

    NoticeFeed notices(List<GameNotice> list) => NoticeFeed(
      board: _Board(list),
      seen: NoticeSeen.memory(),
      initial: list,
    );

    testWidgets('menu opens Hộp thư on Thư; dots add mail and news', (
      tester,
    ) async {
      final mail = _feed(_Server([_gift(), _letter()]));
      final inbox = await pumpInbox(tester, mail, notices([news]));
      await mail.bindUser('u1');
      await tester.pump();
      // Basket and Hộp thư entry: 2 mails + 1 news.
      expect(inbox.unread, 3);
      expect(
        find.descendant(
          of: find.byKey(const Key('corner-menu-dot')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('corner-menu-closed')), findsOneWidget);
      await tester.tap(find.byKey(const Key('corner-menu')));
      await tester.pump();
      expect(find.byKey(const Key('corner-menu-open')), findsOneWidget);
      expect(find.byKey(const Key('corner-menu-tray')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('corner-menu-dot-mailbox')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('corner-menu-mailbox')));
      await tester.pump();
      expect(find.byKey(const Key('corner-menu-tray')), findsNothing);
      expect(find.text('Hộp thư'), findsOneWidget);
      expect(inbox.tab, InboxTab.mail);
      expect(find.byKey(const Key('mail-item-m1')), findsOneWidget);
      expect(find.byKey(const Key('notice-item-n1')), findsNothing);
      expect(find.byKey(const Key('inbox-tab-badge-news')), findsOneWidget);

      await tester.tap(find.byKey(const Key('inbox-tab-news')));
      await tester.pump();
      expect(find.byKey(const Key('notice-item-n1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('notice-item-n1')));
      await tester.pump();
      expect(find.byKey(const Key('notice-detail')), findsOneWidget);
      expect(inbox.unreadNews, 0);
      // Back: the news list, which has only the X.
      await tester.tap(find.byKey(const Key('mailbox-back')));
      await tester.pump();
      expect(find.byKey(const Key('notice-item-n1')), findsOneWidget);
      expect(find.byKey(const Key('mailbox-back')), findsNothing);
      await tester.tap(find.byKey(const Key('mailbox-close')));
      await tester.pump();
      expect(inbox.open, isFalse);

      inbox.openAt(InboxTab.news);
      await tester.pump();
      expect(inbox.tab, InboxTab.news);
      expect(find.byKey(const Key('notice-item-n1')), findsOneWidget);
    });

    testWidgets('a tap outside closes the tray', (tester) async {
      await pumpInbox(tester, MailboxFeed(), notices(const []));
      expect(find.byKey(const Key('corner-menu-dot')), findsNothing);
      await tester.tap(find.byKey(const Key('corner-menu')));
      await tester.pump();
      final tray = tester.getRect(find.byKey(const Key('corner-menu-tray')));
      final basket = tester.getRect(find.byKey(const Key('corner-menu')));
      // One entry: 72 dp; the pointer (31.4 dp from the right) at the
      // basket's centre.
      expect(tray.width, 64);
      expect(tray.height, CornerMenu.trayHeight(1));
      expect(tray.right - 31.4, closeTo(basket.center.dx, 0.01));
      expect(CornerMenu.trayHeight(2), 120);
      expect(CornerMenu.trayHeight(3), 168);
      await tester.tapAt(const Offset(40, 400));
      await tester.pump();
      expect(find.byKey(const Key('corner-menu-tray')), findsNothing);
    });

    testWidgets('empty Tin tức says so', (tester) async {
      final inbox = await pumpInbox(tester, MailboxFeed(), notices(const []));
      inbox.openAt(InboxTab.news);
      await tester.pump();
      expect(find.text(WelfareText.newsEmpty), findsOneWidget);
      expect(
        WelfareText.newsEmpty,
        'Chưa có tin mới. Có gì vui ở tiệm, mình báo ngay nhé!',
      );
    });

    test('without a notice feed the inbox stays on Thư', () {
      final inbox = Inbox(mail: MailboxFeed());
      inbox.openAt(InboxTab.news);
      expect(inbox.tab, InboxTab.mail);
      expect(inbox.open, isTrue);
      inbox.close();
      expect(inbox.open, isFalse);
      inbox.dispose();
    });
  });

  group('pictures on notices', () {
    testWidgets('a notice shows its picture; a broken one falls back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const withImage = GameNotice(
        id: 'img',
        title: 'Chậu mới',
        body: 'Xem ảnh nhé.',
        imageUrl: 'https://example.invalid/chau.jpg',
        createdAt: null,
      );
      const plain = GameNotice(
        id: 'plain',
        title: 'Chữ',
        body: 'Chỉ chữ.',
        createdAt: null,
      );
      final feed = NoticeFeed(
        board: _Board(const [withImage, plain]),
        seen: NoticeSeen.memory(),
        initial: const [withImage, plain],
      )..open = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(width: 360, height: 640, child: NewsTab(feed: feed)),
        ),
      );
      await tester.tap(find.byKey(const Key('notice-item-plain')));
      await tester.pump();
      expect(find.byKey(const Key('notice-detail')), findsOneWidget);
      expect(find.byKey(const Key('notice-image')), findsNothing);
      feed.showList();
      await tester.pump();
      await tester.tap(find.byKey(const Key('notice-item-img')));
      await tester.pump();
      expect(find.byKey(const Key('notice-image')), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(find.byKey(const Key('image-missing')), findsOneWidget);
    });

    testWidgets('admin saves a picture link and refuses http', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final admin = _NoticeAdmin();
      await tester.pumpWidget(
        MaterialApp(
          home: NoticeAdminPanel(
            admin: admin,
            onClose: () {},
            photos: _Photos(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('notice-add')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('notice-title')), 'Ảnh');
      await tester.enterText(find.byKey(const Key('notice-body')), 'Có ảnh.');
      await tester.enterText(
        find.byKey(const Key('notice-image')),
        'http://x.y/a.jpg',
      );
      await tester.tap(find.byKey(const Key('notice-save')));
      await tester.pump();
      expect(find.text('Link ảnh cần bắt đầu bằng https://'), findsOneWidget);
      expect(admin.saved, isEmpty);

      await tester.tap(find.byKey(const Key('notice-image-upload')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('notice-save')));
      await tester.pump();
      expect(admin.saved.single.imageUrl, _Photos.boardUrl);
    });

    testWidgets('a góp ý answer can carry one photo', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const notice = GameNotice(
        id: 'gy',
        title: 'Góp ý lỗi',
        body: 'Gửi ảnh lỗi nhé.',
        kind: NoticeKind.form,
        fields: [
          NoticeField(
            id: 'note1',
            label: 'Lỗi gì',
            type: NoticeInputType.note,
            required: false,
          ),
        ],
      );
      final replies = _Replies();
      final photos = _Photos();
      final feed = NoticeFeed(
        board: _Board(const [notice]),
        seen: NoticeSeen.memory(),
        initial: const [notice],
      )..open = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 360,
            height: 900,
            child: NewsTab(
              feed: feed,
              replies: replies,
              signedIn: true,
              uid: 'u1',
              email: 'an@x.com',
              playerName: 'An',
              shopName: 'Hoa',
              photos: photos,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('notice-item-gy')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('notice-open-form')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('notice-reply-photo-pick')),
      );
      await tester.tap(find.byKey(const Key('notice-reply-photo-pick')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('notice-reply-photo')), findsOneWidget);
      expect(photos.replyUploads, ['u1/gy']);
      await tester.enterText(find.byKey(const Key('feedback-message')), 'Note');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('notice-reply-send')));
      await tester.tap(find.byKey(const Key('notice-reply-send')));
      await tester.pumpAndSettle();
      expect(replies.sent!.imageUrl, _Photos.replyUrl);
      expect(replies.sent!.noticeId, 'gy');
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('admin sends a mail with Pha lê to everyone', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final mails = _MailAdmin();
    await tester.pumpWidget(
      MaterialApp(
        home: MailAdminPanel(
          mails: mails,
          accounts: _Accounts(),
          onClose: () {},
          now: () => _now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mail-send')));
    await tester.pump();
    expect(find.byKey(const Key('mail-admin-error')), findsOneWidget);
    expect(mails.sent, isEmpty);

    await tester.tap(find.text('Tất cả người chơi'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('mail-title')), 'Quà mừng');
    await tester.enterText(
      find.byKey(const Key('mail-body-input')),
      'Chúc vui.',
    );
    await tester.tap(find.byKey(const Key('gift-card-pha_le')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('gift-qty-pha_le')), '30');
    await tester.enterText(find.byKey(const Key('mail-xu')), '5000');
    await tester.pump();
    expect(find.byKey(const Key('mail-admin-preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mail-send')));
    await tester.pumpAndSettle();
    final mail = mails.sent.single;
    expect(mail.target, mailToAll);
    expect(mail.title, 'Quà mừng');
    expect(mail.rewards.amountOf(RewardKind.phaLe), 30);
    expect(mail.rewards.amountOf(RewardKind.coins), 5000);
    expect(find.byKey(const Key('mail-admin-sent')), findsOneWidget);
    expect(find.byKey(Key('mail-sent-${mail.id}')), findsOneWidget);
  });
}

class _Board implements NoticeBoard {
  _Board(this.items);
  final List<GameNotice> items;

  @override
  Future<List<GameNotice>> published() async => items;
}

class _NoticeAdmin implements NoticeAdmin {
  final saved = <GameNotice>[];

  @override
  String newId() => 'n1';

  @override
  Future<List<GameNotice>> loadAll() async => saved;

  @override
  Future<void> save(GameNotice notice) async => saved.add(notice);

  @override
  Future<void> delete(String id) async {}
}

class _Replies implements NoticeReplies {
  NoticeReply? sent;

  @override
  Future<NoticeReply?> mine(String noticeId, String uid) async => sent;

  @override
  Future<void> submit(NoticeReply reply) async => sent = reply;
}

class _Photos implements PhotoUploads {
  static const boardUrl = 'https://example.invalid/board.jpg';
  static const replyUrl = 'https://example.invalid/reply.jpg';
  final replyUploads = <String>[];

  @override
  Future<Uint8List?> pickPhotoJpeg() async => Uint8List.fromList([1, 2, 3]);

  @override
  Future<String> uploadBoardImage(Uint8List jpeg) async => boardUrl;

  @override
  Future<String> uploadSlideImage(Uint8List jpeg) async => boardUrl;

  @override
  Future<String> uploadReplyPhoto({
    required String uid,
    required String noticeId,
    required Uint8List jpeg,
  }) async {
    replyUploads.add('$uid/$noticeId');
    return replyUrl;
  }
}

class _MailAdmin implements MailAdmin {
  final sent = <GameMail>[];
  var _n = 0;

  @override
  String newId() => 'mail${_n++}';

  @override
  Future<List<GameMail>> loadAll() async => sent;

  @override
  Future<void> send(GameMail mail) async => sent.add(mail);

  @override
  Future<void> delete(String id) async => sent.removeWhere((m) => m.id == id);
}

class _Accounts implements AccountAdmin {
  @override
  Future<List<PlayerAccount>> findByEmail(String email) async => const [
    PlayerAccount(uid: 'an', email: 'an@x.com', shopName: 'Hoa'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
