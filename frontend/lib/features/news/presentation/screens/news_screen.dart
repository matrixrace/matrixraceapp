import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../widgets/news_card.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final ApiClient _api = ApiClient();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _newsList = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadNews();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String get _lang => 'pt';

  Future<void> _loadNews({bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final res = await _api.get('/news?page=$_page&limit=15&lang=$_lang');

      if (!mounted) return;

      if (res.success && res.data != null) {
        final newItems = res.data['news'] as List? ?? [];
        _totalPages = res.data['totalPages'] as int? ?? 1;

        setState(() {
          if (append) {
            _newsList.addAll(newItems);
          } else {
            _newsList = newItems;
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _error = 'Erro ao carregar notícias';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro de conexão';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    _page = 1;
    await _loadNews();
  }

  void _onScroll() {
    if (_isLoadingMore || _page >= _totalPages) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll - 300) {
      _page++;
      _isLoadingMore = true;
      _loadNews(append: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryGreen,
      backgroundColor: AppTheme.cardBackground,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerList(itemCount: 5, itemHeight: 200),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_newsList.isEmpty) {
      return Center(
        child: EmptyStateWidget(
          icon: Icons.newspaper_outlined,
          title: 'Nenhuma notícia ainda',
          subtitle: 'As notícias de F1 aparecem aqui automaticamente a cada 4 horas.',
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _newsList.length + (_isLoadingMore ? 1 : 0),
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        if (index == _newsList.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          );
        }

        final item = _newsList[index] as Map<String, dynamic>;
        return NewsCard(news: item)
            .animate()
            .fadeIn(duration: 200.ms, delay: (index * 40).ms)
            .slideX(begin: 0.02, end: 0);
      },
    );
  }
}
