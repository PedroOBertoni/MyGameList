import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/game.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/game_cover_image.dart';
import '../integrations/rawg_attribution_link.dart';

class GameDetailScreen extends ConsumerWidget {
  const GameDetailScreen({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameProvider(gameId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do jogo')),
      body: gameAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Não foi possível carregar este jogo.')),
        data: (game) => game == null
            ? const Center(child: Text('Este jogo não está disponível.'))
            : _content(context, ref, game),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, Game game) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 220,
          child: GameCoverImage(
            game: game,
            placeholderIconSize: 68,
            placeholderColor: Theme.of(context).colorScheme.surface,
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        game.name,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          Chip(
            avatar: const Icon(Icons.devices_rounded, size: 16),
            label: Text(platformLabel(game.platformId)),
          ),
          if (game.status != null)
            Chip(
              avatar: const Icon(Icons.flag_outlined, size: 16),
              label: Text(game.status!.label),
            ),
          Chip(
            avatar: const Icon(Icons.folder_outlined, size: 16),
            label: Text(game.listType.label),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _detail(
        context,
        'Nota',
        game.rating?.toStringAsFixed(1) ?? 'Não informada',
        Icons.star_outline_rounded,
      ),
      _detail(
        context,
        'Horas jogadas',
        game.playtimeMinutes == null
            ? 'Não informadas'
            : '${(game.playtimeMinutes! / 60).toStringAsFixed(1)} h',
        Icons.schedule_rounded,
      ),
      _detail(
        context,
        'Data de início',
        _date(game.startDate),
        Icons.play_arrow_rounded,
      ),
      _detail(
        context,
        'Data de conclusão',
        _date(game.completionDate),
        Icons.check_circle_outline_rounded,
      ),
      _detail(context, 'Origem', game.source.label, Icons.source_outlined),
      if (game.source == GameSource.rawg)
        Align(
          alignment: Alignment.centerLeft,
          child: RawgAttributionLink(gameSlug: game.sourceGameId),
        ),
      _detail(
        context,
        'Criado',
        DateFormat('dd/MM/yyyy').format(game.createdAt.toLocal()),
        Icons.event_note_rounded,
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => context.push('/games/${game.id}/edit'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Editar jogo'),
      ),
      if (game.listType == GameListType.wishlist) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _moveToLibrary(context, ref, game),
          icon: const Icon(Icons.library_add_outlined),
          label: const Text('Mover para biblioteca'),
        ),
      ],
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: () => _delete(context, ref, game),
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Excluir jogo'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
      ),
    ],
  );

  Widget _detail(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  String _date(DateTime? date) => date == null
      ? 'Não informada'
      : DateFormat('dd/MM/yyyy').format(date.toLocal());

  Future<void> _moveToLibrary(
    BuildContext context,
    WidgetRef ref,
    Game game,
  ) async {
    GameStatus? selected;
    final result = await showDialog<GameStatus>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adicionar à biblioteca'),
          content: RadioGroup<GameStatus>(
            groupValue: selected,
            onChanged: (value) => setDialogState(() => selected = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Escolha o status atual deste jogo.'),
                const SizedBox(height: 8),
                ...GameStatus.values.map(
                  (status) => RadioListTile<GameStatus>(
                    value: status,
                    title: Text(status.label),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(context, selected),
              child: const Text('Mover'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final repository = await ref.read(gameRepositoryProvider.future);
    await repository.moveToLibrary(game.id, result);
    ref.invalidate(gamesProvider);
    ref.invalidate(gameProvider(game.id));
    ref.invalidate(pendingOperationCountProvider);
    if (context.mounted) context.go('/library');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Game game) async {
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
    final repository = await ref.read(gameRepositoryProvider.future);
    await repository.deleteGame(game.id);
    ref.invalidate(gamesProvider);
    ref.invalidate(gameProvider(game.id));
    ref.invalidate(pendingOperationCountProvider);
    if (context.mounted) {
      context.go(
        game.listType == GameListType.wishlist ? '/wishlist' : '/library',
      );
    }
  }
}
