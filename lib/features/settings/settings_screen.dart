import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  String? _linkedSteamProfile;
  bool _steamProfileLoading = true;
  bool _steamSyncing = false;
  bool _creatingAccount = false;
  bool _authBusy = false;

  @override
  void initState() {
    super.initState();
    _steamProfileController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    unawaited(_loadSteamProfile());
  }

  @override
  void dispose() {
    _steamProfileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
    ref.listen(authStateProvider, (previous, next) {
      if (previous?.asData?.value?.uid != next.asData?.value?.uid) {
        unawaited(_loadSteamProfile());
      }
    });
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
          _sectionHeading(context, 'Conta MyGameList'),
          _accountCard(context),
          const SizedBox(height: 20),
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
                _IntegrationRow(
                  icon: Icons.cloud_outlined,
                  title: 'Firebase Auth e Firestore',
                  detail: !ref.watch(firebaseInitializedProvider)
                      ? 'Configuração Firebase indisponível neste dispositivo'
                      : ref.watch(authStateProvider).asData?.value == null
                      ? 'Faça login para sincronizar sua biblioteca'
                      : 'Conta conectada; sincronização automática ativa',
                  state: !ref.watch(firebaseInitializedProvider)
                      ? 'Offline'
                      : ref.watch(authStateProvider).asData?.value == null
                      ? 'Login'
                      : 'Conectado',
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

  Widget _accountCard(BuildContext context) {
    if (!ref.watch(firebaseInitializedProvider)) {
      return Card(
        color: Theme.of(context).colorScheme.surface,
        child: const ListTile(
          leading: Icon(Icons.cloud_off_rounded),
          title: Text('Firebase não inicializado'),
          subtitle: Text(
            'Os jogos continuam disponíveis localmente. Confira a configuração Android do Firebase.',
          ),
        ),
      );
    }

    return ref
        .watch(authStateProvider)
        .when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, _) => const Card(
            child: ListTile(
              leading: Icon(Icons.error_outline_rounded),
              title: Text('Não foi possível consultar a conta Firebase'),
            ),
          ),
          data: (user) => Card(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: user == null
                  ? _accountForm(context)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.verified_user_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(user.email ?? 'Conta conectada'),
                          subtitle: const Text(
                            'Sua biblioteca será sincronizada com esta conta.',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _authBusy ? null : _signOut,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Sair da conta'),
                        ),
                      ],
                    ),
            ),
          ),
        );
  }

  Widget _accountForm(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _creatingAccount
            ? 'Crie sua conta para guardar seus dados na nuvem.'
            : 'Entre para sincronizar seus jogos e acessar sua biblioteca em outros dispositivos.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _emailController,
        enabled: !_authBusy,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
          labelText: 'E-mail',
          prefixIcon: Icon(Icons.email_outlined),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _passwordController,
        enabled: !_authBusy,
        obscureText: true,
        textInputAction: TextInputAction.done,
        autofillHints: _creatingAccount
            ? const [AutofillHints.newPassword]
            : const [AutofillHints.password],
        onSubmitted: (_) => _submitAccount(),
        decoration: const InputDecoration(
          labelText: 'Senha',
          prefixIcon: Icon(Icons.lock_outline_rounded),
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _authBusy ? null : _submitAccount,
        icon: _authBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_creatingAccount ? Icons.person_add_alt_1 : Icons.login),
        label: Text(
          _authBusy
              ? 'Aguarde…'
              : _creatingAccount
              ? 'Criar conta'
              : 'Entrar',
        ),
      ),
      Align(
        alignment: Alignment.center,
        child: TextButton(
          onPressed: _authBusy
              ? null
              : () => setState(() => _creatingAccount = !_creatingAccount),
          child: Text(
            _creatingAccount ? 'Já tenho uma conta' : 'Ainda não tenho conta',
          ),
        ),
      ),
    ],
  );

  Future<void> _submitAccount() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@')) {
      _showMessage('Informe um e-mail válido.');
      return;
    }
    if (password.length < 6) {
      _showMessage('A senha precisa ter pelo menos 6 caracteres.');
      return;
    }

    setState(() => _authBusy = true);
    try {
      final gateway = ref.read(authGatewayProvider);
      if (_creatingAccount) {
        await gateway.createAccountWithEmail(email, password);
        _showMessage('Conta criada. Iniciando sincronização da biblioteca.');
      } else {
        await gateway.signInWithEmail(email, password);
        _showMessage('Login realizado. Sincronizando sua biblioteca.');
      }
    } catch (error) {
      if (mounted) _showMessage(_authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _authBusy = true);
    try {
      await ref.read(authGatewayProvider).signOut(preserveLocalData: true);
      if (mounted) {
        _showMessage('Sessão encerrada. Os dados locais foram mantidos.');
      }
    } catch (error) {
      if (mounted) _showMessage(_authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  String _authErrorMessage(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Não foi possível acessar a conta.';
    }
    return switch (error.code) {
      'email-already-in-use' => 'Este e-mail já possui uma conta.',
      'invalid-email' => 'O formato do e-mail é inválido.',
      'weak-password' => 'Escolha uma senha mais forte.',
      'operation-not-allowed' =>
        'Habilite o provedor E-mail/senha nas configurações do Firebase Auth.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'E-mail ou senha incorretos.',
      'network-request-failed' =>
        'Sem conexão. Tente novamente quando estiver online.',
      'too-many-requests' =>
        'Muitas tentativas. Aguarde um pouco e tente novamente.',
      _ => 'Não foi possível acessar a conta. (${error.code})',
    };
  }

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
              'As alterações ficam salvas neste aparelho. Entre na sua conta para sincronizá-las com a nuvem.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                if (!ref.read(firebaseInitializedProvider)) {
                  _showMessage(
                    'Firebase não está disponível neste dispositivo.',
                  );
                  return;
                }
                if (ref.read(authStateProvider).asData?.value == null) {
                  _showMessage('Entre na sua conta para sincronizar os dados.');
                  return;
                }
                try {
                  await syncCurrentAccountFromWidgetRef(ref);
                  if (mounted) _showMessage('Sincronização concluída.');
                } catch (_) {
                  if (mounted) {
                    _showMessage(
                      'Falha na sincronização. Os dados locais foram mantidos.',
                    );
                  }
                }
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
