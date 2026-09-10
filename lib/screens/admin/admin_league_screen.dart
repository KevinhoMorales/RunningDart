import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/league_standing_model.dart';
import '../../services/league_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/league_helpers.dart';
import '../../widgets/custom_app_bar.dart';

class AdminLeagueScreen extends StatefulWidget {
  const AdminLeagueScreen({super.key});

  @override
  State<AdminLeagueScreen> createState() => _AdminLeagueScreenState();
}

class _AdminLeagueScreenState extends State<AdminLeagueScreen> {
  late Future<List<LeagueStandingModel>> _future;
  final _periodKey = LeagueHelpers.currentPeriodKey();

  @override
  void initState() {
    super.initState();
    _future =
        context.read<LeagueService>().loadFullRanking(periodKey: _periodKey);
  }

  Future<void> _reload() async {
    setState(() {
      _future =
          context.read<LeagueService>().loadFullRanking(periodKey: _periodKey);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Liga del mes'),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<LeagueStandingModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data ?? const <LeagueStandingModel>[];
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  LeagueHelpers.periodLabel(_periodKey),
                  style: AppTypography.sectionTitle(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${rows.length} con puntos este mes',
                  style: AppTypography.muted(context),
                ),
                const SizedBox(height: AppSpacing.md),
                if (rows.isEmpty)
                  Text(
                    'Nadie ha sumado puntos todavía.',
                    style: AppTypography.muted(context),
                  )
                else
                  ...List.generate(rows.length, (index) {
                    final row = rows[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            palette.accentPrimary.withValues(alpha: 0.12),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: palette.accentPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(row.displayName),
                      trailing: Text(
                        '${row.points} pts',
                        style: AppTypography.body(
                          context,
                          weight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
