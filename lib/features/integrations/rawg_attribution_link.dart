import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class RawgAttributionLink extends StatelessWidget {
  const RawgAttributionLink({this.compact = false, this.gameSlug, super.key});

  final bool compact;
  final String? gameSlug;

  Future<void> _open(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(
        gameSlug == null
            ? 'https://rawg.io'
            : 'https://rawg.io/games/$gameSlug',
      ),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir rawg.io neste dispositivo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: 'Dados e imagens fornecidos pela RAWG. Abrir rawg.io',
    child: InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          compact ? 'RAWG ↗' : 'Dados e imagens: RAWG ↗',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    ),
  );
}
