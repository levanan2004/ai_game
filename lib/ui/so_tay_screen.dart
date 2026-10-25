import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/regulars.dart';
import '../logic/regulars.dart';
import '../logic/regulars_view.dart';
import '../logic/shop_session.dart';
import '../save/game_state.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'common.dart';
import 'ui_skin.dart';

/// Sổ tay khách quen (spec_so_tay_khach_quen.md §4–§5): the list of
/// regulars, one regular's page and an open letter. Text from
/// so_tay_strings.json (Nhất), numbers from khach_quen_block.json.
abstract final class SoTayArt {
  static String so(String id) => '${Art.root}so_tay/$id${Art.ext}';
  static String le(String id) => '${Art.root}le/$id${Art.ext}';
}

/// Colours of this screen (spec §2).
abstract final class SoTayColors {
  static const cream = Color(0xFFFFF6E3);
  static const line = Color(0xFFE8DCC0);
  static const ink = Color(0xFF2E5E3C);
  static const pink = Color(0xFFF4A6C0);
  static const red = Color(0xFFE26D5A);
}

class SoTayScreen extends StatelessWidget {
  const SoTayScreen({super.key, required this.session});

  final ShopSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final def = s.notebookDetailId == null
            ? null
            : s.regulars.byId(s.notebookDetailId!);
        final step = s.letterShownStep;
        return OpaqueScreen(
          color: SoTayColors.cream,
          child: Stack(
            key: const Key('so-tay'),
            children: [
              const Positioned.fill(child: CustomPaint(painter: _Ruled())),
              if (def == null)
                RegularsGridPage(session: s)
              else
                RegularDetailPage(session: s, def: def),
              if (def != null && step != null)
                Positioned.fill(
                  child: LetterOverlay(session: s, def: def, step: step),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Lines every 28 dp from the grid down and the pink margin at x 28 (§4.1).
class _Ruled extends CustomPainter {
  const _Ruled();

  @override
  void paint(Canvas c, Size size) {
    final line = Paint()
      ..color = SoTayColors.line
      ..strokeWidth = 1;
    for (var y = 148.0; y < size.height; y += 28) {
      c.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    c.drawLine(
      const Offset(28, 0),
      Offset(28, size.height),
      Paint()
        ..color = SoTayColors.pink
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Ruled old) => false;
}

/// Back button and the page title (§4.2, §5.1).
List<Widget> _header(ShopSession s, String title, {Widget? right}) => [
  Positioned(
    left: 12,
    top: 52,
    child: SkinRoundButton(
      key: const Key('so-tay-back'),
      kind: SkinRound.back,
      width: 40,
      onTap: s.closeNotebook,
    ),
  ),
  Positioned(
    left: 60,
    right: 60,
    top: 56,
    height: 32,
    child: Center(
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.title(size: 22, weight: 800, color: SoTayColors.ink),
      ),
    ),
  ),
  if (right != null) Positioned(right: 16, top: 59, child: right),
];

/// Always five hearts, `tim_day` / `tim_rong` (§6).
class HeartRow extends StatelessWidget {
  const HeartRow({super.key, required this.filled, this.size = 20});

  final int filled;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < heartScale; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Image.asset(
          SoTayArt.so(i < filled ? 'tim_day' : 'tim_rong'),
          width: size,
          height: size * 19 / 20,
          fit: BoxFit.contain,
        ),
      ],
    ],
  );
}

/// Round portrait: assets/images/regulars/{id}.webp, the initial on
/// #DCEFD9 until it loads (§4.5a).
class RegularAvatar extends StatelessWidget {
  const RegularAvatar({
    super.key,
    required this.def,
    required this.size,
    this.border = 3,
  });

  final RegularDef def;
  final double size;
  final double border;

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(
        def.name.isEmpty ? '?' : def.name.split(' ').last.characters.first,
        style: AppText.title(
          size: size * 0.4,
          weight: 800,
          color: AppColors.primaryBase,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.primaryBase, width: border),
      ),
      child: ClipOval(
        child: ArtImage(
          '${Art.root}${regularAvatarId(def.id)}${Art.ext}',
          size: size,
          fallback: initial,
        ),
      ),
    );
  }
}

Widget _dot() => Container(
  width: 10,
  height: 10,
  decoration: BoxDecoration(
    color: SoTayColors.red,
    shape: BoxShape.circle,
    border: Border.all(color: SoTayColors.cream, width: 2),
  ),
);

// ---- list ------------------------------------------------------------------

class RegularsGridPage extends StatelessWidget {
  const RegularsGridPage({super.key, required this.session});

  final ShopSession session;

  static const tabs = ['all', 'regular', 'locked'];

  @override
  Widget build(BuildContext context) {
    final s = session;
    final cat = s.regulars;
    final t = cat.t;
    final states = {
      for (final d in cat.customers)
        d.id: cardStateOf(cat, s.state.regulars[d.id]),
    };
    final regularsCount = states.values
        .where((v) => v == RegularCardState.regular)
        .length;
    final shown = [
      for (final d in cat.customers)
        if (switch (s.notebookTab) {
          'regular' => states[d.id] == RegularCardState.regular,
          'locked' => states[d.id] == RegularCardState.locked,
          _ => true,
        })
          d,
    ];
    return Stack(
      children: [
        ..._header(
          s,
          t.ui('title'),
          right: Container(
            key: const Key('so-tay-count'),
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$regularsCount/${cat.customers.length}',
              style: AppText.title(size: 14, color: AppColors.primaryBase),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 104,
          height: 32,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                for (final tab in tabs) ...[
                  if (tab != tabs.first) const SizedBox(width: 8),
                  _chip(s, tab, t.ui('tabs.$tab')),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 148,
          bottom: 0,
          child: shown.isEmpty
              ? _empty(t)
              : LayoutBuilder(
                  builder: (context, box) {
                    final w = (box.maxWidth - 48) / 2;
                    return SingleChildScrollView(
                      key: const Key('so-tay-grid'),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final d in shown)
                            RegularCard(
                              session: s,
                              def: d,
                              state: states[d.id]!,
                              width: w,
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(ShopSession s, String tab, String label) {
    final on = s.notebookTab == tab;
    return GestureDetector(
      key: Key('so-tay-tab-$tab'),
      onTap: () => s.selectNotebookTab(tab),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.primaryBase : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: on
              ? null
              : Border.all(color: AppColors.primaryBase, width: 1.5),
        ),
        child: Text(
          label,
          style: AppText.title(
            size: 14,
            color: on ? SoTayColors.cream : AppColors.primaryBase,
          ),
        ),
      ),
    );
  }

  Widget _empty(SoTayText t) => Center(
    key: const Key('so-tay-empty'),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 0.8,
            child: Image.asset(SoTayArt.so('so_tay_mo'), width: 200),
          ),
          const SizedBox(height: 12),
          Text(
            t.ui('empty.title'),
            textAlign: TextAlign.center,
            style: AppText.title(size: 18, weight: 800, color: SoTayColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            t.ui('empty.body'),
            textAlign: TextAlign.center,
            style: AppText.body(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

/// One regular on the list (§4.5–§4.7).
class RegularCard extends StatelessWidget {
  const RegularCard({
    super.key,
    required this.session,
    required this.def,
    required this.state,
    required this.width,
  });

  final ShopSession session;
  final RegularDef def;
  final RegularCardState state;
  final double width;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final cat = s.regulars;
    final h = width * 1.24;
    final shadow = BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x332E5E3C),
          offset: Offset(0, 4),
          blurRadius: 8,
        ),
      ],
    );
    if (state == RegularCardState.locked) {
      final hints = lockedHints(
        cat,
        s.e,
        def,
        day: s.state.day,
        great: s.state.lifetimeGreat,
      );
      final hint = hints.take(2).join('\n');
      return GestureDetector(
        key: Key('regular-card-${def.id}'),
        onTap: () => showTapHint(context, hint.isEmpty ? '???' : hint),
        child: SizedBox(
          width: width,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(SoTayArt.so('trang_khoa'), fit: BoxFit.fill),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 20,
                child: Text(
                  cat.t.ui('lockedCard.name'),
                  textAlign: TextAlign.center,
                  style: AppText.title(
                    size: 17,
                    weight: 800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 10,
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(size: 11),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final p = s.state.regulars[def.id]!;
    final meeting = state == RegularCardState.meeting;
    final avatar = math.min(88.0, width * 0.52);
    final unread = p.unread.isNotEmpty || p.inviteUnseen;
    return GestureDetector(
      key: Key('regular-card-${def.id}'),
      onTap: () => s.openRegularCard(def.id),
      child: Container(
        width: width,
        height: h,
        decoration: shadow,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.asset(SoTayArt.so('trang_giay'), fit: BoxFit.fill),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: h * 0.075,
              child: Center(
                child: Opacity(
                  opacity: meeting ? 0.7 : 1,
                  child: RegularAvatar(def: def, size: avatar),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: h * 0.075 + avatar + 6,
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      def.name,
                      maxLines: 1,
                      style: AppText.title(
                        size: 17,
                        weight: 800,
                        color: SoTayColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    favoriteNames(s.e, def),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(size: 12),
                  ),
                  const SizedBox(height: 4),
                  if (meeting)
                    Text(
                      // Spec §4.7 line; not in so_tay_strings.json yet.
                      'Đang làm quen',
                      style: AppText.caption(size: 11, color: SoTayColors.red),
                    )
                  else
                    HeartRow(
                      filled: heartsOf(cat, def, p),
                      size: math.min(20, (width - 40) / 6),
                    ),
                ],
              ),
            ),
            if (chainDone(def, p))
              Positioned(
                left: -4,
                top: -4,
                child: Transform.rotate(
                  angle: -12 * math.pi / 180,
                  child: Image.asset(
                    SoTayArt.so('dau_sap_tim'),
                    key: const Key('wax-seal'),
                    width: 34,
                    height: 35,
                  ),
                ),
              ),
            if (unread)
              Positioned(
                right: 8,
                top: 8,
                child: KeyedSubtree(
                  key: Key('card-dot-${def.id}'),
                  child: _dot(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---- one regular -----------------------------------------------------------

class RegularDetailPage extends StatelessWidget {
  const RegularDetailPage({
    super.key,
    required this.session,
    required this.def,
  });

  final ShopSession session;
  final RegularDef def;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final cat = s.regulars;
    final p = s.regularProgress(def.id);
    final met = [
      for (final d in cat.customers)
        if (s.state.regulars[d.id]?.met ?? false) d,
    ];
    final at = met.indexWhere((d) => d.id == def.id);
    Widget? flip(int dir, Key key) {
      final i = at + dir;
      if (at < 0 || i < 0 || i >= met.length) return null;
      return IconButton(
        key: key,
        iconSize: 28,
        color: SoTayColors.ink,
        icon: Icon(dir < 0 ? Icons.chevron_left : Icons.chevron_right),
        onPressed: () => s.openRegularCard(met[i].id),
      );
    }

    final letters = lettersOf(
      cat,
      s.e,
      def,
      p,
      day: s.state.day,
      owned: s.owned,
    );
    final hint = nextVisitView(
      cat,
      s.e,
      def,
      p,
      day: s.state.day,
      owned: s.owned,
    );
    final invite = canInviteAgain(def, p);
    final prev = flip(-1, const Key('regular-prev'));
    final next = flip(1, const Key('regular-next'));
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 200) prev == null ? null : (prev as IconButton).onPressed!();
        if (v < -200) next == null ? null : (next as IconButton).onPressed!();
      },
      child: Stack(
        key: Key('regular-page-${def.id}'),
        children: [
          ..._header(s, def.name, right: next),
          if (prev != null) Positioned(left: 50, top: 52, child: prev),
          Positioned(
            left: 16,
            right: 16,
            top: 100,
            height: 176,
            child: _profile(s, p),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 286,
            height: 64,
            child: NextVisitHint(view: hint),
          ),
          Positioned(
            left: 16,
            top: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Spec §5.4 title; not in so_tay_strings.json yet.
                  'Những lá thư',
                  style: AppText.title(
                    size: 17,
                    weight: 800,
                    color: SoTayColors.ink,
                  ),
                ),
                Container(width: 40, height: 3, color: SoTayColors.pink),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 392,
            bottom: invite ? 68 : 0,
            child: ListView.separated(
              key: const Key('letters'),
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: letters.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  LetterTile(view: letters[i], onOpen: s.openLetter),
            ),
          ),
          if (invite)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: SizedBox(
                  width: 200,
                  child: SkinButton(
                    key: const Key('invite-again'),
                    // Spec §5.6 label; not in so_tay_strings.json yet.
                    label: 'Mời ghé lại',
                    kind: SkinButtonKind.secondary,
                    height: 44,
                    onPressed: () => s.inviteRegularAgain(def.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profile(ShopSession s, RegularProgress p) {
    final cat = s.regulars;
    final t = cat.t;
    final small = AppText.caption(size: 11);
    final label = AppText.body(size: 13, weight: 700, color: SoTayColors.ink);
    return Stack(
      key: const Key('regular-profile'),
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(SoTayArt.so('trang_giay'), fit: BoxFit.fill),
          ),
        ),
        Positioned(
          left: 16,
          top: 16,
          child: Opacity(
            opacity: isRegular(cat, p) ? 1 : 0.7,
            child: RegularAvatar(def: def, size: 96),
          ),
        ),
        Positioned(
          left: 124,
          right: 12,
          top: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                def.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title(
                  size: 20,
                  weight: 800,
                  color: SoTayColors.ink,
                ),
              ),
              Text(
                def.profile,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(t.ui('profile.favorite'), style: label),
                  for (final id in def.favoriteFlowerIds)
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ArtImage(Art.flower(id), size: 20),
                          const SizedBox(width: 2),
                          Text(
                            itemNameVi(s.e, id),
                            style: AppText.caption(
                              size: 12,
                              color: AppColors.primaryBase,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(t.ui('profile.birthday'), style: label),
                  Text(def.birthday, style: label),
                  Text(
                    t.ui('profile.birthdayGameDay', {
                      'birthdayDayOfYear': def.birthdayDayOfYear,
                    }),
                    style: small,
                  ),
                  if (birthdayToday(s.e, def, s.state.day))
                    Container(
                      key: const Key('birthday-today'),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: SoTayColors.pink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(t.ui('profile.today'), style: label),
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 12,
          bottom: 12,
          child: Row(
            children: [
              HeartRow(filled: heartsOf(cat, def, p), size: 24),
              const Spacer(),
              Text(
                t.ui('profile.visits', {
                  'done': stepsDoneCount(p),
                  'total': def.visits.length,
                }),
                style: AppText.caption(color: AppColors.primaryBase),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// §5.3: when the regular comes next.
class NextVisitHint extends StatelessWidget {
  const NextVisitHint({super.key, required this.view});

  final NextVisitView view;

  @override
  Widget build(BuildContext context) {
    final le = holidayIcon(view.icon);
    final icon = le != null
        ? SoTayArt.le(le)
        : SoTayArt.so(view.icon == 'birthday' ? 'dau_sap_tim' : 'phong_thu');
    final style = AppText.body(size: 13, weight: 700, color: SoTayColors.ink);
    return Container(
      key: const Key('next-visit'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBase, width: 1.5),
      ),
      child: Row(
        children: [
          Image.asset(icon, width: 40, height: 40, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.lines.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
                if (view.needUnlock != null)
                  Text(
                    view.needUnlock!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(color: SoTayColors.red),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One letter row (§5.2).
class LetterTile extends StatelessWidget {
  const LetterTile({super.key, required this.view, required this.onOpen});

  final LetterView view;
  final void Function(int step) onOpen;

  @override
  Widget build(BuildContext context) {
    final v = view;
    final locked = v.state == LetterState.waiting || v.state == LetterState.far;
    Widget pic = Image.asset(
      SoTayArt.so(locked ? 'trang_khoa' : 'phong_thu'),
      width: locked ? 56 : 72,
      height: locked ? 59 : 51,
      fit: BoxFit.contain,
    );
    pic = switch (v.state) {
      LetterState.great => Stack(
        clipBehavior: Clip.none,
        children: [
          pic,
          Positioned(
            right: -4,
            bottom: -4,
            child: Image.asset(
              SoTayArt.so('dau_sap_tim'),
              key: const Key('letter-seal'),
              width: 28,
              height: 28,
            ),
          ),
        ],
      ),
      LetterState.poorEnd => Opacity(opacity: 0.7, child: pic),
      LetterState.far => Opacity(opacity: 0.5, child: pic),
      LetterState.missed => ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.33, 0.33, 0.33, 0, 0, //
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: pic,
      ),
      _ => pic,
    };
    if (v.unread) pic = Transform.rotate(angle: -6 * math.pi / 180, child: pic);
    return GestureDetector(
      key: Key('letter-${v.step}'),
      onTap: v.canOpen ? () => onOpen(v.step) : null,
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF1DC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SoTayColors.line, width: 1.5),
        ),
        child: Row(
          children: [
            SizedBox(width: 76, child: Center(child: pic)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(size: 14, color: SoTayColors.ink),
                  ),
                  if (v.line.isNotEmpty)
                    Text(
                      v.line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 12),
                    ),
                ],
              ),
            ),
            if (v.unread)
              KeyedSubtree(key: Key('letter-dot-${v.step}'), child: _dot()),
          ],
        ),
      ),
    );
  }
}

/// An open letter (§5.3): the order, then `thanks` (or `poor`), signed.
class LetterOverlay extends StatelessWidget {
  const LetterOverlay({
    super.key,
    required this.session,
    required this.def,
    required this.step,
  });

  final ShopSession session;
  final RegularDef def;
  final int step;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = s.regulars.t;
    final v = def.visit(step);
    final done = s.regularProgress(def.id).stepsDone[step];
    if (v == null) return const SizedBox.shrink();
    final great = done is int && done >= (s.e.reviewStars['great'] ?? 5);
    final body = done == RegularProgress.poorEnding ? v.poor : v.thanks;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final paper = SizedBox(
      key: const Key('letter-overlay'),
      width: 300,
      height: 399,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(SoTayArt.so('trang_giay'), fit: BoxFit.fill),
          ),
          Positioned(
            left: 28,
            right: 28,
            top: 36,
            bottom: 70,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.order,
                    style: AppText.body(
                      size: 15,
                      color: AppColors.textSecondary,
                    ).copyWith(fontStyle: FontStyle.italic, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    style: AppText.body(
                      size: 15,
                      color: SoTayColors.ink,
                    ).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      t.ui('letter.sign', {'name': def.name}),
                      style: AppText.title(size: 15, color: SoTayColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (great)
            Positioned(
              right: 20,
              bottom: 64,
              child: Image.asset(SoTayArt.so('dau_sap_tim'), width: 48),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: SizedBox(
                width: 160,
                child: SkinButton(
                  key: const Key('letter-close'),
                  label: t.ui('letter.close'),
                  height: 44,
                  onPressed: s.closeNotebook,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: s.closeNotebook,
      child: ColoredBox(
        color: const Color(0x73000000),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: reduce
                ? paper
                : Transform.rotate(angle: -2 * math.pi / 180, child: paper),
          ),
        ),
      ),
    );
  }
}
