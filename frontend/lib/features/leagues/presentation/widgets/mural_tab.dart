import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/theme/app_theme.dart';
import 'league_post_card.dart';

/// Aba Mural da área da liga
/// Exibe: Próxima corrida, Melhor da Rodada, feed de posts e enquetes
class MuralTab extends StatefulWidget {
  final String leagueId;
  final String myUserId;
  final bool isOwner;
  final bool canPost; // baseado em post_mode

  const MuralTab({
    super.key,
    required this.leagueId,
    required this.myUserId,
    required this.isOwner,
    required this.canPost,
  });

  @override
  State<MuralTab> createState() => _MuralTabState();
}

class _MuralTabState extends State<MuralTab>
    with AutomaticKeepAliveClientMixin {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _posts = [];
  Map<String, dynamic>? _highlights;
  bool _isLoading = true;
  final TextEditingController _postController = TextEditingController();
  bool _isSending = false;

  // Para criação de enquete
  bool _showPollForm = false;
  final TextEditingController _pollQuestion = TextEditingController();
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _postController.dispose();
    _pollQuestion.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _api.get('/leagues/${widget.leagueId}/posts'),
      _api.get('/leagues/${widget.leagueId}/highlights'),
    ]);
    if (!mounted) return;
    setState(() {
      _posts = results[0].success && results[0].data != null
          ? (results[0].data as List)
              .map((p) => p as Map<String, dynamic>)
              .toList()
          : [];
      _highlights =
          results[1].success && results[1].data != null
              ? results[1].data as Map<String, dynamic>
              : null;
      _isLoading = false;
    });
  }

  Future<void> _submitPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSending = true);
    final res = await _api.post(
      '/leagues/${widget.leagueId}/posts',
      body: {'type': 'text', 'content': content},
    );
    if (res.success && res.data != null && mounted) {
      _postController.clear();
      setState(() {
        _posts.insert(0, res.data as Map<String, dynamic>);
        _isSending = false;
      });
    } else {
      setState(() => _isSending = false);
    }
  }

  Future<void> _submitPoll() async {
    final question = _pollQuestion.text.trim();
    final options =
        _pollOptions.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Preencha a pergunta e ao menos 2 opções')),
      );
      return;
    }
    setState(() => _isSending = true);
    final res = await _api.post(
      '/leagues/${widget.leagueId}/posts',
      body: {'type': 'poll', 'poll': {'question': question, 'options': options}},
    );
    if (res.success && res.data != null && mounted) {
      _pollQuestion.clear();
      for (final c in _pollOptions) {
        c.clear();
      }
      setState(() {
        _posts.insert(0, res.data as Map<String, dynamic>);
        _isSending = false;
        _showPollForm = false;
      });
    } else {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ── Card: Próxima Corrida ──────────────────────────
          if (_highlights?['nextRace'] != null)
            _NextRaceCard(
              race: _highlights!['nextRace'] as Map<String, dynamic>,
              leagueId: widget.leagueId,
            ),

          // ── Card: Melhor da Rodada ─────────────────────────
          if (_highlights?['bestLastRace'] != null)
            _BestRaceCard(
              best: _highlights!['bestLastRace'] as Map<String, dynamic>,
            ),

          // ── Campo de criar post ────────────────────────────
          if (widget.canPost) ...[
            if (!_showPollForm)
              _buildPostInput()
            else
              _buildPollForm(),
          ],

          // ── Feed de posts ──────────────────────────────────
          if (_posts.isEmpty && !widget.canPost)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.article_outlined,
                        size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 8),
                    Text('Nenhum post ainda.',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ..._posts.map((post) => LeaguePostCard(
                  post: post,
                  leagueId: widget.leagueId,
                  myUserId: widget.myUserId,
                  isOwner: widget.isOwner,
                  onDeleted: () {
                    setState(() => _posts.removeWhere((p) => p['id'] == post['id']));
                  },
                  onUpdated: (updated) {
                    final idx = _posts.indexWhere((p) => p['id'] == updated['id']);
                    if (idx >= 0) setState(() => _posts[idx] = updated);
                  },
                )),
        ],
      ),
    );
  }

  Widget _buildPostInput() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _postController,
              decoration: const InputDecoration(
                hintText: 'O que você pensa?',
                hintStyle: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                border: InputBorder.none,
                isDense: true,
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          Column(
            children: [
              if (widget.isOwner)
                IconButton(
                  icon: const Icon(Icons.poll_outlined,
                      color: AppTheme.textSecondary, size: 20),
                  tooltip: 'Criar enquete',
                  onPressed: () => setState(() => _showPollForm = true),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded,
                        color: AppTheme.primaryRed, size: 20),
                onPressed: _isSending ? null : _submitPost,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPollForm() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.primaryRed.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nova Enquete',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _pollQuestion,
            decoration: const InputDecoration(
              labelText: 'Pergunta',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          ..._pollOptions.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: e.value,
                  decoration: InputDecoration(
                    labelText: 'Opção ${e.key + 1}',
                    isDense: true,
                  ),
                ),
              )),
          if (_pollOptions.length < 4)
            TextButton.icon(
              onPressed: () {
                setState(() => _pollOptions.add(TextEditingController()));
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar opção'),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showPollForm = false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSending ? null : _submitPoll,
                child: const Text('Publicar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card da Próxima Corrida ──────────────────────────────────────
class _NextRaceCard extends StatefulWidget {
  final Map<String, dynamic> race;
  final String leagueId;

  const _NextRaceCard({required this.race, required this.leagueId});

  @override
  State<_NextRaceCard> createState() => _NextRaceCardState();
}

class _NextRaceCardState extends State<_NextRaceCard> {
  late Duration _timeLeft;
  late DateTime _lockDate;

  @override
  void initState() {
    super.initState();
    final fp1 = widget.race['fp1_date'] != null
        ? DateTime.tryParse(widget.race['fp1_date'].toString())
        : null;
    final quali = widget.race['qualifying_date'] != null
        ? DateTime.tryParse(widget.race['qualifying_date'].toString())
        : null;
    final race = DateTime.tryParse(widget.race['race_date'].toString()) ??
        DateTime.now();
    _lockDate = fp1 ?? quali ?? race;
    _timeLeft = _lockDate.difference(DateTime.now());
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _timeLeft = _lockDate.difference(DateTime.now()));
      _tick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.race['name'] as String? ?? '';
    final round = widget.race['round'] as int? ?? 0;
    final d = _timeLeft.isNegative ? Duration.zero : _timeLeft;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.primaryRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 14, color: AppTheme.primaryRed),
              const SizedBox(width: 6),
              Text('PRÓXIMA CORRIDA · R$round',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(name,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Countdown
              Row(
                children: [
                  _CountdownUnit(value: d.inDays, label: 'd'),
                  _Separator(),
                  _CountdownUnit(value: d.inHours % 24, label: 'h'),
                  _Separator(),
                  _CountdownUnit(value: d.inMinutes % 60, label: 'm'),
                  _Separator(),
                  _CountdownUnit(value: d.inSeconds % 60, label: 's'),
                ],
              ),
              _buildPredictionButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionButton(BuildContext context) {
    final hasPrediction = widget.race['has_prediction'] == true;
    final predictionApplied = widget.race['prediction_applied'] == true;

    if (predictionApplied) {
      return OutlinedButton.icon(
        onPressed: () => context.push('/predictions-view/${widget.race['id']}'),
        icon: const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
        label: const Text('Aplicado', style: TextStyle(fontSize: 12, color: Colors.green)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: const BorderSide(color: Colors.green),
        ),
      );
    }

    if (hasPrediction) {
      return OutlinedButton.icon(
        onPressed: () => context.push('/predictions-view/${widget.race['id']}'),
        icon: const Icon(Icons.visibility_outlined, size: 14),
        label: const Text('Ver palpite', style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => context.push('/predictions/${widget.race['id']}'),
      icon: const Icon(Icons.edit_outlined, size: 14),
      label: const Text('Palpitar', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  final int value;
  final String label;
  const _CountdownUnit({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value.toString().padLeft(2, '0'),
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryRed)),
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(':',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary)),
    );
  }
}

// ── Card Melhor da Rodada ────────────────────────────────────────
class _BestRaceCard extends StatelessWidget {
  final Map<String, dynamic> best;
  const _BestRaceCard({required this.best});

  @override
  Widget build(BuildContext context) {
    final name = best['display_name'] as String? ?? '';
    final avatar = best['avatar_url'] as String?;
    final points = best['points'] as int? ?? 0;
    final raceName = best['race_name'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MELHOR DA RODADA',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(raceName,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.surfaceColor,
            backgroundImage:
                avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppTheme.primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 11))
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text('$points pts',
                  style: const TextStyle(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
