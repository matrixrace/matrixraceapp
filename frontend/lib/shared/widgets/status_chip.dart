import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Chip de status acessível — sempre com ícone + texto.
class StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double fontSize;

  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.fontSize = 11,
  });

  /// Corrida ativa / em andamento
  factory StatusChip.active({String label = 'Ativa'}) => StatusChip(
        label: label,
        icon: Icons.circle,
        color: AppTheme.primaryGreen,
      );

  /// Corrida encerrada / completada
  factory StatusChip.completed({String label = 'Encerrada'}) => StatusChip(
        label: label,
        icon: Icons.check_circle_outline,
        color: AppTheme.textSecondary,
      );

  /// Sessão ao vivo
  factory StatusChip.live({String label = 'AO VIVO'}) => StatusChip(
        label: label,
        icon: Icons.sensors,
        color: AppTheme.primaryGreen,
      );

  /// Pendente
  factory StatusChip.pending({String label = 'Pendente'}) => StatusChip(
        label: label,
        icon: Icons.schedule,
        color: AppTheme.warningOrange,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: AppTheme.chipDecoration(color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip para compound de pneu com cor temática.
class TireChip extends StatelessWidget {
  final String compound;
  final double size;

  const TireChip({
    super.key,
    required this.compound,
    this.size = 24,
  });

  static const Map<String, ({Color color, String abbr, String name})> _tires = {
    'SOFT':    (color: Color(0xFFEF4444), abbr: 'S', name: 'Soft'),
    'S':       (color: Color(0xFFEF4444), abbr: 'S', name: 'Soft'),
    'MEDIUM':  (color: Color(0xFFFBBF24), abbr: 'M', name: 'Medium'),
    'M':       (color: Color(0xFFFBBF24), abbr: 'M', name: 'Medium'),
    'HARD':    (color: Color(0xFFF1F5F9), abbr: 'H', name: 'Hard'),
    'H':       (color: Color(0xFFF1F5F9), abbr: 'H', name: 'Hard'),
    'INTERMEDIATE': (color: Color(0xFF22C55E), abbr: 'I', name: 'Inter'),
    'I':       (color: Color(0xFF22C55E), abbr: 'I', name: 'Inter'),
    'WET':     (color: Color(0xFF3B82F6), abbr: 'W', name: 'Wet'),
    'W':       (color: Color(0xFF3B82F6), abbr: 'W', name: 'Wet'),
  };

  @override
  Widget build(BuildContext context) {
    final upper = compound.toUpperCase();
    final tire = _tires[upper] ??
        (color: AppTheme.textSecondary, abbr: compound.substring(0, 1).toUpperCase(), name: compound);

    return Tooltip(
      message: tire.name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tire.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: tire.color, width: 1.5),
        ),
        child: Center(
          child: Text(
            tire.abbr,
            style: TextStyle(
              color: tire.color,
              fontSize: size * 0.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
