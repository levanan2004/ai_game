import 'package:ai_game/data/firebase_account.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the web login lasts across tabs and browser restarts', () {
    expect(webLoginPersistence, Persistence.LOCAL);
  });
}
