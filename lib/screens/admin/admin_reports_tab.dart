import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/post_report_model.dart';
import '../../providers/admin_reports_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';
import '../../widgets/hide_post_dialog.dart';
import '../../widgets/post_viewer.dart';

/// Destino de los reportes que la comunidad envía desde el feed. Sin esto,
/// `post_reports` se llenaba sin que nadie los leyera.
class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  bool _onlyPending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminReportsProvider>().startListening();
      }
    });
  }

  Future<void> _handleRefresh() {
    return context.read<AdminReportsProvider>().refresh();
  }

  Future<void> _hidePost(ReportedPost item) async {
    final decision = await askHideReason(context);
    if (decision == null || !mounted) {
      return;
    }

    final moderatorId = context.read<AuthProvider>().user?.id;
    if (moderatorId == null) {
      return;
    }

    final success = await context.read<AdminReportsProvider>().hideReportedPost(
          item: item,
          reason: decision.reason,
          moderatorId: moderatorId,
          note: decision.note,
        );

    if (!mounted) {
      return;
    }
    AppSnackBar.show(
      context,
      success
          ? 'Publicación oculta y reporte resuelto.'
          : 'No se pudo ocultar la publicación.',
    );
  }

  Future<void> _setStatus(ReportedPost item, PostReportStatus status) async {
    final reviewerId = context.read<AuthProvider>().user?.id;
    if (reviewerId == null) {
      return;
    }

    final success = await context.read<AdminReportsProvider>().setStatus(
          reportId: item.report.id,
          status: status,
          reviewedByUserId: reviewerId,
        );

    if (!mounted) {
      return;
    }
    AppSnackBar.show(
      context,
      success ? 'Reporte actualizado.' : 'No se pudo actualizar el reporte.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminReportsProvider>();
    final items = _onlyPending ? provider.pendingReports : provider.reports;

    if (provider.isLoading && provider.reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${provider.pendingReports.length} pendientes',
                  style: AppTypography.caption(context),
                ),
              ),
              FilterChip(
                label: const Text('Solo pendientes'),
                selected: _onlyPending,
                onSelected: AppHaptics.wrapValue(
                  (value) => setState(() => _onlyPending = value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: HapticRefreshIndicator(
            onRefresh: _handleRefresh,
            child: _buildBody(provider, items),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(AdminReportsProvider provider, List<ReportedPost> items) {
    if (provider.error != null && provider.reports.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyStateCard(
            icon: Icons.cloud_off_rounded,
            message: 'No pudimos cargar los reportes',
            subtitle: provider.error,
            actionLabel: 'Reintentar',
            onAction: _handleRefresh,
          ),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyStateCard(
            icon: Icons.flag_outlined,
            message: _onlyPending
                ? 'No hay reportes pendientes'
                : 'Aún no hay reportes',
            subtitle: _onlyPending
                ? 'Cuando alguien reporte una publicación, aparecerá aquí.'
                : null,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ReportCard(
          item: item,
          isUpdating: provider.isUpdating,
          onOpenPost: item.post == null
              ? null
              : () => showPostViewer(context, item.post!),
          onOpenAuthor: item.post == null
              ? null
              : () => context.push('/user/${item.post!.authorId}'),
          onHide: item.post == null || item.post!.isHidden
              ? null
              : () => _hidePost(item),
          onResolve: () => _setStatus(item, PostReportStatus.resolved),
          onDismiss: () => _setStatus(item, PostReportStatus.dismissed),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.item,
    required this.isUpdating,
    required this.onOpenPost,
    required this.onOpenAuthor,
    required this.onHide,
    required this.onResolve,
    required this.onDismiss,
  });

  final ReportedPost item;
  final bool isUpdating;
  final VoidCallback? onOpenPost;
  final VoidCallback? onOpenAuthor;
  final VoidCallback? onHide;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final report = item.report;
    final post = item.post;
    final imageUrl = post?.imageUrl;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? Container(
                          color: palette.skeletonColor,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 20,
                            color: palette.textMuted,
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: palette.skeletonColor),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post == null
                          ? 'Publicación eliminada'
                          : 'De ${post.authorName}',
                      style: AppTypography.title(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        report.status.displayName,
                        if (report.createdAt != null)
                          Helpers.formatDate(report.createdAt!),
                        if (post?.isHidden == true) 'Ya oculta',
                      ].join(' · '),
                      style: AppTypography.caption(context),
                    ),
                    if (report.reason != null && report.reason!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '"${report.reason}"',
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (onOpenPost != null)
                OutlinedButton(
                  onPressed: AppHaptics.wrap(onOpenPost!),
                  child: const Text('Ver'),
                ),
              if (onOpenAuthor != null)
                OutlinedButton(
                  onPressed: AppHaptics.wrap(onOpenAuthor!),
                  child: const Text('Autor'),
                ),
              if (onHide != null)
                OutlinedButton(
                  onPressed: isUpdating ? null : AppHaptics.wrap(onHide!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text('Ocultar'),
                ),
              if (report.isPending) ...[
                HapticFilledButton(
                  onPressed: isUpdating ? null : onResolve,
                  child: const Text('Resuelto'),
                ),
                OutlinedButton(
                  onPressed: isUpdating ? null : AppHaptics.wrap(onDismiss),
                  child: const Text('Descartar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
