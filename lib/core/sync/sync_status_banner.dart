import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class SyncStatusBanner extends ConsumerStatefulWidget {
  const SyncStatusBanner({super.key});

  @override
  ConsumerState<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends ConsumerState<SyncStatusBanner> {
  bool _dismissed = false;
  bool _trying = false;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingOperationCountProvider);
    return pending.when(
      data: (count) {
        if (count == 0 || _dismissed) return const SizedBox.shrink();
        final colors = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(AppSpace.radius),
            border: Border.all(color: colors.primary.withValues(alpha: .35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_rounded, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dados não sincronizados',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Suas alterações estão salvas neste dispositivo, mas ainda não foram sincronizadas.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$count ${count == 1 ? 'alteração pendente' : 'alterações pendentes'} · Firebase não configurado',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Fechar aviso',
                    onPressed: () => setState(() => _dismissed = true),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: FilledButton.tonalIcon(
                  onPressed: _trying ? null : _trySync,
                  icon: _trying
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(_trying ? 'Verificando…' : 'Sincronizar agora'),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _trySync() async {
    setState(() => _trying = true);
    String message;
    try {
      await ref.read(syncBackendProvider).syncPendingChanges();
      ref.invalidate(pendingOperationCountProvider);
      message = 'Sincronização concluída.';
    } catch (_) {
      message =
          'Firebase ainda não está configurado. Seus dados seguem salvos neste dispositivo.';
    }
    if (!mounted) return;
    setState(() => _trying = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
