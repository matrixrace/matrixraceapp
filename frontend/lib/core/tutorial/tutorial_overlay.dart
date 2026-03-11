import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/app_theme.dart';
import 'tutorial_bloc.dart';
import 'tutorial_painter.dart';
import 'tutorial_step.dart';

/// Overlay que mostra o spotlight + tooltip card do tutorial.
/// Deve ser colocado numa Stack acima do body principal.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Obtém o Rect do widget via GlobalKey
  Rect? _getTargetRect(GlobalKey key) {
    final renderObj = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderObj == null || !renderObj.hasSize) return null;
    final offset = renderObj.localToGlobal(Offset.zero);
    return offset & renderObj.size;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TutorialBloc, TutorialState>(
      builder: (context, state) {
        if (!state.isShowingOverlay) return const SizedBox.shrink();

        final step = state.currentStep;
        if (step == null) return const SizedBox.shrink();

        final targetRect = _getTargetRect(step.targetKey);
        if (targetRect == null) {
          // Widget-alvo não encontrado → pula para o próximo step
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.read<TutorialBloc>().add(TutorialNextStep());
          });
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _pulseAnimation,
          targetRect: targetRect,
          step: step,
          state: state,
        );
      },
    );
  }
}

/// Widget separado que escuta a animação de pulsação e reconstrói
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Rect targetRect;
  final TutorialStep step;
  final TutorialState state;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.targetRect,
    required this.step,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      animation: animation,
      builder: (context, _) {
        final screenSize = MediaQuery.of(context).size;

        return Stack(
          children: [
            // 1. Spotlight overlay (fundo escuro + recorte)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => context.read<TutorialBloc>().add(TutorialSkip()),
                child: CustomPaint(
                  painter: TutorialPainter(
                    targetRect: targetRect,
                    pulseValue: animation.value,
                  ),
                ),
              ),
            ),
            // 2. Tooltip card
            _buildTooltipCard(context, screenSize),
          ],
        );
      },
    );
  }

  Widget _buildTooltipCard(BuildContext context, Size screenSize) {
    const tooltipMaxWidth = 320.0;
    const tooltipPadding = 16.0;
    const arrowGap = 12.0;

    // Decide posição vertical
    final bool showAbove;
    if (step.position == TooltipPosition.above) {
      showAbove = targetRect.top > 200;
    } else {
      showAbove = false;
    }

    // Calcula top
    double top;
    if (showAbove) {
      // Acima do target — será posicionado depois via Positioned com bottom
      top = 0; // não usado
    } else {
      top = targetRect.bottom + arrowGap + 8; // 8 = padding do spotlight
    }

    // Calcula left (centralizado com o target, clampado nas bordas)
    double left = targetRect.center.dx - tooltipMaxWidth / 2;
    left = left.clamp(tooltipPadding, screenSize.width - tooltipMaxWidth - tooltipPadding);

    if (showAbove) {
      return Positioned(
        left: left,
        bottom: screenSize.height - targetRect.top + arrowGap,
        child: _TooltipContent(
          step: step,
          state: state,
          maxWidth: tooltipMaxWidth,
        ),
      );
    }

    return Positioned(
      left: left,
      top: top,
      child: _TooltipContent(
        step: step,
        state: state,
        maxWidth: tooltipMaxWidth,
      ),
    );
  }
}

/// Wrapper para AnimatedWidget (renomeado para evitar conflito de nome)
class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  const AnimatedBuilder2({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, null);
}

// ─── Tooltip Content ─────────────────────────────────────────────────────────

class _TooltipContent extends StatelessWidget {
  final TutorialStep step;
  final TutorialState state;
  final double maxWidth;

  const _TooltipContent({
    required this.step,
    required this.state,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStep = state.currentStepIndex >= state.totalSteps - 1;

    return Container(
      width: maxWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: título + step counter
          Row(
            children: [
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.currentStepIndex + 1}/${state.totalSteps}',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Descrição
          Text(
            step.description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Progress dots
          Row(
            children: List.generate(state.totalSteps, (i) {
              final isActive = i == state.currentStepIndex;
              return Container(
                width: isActive ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryGreen
                      : AppTheme.primaryGreen.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Footer: checkbox + botão
          Row(
            children: [
              GestureDetector(
                onTap: () =>
                    context.read<TutorialBloc>().add(TutorialDontShowAgain()),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_box_outline_blank,
                      size: 18,
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Não mostrar mais',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Botão Pular
              TextButton(
                onPressed: () =>
                    context.read<TutorialBloc>().add(TutorialSkip()),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Text('Pular', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 4),
              // Botão Próximo / Entendi
              ElevatedButton(
                onPressed: () =>
                    context.read<TutorialBloc>().add(TutorialNextStep()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isLastStep ? 'Entendi' : 'Próximo',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
