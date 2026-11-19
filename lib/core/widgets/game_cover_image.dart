import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../models/game.dart';
import '../utils/steam_cover_art.dart';

class GameCoverImage extends StatelessWidget {
  const GameCoverImage({
    required this.game,
    this.fit = BoxFit.cover,
    this.placeholderIconSize = 22,
    this.placeholderColor,
    super.key,
  });

  final Game game;
  final BoxFit fit;
  final double placeholderIconSize;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    final steamAppId = game.source == GameSource.steam
        ? game.sourceGameId ?? game.externalGameId
        : null;
    final primaryUrl = steamAppId == null
        ? game.coverUrl
        : steamLibraryCoverUrl(steamAppId);
    final fallbackUrl = steamAppId == null
        ? null
        : steamHeaderCoverUrl(steamAppId);

    if (primaryUrl == null || primaryUrl.isEmpty) {
      return _placeholder(context);
    }

    return CachedNetworkImage(
      imageUrl: primaryUrl,
      fit: fit,
      placeholder: (_, _) => _placeholder(context),
      errorWidget: (_, _, _) => fallbackUrl == null
          ? _placeholder(context)
          : CachedNetworkImage(
              imageUrl: fallbackUrl,
              fit: fit,
              placeholder: (_, _) => _placeholder(context),
              errorWidget: (_, _, _) => _placeholder(context),
            ),
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color:
        placeholderColor ??
        Theme.of(context).colorScheme.secondary.withValues(alpha: .2),
    child: Icon(
      Icons.videogame_asset_rounded,
      color: Theme.of(context).colorScheme.primary,
      size: placeholderIconSize,
    ),
  );
}
