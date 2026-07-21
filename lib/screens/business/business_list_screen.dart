import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../theme/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/business_card.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/custom_app_bar.dart';

class BusinessListScreen extends StatefulWidget {
  const BusinessListScreen({super.key});

  @override
  State<BusinessListScreen> createState() => _BusinessListScreenState();
}

class _BusinessListScreenState extends State<BusinessListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BusinessProvider>().loadBusinesses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    final auth = context.watch<AuthProvider>();
    final modality = auth.user?.membershipModality;
    final businesses = provider.businesses
        .where(
          (business) =>
              business.isAllianceActive &&
              (modality == null || business.appliesToModality(modality)),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Marcas aliadas',
          subtitle: 'Beneficios exclusivos para la comunidad SAINTS',
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: AppConstants.businessCategories.length,
            separatorBuilder: (context, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final category = AppConstants.businessCategories[index];
              final isSelected = provider.selectedCategory == category;

              return CategoryChip(
                label: category == 'Todos'
                    ? 'Todos'
                    : Helpers.categoryLabel(category),
                category: category,
                isSelected: isSelected,
                onSelected: () {
                  provider.loadBusinesses(category: category);
                },
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: _buildBody(provider, businesses)),
      ],
    );
  }

  Widget _buildBody(
    BusinessProvider provider,
    List<BusinessModel> businesses,
  ) {
    if (provider.isLoading && businesses.isEmpty) {
      return const LoadingSkeleton();
    }

    if (provider.error != null && businesses.isEmpty) {
      return Center(
        child: EmptyStateCard(
          icon: Icons.error_outline_rounded,
          message: provider.error!,
          actionLabel: 'Reintentar',
          onAction: () => provider.loadBusinesses(),
        ),
      );
    }

    if (businesses.isEmpty) {
      return const Center(
        child: EmptyStateCard(
          icon: Icons.storefront_outlined,
          message: 'No hay marcas aliadas en esta categoría',
        ),
      );
    }

    return RefreshIndicator(
      color: AppConstants.primaryColor,
      onRefresh: () => provider.loadBusinesses(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        itemCount: businesses.length,
        itemBuilder: (context, index) {
          final business = businesses[index];
          return BusinessCard(
            business: business,
            onTap: () => context.push('/business/${business.id}'),
          );
        },
      ),
    );
  }
}
