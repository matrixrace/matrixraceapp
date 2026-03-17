import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Serviço centralizado de feedback visual para o usuário.
class FeedbackService {
  static void success(BuildContext context, String message) {
    _show(context, message, AppTheme.primaryGreen, Icons.check_circle_outline);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, const Color(0xFFCF6679), Icons.error_outline);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message, AppTheme.warningOrange, Icons.warning_amber_rounded);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, AppTheme.accentCyan, Icons.info_outline);
  }

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.cardBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
