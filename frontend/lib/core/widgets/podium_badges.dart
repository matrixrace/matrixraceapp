import 'package:flutter/material.dart';

/// Exibe ícones de pódio (🥇🥈🥉) com contagem ao lado do nome do usuário.
///
/// Regras:
/// - Posição com count == 0 → não aparece
/// - Posição com count == 1 → só o ícone, sem número
/// - Posição com count >= 2 → número + ícone
/// - Ordem: 🥇 → 🥈 → 🥉
class PodiumBadges extends StatelessWidget {
  final int gold;
  final int silver;
  final int bronze;
  final double fontSize;

  const PodiumBadges({
    super.key,
    required this.gold,
    required this.silver,
    required this.bronze,
    this.fontSize = 13,
  });

  /// Constrói a partir de um Map (vindo da API).
  factory PodiumBadges.fromMap(Map<String, dynamic>? stats, {double fontSize = 13}) {
    return PodiumBadges(
      gold: stats?['gold'] as int? ?? 0,
      silver: stats?['silver'] as int? ?? 0,
      bronze: stats?['bronze'] as int? ?? 0,
      fontSize: fontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (gold == 0 && silver == 0 && bronze == 0) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    void addMedal(int count, String emoji) {
      if (count <= 0) return;
      if (children.isNotEmpty) children.add(const SizedBox(width: 2));
      if (count >= 2) {
        children.add(Text(
          '$count',
          style: TextStyle(fontSize: fontSize - 2, fontWeight: FontWeight.bold),
        ));
      }
      children.add(Text(emoji, style: TextStyle(fontSize: fontSize)));
    }

    addMedal(gold, '🏆');
    addMedal(silver, '🥈');
    addMedal(bronze, '🥉');

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
