import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = <({IconData icon, String label})>[
    (icon: Icons.sports_esports_outlined, label: 'Biblioteca'),
    (icon: Icons.favorite_border_rounded, label: 'Desejos'),
    (icon: Icons.person_outline_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(
            top: BorderSide(
              color: AppColors.blue.withValues(alpha: .62),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: .12),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              for (var index = 0; index < _destinations.length; index++)
                Expanded(
                  child: _NavigationItem(
                    icon: _destinations[index].icon,
                    label: _destinations[index].label,
                    selected: selectedIndex == index,
                    onTap: () => onDestinationSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const inactive = AppColors.muted;
    final color = selected ? AppColors.gold : inactive;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(selected),
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: selected ? 40 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: selected ? AppColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: .62),
                            blurRadius: 8,
                            spreadRadius: .5,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
