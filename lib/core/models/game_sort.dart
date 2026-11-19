import 'game.dart';

String _nameKey(Game game) => game.name.trim().toLowerCase();

String? _criterionKey(Game game, GameSortMode mode) {
  if (mode.isRating) {
    return game.rating == null ? 'rating:null' : 'rating:${game.rating}';
  }
  if (mode.isPlaytime) {
    return game.playtimeMinutes == null
        ? 'playtime:null'
        : 'playtime:${game.playtimeMinutes}';
  }
  return null;
}

String _tieKey(GameSortMode mode, Game game) =>
    '${mode.name}|${_criterionKey(game, mode)}';

int _compareNullable(num? left, num? right, bool descending) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  final result = left.compareTo(right);
  return descending ? -result : result;
}

int _compareSortCriterion(Game left, Game right, GameSortMode mode) {
  if (mode.isRating) {
    return _compareNullable(left.rating, right.rating, mode.isDescending);
  }
  return _compareNullable(
    left.playtimeMinutes,
    right.playtimeMinutes,
    mode.isDescending,
  );
}

List<Game> sortGames(
  Iterable<Game> input,
  GameSortMode mode, {
  Map<String, List<String>> tieOrders = const {},
}) {
  final games = input.toList();
  if (mode == GameSortMode.manual) {
    games.sort((a, b) {
      final position = a.manualPosition.compareTo(b.manualPosition);
      return position != 0 ? position : a.id.compareTo(b.id);
    });
    return games;
  }

  games.sort((a, b) {
    var primary = 0;
    if (mode.isRating) {
      primary = _compareNullable(a.rating, b.rating, mode.isDescending);
    } else if (mode.isPlaytime) {
      primary = _compareNullable(
        a.playtimeMinutes,
        b.playtimeMinutes,
        mode.isDescending,
      );
    } else {
      primary = _nameKey(a).compareTo(_nameKey(b));
      if (mode.isDescending) primary = -primary;
    }
    if (primary != 0) return primary;

    if (mode.isRating || mode.isPlaytime) {
      final key = _tieKey(mode, a);
      final orderedIds = tieOrders[key];
      final leftIndex = orderedIds?.indexOf(a.id) ?? -1;
      final rightIndex = orderedIds?.indexOf(b.id) ?? -1;
      if (leftIndex >= 0 || rightIndex >= 0) {
        if (leftIndex < 0) return 1;
        if (rightIndex < 0) return -1;
        final tiePosition = leftIndex.compareTo(rightIndex);
        if (tiePosition != 0) return tiePosition;
      }
      final byName = _nameKey(a).compareTo(_nameKey(b));
      if (byName != 0) return byName;
    }
    return a.id.compareTo(b.id);
  });
  return games;
}

class ReorderResult {
  const ReorderResult({
    required this.games,
    required this.mode,
    required this.tieOrders,
  });

  final List<Game> games;
  final GameSortMode mode;
  final Map<String, List<String>> tieOrders;
}

ReorderResult reorderGames({
  required List<Game> sortedGames,
  required GameSortMode mode,
  required int oldIndex,

  /// Post-removal insertion index from ReorderableListView.onReorderItem.
  required int newIndex,
  Map<String, List<String>> tieOrders = const {},
}) {
  final reordered = List<Game>.of(sortedGames);
  final moving = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, moving);
  if (mode == GameSortMode.manual) {
    return ReorderResult(
      games: reordered,
      mode: mode,
      tieOrders: Map.of(tieOrders),
    );
  }

  if (!mode.isRating && !mode.isPlaytime) {
    final naturallySorted = sortGames(sortedGames, mode);
    final unchanged = reordered.asMap().entries.every(
      (entry) => entry.value.id == naturallySorted[entry.key].id,
    );
    return ReorderResult(
      games: reordered,
      mode: unchanged ? mode : GameSortMode.manual,
      tieOrders: Map.of(tieOrders),
    );
  }

  final remainsSorted = reordered
      .asMap()
      .entries
      .skip(1)
      .every(
        (entry) =>
            _compareSortCriterion(
              reordered[entry.key - 1],
              entry.value,
              mode,
            ) <=
            0,
      );
  if (!remainsSorted) {
    return ReorderResult(
      games: reordered,
      mode: GameSortMode.manual,
      tieOrders: Map.of(tieOrders),
    );
  }

  final updatedTieOrders = Map<String, List<String>>.from(tieOrders);
  final tieGroups = <String, List<String>>{};
  for (final game in reordered) {
    final group = _criterionKey(game, mode)!;
    tieGroups.putIfAbsent(group, () => []).add(game.id);
  }
  for (final entry in tieGroups.entries) {
    if (entry.value.length > 1) {
      updatedTieOrders['${mode.name}|${entry.key}'] = entry.value;
    }
  }
  return ReorderResult(
    games: reordered,
    mode: mode,
    tieOrders: updatedTieOrders,
  );
}
