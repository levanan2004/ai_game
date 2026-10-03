import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../theme/tokens.dart';
import 'art.dart';
import 'ui_skin.dart';

/// One row in the corner menu's tray (Hộp thư, Phúc lợi; Xếp hạng later).
class CornerMenuEntry {
  const CornerMenuEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.unread,
    required this.onTap,
  });

  /// Keys: `corner-menu-<id>`, `corner-menu-dot-<id>`.
  final String id;

  /// Read by screen readers; the tray only has room for icons.
  final String label;
  final WidgetBuilder icon;
  final int Function() unread;
  final VoidCallback onTap;
}

/// Phú's basket button beside the settings gear, with a drop-down tray of
/// [entries]. The red dot on the basket adds up every entry's count.
/// Fills the screen so a tap outside the open tray closes it.
class CornerMenu extends StatefulWidget {
  const CornerMenu({
    super.key,
    required this.left,
    required this.top,
    required this.entries,
    required this.listenable,
  });

  /// Basket's top-left corner, in frame dp.
  final double left, top;
  final List<CornerMenuEntry> entries;

  /// Rebuilds the dots when any count changes.
  final Listenable listenable;

  static const size = 40.0;

  /// cham_do: 16 dp, top-left at (26, −2) from the button's corner.
  static const dotOffset = Offset(26, -2);

  /// khay_tha_xuong @1x: 64 dp wide; each 40 dp entry adds 48 dp, so two
  /// entries make 120 dp and three make 168 dp.
  static const trayWidth = 64.0;
  static double trayHeight(int entries) => 24 + 48.0 * entries;

  /// The tray's pointer sits this far from its right edge.
  static const pointerFromRight = 31.4;

  @override
  State<CornerMenu> createState() => _CornerMenuState();
}

/// khay_tha_xuong @1x canvas: 64×100, stretch rect (23, 31)–(26, 70).
const menuTray = SkinSlice(
  'khay_tha_xuong',
  w: 64,
  h: 100,
  left: 23,
  top: 31,
  right: 38,
  bottom: 30,
  padding: EdgeInsets.fromLTRB(10, 15, 10, 9),
  dir: 'ui_menu',
);

class _CornerMenuState extends State<CornerMenu> {
  var _open = false;

  void _toggle() {
    SoundScope.maybeOf(context)?.effect(_open ? 'popup_close' : 'popup_open');
    setState(() => _open = !_open);
  }

  void _pick(CornerMenuEntry entry) {
    setState(() => _open = false);
    entry.onTap();
  }

  @override
  Widget build(BuildContext context) {
    const size = CornerMenu.size;
    final trayHeight = CornerMenu.trayHeight(widget.entries.length);
    final centerX = widget.left + size / 2;
    const trayWidth = CornerMenu.trayWidth;
    return ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, _) {
        var total = 0;
        for (final e in widget.entries) {
          total += e.unread();
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (_open)
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('corner-menu-outside'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                ),
              ),
            Positioned(
              left: widget.left,
              top: widget.top,
              child: GestureDetector(
                key: const Key('corner-menu'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: Semantics(
                  button: true,
                  label: 'Menu',
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Both states share one canvas and centre.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: Image.asset(
                            Art.menu(_open ? 'nut_menu_mo' : 'nut_menu_dong'),
                            key: Key(
                              _open ? 'corner-menu-open' : 'corner-menu-closed',
                            ),
                            width: size,
                            height: size,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.menu_rounded,
                              color: AppColors.primaryBase,
                            ),
                          ),
                        ),
                        if (total > 0 && !_open)
                          Positioned(
                            left: CornerMenu.dotOffset.dx,
                            top: CornerMenu.dotOffset.dy,
                            child: MenuDot(
                              key: const Key('corner-menu-dot'),
                              count: total,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_open)
              Positioned(
                key: const Key('corner-menu-tray'),
                // Pointer right under the basket's centre.
                left: centerX - (trayWidth - CornerMenu.pointerFromRight),
                top: widget.top + size - 2,
                width: trayWidth,
                height: trayHeight,
                child: GestureDetector(
                  onTap: () {},
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: SkinSliceImage(menuTray, scale: 1),
                      ),
                      Padding(
                        padding: menuTray.padding,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final (i, e) in widget.entries.indexed) ...[
                              if (i > 0) const SizedBox(height: 8),
                              _entry(e),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _entry(CornerMenuEntry e) {
    final count = e.unread();
    return GestureDetector(
      key: Key('corner-menu-${e.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _pick(e),
      child: Semantics(
        button: true,
        label: e.label,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.headerChip,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: e.icon(context),
              ),
              if (count > 0)
                Positioned(
                  left: CornerMenu.dotOffset.dx,
                  top: CornerMenu.dotOffset.dy,
                  child: MenuDot(
                    key: Key('corner-menu-dot-${e.id}'),
                    count: count,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phú's cham_do with the count in white Baloo 2 Bold.
class MenuDot extends StatelessWidget {
  const MenuDot({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            Art.menu('cham_do'),
            width: 16,
            height: 16,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.statusDanger,
                shape: BoxShape.circle,
              ),
              child: SizedBox.expand(),
            ),
          ),
          Text(
            count > 9 ? '9+' : '$count',
            style: AppText.make(
              AppFonts.display,
              count > 9 ? 8 : 10,
              700,
              color: AppColors.textInverse,
            ),
          ),
        ],
      ),
    );
  }
}
