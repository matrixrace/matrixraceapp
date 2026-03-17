import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Como Funciona')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sports_motorsports,
                      color: AppTheme.primaryGreen,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Matrix Race',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Mostre que você entende de F1!\n'
                    'Faça seus palpites, dispute com amigos e prove\n'
                    'que é o maior especialista da grid!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textPrimary.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Seções ──────────────────────────────────────────────
            const _SectionCard(
              icon: Icons.touch_app,
              title: 'Como funcionam os Palpites?',
              body: 'Antes de cada Grande Prêmio, você monta a sua previsão '
                  'arrastando os pilotos na ordem em que acredita que vão '
                  'cruzar a linha de chegada.\n\n'
                  'Quanto mais cedo você travar o palpite, mais pontos pode '
                  'ganhar! Desafie seu conhecimento e mostre que sabe tudo '
                  'sobre a Fórmula 1.',
            ),

            _SectionCard(
              icon: Icons.lock_clock,
              title: 'Tipos de Travamento',
              bodyWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escolha quando travar seu palpite — quanto mais cedo, '
                    'maior a recompensa!',
                    style: TextStyle(
                      color: AppTheme.textPrimary.withValues(alpha: 0.85),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLockRow(
                    'Antes do TL1',
                    'até 20 pts',
                    AppTheme.primaryGreen,
                  ),
                  const SizedBox(height: 8),
                  _buildLockRow(
                    'Antes da Classificação',
                    'até 15 pts',
                    AppTheme.warningOrange,
                  ),
                  const SizedBox(height: 8),
                  _buildLockRow(
                    'Antes da Corrida',
                    'até 10 pts',
                    AppTheme.textSecondary,
                  ),
                ],
              ),
            ),

            _SectionCard(
              icon: Icons.calculate,
              title: 'Sistema de Pontuação',
              bodyWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seus pontos dependem da precisão do palpite:',
                    style: TextStyle(
                      color: AppTheme.textPrimary.withValues(alpha: 0.85),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Pontos = máximo − |posição prevista − posição real|',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: AppTheme.textPrimary.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.6,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Exemplo: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: 'Você previu que o piloto terminaria em P3, '
                              'mas ele chegou em P5. Diferença = 2.\n'
                              'Com trava antes do TL1: 20 − 2 = ',
                        ),
                        TextSpan(
                          text: '18 pontos!',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const _SectionCard(
              icon: Icons.groups,
              title: 'Ligas',
              body: 'Crie ou entre em ligas públicas e privadas para competir '
                  'com seus amigos! Cada liga cobre corridas específicas da '
                  'temporada.\n\n'
                  'Acompanhe o placar da liga e dispute o topo do ranking. '
                  'Quem será o campeão da sua turma?',
            ),

            const _SectionCard(
              icon: Icons.leaderboard,
              title: 'Ranking Global',
              body: 'Além das ligas, existe um ranking global com todos os '
                  'jogadores do Matrix Race. Acompanhe sua posição e veja '
                  'como você se compara com os melhores palpiteiros do mundo!',
            ),

            const _SectionCard(
              icon: Icons.people,
              title: 'Social',
              body: 'Adicione amigos, converse pelo chat privado e participe '
                  'do mural da sua liga. A Fórmula 1 é mais divertida quando '
                  'se disputa junto!',
            ),

            const _SectionCard(
              icon: Icons.flag,
              title: 'Resultados da F1',
              body: 'Consulte os resultados oficiais de cada GP, a classificação '
                  'de pilotos e construtores. Navegue por qualquer temporada '
                  'desde 1950 até hoje!',
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildLockRow(String label, String points, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
          Text(
            points,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? bodyWidget;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.body,
    this.bodyWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (bodyWidget != null)
            bodyWidget!
          else
            Text(
              body!,
              style: TextStyle(
                color: AppTheme.textPrimary.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}
