import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/news_model.dart';
import '../../providers/news_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/news_card.dart';

/// Tab de Noticias para socios (también admin/operador en el shell). Solo
/// publica lo publicado: los borradores viven en el panel Admin.
const memberNewsHomeTabIndex = 3;

class NewsListScreen extends StatefulWidget {
  const NewsListScreen({super.key});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  void _startListening() {
    if (!mounted) {
      return;
    }
    context.read<NewsProvider>().startListening();
  }

  Future<void> _handleRefresh() => context.read<NewsProvider>().refresh();

  void _openItem(NewsModel item) {
    context.push('/news/${item.id}');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final isLoading = provider.isLoading;
    final error = provider.error;
    final news = provider.news;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Noticias y eventos',
          subtitle: 'Actividades de SAINTS',
        ),
        if (isLoading && news.isEmpty)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null && news.isEmpty)
          Expanded(
            child: HapticRefreshIndicator(
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: EmptyStateCard(
                        icon: Icons.cloud_off_rounded,
                        message: 'No pudimos cargar los eventos',
                        subtitle: error,
                        actionLabel: 'Reintentar',
                        onAction: _handleRefresh,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (news.isEmpty)
          Expanded(
            child: HapticRefreshIndicator(
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: EmptyStateCard(
                        icon: Icons.event_note_outlined,
                        message: 'Aún no hay eventos',
                        subtitle:
                            'Cuando SAINTS publique actividades, aparecerán aquí.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: HapticRefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: news.length,
                itemBuilder: (context, index) {
                  final item = news[index];
                  return NewsCard(
                    news: item,
                    onTap: () => _openItem(item),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
