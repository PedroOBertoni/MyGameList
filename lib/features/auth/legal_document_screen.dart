import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';

enum LegalDocument { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final isTerms = document == LegalDocument.terms;
    final title = isTerms ? 'Termos de Uso' : 'Política de Privacidade';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Icon(
              isTerms ? Icons.description_outlined : Icons.privacy_tip_outlined,
              size: 44,
              color: AppColors.accent(context),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'O conteúdo oficial deste documento ainda não foi fornecido. Esta página é apenas um aviso de preparação e não representa um documento jurídico concluído. O texto precisa ser fornecido e revisado antes de ser publicado.',
                  style: TextStyle(height: 1.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
