import 'package:ai_game/logic/install_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('day 1 summary and a later visit qualify once', () {
    expect(
      installOfferDue(
        web: true,
        installed: false,
        alreadySeen: false,
        day: 1,
        dayJustEnded: true,
      ),
      isTrue,
    );
    expect(
      installOfferDue(
        web: true,
        installed: false,
        alreadySeen: false,
        day: 1,
        dayJustEnded: false,
      ),
      isFalse,
    );
    for (final day in [2, 4, 9, 200]) {
      expect(
        installOfferDue(
          web: true,
          installed: false,
          alreadySeen: false,
          day: day,
          dayJustEnded: false,
        ),
        isTrue,
        reason: 'day $day',
      );
    }
    expect(
      installOfferDue(
        web: true,
        installed: false,
        alreadySeen: true,
        day: 200,
        dayJustEnded: false,
      ),
      isFalse,
    );
    expect(
      installOfferDue(
        web: false,
        installed: false,
        alreadySeen: false,
        day: 9,
        dayJustEnded: true,
      ),
      isFalse,
    );
    expect(
      installOfferDue(
        web: true,
        installed: true,
        alreadySeen: false,
        day: 5,
        dayJustEnded: true,
      ),
      isFalse,
    );
  });
}
