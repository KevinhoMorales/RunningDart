import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/membership_modality.dart';
import '../models/monthly_challenge_model.dart';
import '../models/user_model.dart';
import '../services/challenge_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Soft Official perk explainer on Profile — no ranking advantage, no IAP.
class OfficialMemberPerkCard extends StatelessWidget {
  const OfficialMemberPerkCard({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final isOfficial =
        user.membershipModality == MembershipModality.official;
    final service = context.read<ChallengeService>();
    final palette = context.palette;

    return StreamBuilder<MonthlyChallengeModel?>(
      stream: service.watchActiveChallenge(),
      builder: (context, snap) {
        final challenge = snap.data;
        final title = isOfficial
            ? 'Tu perk Oficial'
            : 'Perk de Miembro Oficial';
        String body;
        if (isOfficial) {
          if (challenge != null && challenge.hasOfficialPerkConfigured) {
            body =
                'Este mes: ${challenge.officialPerkTitle}'
                '${challenge.officialPerkDescription != null && challenge.officialPerkDescription!.trim().isNotEmpty ? ' — ${challenge.officialPerkDescription!.trim()}' : ''}. '
                'Si ganas un Reward Spot, lo recibes además del premio general. '
                'Misma Liga y mismos puntos que Comunidad.';
          } else {
            body = MembershipModality.officialPerkMemberBlurb;
          }
        } else {
          if (challenge != null && challenge.hasOfficialPerkConfigured) {
            body =
                'Perk del mes para Oficiales en Reward Spots: '
                '${challenge.officialPerkTitle}. '
                '${MembershipModality.officialPerkUpsellBlurb}';
          } else {
            body = MembershipModality.officialPerkUpsellBlurb;
          }
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.infoBannerBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: palette.infoBannerBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isOfficial
                    ? Icons.workspace_premium_rounded
                    : Icons.info_outline_rounded,
                color: palette.accentPrimary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body(
                        context,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      body,
                      style:
                          AppTypography.muted(context).copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
