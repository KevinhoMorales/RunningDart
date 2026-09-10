import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/league_standing_model.dart';
import '../services/league_service.dart';
import '../utils/league_helpers.dart';

class LeagueProvider extends ChangeNotifier {
  LeagueProvider(this._leagueService);

  final LeagueService _leagueService;

  StreamSubscription<List<LeagueStandingModel>>? _boardSub;
  StreamSubscription<LeagueStandingModel?>? _mineSub;

  String _periodKey = LeagueHelpers.currentPeriodKey();
  List<LeagueStandingModel> _leaderboard = const [];
  LeagueStandingModel? _myStanding;
  int? _myRank;
  int _participantCount = 0;
  bool _loading = true;
  String? _error;
  String? _userId;

  String get periodKey => _periodKey;
  List<LeagueStandingModel> get leaderboard => _leaderboard;
  LeagueStandingModel? get myStanding => _myStanding;
  int? get myRank => _myRank;
  int get participantCount => _participantCount;
  int get myPoints => _myStanding?.points ?? 0;
  bool get isLoading => _loading;
  String? get error => _error;

  void start({required String userId, String? periodKey}) {
    final period = periodKey ?? LeagueHelpers.currentPeriodKey();
    if (_userId == userId &&
        _periodKey == period &&
        (_boardSub != null || _mineSub != null)) {
      return;
    }
    stop();
    _userId = userId;
    _periodKey = period;
    _loading = true;
    _error = null;
    notifyListeners();

    _boardSub = _leagueService
        .watchLeaderboard(periodKey: period, limit: 10)
        .listen((board) {
      _leaderboard = board;
      _recomputeRank();
      _loading = false;
      notifyListeners();
    }, onError: (Object e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    });

    _mineSub = _leagueService
        .watchMyStanding(userId: userId, periodKey: period)
        .listen((mine) async {
      _myStanding = mine;
      await _refreshMeta();
      _recomputeRank();
      notifyListeners();
    }, onError: (Object e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    try {
      final snap = await _leagueService.loadSnapshot(
        userId: userId,
        periodKey: _periodKey,
      );
      _leaderboard = snap.leaderboard;
      _myStanding = snap.myStanding;
      _myRank = snap.myRank;
      _participantCount = snap.participantCount;
      _error = null;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshMeta() async {
    try {
      _participantCount =
          await _leagueService.participantCount(periodKey: _periodKey);
      final points = _myStanding?.points ?? 0;
      if (points <= 0) {
        _myRank = null;
        return;
      }
      final onBoard = _leaderboard.indexWhere((s) => s.userId == _userId);
      if (onBoard >= 0) {
        _myRank = onBoard + 1;
      } else {
        _myRank = await _leagueService.rankForPoints(
          periodKey: _periodKey,
          points: points,
        );
      }
    } catch (_) {
      // Mantener último valor conocido.
    }
  }

  void _recomputeRank() {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    final onBoard = _leaderboard.indexWhere((s) => s.userId == userId);
    if (onBoard >= 0) {
      _myRank = onBoard + 1;
    }
  }

  void stop() {
    _boardSub?.cancel();
    _mineSub?.cancel();
    _boardSub = null;
    _mineSub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
