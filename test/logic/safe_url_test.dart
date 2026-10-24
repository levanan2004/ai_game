import 'package:ai_game/logic/safe_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web pages and mailto are launchable', () {
    expect(
      launchableUri('https://tiemhoasommai.com/terms')?.host,
      'tiemhoasommai.com',
    );
    expect(launchableUri('http://example.com')?.scheme, 'http');
    expect(
      launchableUri('mailto:ho-tro@tiemhoasommai.com?subject=Hi')?.path,
      'ho-tro@tiemhoasommai.com',
    );
    expect(
      launchableUri('  https://tiemhoasommai.com/ ')?.host,
      'tiemhoasommai.com',
    );
  });

  test('other schemes and empty links are refused', () {
    for (final bad in [
      '',
      'intent://scan/#Intent;scheme=zxing;end',
      'file:///sdcard/a',
      'javascript:alert(1)',
      'tel:123',
      'https://',
      'mailto:',
      'not a url',
    ]) {
      expect(launchableUri(bad), isNull, reason: bad);
    }
  });
}
