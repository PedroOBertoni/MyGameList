import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../integrations/rawg_attribution_link.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: const Column(
              children: [
                _IntegrationRow(
                  icon: Icons.cloud_outlined,
                  title: 'Firebase Auth e Firestore',
                  detail:
                      'Dependências preparadas · projeto ainda não configurado',
                  state: 'Pendente',
                ),
                Divider(height: 1, indent: 58, endIndent: 16),
                _IntegrationRow(
                  icon: Icons.search_rounded,
                  title: 'RAWG',
                  detail:
                      'Pesquisa direta; configure a chave local para ativar',
                  state: 'Opcional',
                ),
                Divider(height: 1, indent: 58, endIndent: 16),
                _IntegrationRow(
                  icon: Icons.sports_esports_outlined,
                  title: 'Steam',
                  detail: 'Importação com prévia a implementar',
                  state: 'Pendente',
                ),
                Divider(height: 1, indent: 58, endIndent: 16),
                _IntegrationRow(
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
              'MyGameList · versão 0.1.0\nSeus dados permanecem no aparelho até uma sincronização real ser configurada.',
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
