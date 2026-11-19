import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/game.dart';
import '../../core/models/game_sort.dart';
import '../../core/providers/app_providers.dart';
import '../../core/sync/sync_status_banner.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_cover_image.dart';
import 'library_header_art.dart';

class GameListScreen extends ConsumerStatefulWidget {
  const GameListScreen({required this.listType, super.key});

  final GameListType listType;

  @override
  ConsumerState<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends ConsumerState<GameListScreen> {
  final _searchController = TextEditingController();
  final Set<String> _selectedGameIds = {};
  String? _platformFilter;
  GameStatus? _statusFilter;
  List<Game>? _reorderPreviewGames;
  ListPreferences? _reorderPreviewPreferences;
  bool _previewClearScheduled = false;
  bool _batchDeleting = false;

  bool get _selectionMode => _selectedGameIds.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gamesProvider(widget.listType));
    final preferencesAsync = ref.watch(
      listPreferencesProvider(widget.listType),
    );
    final isWishlist = widget.listType == GameListType.wishlist;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: gamesAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          data: (games) => preferencesAsync.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            data: (preferences) =>
                _content(context, games, preferences, isWishlist),
            loading: () => _loadingPage(isWishlist),
            error: (error, _) => _errorPage(isWishlist, error),
          ),
          loading: () => _loadingPage(isWishlist),
          error: (error, _) => _errorPage(isWishlist, error),
        ),
      ),
    );
  }

  Widget _loadingPage(bool isWishlist) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: _header(isWishlist)),
      const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    ],
  );

  Widget _errorPage(bool isWishlist, Object error) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: _header(isWishlist)),
      SliverFillRemaining(hasScrollBody: false, child: _error(context, error)),
    ],
  );

  Widget _content(
    BuildContext context,
    List<Game> games,
    ListPreferences preferences,
    bool isWishlist,
  ) {
    _clearReorderPreviewWhenSynced(games, preferences);
    final displayedGames = _reorderPreviewGames ?? games;
    final displayedPreferences = _reorderPreviewPreferences ?? preferences;
    final sorted = _reorderPreviewGames == null
        ? sortGames(
            displayedGames,
            displayedPreferences.sortMode,
            tieOrders: displayedPreferences.tieOrders,
          )
        : List<Game>.of(displayedGames);
    final query = _searchController.text.trim().toLowerCase();
    final visible = sorted.where((game) {
      final matchesName =
          query.isEmpty || game.name.toLowerCase().contains(query);
      final matchesPlatform =
          _platformFilter == null ||
          platformFamilyId(game.platformId) == _platformFilter;
      final matchesStatus =
          _statusFilter == null || game.status == _statusFilter;
      return matchesName && matchesPlatform && matchesStatus;
    }).toList();
    final filtered =
        query.isNotEmpty || _platformFilter != null || _statusFilter != null;
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: _header(isWishlist)),
        if (isWishlist) const SliverToBoxAdapter(child: SyncStatusBanner()),
        SliverToBoxAdapter(
          child: isWishlist
              ? _searchField(context)
              : _librarySearchField(context, displayedPreferences, isWishlist),
        ),
        SliverToBoxAdapter(
          child: isWishlist
              ? _wishlistSummary(displayedGames.length)
              : _stats(context, displayedGames),
        ),
        if (isWishlist)
          SliverToBoxAdapter(child: _filters(context, isWishlist)),
        if (isWishlist)
          SliverToBoxAdapter(
            child: _rankingControls(
              context,
              displayedPreferences,
              filtered,
              isWishlist,
            ),
          ),
        if (filtered)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(
                'Limpe a busca e os filtros para reorganizar a lista completa.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (_selectionMode)
          SliverToBoxAdapter(
            child: _selectionToolbar(context, displayedGames),
          ),
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyState(context, displayedGames.isEmpty, isWishlist),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isWishlist ? 12 : 10,
              0,
              isWishlist ? 12 : 10,
              8,
            ),
            sliver: SliverReorderableList(
              itemCount: visible.length,
              onReorderItem: filtered
                  ? (_, _) {}
                  : (oldIndex, newIndex) => _reorder(
                      sorted,
                      displayedPreferences,
                      oldIndex,
                      newIndex,
                    ),
              itemBuilder: (context, index) {
                final game = visible[index];
                final globalPosition =
                    sorted.indexWhere((item) => item.id == game.id) + 1;
                if (isWishlist) {
                  return WishlistGameCard(
                    key: ValueKey(game.id),
                    game: game,
                    position: globalPosition,
                    index: index,
                    draggable: !filtered && !_selectionMode,
                    selected: _selectedGameIds.contains(game.id),
                    selectionMode: _selectionMode,
                    onEdit: () {
                      _discardReorderPreview();
                      context.push('/games/${game.id}/edit');
                    },
                    onOpen: () => _handleGameTap(game),
                    onLongPress: () => _toggleGameSelection(game.id),
                    onDelete: () => _confirmDelete(game),
                  );
                }
                return GameCard(
                  key: ValueKey(game.id),
                  game: game,
                  position: globalPosition,
                  index: index,
                  draggable: !filtered && !_selectionMode,
                  selected: _selectedGameIds.contains(game.id),
                  selectionMode: _selectionMode,
                  onEdit: () {
                    _discardReorderPreview();
                    context.push('/games/${game.id}/edit');
                  },
                  onOpen: () => _handleGameTap(game),
                  onLongPress: () => _toggleGameSelection(game.id),
                  onDelete: () => _confirmDelete(game),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _header(bool isWishlist) => LibraryHeaderArt(
    title: isWishlist ? 'Lista de Desejos' : 'Minha Biblioteca',
    subtitle: isWishlist ? 'Seus próximos jogos' : 'Seus jogos ranqueados',
    onAdd: () {
      _discardReorderPreview();
      context.push('/add?list=${widget.listType.name}');
    },
    useImageBackground: true,
  );

  Widget _selectionToolbar(
    BuildContext context,
    List<Game> allGames,
  ) {
    final allGameIds = allGames.map((game) => game.id).toSet();
    final allGamesSelected =
        allGameIds.isNotEmpty && allGameIds.every(_selectedGameIds.contains);
    final count = _selectedGameIds.length;
    final horizontalPadding = widget.listType == GameListType.wishlist
        ? 12.0
        : 10.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: .5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$count selecionado${count == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: allGames.isEmpty || _batchDeleting
                      ? null
                      : () => _toggleGamesSelection(allGames),
                  child: Text(
                    allGamesSelected
                        ? 'Desmarcar todos'
                        : 'Selecionar todos',
                  ),
                ),
                IconButton(
                  tooltip: 'Cancelar seleção',
                  onPressed: _batchDeleting ? null : _clearSelection,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _batchDeleting
                  ? null
                  : () => _confirmDeleteSelected(allGames),
              icon: _batchDeleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(
                _batchDeleting
                    ? 'Excluindo…'
                    : count == 1
                        ? 'Excluir 1 jogo'
                        : 'Excluir $count jogos',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleGameTap(Game game) {
    if (_selectionMode) {
      _toggleGameSelection(game.id);
      return;
    }
    _discardReorderPreview();
    context.push('/games/${game.id}');
  }

  void _toggleGameSelection(String gameId) {
    if (_batchDeleting) return;
    setState(() {
      if (!_selectedGameIds.add(gameId)) _selectedGameIds.remove(gameId);
    });
  }

  void _toggleGamesSelection(List<Game> games) {
    final gameIds = games.map((game) => game.id).toSet();
    final allGamesSelected =
        gameIds.isNotEmpty && gameIds.every(_selectedGameIds.contains);
    setState(() {
      if (allGamesSelected) {
        _selectedGameIds.removeAll(gameIds);
      } else {
        _selectedGameIds.addAll(gameIds);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedGameIds.clear);
  }

  void _clearReorderPreviewWhenSynced(
    List<Game> games,
    ListPreferences preferences,
  ) {
    final previewGames = _reorderPreviewGames;
    final previewPreferences = _reorderPreviewPreferences;
    if (previewGames == null ||
        previewPreferences == null ||
        preferences.sortMode != previewPreferences.sortMode) {
      return;
    }

    final currentOrder = sortGames(
      games,
      preferences.sortMode,
      tieOrders: preferences.tieOrders,
    );
    if (!_hasSameGameOrder(currentOrder, previewGames) ||
        _previewClearScheduled) {
      return;
    }

    _previewClearScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previewClearScheduled = false;
      if (!mounted ||
          !identical(_reorderPreviewGames, previewGames) ||
          !identical(_reorderPreviewPreferences, previewPreferences)) {
        return;
      }
      setState(_discardReorderPreview);
    });
  }

  bool _hasSameGameOrder(List<Game> left, List<Game> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id) return false;
    }
    return true;
  }

  void _discardReorderPreview() {
    _reorderPreviewGames = null;
    _reorderPreviewPreferences = null;
  }

  Widget _librarySearchField(
    BuildContext context,
    ListPreferences preferences,
    bool isWishlist,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
    child: Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar jogo...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: const Color(0xFF101820),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: .58),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: .58),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: const Color(0xFF101820),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => _showLibraryFilters(preferences, isWishlist),
              child: Tooltip(
                message: 'Filtros da biblioteca',
                child: Icon(
                  Icons.filter_list_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 23,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _showLibraryFilters(
    ListPreferences preferences,
    bool isWishlist,
  ) async => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ordenação e filtros',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<GameSortMode>(
                initialValue: preferences.sortMode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ordenar por'),
                items: GameSortMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode.label),
                      ),
                    )
                    .toList(),
                onChanged: (mode) {
                  if (mode == null) return;
                  Navigator.pop(sheetContext);
                  unawaited(_changeSort(mode));
                },
              ),
              if (!isWishlist) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _statusFilter?.name ?? '__all__',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(
                      value: '__all__',
                      child: Text('Todos os status'),
                    ),
                    ...GameStatus.values.map(
                      (status) => DropdownMenuItem(
                        value: status.name,
                        child: Text(status.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(
                      () => _statusFilter = value == null || value == '__all__'
                          ? null
                          : GameStatus.values.firstWhere(
                              (item) => item.name == value,
                            ),
                    );
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _platformFilter ?? '__all__',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Plataforma'),
                items: [
                  const DropdownMenuItem(
                    value: '__all__',
                    child: Text('Todas as plataformas'),
                  ),
                  ...gamePlatforms.map(
                    (platform) => DropdownMenuItem(
                      value: platform.$1,
                      child: Text(platform.$2),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(
                    () => _platformFilter = value == null || value == '__all__'
                        ? null
                        : value,
                  );
                  Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _statusFilter = null;
                    _platformFilter = null;
                  });
                  Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Limpar filtros'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _searchField(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    child: TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar jogo...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: .55),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
      ),
    ),
  );

  Widget _stats(BuildContext context, List<Game> games) {
    final counts = <({String label, int value, IconData icon, Color color})>[
      (
        label: 'Total',
        value: games.length,
        icon: Icons.sports_esports_outlined,
        color: AppColors.accent(context),
      ),
      (
        label: 'Concluídos',
        value: games
            .where((game) => game.status == GameStatus.completed)
            .length,
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.green,
      ),
      (
        label: 'Jogando',
        value: games.where((game) => game.status == GameStatus.playing).length,
        icon: Icons.sports_esports_outlined,
        color: AppColors.playingBlue,
      ),
      (
        label: 'Dropados',
        value: games.where((game) => game.status == GameStatus.dropped).length,
        icon: Icons.cancel_outlined,
        color: AppColors.red,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          for (var index = 0; index < counts.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            Expanded(
              child: _StatCard(
                label: counts[index].label,
                value: counts[index].value,
                icon: counts[index].icon,
                color: counts[index].color,
                highlighted: index == 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _wishlistSummary(int total) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .38),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_border_rounded, color: AppColors.accent(context)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Jogos na lista')),
          Text(
            '$total',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.accent(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _filters(BuildContext context, bool isWishlist) {
    final platformOptions = <(String, String)>[
      ('__all__', 'Todas'),
      ...gamePlatforms,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _choiceButton<String>(
              context,
              label: 'Plataforma',
              valueLabel: _platformFilter == null
                  ? 'Todas'
                  : platformLabel(_platformFilter!),
              icon: Icons.devices_rounded,
              options: platformOptions,
              onSelected: (value) => setState(
                () => _platformFilter = value == '__all__' ? null : value,
              ),
            ),
          ),
          if (!isWishlist) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _choiceButton<String>(
                context,
                label: 'Status',
                valueLabel: _statusFilter?.label ?? 'Todos',
                icon: Icons.filter_list_rounded,
                options: [
                  const ('__all__', 'Todos'),
                  ...GameStatus.values.map(
                    (status) => (status.name, status.label),
                  ),
                ],
                onSelected: (value) => setState(
                  () => _statusFilter = value == '__all__'
                      ? null
                      : GameStatus.values.firstWhere(
                          (status) => status.name == value,
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rankingControls(
    BuildContext context,
    ListPreferences preferences,
    bool filtered,
    bool isWishlist,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  isWishlist ? 'Sua lista' : 'Ranking',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (filtered) ...[
                const SizedBox(width: 6),
                const Tooltip(
                  message:
                      'Limpe busca e filtros para reorganizar a lista completa.',
                  child: Icon(Icons.info_outline_rounded, size: 16),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 178,
          child: _choiceButton<GameSortMode>(
            context,
            label: 'Ordenar',
            valueLabel: preferences.sortMode.label,
            icon: Icons.sort_rounded,
            options: GameSortMode.values
                .map((mode) => (mode, mode.label))
                .toList(),
            onSelected: _changeSort,
          ),
        ),
      ],
    ),
  );

  Widget _choiceButton<T>(
    BuildContext context, {
    required String label,
    required String valueLabel,
    required IconData icon,
    required List<(T, String)> options,
    required ValueChanged<T> onSelected,
  }) => PopupMenuButton<T>(
    tooltip: label,
    onSelected: onSelected,
    itemBuilder: (context) => options
        .map(
          (option) =>
              PopupMenuItem<T>(value: option.$1, child: Text(option.$2)),
        )
        .toList(),
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              valueLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );

  Widget _emptyState(
    BuildContext context,
    bool noGames,
    bool isWishlist,
  ) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            noGames ? Icons.sports_esports_rounded : Icons.search_off_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            noGames
                ? (isWishlist
                      ? 'Sua lista começa aqui'
                      : 'Sua biblioteca está vazia')
                : 'Nenhum jogo encontrado',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            noGames
                ? 'Adicione um jogo manualmente. Seus dados ficam neste dispositivo.'
                : 'Tente mudar a busca ou limpar os filtros.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (noGames) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  context.push('/add?list=${widget.listType.name}'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar jogo'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _error(BuildContext context, Object error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Não foi possível abrir os dados locais.\n$error',
        textAlign: TextAlign.center,
      ),
    ),
  );

  Future<void> _changeSort(GameSortMode mode) async {
    if (_reorderPreviewGames != null) {
      setState(_discardReorderPreview);
    }
    final repository = await ref.read(gameRepositoryProvider.future);
    await repository.writePreference('${widget.listType.name}.sort', mode.name);
    ref.invalidate(listPreferencesProvider(widget.listType));
  }

  Future<void> _reorder(
    List<Game> sorted,
    ListPreferences preferences,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= sorted.length) {
      return;
    }
    final result = reorderGames(
      sortedGames: sorted,
      mode: preferences.sortMode,
      oldIndex: oldIndex,
      newIndex: newIndex,
      tieOrders: preferences.tieOrders,
    );
    final previewGames = List<Game>.of(result.games);
    final previewPreferences = ListPreferences(
      sortMode: result.mode,
      tieOrders: result.tieOrders,
    );
    setState(() {
      _reorderPreviewGames = previewGames;
      _reorderPreviewPreferences = previewPreferences;
    });

    try {
      final repository = await ref.read(gameRepositoryProvider.future);
      if (result.mode != preferences.sortMode) {
        await repository.writePreference(
          '${widget.listType.name}.sort',
          result.mode.name,
        );
        await repository.persistPositions(widget.listType, result.games);
      } else if (result.mode == GameSortMode.manual) {
        await repository.persistPositions(widget.listType, result.games);
      } else {
        await repository.writePreference(
          '${widget.listType.name}.ties',
          jsonEncode(result.tieOrders),
        );
        await repository.persistPositions(widget.listType, result.games);
      }
      ref.invalidate(gamesProvider(widget.listType));
      ref.invalidate(listPreferencesProvider(widget.listType));
      ref.invalidate(pendingOperationCountProvider);
    } catch (error) {
      if (!mounted) return;
      setState(_discardReorderPreview);
      ref.invalidate(gamesProvider(widget.listType));
      ref.invalidate(listPreferencesProvider(widget.listType));
      ref.invalidate(pendingOperationCountProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar a nova ordem: $error')),
      );
    }
  }

  Future<void> _confirmDeleteSelected(List<Game> games) async {
    final selectedGames = games
        .where((game) => _selectedGameIds.contains(game.id))
        .toList(growable: false);
    if (selectedGames.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          selectedGames.length == 1
              ? 'Excluir 1 jogo?'
              : 'Excluir ${selectedGames.length} jogos?',
        ),
        content: const Text(
          'Os jogos selecionados serão removidos desta lista neste dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _batchDeleting = true;
      _discardReorderPreview();
    });
    try {
      final repository = await ref.read(gameRepositoryProvider.future);
      await repository.deleteGames(
        selectedGames.map((game) => game.id).toList(growable: false),
      );
      if (!mounted) return;
      setState(_selectedGameIds.clear);
      ref.invalidate(gamesProvider(widget.listType));
      ref.invalidate(pendingOperationCountProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedGames.length == 1
                ? 'Jogo excluído.'
                : 'Excluídos ${selectedGames.length} jogos.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível excluir os jogos: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _batchDeleting = false);
    }
  }

  Future<void> _confirmDelete(Game game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir jogo?'),
        content: Text(
          '“${game.name}” será removido da lista deste dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_reorderPreviewGames != null) {
      setState(_discardReorderPreview);
    }
    final repository = await ref.read(gameRepositoryProvider.future);
    await repository.deleteGame(game.id);
    ref.invalidate(gamesProvider(widget.listType));
    ref.invalidate(pendingOperationCountProvider);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlighted = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 100;
        final heading = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: compact ? 9 : 10,
            height: 1,
            color: colors.onSurfaceVariant,
          ),
        );
        final count = Text(
          '$value',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: highlighted ? AppColors.gold : colors.onSurface,
            fontSize: compact ? 17 : 19,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        );
        return Container(
          height: 60,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 2 : 7,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0C151D),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: (highlighted ? AppColors.gold : colors.outlineVariant)
                  .withValues(alpha: highlighted ? .76 : .34),
            ),
          ),
          child: compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(height: 2),
                    heading,
                    const SizedBox(height: 3),
                    count,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 26),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [heading, const SizedBox(height: 4), count],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class GameCard extends StatelessWidget {
  const GameCard({
    required this.game,
    required this.position,
    required this.index,
    required this.draggable,
    required this.selected,
    required this.selectionMode,
    required this.onEdit,
    required this.onOpen,
    required this.onLongPress,
    required this.onDelete,
    super.key,
  });

  final Game game;
  final int position;
  final int index;
  final bool draggable;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onEdit;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected
          ? AppColors.gold.withValues(alpha: .12)
          : const Color(0xFF0A121A),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? AppColors.gold.withValues(alpha: .9)
              : const Color(0xFF33424E).withValues(alpha: .62),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 370;
          final coverWidth = narrow ? 69.0 : 86.0;
          final coverHeight = narrow ? 84.0 : 96.0;
          final positionText = position <= 5 ? '#$position' : '$position';
          final positionWidth =
              (narrow ? 26.0 : 32.0) +
              (positionText.length > 2
                  ? (positionText.length - 2) * (narrow ? 11.0 : 13.0)
                  : 0.0);
          final statusContentWidth = narrow ? 66.0 : 74.0;
          final positionColor = switch (position) {
            1 => AppColors.accent(context),
            2 => const Color(0xFFD4D9E2),
            3 => const Color(0xFFC98750),
            4 => const Color(0xFF68B7FF),
            5 => AppColors.green,
            _ => theme.colorScheme.onSurfaceVariant,
          };
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onOpen,
            onLongPress: onLongPress,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 5 : 8,
                vertical: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: positionWidth,
                          child: Text(
                            positionText,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: positionColor,
                              fontWeight: FontWeight.w900,
                              fontSize: narrow ? 17 : 21,
                            ),
                          ),
                        ),
                        SizedBox(width: narrow ? 5 : 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: SizedBox(
                            width: coverWidth,
                            height: coverHeight,
                            child: GameCoverImage(game: game),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: narrow ? 5 : 7),
                  Expanded(
                    child: Container(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.name,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: narrow ? 14 : 17,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _PlatformLabel(game: game),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: Divider(
                                      height: 1,
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: .4),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                game.playtimeMinutes == null
                                    ? '— h'
                                    : '${game.playtimeHours!.toStringAsFixed(game.playtimeHours! % 1 == 0 ? 0 : 1)}h',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: statusContentWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (game.rating != null)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: narrow ? 5 : 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(
                                      alpha: .08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(
                                        alpha: .78,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: AppColors.gold,
                                        size: narrow ? 14 : 17,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        game.rating!.toStringAsFixed(1),
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: AppColors.gold,
                                              fontWeight: FontWeight.w900,
                                              fontSize: narrow ? 11 : 14,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (game.status != null) ...[
                                if (game.rating != null)
                                  SizedBox(height: narrow ? 8 : 10),
                                _StatusChip(
                                  status: game.status!,
                                  compact: narrow,
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: narrow ? 4 : 7),
                        _LibraryDragHandle(
                          index: index,
                          draggable: draggable,
                          selected: selected,
                          selectionMode: selectionMode,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LibraryDragHandle extends StatelessWidget {
  const _LibraryDragHandle({
    required this.index,
    required this.draggable,
    required this.selected,
    required this.selectionMode,
  });

  final int index;
  final bool draggable;
  final bool selected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    if (selectionMode) {
      return Tooltip(
        message: selected ? 'Selecionado' : 'Toque para selecionar',
        child: SizedBox(
          width: 26,
          height: 46,
          child: Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: selected ? AppColors.gold : AppColors.muted,
          ),
        ),
      );
    }

    final handle = Tooltip(
      message: draggable
          ? 'Arraste para reordenar'
          : 'Limpe os filtros para reordenar',
      child: SizedBox(
        width: 26,
        height: 46,
        child: Icon(
          Icons.drag_indicator_rounded,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
            alpha: draggable ? .85 : .4,
          ),
        ),
      ),
    );
    if (!draggable) return handle;
    return ReorderableDragStartListener(index: index, child: handle);
  }
}

class _PlatformLabel extends StatelessWidget {
  const _PlatformLabel({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final lower = game.platformId.toLowerCase();
    final icon = lower.contains('pc') || lower.contains('steam')
        ? Icons.computer_rounded
        : lower.contains('xbox')
        ? Icons.sports_esports_outlined
        : lower.contains('playstation') || lower.contains('ps')
        ? Icons.sports_esports_rounded
        : lower.contains('nintendo')
        ? Icons.videogame_asset_outlined
        : Icons.devices_rounded;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 138),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              platformLabel(game.platformId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.compact = false});

  final GameStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      GameStatus.completed => AppColors.green,
      GameStatus.playing => AppColors.playingBlue,
      GameStatus.dropped => AppColors.red,
    };
    final label = switch (status) {
      GameStatus.completed => 'Concluído',
      GameStatus.playing => 'Jogando',
      GameStatus.dropped => 'Dropado',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 11 : 12,
          height: 1.1,
        ),
      ),
    );
  }
}

class WishlistGameCard extends StatelessWidget {
  const WishlistGameCard({
    required this.game,
    required this.position,
    required this.index,
    required this.draggable,
    required this.selected,
    required this.selectionMode,
    required this.onEdit,
    required this.onOpen,
    required this.onLongPress,
    required this.onDelete,
    super.key,
  });

  final Game game;
  final int position;
  final int index;
  final bool draggable;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onEdit;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected
          ? AppColors.gold.withValues(alpha: .12)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? AppColors.gold.withValues(alpha: .9)
              : theme.colorScheme.outlineVariant.withValues(alpha: .3),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Center(
                  child: Text(
                    '$position',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 62,
                  height: 78,
                  child: GameCoverImage(game: game),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      platformLabel(game.platformId),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if (game.rating != null)
                          _WishlistPill(
                            label: '★ ${game.rating!.toStringAsFixed(1)}',
                            color: AppColors.gold,
                          ),
                        if (game.playtimeMinutes != null)
                          _WishlistPill(
                            label:
                                '${(game.playtimeMinutes! / 60).toStringAsFixed(1)} h',
                            color: theme.colorScheme.secondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selectionMode)
                PopupMenuButton<String>(
                  tooltip: 'Opções do jogo',
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Excluir'),
                      ),
                    ),
                  ],
                ),
              if (selectionMode)
                SizedBox(
                  width: 48,
                  child: Center(
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? AppColors.gold : AppColors.muted,
                    ),
                  ),
                )
              else if (draggable)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    child: Icon(Icons.drag_indicator_rounded),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishlistPill extends StatelessWidget {
  const _WishlistPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
