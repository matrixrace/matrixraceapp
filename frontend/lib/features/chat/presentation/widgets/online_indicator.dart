import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Indicador circular verde de "online"
class OnlineIndicator extends StatelessWidget {
  final double size;

  const OnlineIndicator({super.key, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.successGreen,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.darkBackground,
          width: 2,
        ),
      ),
    );
  }
}
