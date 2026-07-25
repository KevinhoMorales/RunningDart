import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/news_model.dart';
import '../../providers/admin_news_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/news_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/external_url_launcher.dart';
import '../../utils/helpers.dart';
import '../../utils/whatsapp_launcher.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/event_status_badge.dart';

class NewsDetailScreen extends StatefulWidget {
  const NewsDetailScreen({
    super.key,
    required this.newsId,
  });

  final String newsId;

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  NewsModel? _news;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    NewsModel? news =
        await context.read<NewsProvider>().getNewsById(widget.newsId);

    if (!mounted) {
      return;
    }

    if (news == null && auth.isAdmin) {
      news = await context.read<AdminNewsProvider>().getNewsById(widget.newsId);
      if (!mounted) {
        return;
      }
    }

    if (news == null) {
      setState(() {
        _news = null;
        _isLoading = false;
        _error = 'Evento no encontrado.';
      });
      return;
    }

    if (!auth.isAdmin && Helpers.isEventPast(news.eventDate)) {
      setState(() {
        _news = null;
        _isLoading = false;
        _error = 'Este evento ya finalizó.';
      });
      return;
    }

    setState(() {
      _news = news;
      _isLoading = false;
      _error = null;
    });
  }

  Future<void> _openWhatsApp(BuildContext context, NewsModel news) async {
    final phone = news.whatsapp;
    if (phone == null || phone.isEmpty) {
      return;
    }

    final launched = await launchWhatsApp(
      phone,
      message: 'Hola, quiero más información sobre el evento "${news.title}".',
    );
    if (!launched && context.mounted) {
      AppSnackBar.show(context, 'No se pudo abrir WhatsApp. Intenta de nuevo.');
    }
  }

  Future<void> _editEvent(NewsModel news) async {
    await context.push('/admin/news/${news.id}/edit');
    if (mounted) {
      await _loadNews();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final news = _news;
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Evento',
        leading: HapticIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isAdmin && news != null)
            HapticIconButton(
              tooltip: 'Editar evento',
              icon: Icon(
                Icons.edit_rounded,
                color: palette.textPrimary,
              ),
              onPressed: () => _editEvent(news),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 48,
                          color: palette.textMuted,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        HapticFilledButton(
                          onPressed: () => context.pop(),
                          child: const Text('Volver'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          EventStatusBadge(eventDate: news!.eventDate),
                          if (!news.isPublished)
                            _DraftBadge(palette: palette),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              news.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
                        const SizedBox(height: AppSpacing.lg),
                      Text(
                        news.title,
                        style: AppTypography.sectionTitle(context),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Fecha',
                        value: Helpers.formatDate(news.eventDate),
                      ),
                      if (news.location != null && news.location!.isNotEmpty)
                        _InfoRow(
                          icon: Icons.place_outlined,
                          label: 'Lugar',
                          value: news.location!,
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        news.summary,
                        style: AppTypography.title(
                          context,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        news.body,
                        style: AppTypography.muted(context).copyWith(height: 1.5),
                      ),
                      if (news.moreInfo != null &&
                          news.moreInfo!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Información adicional',
                          style: AppTypography.title(
                            context,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          news.moreInfo!,
                          style: AppTypography.muted(context)
                              .copyWith(height: 1.5),
                        ),
                      ],
                      if (news.link != null && news.link!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        HapticFilledButton(
                          onPressed: () => launchExternalUrlFromContext(
                            context,
                            news.link!,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link_rounded, size: 18),
                              SizedBox(width: AppSpacing.sm),
                              Text('Abrir enlace'),
                            ],
                          ),
                        ),
                      ],
                      if (news.whatsapp != null &&
                          news.whatsapp!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        HapticFilledButton(
                          onPressed: () => _openWhatsApp(context, news),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_rounded, size: 18),
                              SizedBox(width: AppSpacing.sm),
                              Text('Más información'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _DraftBadge extends StatelessWidget {
  const _DraftBadge({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Text(
        'Borrador',
        style: AppTypography.micro(context, color: palette.accentPrimary),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: palette.accentPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.body(context, color: palette.textMuted),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: AppTypography.body(
                      context,
                      weight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
