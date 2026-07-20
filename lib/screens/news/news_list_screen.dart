import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/news_model.dart';
import '../../providers/admin_news_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/news_provider.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/news_card.dart';

const adminNewsHomeTabIndex = 1;
const memberNewsHomeTabIndex = 1;
const operatorNewsHomeTabIndex = 3;

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

    final auth = context.read<AuthProvider>();
    if (auth.isAdmin) {
      context.read<AdminNewsProvider>().startListening();
    } else {
      context.read<NewsProvider>().startListening();
    }
  }

  Future<void> _handleRefresh() async {
    final auth = context.read<AuthProvider>();
    if (auth.isAdmin) {
      await context.read<AdminNewsProvider>().refresh();
    } else {
      await context.read<NewsProvider>().refresh();
    }
  }

  void _openItem(NewsModel item, {required bool isAdmin}) {
    if (isAdmin && !item.isPublished) {
      context.push('/admin/news/${item.id}/edit');
      return;
    }
    context.push('/news/${item.id}');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;

    final isLoading = isAdmin
        ? context.watch<AdminNewsProvider>().isLoading
        : context.watch<NewsProvider>().isLoading;
    final error = isAdmin
        ? context.watch<AdminNewsProvider>().error
        : context.watch<NewsProvider>().error;
    final news = isAdmin
        ? context
            .watch<AdminNewsProvider>()
            .news
            .where((item) => Helpers.isEventUpcoming(item.eventDate))
            .toList(growable: false)
        : context.watch<NewsProvider>().news;

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
            child: RefreshIndicator(
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
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: EmptyStateCard(
                        icon: isAdmin
                            ? Icons.event_note_outlined
                            : Icons.event_available_outlined,
                        message: isAdmin
                            ? 'Aún no hay eventos'
                            : 'Sin eventos por ahora',
                        subtitle: isAdmin
                            ? 'Publica el primero para que la comunidad lo vea en este tab.'
                            : 'Vuelve pronto para ver actividades y novedades de SAINTS. Desliza hacia abajo para actualizar.',
                        actionLabel: isAdmin ? 'Crear evento' : null,
                        onAction: isAdmin
                            ? () => context.push('/admin/news/new')
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: news.length,
                itemBuilder: (context, index) {
                  final item = news[index];
                  return NewsCard(
                    news: item,
                    showDraftBadge: isAdmin,
                    onTap: () => _openItem(item, isAdmin: isAdmin),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
