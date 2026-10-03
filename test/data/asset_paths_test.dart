import 'dart:io';

import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/ui/art.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Every image path the code can build must exist on disk.
void main() {
  void expectFile(String path, String reason) {
    expect(File(path).existsSync(), isTrue, reason: '$path ($reason)');
  }

  final dartFiles = [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f,
  ];

  test('asset path literals in lib exist', () {
    final literal = RegExp(r'''assets/images/[A-Za-z0-9_/]+\.[a-z]+''');
    var count = 0;
    for (final file in dartFiles) {
      for (final m in literal.allMatches(file.readAsStringSync())) {
        expectFile(m.group(0)!, file.path);
        count++;
      }
    }
    expect(count, greaterThan(0));
  });

  test('Art calls with a fixed id point at real files', () {
    final builders = <String, String Function(String)>{
      'flower': Art.flower,
      'pot': Art.pot,
      'ui': Art.ui,
      'paper': Art.paper,
      'ribbon': Art.ribbon,
      'upgrade': Art.upgrade,
      'customer': Art.customer,
      'customerFull': Art.customerFull,
      'nav': Art.nav,
      'garden': Art.garden,
      'pet': Art.pet,
      'scene': Art.scene,
      'event': Art.event,
      'shipper': Art.shipper,
      'donate': Art.donate,
      'phucLoi': Art.phucLoi,
      'banBiet': Art.banBiet,
      'uiSkin': Art.uiSkin,
    };
    final call = RegExp(r"""Art\.(\w+)\(\s*'([A-Za-z0-9_]+)'\s*\)""");
    var count = 0;
    for (final file in dartFiles) {
      for (final m in call.allMatches(file.readAsStringSync())) {
        final build = builders[m.group(1)];
        if (build == null) continue;
        expectFile(build(m.group(2)!), file.path);
        count++;
      }
    }
    expect(count, greaterThan(20));
  });

  test('art built from game data exists', () {
    final d = loadTestData();
    final e = d.economy;
    final paths = <String>[
      for (final f in e.flowers) Art.flower(f.id),
      for (final p in e.pots)
        if (!p.unlimited) Art.pot(p.id),
      for (final p in e.papers) Art.paper(p.id),
      for (final r in e.ribbons) Art.ribbon(r.id),
      for (final u in e.upgrades) Art.upgrade(u.id),
      for (final c in d.orders.customers) ...[
        Art.customer(c.avatarId),
        Art.customerFull(c.avatarId),
      ],
      for (final s in e.delivery.shippers) ...[
        Art.shipperPose(s.id, riding: true),
        Art.shipperPose(s.id, riding: false),
      ],
      for (final skin in petSkins) Art.pet(skin.asset),
      for (final treat in treatsForSale) Art.pet(treat.asset),
      for (final gift in giftCatalog)
        switch (gift.art) {
          GiftArt.pet => Art.pet(gift.asset),
          GiftArt.pot => Art.pot(gift.asset),
          GiftArt.coin || GiftArt.phaLe => Art.nav(gift.asset),
        },
      Art.nav('pha_le'),
      for (var stage = 0; stage < petStageIds.length; stage++)
        for (final pose in const [
          'an',
          'be',
          'doi',
          'dotpha',
          'nang',
          'ngoi',
          'vuot',
        ])
          Art.pet(petSprite(stage, pose)),
    ];
    for (final p in paths) {
      expectFile(p, 'data');
    }
  });

  test('game art is WebP; only the bank QR stays PNG', () {
    final old = RegExp(r'''assets/images/[A-Za-z0-9_/]+\.(png|jpe?g)''');
    for (final file in dartFiles) {
      for (final m in old.allMatches(file.readAsStringSync())) {
        expect(
          m.group(0),
          'assets/images/donate/qr_bidv_levanan.png',
          reason: file.path,
        );
      }
    }
    expect(Art.flower('rose'), endsWith('.webp'));
    expect(Art.donate('qr_bidv_levanan'), endsWith('.png'));
  });
}
