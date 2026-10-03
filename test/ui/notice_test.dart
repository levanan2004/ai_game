import 'package:ai_game/logic/game_notice.dart';
import 'package:ai_game/logic/notice_feed.dart';
import 'package:ai_game/logic/notice_reply.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/notice_admin_panel.dart';
import 'package:ai_game/ui/notice_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _fresh = GameNotice(
  id: 'new',
  title: 'Bảo trì tối nay',
  body: 'Tiệm đóng cửa từ 22 giờ.',
  link: 'https://tiemhoasommai.com/about',
  linkLabel: 'Xem lịch',
  createdAt: null,
);

const _old = GameNotice(
  id: 'old',
  title: 'Bản alpha',
  body: 'Cảm ơn bạn đã chơi.',
  createdAt: null,
);

class _Board implements NoticeBoard {
  _Board(this.items);
  final List<GameNotice> items;

  @override
  Future<List<GameNotice>> published() async => items;
}

class _Admin implements NoticeAdmin {
  final saved = <String, GameNotice>{};
  var _next = 0;

  @override
  String newId() => 'n${_next++}';

  @override
  Future<List<GameNotice>> loadAll() async {
    final list = saved.values.toList()..sort(compareNotices);
    return list;
  }

  @override
  Future<void> save(GameNotice notice) async {
    saved[notice.id] = notice;
  }

  @override
  Future<void> delete(String id) async {
    saved.remove(id);
  }
}

void main() {
  testWidgets('a notice opens its detail and the link', (tester) async {
    final opened = <String>[];
    final feed = NoticeFeed(
      board: _Board([_fresh, _old]),
      seen: NoticeSeen.memory({'old'}),
      initial: [_fresh, _old],
    );
    feed.open = true;
    expect(feed.unread, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 640,
          child: NewsTab(feed: feed, onOpenLink: opened.add),
        ),
      ),
    );

    expect(find.byKey(const Key('notice-badge')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 640,
          child: NewsTab(feed: feed, onOpenLink: opened.add),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('notice-item-new')));
    await tester.pump();
    expect(find.byKey(const Key('notice-detail')), findsOneWidget);
    expect(find.text('Tiệm đóng cửa từ 22 giờ.'), findsOneWidget);
    expect(feed.unread, 0);

    await tester.tap(find.byKey(const Key('notice-open-link')));
    await tester.pump();
    expect(opened, ['https://tiemhoasommai.com/about']);

    feed.showList();
    await tester.pump();
    final readTitle = tester.widget<Text>(find.text('Bảo trì tối nay'));
    // Read rows keep normal text; only the dot goes away.
    expect(readTitle.style?.color, AppColors.textPrimary);
    expect(
      find.descendant(
        of: find.byKey(const Key('notice-item-new')),
        matching: find.byKey(const Key('unread-dot')),
      ),
      findsNothing,
    );
    expect(find.byType(Opacity), findsNothing);

    await tester.tap(find.byKey(const Key('notice-hide-old')));
    await tester.pump();
    expect(find.byKey(const Key('notice-item-old')), findsNothing);
    expect(find.byKey(const Key('notice-item-new')), findsOneWidget);
    expect(feed.unread, 0);
  });

  testWidgets('admin adds, hides and deletes a notice', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final admin = _Admin();
    await tester.pumpWidget(
      MaterialApp(
        home: NoticeAdminPanel(admin: admin, onClose: () {}),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('notice-add')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('notice-title')), 'Sự kiện');
    await tester.enterText(
      find.byKey(const Key('notice-body')),
      'Ghé trang chủ nhé.',
    );
    await tester.enterText(
      find.byKey(const Key('notice-link')),
      'javascript:1',
    );
    await tester.ensureVisible(find.byKey(const Key('notice-save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('notice-save')));
    await tester.pump();
    expect(find.byKey(const Key('notice-error')), findsOneWidget);
    expect(admin.saved, isEmpty);

    await tester.enterText(find.byKey(const Key('notice-link')), '/about');
    await tester.enterText(
      find.byKey(const Key('notice-label')),
      'Về trang chủ',
    );
    await tester.ensureVisible(find.byKey(const Key('notice-save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('notice-save')));
    await tester.pump();

    final saved = admin.saved.values.single;
    expect(saved.title, 'Sự kiện');
    expect(saved.link, '/about');
    expect(saved.linkLabel, 'Về trang chủ');
    expect(saved.visible, isTrue);
    expect(find.text('Sự kiện'), findsOneWidget);

    await tester.ensureVisible(find.byKey(Key('notice-row-${saved.id}')));
    await tester.pump();
    await tester.tap(find.byKey(Key('notice-row-${saved.id}')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('notice-visible')));
    await tester.tap(find.byKey(const Key('notice-visible')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('notice-save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('notice-save')));
    await tester.pump();
    expect(admin.saved[saved.id]!.visible, isFalse);

    await tester.ensureVisible(find.byKey(Key('notice-row-${saved.id}')));
    await tester.pump();
    await tester.tap(find.byKey(Key('notice-row-${saved.id}')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('notice-delete')));
    await tester.tap(find.byKey(const Key('notice-delete')));
    await tester.pump();
    expect(find.text('Bấm lần nữa để xoá hẳn'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('notice-delete')));
    await tester.tap(find.byKey(const Key('notice-delete')));
    await tester.pump();
    expect(admin.saved, isEmpty);
  });

  testWidgets('a góp ý notice sends once and groups the number', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const notice = GameNotice(
      id: 'den',
      title: 'Đền tài khoản',
      body: 'Điền màn và tiền bạn còn nhớ.',
      kind: NoticeKind.form,
      fields: [
        NoticeField(
          id: 'day1',
          label: 'Màn chơi',
          type: NoticeInputType.number,
        ),
        NoticeField(
          id: 'note1',
          label: 'Ghi chú',
          type: NoticeInputType.note,
          required: false,
        ),
      ],
    );
    final replies = _Replies();
    final feed = NoticeFeed(
      board: _Board([notice]),
      seen: NoticeSeen.memory(),
      initial: [notice],
    );
    feed.open = true;

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
            shopName: 'Hoa Mai',
          ),
        ),
      ),
    );
    expect(find.text('Góp ý'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notice-item-den')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('notice-open-form')));
    await tester.pumpAndSettle();
    expect(find.text('Màn chơi'), findsOneWidget);
    expect(find.text('Ghi chú (không bắt buộc)'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('notice-reply-day1')),
      '100000',
    );
    await tester.enterText(
      find.byKey(const Key('notice-reply-note1')),
      'Đã mở tulip',
    );
    await tester.ensureVisible(find.byKey(const Key('notice-reply-send')));
    await tester.tap(find.byKey(const Key('notice-reply-send')));
    await tester.pumpAndSettle();

    expect(find.text('100.000'), findsOneWidget);
    expect(replies.sent, isNotNull);
    expect(replies.sent!.noticeId, 'den');
    expect(replies.sent!.answers.map((a) => a.value), [
      '100000',
      'Đã mở tulip',
    ]);
    expect(replies.sent!.answers.first.label, 'Màn chơi');
    expect(find.text('Đã gửi'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notice-reply-send')));
    await tester.pumpAndSettle();
    expect(replies.calls, 1);
  });

  testWidgets('admin replies stay grouped by notice', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final admin = _Admin();
    const den = GameNotice(
      id: 'den',
      title: 'Đền tài khoản',
      body: 'Điền giúp mình.',
      kind: NoticeKind.form,
    );
    const other = GameNotice(
      id: 'y',
      title: 'Góp ý tiệm',
      body: 'Bạn thấy sao?',
      kind: NoticeKind.form,
    );
    admin.saved['den'] = den;
    admin.saved['y'] = other;
    final replies = _ReplyAdmin([
      const NoticeReply(
        noticeId: 'den',
        uid: 'u1',
        email: 'an@x.com',
        name: 'An',
        shopName: 'Hoa Mai',
        answers: [
          NoticeAnswer(
            id: 'day1',
            label: 'Màn chơi',
            type: NoticeInputType.number,
            value: '15',
          ),
        ],
      ),
      const NoticeReply(
        noticeId: 'y',
        uid: 'u2',
        email: 'lan@x.com',
        name: 'Lan',
        shopName: 'Hoa Lan',
        answers: [
          NoticeAnswer(
            id: 'idea',
            label: 'Ý kiến',
            type: NoticeInputType.note,
            value: 'Thêm hoa',
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: NoticeAdminPanel(admin: admin, replies: replies, onClose: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notice-replies-den')));
    await tester.pumpAndSettle();
    expect(find.text('an@x.com'), findsOneWidget);
    expect(find.text('lan@x.com'), findsNothing);

    await tester.tap(find.byKey(const Key('notice-reply-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Góp ý tiệm').last);
    await tester.pumpAndSettle();
    expect(find.text('lan@x.com'), findsOneWidget);
    expect(find.text('an@x.com'), findsNothing);
    expect(find.text('Ý kiến: Thêm hoa'), findsOneWidget);
  });

  testWidgets('admin marks a reply đã duyệt and chưa duyệt', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final admin = _Admin();
    const den = GameNotice(
      id: 'den',
      title: 'Đền tài khoản',
      body: 'Điền giúp mình.',
      kind: NoticeKind.form,
    );
    admin.saved['den'] = den;
    final replies = _ReplyAdmin([
      const NoticeReply(
        noticeId: 'den',
        uid: 'u1',
        email: 'an@x.com',
        name: 'An',
        shopName: 'Hoa Mai',
        answers: [
          NoticeAnswer(
            id: 'day1',
            label: 'Màn chơi',
            type: NoticeInputType.number,
            value: '15',
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: NoticeAdminPanel(admin: admin, replies: replies, onClose: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notice-replies-den')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notice-reply-approve-u1')));
    await tester.pumpAndSettle();
    expect(replies.marked['den|u1'], isTrue);

    await tester.tap(find.byKey(const Key('notice-reply-status-approved')));
    await tester.pumpAndSettle();
    expect(find.text('an@x.com'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notice-reply-status-pending')));
    await tester.pumpAndSettle();
    expect(find.text('an@x.com'), findsNothing);

    await tester.tap(find.byKey(const Key('notice-reply-status-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notice-reply-pending-u1')));
    await tester.pumpAndSettle();
    expect(replies.marked['den|u1'], isFalse);
  });

  testWidgets('auto duyệt skips a form over the xu cap', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final admin = _Admin();
    const den = GameNotice(
      id: 'den',
      title: '[Form] Quà đền bù',
      body: 'Điền giúp mình.',
      kind: NoticeKind.form,
    );
    admin.saved['den'] = den;
    final replies = _ReplyAdmin([
      const NoticeReply(
        noticeId: 'den',
        uid: 'low',
        email: 'low@x.com',
        name: 'Low',
        shopName: 'Hoa Nhỏ',
        answers: [
          NoticeAnswer(
            id: 'xu01',
            label: 'số xu',
            type: NoticeInputType.number,
            value: '1000',
          ),
          NoticeAnswer(
            id: 'ho01',
            label: 'số hoa mở khóa',
            type: NoticeInputType.number,
            value: '2',
          ),
          NoticeAnswer(
            id: 'ch01',
            label: 'số chậu mở khóa',
            type: NoticeInputType.number,
            value: '1',
          ),
          NoticeAnswer(
            id: 'vp01',
            label: 'số vật phẩm khác',
            type: NoticeInputType.number,
            value: '1',
          ),
        ],
      ),
      const NoticeReply(
        noticeId: 'den',
        uid: 'high',
        email: 'high@x.com',
        name: 'High',
        shopName: 'Hoa Lớn',
        answers: [
          NoticeAnswer(
            id: 'xu01',
            label: 'số xu',
            type: NoticeInputType.number,
            value: '80000000',
          ),
          NoticeAnswer(
            id: 'ho01',
            label: 'số hoa mở khóa',
            type: NoticeInputType.number,
            value: '1',
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: NoticeAdminPanel(admin: admin, replies: replies, onClose: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notice-replies-den')));
    await tester.pumpAndSettle();
    expect(find.text('Tính đền: 2.251.000 xu'), findsOneWidget);
    expect(find.text('Tính đền: 80.150.000 xu'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('notice-reply-auto')));
    await tester.tap(find.byKey(const Key('notice-reply-auto')));
    await tester.pumpAndSettle();
    expect(replies.marked['den|low'], isTrue);
    expect(replies.marked.containsKey('den|high'), isFalse);
    expect(find.textContaining('Đã duyệt 1 form'), findsOneWidget);
    expect(find.textContaining('Bỏ qua 1 form'), findsOneWidget);
  });

  testWidgets('admin adds an input with a label and a type', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final admin = _Admin();
    await tester.pumpWidget(
      MaterialApp(
        home: NoticeAdminPanel(admin: admin, onClose: () {}),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('notice-add')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('notice-kind-form')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('notice-field-add')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('notice-field-label-fld1')),
      'Màn chơi',
    );
    await tester.tap(find.byKey(const Key('notice-field-type-fld1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chữ ngắn').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notice-field-required-fld1')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('notice-title')), 'Đền');
    await tester.enterText(find.byKey(const Key('notice-body')), 'Điền giúp.');
    await tester.ensureVisible(find.byKey(const Key('notice-save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('notice-save')));
    await tester.pump();

    final saved = admin.saved.values.single;
    expect(saved.kind, NoticeKind.form);
    expect(saved.fields, hasLength(1));
    expect(saved.fields.single.label, 'Màn chơi');
    expect(saved.fields.single.type, NoticeInputType.text);
    expect(saved.fields.single.required, isFalse);
  });
}

class _Replies implements NoticeReplies {
  NoticeReply? sent;
  var calls = 0;

  @override
  Future<NoticeReply?> mine(String noticeId, String uid) async => sent;

  @override
  Future<void> submit(NoticeReply reply) async {
    calls++;
    sent = reply;
  }
}

class _ReplyAdmin implements NoticeReplyAdmin {
  _ReplyAdmin(this.rows);
  final List<NoticeReply> rows;
  final marked = <String, bool>{};

  @override
  Future<List<NoticeReply>> loadAll() async => rows;

  @override
  Future<void> setApproved({
    required String noticeId,
    required String uid,
    required bool approved,
  }) async {
    marked['$noticeId|$uid'] = approved;
  }
}
