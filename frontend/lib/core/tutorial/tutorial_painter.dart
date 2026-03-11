import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pinta a tela inteira com fundo escuro semi-transparente e recorta um
/// retângulo arredondado na posição do widget-alvo (spotlight).
class TutorialPainter extends CustomPainter {
  final Rect targetRect;
  final double borderRadius;
  final double pulseValue; // 0..1 para animação de pulsação da borda

  TutorialPainter({
    required this.targetRect,
    this.borderRadius = 12,
    this.pulseValue = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Salva o canvas para usar saveLayer + BlendMode.clear
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Fundo escuro cobrindo tudo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );

    // Rect expandido com padding para o spotlight
    final padding = 8.0;
    final spotlightRect = targetRect.inflate(padding);

    // 2. Recorta o spotlight (apaga o fundo escuro na região do target)
    final rrect = RRect.fromRectAndRadius(
      spotlightRect,
      Radius.circular(borderRadius + 4),
    );
    canvas.drawRRect(
      rrect,
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();

    // 3. Borda verde ao redor do spotlight (com pulsação)
    final borderOpacity = 0.4 + (pulseValue * 0.4); // 0.4 → 0.8
    final borderWidth = 2.0 + (pulseValue * 1.0); // 2 → 3
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppTheme.primaryGreen.withValues(alpha: borderOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  bool shouldRepaint(TutorialPainter oldDelegate) =>
      targetRect != oldDelegate.targetRect ||
      pulseValue != oldDelegate.pulseValue;
}
