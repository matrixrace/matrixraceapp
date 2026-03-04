import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Indicador "digitando..." com animação de 3 pontos
class TypingIndicator extends StatefulWidget {
  final String? userName;

  const TypingIndicator({super.key, this.userName});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.userName != null
        ? '${widget.userName} está digitando'
        : 'digitando';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i * 0.2;
                  final value = (_controller.value - delay).clamp(0.0, 1.0);
                  final opacity = (0.3 + 0.7 * _bounce(value));
                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Opacity(
                      opacity: opacity,
                      child: const Text(
                        '.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  double _bounce(double t) {
    if (t < 0.5) return 2 * t;
    return 2 * (1 - t);
  }
}
