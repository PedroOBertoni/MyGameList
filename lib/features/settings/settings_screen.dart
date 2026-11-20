import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/game.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../integrations/rawg_attribution_link.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _steamProfilePreferenceKey = 'steam.profile';

  late final TextEditingController _steamProfileController;
  String? _linkedSteamProfile;
  bool _steamProfileLoading = true;
  bool _steamSyncing = false;

  @override
  void initState() {
    super.initState();
    _steamProfileController = TextEditingController();
    unawaited(_loadSteamProfile());
  }

  @override
  void dispose() {
    _steamProfileController.dispose();
    super.dispose();
  }

  Future<void> _loadSteamProfile() async {
    String? savedProfile;
    try {
      final repository = await ref.read(gameRepositoryProvider.future);
      savedProfile = await repository.readPreference(
        _steamProfilePreferenceKey,
      );
      if (savedProfile?.isEmpty ?? false) savedProfile = null;
    } catch (_) {
      // The profile screen remains available if local storage is unavailable.
    }
    if (!mounted) return;
    _steamProfileController.text = savedProfile ?? '';
    setState(() {
      _linkedSteamProfile = savedProfile;
      _steamProfileLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ref.watch(themeControllerProvider);
    final pending = ref.watch(pendingOperationCountProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil e configurações'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .16),
              child: Icon(
                Icons.person_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        children: [
          _sectionHeading(context, 'Neste dispositivo'),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.storage_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Armazenamento local'),
                  subtitle: const Text(
                    'Biblioteca salva offline neste dispositivo',
                  ),
                  trailing: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.green,
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(
                    Icons.sync_problem_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Fila de sincronização'),
                  subtitle: Text(
                    pending.when(
                      data: (count) =>
                          '$count ${count == 1 ? 'operação pendente' : 'operações pendentes'}',
                      loading: () => 'Carregando estado local…',
                      error: (_, _) => 'Não foi possível consultar a fila',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showQueueInfo(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeading(context, 'Conta Steam'),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _steamProfileController,
                    enabled: !_steamSyncing,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Link do perfil ou SteamID64',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use um perfil público ou seu SteamID64. A visibilidade do perfil e dos detalhes dos jogos precisa estar pública.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _steamSyncing || _steamProfileLoading
                        ? null
                        : _syncSteamLibrary,
                    icon: _steamSyncing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      _steamSyncing
                          ? 'Importando biblioteca…'
                          : _linkedSteamProfile == null
                          ? 'Vincular e importar jogos'
                          : 'Sincronizar biblioteca',
                    ),
                  ),
                  if (_linkedSteamProfile != null) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _steamSyncing ? null : _unlinkSteamProfile,
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Desvincular perfil'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeading(context, 'Aparência'),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: ListenableBuilder(
              listenable: themeController,
              builder: (context, _) => SwitchListTile.adaptive(
                secondary: Icon(
                  themeController.mode == ThemeMode.dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Tema escuro'),
                subtitle: Text(
                  themeController.mode == ThemeMode.dark
                      ? 'A paleta noturna está ativa'
                      : 'A paleta clara está ativa',
                ),
                value: themeController.mode == ThemeMode.dark,
                onChanged: (value) => themeController.setMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeading(context, 'Integrações'),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const _IntegrationRow(
                  icon: Icons.cloud_outlined,
                  title: 'Firebase Auth e Firestore',
                  detail:
                      'Dependências preparadas · projeto ainda não configurado',
                  state: 'Pendente',
                ),
                const Divider(height: 1, indent: 58, endIndent: 16),
                const _IntegrationRow(
                  icon: Icons.search_rounded,
                  title: 'RAWG',
                  detail:
                      'Pesquisa direta; configure a chave local para ativar',
                  state: 'Opcional',
                ),
                const Divider(height: 1, indent: 58, endIndent: 16),
                _IntegrationRow(
                  icon: Icons.sports_esports_outlined,
                  title: 'Steam',
                  detail: _steamProfileLoading
                      ? 'Carregando perfil vinculado…'
                      : _linkedSteamProfile == null
                      ? 'Vincule um perfil para importar seus jogos'
                      : 'Perfil vinculado; biblioteca disponível para sincronizar',
                  state: _steamProfileLoading
                      ? 'Carregando'
                      : _linkedSteamProfile == null
                      ? 'Disponível'
                      : 'Vinculada',
                ),
                const Divider(height: 1, indent: 58, endIndent: 16),
                const _IntegrationRow(
                  icon: Icons.gamepad_outlined,
                  title: 'Epic Games',
                  detail: 'Aguardando método oficial suportado',
                  state: 'Pendente',
                ),
              ],
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: RawgAttributionLink(compact: true),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'MyGameList · versão 0.1.0\nA biblioteca fica salva no aparelho; a Steam é usada para importar jogos e horas jogadas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(left: 3, bottom: 9),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
  );

  Future<void> _syncSteamLibrary() async {
    final profile = _steamProfileController.text.trim();
    if (profile.isEmpty) {
      _showMessage('Informe o link do perfil Steam ou o SteamID64.');
      return;
    }

    setState(() => _steamSyncing = true);
    try {
      final importer = ref.read(platformLibraryImporterProvider);
      final steamGames = await importer.previewSteamLibrary(profile);
      final repository = await ref.read(gameRepositoryProvider.future);
      final existingGames = <Game>[
        ...await repository.getGames(GameListType.library),
        ...await repository.getGames(GameListType.wishlist),
      ];
      final existingNames = existingGames
          .map((game) => _normalizeGameName(game.name))
          .where((name) => name.isNotEmpty)
          .toSet();
      final existingSteamIds = existingGames
          .where((game) => game.source == GameSource.steam)
          .map((game) => game.sourceGameId ?? game.externalGameId ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      var importedCount = 0;
      var duplicateCount = 0;
      for (final steamGame in steamGames) {
        final sourceGameId = steamGame.sourceGameId ?? steamGame.externalId;
        if (sourceGameId.isNotEmpty &&
            existingSteamIds.contains(sourceGameId)) {
          duplicateCount++;
          continue;
        }

        final normalizedName = _normalizeGameName(steamGame.name);
        if (normalizedName.isNotEmpty &&
            existingNames.contains(normalizedName)) {
          duplicateCount++;
          continue;
        }

        await repository.saveGame(
          GameDraft(
            name: steamGame.name,
            platformId: 'pc',
            listType: GameListType.library,
            source: GameSource.steam,
            externalGameId: steamGame.externalId,
            sourceGameId: sourceGameId,
            coverUrl: steamGame.coverUrl,
            rating: null,
            playtimeMinutes: steamGame.playtimeMinutes,
            status: GameStatus.completed,
          ),
        );
        importedCount++;
        if (sourceGameId.isNotEmpty) existingSteamIds.add(sourceGameId);
      }

      await repository.writePreference(_steamProfilePreferenceKey, profile);
      if (!mounted) return;
      setState(() => _linkedSteamProfile = profile);
      ref.invalidate(gamesProvider(GameListType.library));
      ref.invalidate(gamesProvider(GameListType.wishlist));
      ref.invalidate(pendingOperationCountProvider);

      final message = steamGames.isEmpty
          ? 'Perfil vinculado, mas nenhum jogo ficou visível. Confira a privacidade dos jogos na Steam.'
          : 'Importados $importedCount jogos; $duplicateCount já estavam nas suas listas.';
      _showMessage(message);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _steamSyncing = false);
    }
  }

  Future<void> _unlinkSteamProfile() async {
    try {
      final repository = await ref.read(gameRepositoryProvider.future);
      await repository.writePreference(_steamProfilePreferenceKey, '');
      if (!mounted) return;
      _steamProfileController.clear();
      setState(() => _linkedSteamProfile = null);
      _showMessage(
        'Perfil Steam desvinculado. Os jogos importados foram mantidos.',
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showQueueInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alterações salvas localmente',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'A fila guarda a última operação pendente por jogo. Ela não é limpa ao fechar o aviso nem quando não há servidor conectado.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Firebase ainda não está configurado; nenhuma operação foi removida.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Verificar sincronização'),
            ),
          ],
        ),
      ),
    );
  }
}

String _normalizeGameName(String value) {
  var normalized = value.trim().toLowerCase();
  const accentGroups = <String, String>{
    'áàâãä': 'a',
    'éèêë': 'e',
    'íìîï': 'i',
    'óòôõö': 'o',
    'úùûü': 'u',
    'ç': 'c',
    'ñ': 'n',
    'ýÿ': 'y',
  };
  for (final entry in accentGroups.entries) {
    for (final character in entry.key.split('')) {
      normalized = normalized.replaceAll(character, entry.value);
    }
  }
  return normalized.replaceAll(RegExp(r'[\s\-_–—:;,.!]+'), '');
}

class _IntegrationRow extends StatelessWidget {
  const _IntegrationRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.state,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String state;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(detail),
    trailing: Text(
      state,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
