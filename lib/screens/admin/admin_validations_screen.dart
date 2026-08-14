import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/page_result.dart';
import '../../models/visit_model.dart';
import '../../services/visit_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';

class AdminValidationsScreen extends StatefulWidget {
  const AdminValidationsScreen({
    super.key,
    this.approvedOnly = false,
  });

  final bool approvedOnly;

  @override
  State<AdminValidationsScreen> createState() => _AdminValidationsScreenState();
}

class _AdminValidationsScreenState extends State<AdminValidationsScreen> {
  final _service = VisitService();

  StreamSubscription<PageResult<VisitModel>>? _subscription;
  List<VisitModel> _live = const [];
  List<VisitModel> _older = const [];
  Object? _cursor;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _generation = 0;
  String? _error;

  List<VisitModel> get _visits {
    final byId = <String, VisitModel>{};
    for (final visit in _older) {
      byId[visit.id] = visit;
    }
    for (final visit in _live) {
      byId[visit.id] = visit;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return merged
        .where(
          (visit) =>
              !widget.approvedOnly ||
              visit.validationResult == ValidationResult.approved,
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _start() {
    _subscription?.cancel();
    _generation++;
    _live = const [];
    _older = const [];
    _cursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    _isLoading = true;
    _error = null;

    _subscription = _service.watchAllVisits().listen(
      (page) {
        if (!mounted) {
          return;
        }
        setState(() {
          _live = page.items;
          if (_older.isEmpty) {
            _cursor = page.cursor;
            _hasMore = page.hasMore;
          } else {
            final liveIds = page.items.map((v) => v.id).toSet();
            _older = _older.where((v) => !liveIds.contains(v.id)).toList();
          }
          _isLoading = false;
          _error = null;
        });
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _error = 'No se pudieron cargar las validaciones.';
        });
      },
    );
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading || _cursor == null) {
      return;
    }
    final generation = _generation;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _service.fetchAllVisitsPage(startAfter: _cursor);
      if (!mounted || generation != _generation) {
        return;
      }
      final known = <String>{
        for (final v in _live) v.id,
        for (final v in _older) v.id,
      };
      final fresh = page.items.where((v) => !known.contains(v.id)).toList();
      setState(() {
        _older = [..._older, ...fresh];
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.pixels >= metrics.maxScrollExtent - 200) {
      unawaited(_loadMore());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visits = _visits;

    // Filtro "solo aprobadas": seguir pidiendo páginas si quedan pocas.
    if (widget.approvedOnly &&
        _hasMore &&
        !_isLoadingMore &&
        !_isLoading &&
        visits.length < 12) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadMore());
        }
      });
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.approvedOnly ? 'Validaciones aprobadas' : 'Validaciones QR',
      ),
      body: _isLoading && visits.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && visits.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTypography.muted(context),
                    ),
                  ),
                )
              : visits.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          widget.approvedOnly
                              ? 'Aún no hay validaciones aprobadas.'
                              : 'Aún no hay validaciones registradas.',
                          textAlign: TextAlign.center,
                          style: AppTypography.muted(context),
                        ),
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: visits.length +
                            (_hasMore || _isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == visits.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Center(
                                child: _isLoadingMore
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : HapticTextButton(
                                        onPressed: _loadMore,
                                        child: const Text('Cargar más'),
                                      ),
                              ),
                            );
                          }
                          final visit = visits[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: palette.cardBackground,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(color: palette.cardBorder),
                              boxShadow: palette.softShadow,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: palette.accentPrimary
                                    .withValues(alpha: 0.12),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: palette.accentPrimary,
                                ),
                              ),
                              title: Text(
                                visit.memberDisplayName,
                                style: AppTypography.title(context),
                              ),
                              subtitle: Text(
                                '${Helpers.formatDate(visit.visitedAt)} · '
                                '${visit.validationResult.displayName}'
                                '${visit.benefitUsed != null ? ' · ${visit.benefitUsed}' : ''}',
                                style: AppTypography.caption(context),
                              ),
                              trailing: Text(
                                _formatTime(visit.visitedAt),
                                style: AppTypography.caption(
                                  context,
                                  color: palette.textPrimary,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
