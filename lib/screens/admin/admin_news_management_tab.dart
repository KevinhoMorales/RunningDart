import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/news_model.dart';
import '../../providers/admin_news_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/helpers.dart';
import '../../utils/secure_delete_flow.dart';
import '../../widgets/admin_search_field.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/event_status_badge.dart';
import '../../widgets/haptic_controls.dart';

class AdminNewsManagementTab extends StatefulWidget {
  const AdminNewsManagementTab({super.key});

  @override
  State<AdminNewsManagementTab> createState() => _AdminNewsManagementTabState();
}

class _AdminNewsManagementTabState extends State<AdminNewsManagementTab> {
  final _secureDeleteFlow = SecureDeleteFlow();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminNewsProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NewsModel> _filteredNews(List<NewsModel> news) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return news;
    }

    return news.where((item) {
      final location = item.location?.toLowerCase() ?? '';
      final dateLabel = Helpers.formatDate(item.eventDate).toLowerCase();
      return item.title.toLowerCase().contains(query) ||
          item.summary.toLowerCase().contains(query) ||
          location.contains(query) ||
          dateLabel.contains(query);
    }).toList(growable: false);
  }

  Future<void> _handleRefresh() async {
    await context.read<AdminNewsProvider>().refresh();
  }

  Future<void> _confirmDelete(NewsModel news) async {
    final isFinished = Helpers.isEventPast(news.eventDate);
    final result = await _secureDeleteFlow.confirmAndAuthenticate(
      context: context,
      resourceType: 'evento',
      itemName: news.title,
      summary: isFinished
          ? 'Vas a eliminar un evento que ya finalizó del historial de SAINTS.'
          : 'Vas a eliminar un evento activo o borrador de SAINTS.',
      consequences: [
        'Se borrará el evento "${news.title}" de Firestore.',
        'Si tiene foto de portada, también se eliminará del almacenamiento.',
        'Los usuarios dejarán de verlo de forma inmediata.',
        'Esta acción no se puede deshacer.',
      ],
    );

    if (!mounted || result != SecureDeleteResult.approved) {
      if (mounted) {
        await showSecureDeleteFeedback(context, result, deleteSucceeded: false);
      }
      return;
    }

    final provider = context.read<AdminNewsProvider>();
    final success = await provider.deleteNews(news.id);

    if (!mounted) {
      return;
    }

    await showSecureDeleteFeedback(
      context,
      result,
      deleteSucceeded: success,
      deleteError: provider.error,
    );
  }

  Widget _refreshableBody({required Widget child}) {
    return HapticRefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminNewsProvider>();
    final palette = context.palette;
    final allNews = provider.news;
    final filteredNews = _filteredNews(allNews);

    if (provider.isLoading && allNews.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSearchFieldStateful(
          controller: _searchController,
          hintText: 'Buscar por título, lugar o fecha',
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        if (provider.error != null && allNews.isEmpty)
          Expanded(
            child: _refreshableBody(
              child: Center(
                child: EmptyStateCard(
                  icon: Icons.cloud_off_rounded,
                  message: 'No pudimos cargar los eventos',
                  subtitle: provider.error,
                  actionLabel: 'Reintentar',
                  onAction: _handleRefresh,
                ),
              ),
            ),
          )
        else if (allNews.isEmpty)
          Expanded(
            child: _refreshableBody(
              child: Center(
                child: EmptyStateCard(
                  icon: Icons.event_note_outlined,
                  message: 'No hay eventos registrados',
                  subtitle:
                      'Crea el primero con el botón + Evento de este panel.',
                  actionLabel: 'Crear evento',
                  onAction: () => context.push('/admin/news/new'),
                ),
              ),
            ),
          )
        else if (filteredNews.isEmpty)
          Expanded(
            child: _refreshableBody(
              child: Center(
                child: EmptyStateCard(
                  icon: Icons.search_off_rounded,
                  message: 'Sin resultados',
                  subtitle:
                      'No encontramos eventos para "$_searchQuery". Prueba con otro título, lugar o fecha.',
                ),
              ),
            ),
          )
        else
          Expanded(
            child: HapticRefreshIndicator(
              onRefresh: _handleRefresh,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final metrics = notification.metrics;
                  if (metrics.pixels >= metrics.maxScrollExtent - 200) {
                    context.read<AdminNewsProvider>().loadMore();
                  }
                  return false;
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  itemCount: filteredNews.length +
                      (provider.hasMore || provider.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == filteredNews.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Center(
                          child: provider.isLoadingMore
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : HapticTextButton(
                                  onPressed: () => context
                                      .read<AdminNewsProvider>()
                                      .loadMore(),
                                  child: const Text('Cargar más'),
                                ),
                        ),
                      );
                    }
                    final item = filteredNews[index];
                    return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: HapticListTile(
                      contentPadding: const EdgeInsets.all(AppSpacing.md),
                      leading: CircleAvatar(
                        backgroundColor: palette.iconButtonBackground,
                        backgroundImage: item.imageUrl != null
                            ? NetworkImage(item.imageUrl!)
                            : null,
                        child: item.imageUrl == null
                            ? Icon(
                                Icons.event_rounded,
                                color: palette.textMuted,
                              )
                            : null,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            Helpers.formatDate(item.eventDate),
                            style: AppTypography.caption(context),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              EventStatusBadge(eventDate: item.eventDate),
                              if (!item.isPublished)
                                _ChipBadge(
                                  label: 'Borrador',
                                  color: palette.accentPrimary,
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: HapticIconButton(
                        tooltip: 'Eliminar',
                        onPressed: () => _confirmDelete(item),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: palette.textMuted,
                        ),
                      ),
                      onTap: () => context.push('/admin/news/${item.id}/edit'),
                    ),
                  );
                },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChipBadge extends StatelessWidget {
  const _ChipBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Text(
        label,
        style: AppTypography.micro(context, color: color),
      ),
    );
  }
}
