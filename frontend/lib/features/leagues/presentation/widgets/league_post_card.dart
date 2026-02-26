import 'package:flutter/material.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/theme/app_theme.dart';
import 'poll_widget.dart';

/// Card de post do mural da liga
/// Suporta tipo 'text' e 'poll'
class LeaguePostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String leagueId;
  final String myUserId;
  final bool isOwner;
  final VoidCallback onDeleted;
  final void Function(Map<String, dynamic> updatedPost) onUpdated;

  const LeaguePostCard({
    super.key,
    required this.post,
    required this.leagueId,
    required this.myUserId,
    required this.isOwner,
    required this.onDeleted,
    required this.onUpdated,
  });

  @override
  State<LeaguePostCard> createState() => _LeaguePostCardState();
}

class _LeaguePostCardState extends State<LeaguePostCard> {
  final ApiClient _api = ApiClient();
  bool _showComments = false;
  List<dynamic> _comments = [];
  bool _loadingComments = false;
  final TextEditingController _commentController = TextEditingController();

  late Map<String, dynamic> _post;

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final res = await _api.post(
        '/leagues/${widget.leagueId}/posts/${_post['id']}/like', body: {});
    if (res.success && mounted) {
      final liked = res.data?['liked'] as bool? ?? false;
      setState(() {
        _post['user_liked'] = liked;
        final count = int.tryParse(_post['likes_count']?.toString() ?? '0') ?? 0;
        _post['likes_count'] = liked ? count + 1 : count - 1;
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    final res = await _api
        .get('/leagues/${widget.leagueId}/posts/${_post['id']}/comments');
    if (mounted) {
      setState(() {
        _comments = res.success && res.data != null ? (res.data as List) : [];
        _loadingComments = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    _commentController.clear();
    final res = await _api.post(
      '/leagues/${widget.leagueId}/posts/${_post['id']}/comments',
      body: {'content': content},
    );
    if (res.success && res.data != null && mounted) {
      setState(() {
        _comments.add(res.data);
        final count =
            int.tryParse(_post['comments_count']?.toString() ?? '0') ?? 0;
        _post['comments_count'] = count + 1;
      });
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Apagar post'),
        content: const Text('Tem certeza que deseja apagar este post?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar',
                  style: TextStyle(color: AppTheme.primaryRed))),
        ],
      ),
    );
    if (confirm != true) return;
    await _api
        .delete('/leagues/${widget.leagueId}/posts/${_post['id']}');
    widget.onDeleted();
  }

  Future<void> _vote(int optionId) async {
    final res = await _api.post(
      '/leagues/${widget.leagueId}/polls/${_post['poll']['id']}/vote',
      body: {'optionId': optionId},
    );
    if (res.success && res.data != null && mounted) {
      setState(() {
        _post['poll'] = {
          ..._post['poll'] as Map<String, dynamic>,
          'options': res.data['options'],
          'totalVotes': res.data['totalVotes'],
          'userVoteOptionId': res.data['userVoteOptionId'],
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorName = _post['author_name'] as String? ?? 'Usuário';
    final authorAvatar = _post['author_avatar'] as String?;
    final content = _post['content'] as String? ?? '';
    final type = _post['type'] as String? ?? 'text';
    final isPinned = _post['is_pinned'] == true;
    final userLiked = _post['user_liked'] == true;
    final likesCount =
        int.tryParse(_post['likes_count']?.toString() ?? '0') ?? 0;
    final commentsCount =
        int.tryParse(_post['comments_count']?.toString() ?? '0') ?? 0;
    final createdAt = _post['created_at'] != null
        ? DateTime.tryParse(_post['created_at'].toString())
        : null;
    final isAuthor = _post['user_id'] == widget.myUserId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: isPinned
            ? Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do post
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.surfaceColor,
                  backgroundImage: authorAvatar != null
                      ? NetworkImage(authorAvatar)
                      : null,
                  child: authorAvatar == null
                      ? Text(authorName[0].toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 12))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(authorName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          if (isPinned) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.push_pin,
                                size: 12, color: AppTheme.primaryRed),
                          ],
                        ],
                      ),
                      if (createdAt != null)
                        Text(_formatDate(createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                if (isAuthor || widget.isOwner)
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: AppTheme.textSecondary),
                    onPressed: _deletePost,
                    tooltip: 'Apagar post',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Conteúdo do post
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: type == 'poll' && _post['poll'] != null
                ? PollWidget(
                    poll: _post['poll'] as Map<String, dynamic>,
                    canVote: true,
                    onVote: _vote,
                  )
                : Text(content,
                    style: const TextStyle(fontSize: 14, height: 1.45)),
          ),

          // Ações: curtir e comentar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _toggleLike,
                  icon: Icon(
                    userLiked ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: userLiked ? AppTheme.primaryRed : AppTheme.textSecondary,
                  ),
                  label: Text('$likesCount',
                      style: TextStyle(
                          fontSize: 12,
                          color: userLiked
                              ? AppTheme.primaryRed
                              : AppTheme.textSecondary)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4)),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showComments = !_showComments);
                    if (_showComments && _comments.isEmpty) _loadComments();
                  },
                  icon: const Icon(Icons.chat_bubble_outline,
                      size: 16, color: AppTheme.textSecondary),
                  label: Text('$commentsCount',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4)),
                ),
              ],
            ),
          ),

          // Seção de comentários
          if (_showComments) ...[
            const Divider(height: 1),
            _loadingComments
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Column(
                    children: [
                      ..._comments.map((c) => _buildComment(c as Map<String, dynamic>)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: const InputDecoration(
                                  hintText: 'Adicionar comentário...',
                                  hintStyle: TextStyle(fontSize: 13),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(20)),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.surfaceColor,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: _submitComment,
                              icon: const Icon(Icons.send_rounded,
                                  color: AppTheme.primaryRed, size: 20),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildComment(Map<String, dynamic> comment) {
    final name = comment['author_name'] as String? ?? 'Usuário';
    final avatar = comment['author_avatar'] as String?;
    final content = comment['content'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppTheme.surfaceColor,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Text(name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.primaryRed,
                        fontSize: 9,
                        fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(content,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inHours < 1) return 'há ${diff.inMinutes}min';
    if (diff.inDays < 1) return 'há ${diff.inHours}h';
    if (diff.inDays < 7) return 'há ${diff.inDays}d';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
