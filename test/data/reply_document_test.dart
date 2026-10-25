import 'package:ai_game/data/notice_replies.dart';
import 'package:ai_game/logic/game_notice.dart';
import 'package:ai_game/logic/notice_reply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final reply = NoticeReply(
    noticeId: 'gy',
    uid: 'u1',
    email: 'an@x.com',
    name: 'An',
    shopName: 'Hoa Mai',
    answers: feedbackAnswers(FeedbackType.baoLoi, const {'coins': 50000}),
    feedbackType: 'bao_loi',
    message: 'm' * 1000,
    progress: const {'coins': 50000},
  );

  test('a góp ý stores type, message and progress', () {
    final doc = replyDocument(reply);
    expect(doc['type'], 'bao_loi');
    expect(doc['message'], 'm' * 1000);
    expect(doc['progress'], {'coins': 50000});
    final answers = doc['answers']! as List;
    expect(answers.length, 2);
  });

  test('the legacy shape carries the note as an answer row', () {
    final doc = replyDocument(reply, legacy: true);
    expect(doc.containsKey('type'), isFalse);
    expect(doc.containsKey('message'), isFalse);
    expect(doc.containsKey('progress'), isFalse);
    final last = (doc['answers']! as List).last as Map;
    expect(last['id'], 'loi_nhan');
    expect(last['type'], NoticeInputType.note.name);
    expect((last['value'] as String).length, 300);
  });
}
