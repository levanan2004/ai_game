import 'package:ai_game/logic/game_notice.dart';
import 'package:ai_game/logic/notice_reply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a reply id is one document per account and notice', () {
    expect(noticeReplyId('n1', 'u1'), 'n1_u1');
  });

  test('a form needs one to eight labelled inputs', () {
    expect(noticeFieldsError(const []), isNotNull);
    expect(
      noticeFieldsError(const [
        NoticeField(id: 'day1', label: 'Màn', type: NoticeInputType.number),
      ]),
      isNull,
    );
    expect(
      noticeFieldsError(const [
        NoticeField(id: 'day1', label: '', type: NoticeInputType.number),
      ]),
      isNotNull,
    );
  });

  test('answers follow the labels and types on the notice', () {
    const fields = [
      NoticeField(id: 'day1', label: 'Màn chơi', type: NoticeInputType.number),
      NoticeField(
        id: 'note1',
        label: 'Ghi chú',
        type: NoticeInputType.note,
        required: false,
      ),
    ];
    expect(
      noticeAnswersError(fields: fields, values: {'day1': '', 'note1': ''}),
      isNotNull,
    );
    expect(
      noticeAnswersError(
        fields: fields,
        values: {'day1': '12', 'note1': 'tulip'},
      ),
      isNull,
    );
    expect(
      noticeAnswersError(fields: fields, values: {'day1': 'abc'}),
      isNotNull,
    );
    final answers = noticeAnswersFor(
      fields: fields,
      values: {'day1': '12', 'note1': ' tulip '},
    );
    expect(answers.map((a) => a.label), ['Màn chơi', 'Ghi chú']);
    expect(answers[1].value, 'tulip');
  });

  test('a number shows a dot every three digits and stores digits', () {
    expect(noticeGroupedNumber('100000'), '100.000');
    expect(noticeGroupedNumber('100.000'), '100.000');
    expect(noticeGroupedNumber(''), '');
    const fields = [
      NoticeField(id: 'xu01', label: 'Số xu', type: NoticeInputType.number),
    ];
    expect(
      noticeAnswersError(fields: fields, values: {'xu01': '100.000'}),
      isNull,
    );
    expect(
      noticeAnswersFor(
        fields: fields,
        values: {'xu01': '100.000'},
      ).single.value,
      '100000',
    );
  });

  test('reply search and time order keep a missing time last', () {
    final older = NoticeReply(
      noticeId: 'n',
      uid: 'b',
      email: 'b@x.com',
      name: 'Bình',
      shopName: 'Hoa B',
      answers: const [
        NoticeAnswer(
          id: 'y',
          label: 'Ý kiến',
          type: NoticeInputType.note,
          value: 'Thêm hoa',
        ),
      ],
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final newer = NoticeReply(
      noticeId: 'n',
      uid: 'a',
      email: 'a@x.com',
      name: 'An',
      shopName: 'Hoa A',
      answers: const [],
      createdAt: DateTime.utc(2026, 9, 1),
    );
    final blank = NoticeReply(
      noticeId: 'n',
      uid: 'c',
      email: '',
      name: '',
      shopName: '',
      answers: const [],
    );
    expect(replyMatches(older, 'thêm hoa'), isTrue);
    expect(replyMatches(newer, 'hoa a'), isTrue);
    expect(replyMatches(blank, 'bình'), isFalse);
    expect(sortReplies([older, newer, blank]).map((r) => r.uid), [
      'a',
      'b',
      'c',
    ]);
    expect(
      sortReplies([older, newer, blank], ascending: true).map((r) => r.uid),
      ['b', 'a', 'c'],
    );
  });

  test('compensation auto-approves at or under the xu cap', () {
    NoticeReply reply({
      required String xu,
      String flowers = '0',
      String pots = '0',
      String other = '0',
      bool approved = false,
    }) {
      return NoticeReply(
        noticeId: 'den',
        uid: 'u',
        email: 'a@x.com',
        name: 'An',
        shopName: 'Hoa',
        approved: approved,
        answers: [
          NoticeAnswer(
            id: 'xu01',
            label: 'số xu',
            type: NoticeInputType.number,
            value: xu,
          ),
          NoticeAnswer(
            id: 'ho01',
            label: 'số hoa mở khóa',
            type: NoticeInputType.number,
            value: flowers,
          ),
          NoticeAnswer(
            id: 'ch01',
            label: 'số chậu mở khóa',
            type: NoticeInputType.number,
            value: pots,
          ),
          NoticeAnswer(
            id: 'vp01',
            label: 'số vật phẩm khác',
            type: NoticeInputType.number,
            value: other,
          ),
        ],
      );
    }

    final low = reply(xu: '1000', flowers: '2', pots: '1', other: '1');
    expect(compensationAmount(low).total, 2251000);
    expect(
      compensationAutoApproves(low, skipAbove: compensationAutoSkipXu),
      isTrue,
    );

    final topped = reply(xu: '80000000');
    expect(compensationAmount(topped).total, compensationAutoSkipXu);
    expect(
      compensationAutoApproves(topped, skipAbove: compensationAutoSkipXu),
      isTrue,
    );

    final high = reply(xu: '80.000.000', flowers: '1');
    expect(compensationAmount(high).total, 80150000);
    expect(
      compensationAutoApproves(high, skipAbove: compensationAutoSkipXu),
      isFalse,
    );
    expect(
      compensationAutoApproves(
        topped.copyWith(approved: true),
        skipAbove: compensationAutoSkipXu,
      ),
      isFalse,
    );
    expect(noticeIsCompensation('[Form] Quà đền bù'), isTrue);
    expect(noticeIsCompensation('Góp ý tiệm'), isFalse);
  });
}
