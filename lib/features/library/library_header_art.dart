import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/my_game_list_logo.dart';

class LibraryHeaderArt extends StatelessWidget {
  const LibraryHeaderArt({
    required this.title,
    required this.subtitle,
    required this.onAdd,
    this.onAddLongPress,
    this.useImageBackground = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onAdd;
  final VoidCallback? onAddLongPress;
  final bool useImageBackground;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 174,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (useImageBackground)
          Image.asset(
            'assets/images/img_fundo.webp',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          )
        else
          const ColoredBox(color: AppColors.ink),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.ink.withValues(alpha: .82),
                AppColors.ink.withValues(alpha: .48),
                AppColors.ink.withValues(alpha: .15),
              ],
              stops: const [0, .54, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.ink.withValues(alpha: .16),
                AppColors.ink.withValues(alpha: .08),
                AppColors.ink.withValues(alpha: .96),
              ],
              stops: const [0, .56, 1],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 320;
                  return Row(
                    children: [
                      MyGameListLogo(
                        iconSize: compact ? 28 : 34,
                        fontSize: compact ? 18 : 22,
                      ),
                      const Expanded(child: SizedBox.shrink()),
                      Tooltip(
                        message: onAddLongPress == null
                            ? 'Adicionar jogo'
                            : 'Toque para adicionar; segure para ordenar desejos',
                        child: Material(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(
                            AppSpace.buttonRadius,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppSpace.buttonRadius,
                            ),
                            onTap: onAdd,
                            onLongPress: onAddLongPress,
                            child: const SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(
                                Icons.add_rounded,
                                size: 28,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: .35),
                          blurRadius: 5,
                          spreadRadius: -1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontSize: 30,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.white.withValues(alpha: .8),
                                fontSize: 15,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
