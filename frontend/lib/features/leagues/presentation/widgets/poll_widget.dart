import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Widget de enquete com barras de progresso
/// Exibe a pergunta, opções, percentuais e permite votar
class PollWidget extends StatelessWidget {
  final Map<String, dynamic> poll;
  final bool canVote;
  final void Function(int optionId) onVote;

  const PollWidget({
    super.key,
    required this.poll,
    required this.canVote,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final question = poll['question'] as String? ?? '';
    final options = (poll['options'] as List?) ?? [];
    final totalVotes = int.tryParse(poll['totalVotes']?.toString() ?? '0') ?? 0;
    final userVoteOptionId = poll['userVoteOptionId'];
    final expiresAt = poll['expires_at'] != null
        ? DateTime.tryParse(poll['expires_at'].toString())
        : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final hasVoted = userVoteOptionId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.poll_outlined, size: 14, color: AppTheme.primaryRed),
            const SizedBox(width: 4),
            const Text('ENQUETE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryRed,
                    letterSpacing: 1)),
            if (isExpired) ...[
              const SizedBox(width: 8),
              const Text('· Encerrada',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ] else if (expiresAt != null) ...[
              const SizedBox(width: 8),
              Text('· Encerra em ${_timeLeft(expiresAt)}',
                  style:
                      const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(question,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...options.map((opt) {
          final optId = opt['id'] as int? ?? 0;
          final optText = opt['text'] as String? ?? '';
          final voteCount =
              int.tryParse(opt['voteCount']?.toString() ?? '0') ?? 0;
          final pct = totalVotes > 0 ? voteCount / totalVotes : 0.0;
          final isSelected = userVoteOptionId != null &&
              userVoteOptionId.toString() == optId.toString();

          return GestureDetector(
            onTap: (!hasVoted && !isExpired && canVote)
                ? () => onVote(optId)
                : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryRed
                      : AppTheme.surfaceColor,
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  children: [
                    // Barra de progresso
                    if (hasVoted || isExpired)
                      Positioned.fill(
                        child: FractionallySizedBox(
                          widthFactor: pct,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            color: isSelected
                                ? AppTheme.primaryRed.withValues(alpha: 0.18)
                                : AppTheme.surfaceColor,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(optText,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ),
                          if (hasVoted || isExpired)
                            Text('${(pct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppTheme.primaryRed
                                        : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Text(
          '$totalVotes ${totalVotes == 1 ? 'voto' : 'votos'}',
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  String _timeLeft(DateTime expires) {
    final diff = expires.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}min';
  }
}
