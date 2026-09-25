import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/shop_game.dart';
import '../logic/shop_session.dart';
import '../theme/tokens.dart';
import 'bouquet_table_screen.dart';
import 'main_shop_overlay.dart';
import 'market_screen.dart';
import 'reviews_screen.dart';
import 'summary_screen.dart';

/// Fixed 360×640 logical frame, scaled uniformly and letterboxed.
class GameFrame extends StatelessWidget {
  const GameFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgBase,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: AppSize.frameWidth,
            height: AppSize.frameHeight,
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}

/// Flame canvas (always mounted so the clock keeps running) plus the
/// Flutter screen for [ShopSession.screen] on top.
class GameRoot extends StatelessWidget {
  const GameRoot({super.key, required this.session, required this.game});

  final ShopSession session;
  final ShopGame game;

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final screen = session.screen;
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: screen != Screen.shop,
                  child: GameWidget<ShopGame>(game: game),
                ),
              ),
              if (screen == Screen.shop)
                Positioned.fill(child: MainShopOverlay(session: session)),
              if (screen == Screen.table)
                Positioned.fill(child: BouquetTableScreen(session: session)),
              if (screen == Screen.reviews)
                Positioned.fill(child: ReviewsScreen(session: session)),
              if (screen == Screen.market)
                Positioned.fill(child: MarketScreen(session: session)),
              if (screen == Screen.summary)
                Positioned.fill(child: SummaryScreen(session: session)),
            ],
          );
        },
      ),
    );
  }
}
