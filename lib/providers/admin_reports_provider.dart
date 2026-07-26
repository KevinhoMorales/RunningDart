import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/post_model.dart';
import '../models/post_report_model.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';

/// Un reporte junto a la publicación reportada, que es lo que el moderador
/// necesita ver para decidir. La publicación puede faltar si su autor ya la
/// borró antes de que alguien revisara el reporte.
class ReportedPost {
  const ReportedPost({required this.report, this.post});

  final PostReportModel report;
  final PostModel? post;

  bool get postWasDeleted => post == null;
}

class AdminReportsProvider extends ChangeNotifier {
  AdminReportsProvider(this._socialService, this._postService);

  final SocialService _socialService;
  final PostService _postService;

  StreamSubscription<List<PostReportModel>>? _subscription;

  List<ReportedPost> _reports = const [];
  final Map<String, PostModel?> _postCache = {};
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;

  List<ReportedPost> get reports => _reports;

  List<ReportedPost> get pendingReports =>
      _reports.where((item) => item.report.isPending).toList(growable: false);

  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;

  void startListening() {
    if (_subscription != null) {
      return;
    }

    _isLoading = _reports.isEmpty;
    notifyListeners();

    _subscription = _socialService.watchReports().listen(
      (reports) => unawaited(_attachPosts(reports)),
      onError: (error) {
        debugPrint('No se pudieron cargar los reportes: $error');
        _error = 'No se pudieron cargar los reportes.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> refresh() async {
    stopListening();
    _postCache.clear();
    _error = null;
    startListening();
  }

  /// Resuelve cada publicación una sola vez: la cola repite el mismo `postId`
  /// cuando varias personas reportan la misma publicación.
  Future<void> _attachPosts(List<PostReportModel> reports) async {
    final missingIds = reports
        .map((report) => report.postId)
        .toSet()
        .where((postId) => !_postCache.containsKey(postId))
        .toList(growable: false);

    for (final postId in missingIds) {
      try {
        _postCache[postId] = await _postService.getPostById(postId);
      } catch (error) {
        debugPrint('No se pudo cargar la publicación $postId: $error');
        _postCache[postId] = null;
      }
    }

    _reports = reports
        .map(
          (report) => ReportedPost(
            report: report,
            post: _postCache[report.postId],
          ),
        )
        .toList(growable: false);
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<bool> setStatus({
    required String reportId,
    required PostReportStatus status,
    required String reviewedByUserId,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _socialService.setReportStatus(
        reportId: reportId,
        status: status,
        reviewedByUserId: reviewedByUserId,
      );
      return true;
    } catch (_) {
      _error = 'No se pudo actualizar el reporte.';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// Oculta la publicación y da el reporte por resuelto en un solo paso, que es
  /// lo que el moderador quiere cuando el reporte es válido.
  Future<bool> hideReportedPost({
    required ReportedPost item,
    required PostHiddenReason reason,
    required String moderatorId,
    String? note,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _postService.hidePost(
        item.report.postId,
        reason: reason,
        moderatorId: moderatorId,
        note: note,
      );
      await _socialService.setReportStatus(
        reportId: item.report.id,
        status: PostReportStatus.resolved,
        reviewedByUserId: moderatorId,
      );
      _postCache.remove(item.report.postId);
      return true;
    } catch (_) {
      _error = 'No se pudo ocultar la publicación.';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
