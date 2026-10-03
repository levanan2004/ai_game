import 'package:ai_game/logic/site_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home, game and admin each have their own path', () {
    expect(areaForPath('/'), SiteArea.home);
    expect(areaForPath('/play-tiem-hoa-som-mai'), SiteArea.game);
    expect(areaForPath('/play-tiem-hoa-som-mai/'), SiteArea.game);
    expect(areaForPath('/quan-tri'), SiteArea.admin);
    expect(areaForPath('/quan-tri/'), SiteArea.admin);
    expect(areaForPath('/about'), SiteArea.home);
  });
}
