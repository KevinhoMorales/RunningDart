import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../providers/admin_business_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';

class AdminBusinessesScreen extends StatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  State<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends State<AdminBusinessesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBusinessProvider>().startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminBusinessProvider>();
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Marcas aliadas',
        leading: HapticIconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: HapticFloatingActionButton(
        onPressed: () => context.push('/admin/businesses/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar marca'),
      ),
      body: _buildBody(provider, palette),
    );
  }

  Widget _buildBody(AdminBusinessProvider provider, AppPalette palette) {
    if (provider.isLoading && provider.businesses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.businesses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            provider.error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted),
          ),
        ),
      );
    }

    if (provider.businesses.isEmpty) {
      return Center(
        child: Text(
          'No hay marcas aliadas registradas.',
          style: TextStyle(color: palette.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: provider.businesses.length,
      itemBuilder: (context, index) {
        final business = provider.businesses[index];
        return _BusinessAdminTile(business: business);
      },
    );
  }
}

class _BusinessAdminTile extends StatelessWidget {
  const _BusinessAdminTile({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: HapticListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        leading: CircleAvatar(
          backgroundColor: palette.iconButtonBackground,
          backgroundImage:
              business.imageUrl != null ? NetworkImage(business.imageUrl!) : null,
          child: business.imageUrl == null
              ? Icon(Icons.storefront_rounded, color: palette.textMuted)
              : null,
        ),
        title: Text(
          business.name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        subtitle: Text(
          '${Helpers.categoryLabel(business.category)} · ${business.discount.isEmpty ? 'Sin descuento' : business.discount}',
          style: TextStyle(color: palette.textMuted),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/admin/businesses/${business.id}/edit'),
      ),
    );
  }
}
