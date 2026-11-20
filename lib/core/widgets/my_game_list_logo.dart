import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

class MyGameListLogo extends StatelessWidget {
  const MyGameListLogo({this.iconSize = 34, this.fontSize = 22, super.key});

  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.sports_esports_rounded, size: iconSize, color: AppColors.gold),
      SizedBox(width: iconSize * .24),
      RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: fontSize,
            letterSpacing: .1,
            fontWeight: FontWeight.w900,
          ),
          children: const [
            TextSpan(
              text: 'MyGame',
              style: TextStyle(color: AppColors.white),
            ),
            TextSpan(
              text: 'List',
              style: TextStyle(color: AppColors.gold),
            ),
          ],
        ),
      ),
    ],
  );
}
