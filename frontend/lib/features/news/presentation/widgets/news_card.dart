import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';

class NewsCard extends StatelessWidget {
  final Map<String, dynamic> news;

  const NewsCard({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    final title = news['title'] as String? ?? '';
    final summary = news['summary'] as String? ?? '';
    final imageUrl = news['imageUrl'] as String?;
    final category = news['category'] as String? ?? 'general';
    final sourceNames = news['sourceNames'] as String? ?? '';
    final isUpdate = news['isUpdate'] as bool? ?? false;
    final publishedAt = news['publishedAt'] as String?;
    final sourceUrls = _parseSourceUrls(news['sourceUrls']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 180,
                  color: AppTheme.surfaceColor,
                  child: const Center(
                    child: Icon(Icons.image_outlined, color: AppTheme.textSecondary, size: 40),
                  ),
                ),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges: categoria + update
                Row(
                  children: [
                    _CategoryBadge(category: category),
                    if (isUpdate) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'UPDATE',
                          style: TextStyle(
                            color: AppTheme.warningOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (publishedAt != null) _TimeAgo(dateStr: publishedAt),
                  ],
                ),

                const SizedBox(height: 12),

                // Título
                Text(
                  title,
                  style: AppTheme.displayStyle(fontSize: 17),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                // Resumo
                Text(
                  summary,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 14),

                // Fontes
                if (sourceUrls.isNotEmpty) ...[
                  Container(
                    height: 1,
                    color: AppTheme.borderSubtle,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Fontes:',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _buildSourceChips(sourceUrls, sourceNames),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _parseSourceUrls(dynamic urls) {
    if (urls == null) return [];
    if (urls is List) return urls.map((e) => e.toString()).toList();
    return [];
  }

  List<Widget> _buildSourceChips(List<String> urls, String names) {
    final namesList = names.split(',').map((e) => e.trim()).toList();
    final chips = <Widget>[];

    for (int i = 0; i < urls.length; i++) {
      final name = i < namesList.length && namesList[i].isNotEmpty
          ? namesList[i]
          : _extractDomain(urls[i]);
      chips.add(
        InkWell(
          onTap: () => _launchUrl(urls[i]),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
            ),
            child: Text(
              name,
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }
    return chips;
  }

  String _extractDomain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final config = _getCategoryConfig(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 12, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  _CategoryConfig _getCategoryConfig(String category) {
    switch (category) {
      case 'race':
        return _CategoryConfig('CORRIDA', AppTheme.primaryGreen, Icons.flag);
      case 'transfer':
        return _CategoryConfig('TRANSFER', AppTheme.warningOrange, Icons.swap_horiz);
      case 'technical':
        return _CategoryConfig('TÉCNICO', AppTheme.accentCyan, Icons.build);
      case 'regulation':
        return _CategoryConfig('REGULAMENTO', AppTheme.accentGold, Icons.gavel);
      default:
        return _CategoryConfig('GERAL', AppTheme.textSecondary, Icons.article);
    }
  }
}

class _CategoryConfig {
  final String label;
  final Color color;
  final IconData icon;
  _CategoryConfig(this.label, this.color, this.icon);
}

class _TimeAgo extends StatelessWidget {
  final String dateStr;

  const _TimeAgo({required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(dateStr);
    final text = date != null ? _formatTimeAgo(date) : '';

    return Text(
      text,
      style: TextStyle(
        color: AppTheme.textSecondary.withValues(alpha: 0.7),
        fontSize: 12,
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final utcDate = dt.isUtc ? dt.toLocal() : dt;
    final diff = now.difference(utcDate);

    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays < 7) return 'há ${diff.inDays}d';
    return '${utcDate.day}/${utcDate.month}/${utcDate.year}';
  }
}
