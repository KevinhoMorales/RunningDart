import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../providers/business_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/admin_search_field.dart';
import '../../widgets/business_card.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/haptic_controls.dart';

class BusinessListScreen extends StatefulWidget {
  const BusinessListScreen({super.key});

  @override
  State<BusinessListScreen> createState() => _BusinessListScreenState();
}

class _BusinessListScreenState extends State<BusinessListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BusinessProvider>().loadBusinesses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BusinessModel> _filterBusinesses(List<BusinessModel> businesses) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return businesses;
    }

    return businesses.where((business) {
      final category = Helpers.categoryLabel(business.category).toLowerCase();
      return business.name.toLowerCase().contains(query) ||
          business.description.toLowerCase().contains(query) ||
          business.address.toLowerCase().contains(query) ||
          business.discount.toLowerCase().contains(query) ||
          category.contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    final palette = context.palette;
    final businesses = _filterBusinesses(
      provider.businesses
          .where((business) => business.isAllianceActive)
          .toList(growable: false),
    );

    return HapticRefreshIndicator(
      color: AppConstants.primaryColor,
      onRefresh: () => provider.loadBusinesses(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Marcas aliadas',
              subtitle: 'Beneficios exclusivos para la comunidad SAINTS',
            ),
          ),
          SliverToBoxAdapter(
            child: AdminSearchFieldStateful(
              controller: _searchController,
              hintText: 'Buscar por nombre, categoría o descuento',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _BusinessCategoryHeaderDelegate(
              selectedCategory: provider.selectedCategory,
              palette: palette,
              onCategorySelected: (category) {
                provider.loadBusinesses(category: category);
              },
            ),
          ),
          ..._buildContentSlivers(
            provider,
            businesses,
            searchQuery: _searchQuery,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BusinessProvider provider,
    List<BusinessModel> businesses, {
    required String searchQuery,
  }) {
    if (provider.isLoading && businesses.isEmpty) {
      return const [
        SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (provider.error != null && businesses.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: EmptyStateCard(
              icon: Icons.error_outline_rounded,
              message: provider.error!,
              actionLabel: 'Reintentar',
              onAction: () => provider.loadBusinesses(),
            ),
          ),
        ),
      ];
    }

    if (businesses.isEmpty) {
      final hasSearch = searchQuery.trim().isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: EmptyStateCard(
              icon: hasSearch
                  ? Icons.search_off_rounded
                  : Icons.storefront_outlined,
              message: hasSearch
                  ? 'No encontramos marcas para "$searchQuery". Prueba con otro nombre o categoría.'
                  : 'No hay marcas aliadas en esta categoría',
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final business = businesses[index];
              return BusinessCard(
                business: business,
                onTap: () => context.push('/business/${business.id}'),
              );
            },
            childCount: businesses.length,
          ),
        ),
      ),
    ];
  }
}

class _BusinessCategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  _BusinessCategoryHeaderDelegate({
    required this.selectedCategory,
    required this.palette,
    required this.onCategorySelected,
  });

  final String selectedCategory;
  final AppPalette palette;
  final ValueChanged<String> onCategorySelected;

  static const double _chipRowHeight = 36;
  static const double _bottomSpacing = AppSpacing.sm;
  static const double headerHeight = _chipRowHeight + _bottomSpacing;

  @override
  double get minExtent => headerHeight;

  @override
  double get maxExtent => headerHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: palette.scaffoldBackground,
      child: Column(
        children: [
          SizedBox(
            height: _chipRowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: AppConstants.businessCategories.length,
              separatorBuilder: (context, _) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final category = AppConstants.businessCategories[index];
                final isSelected = selectedCategory == category;

                return CategoryChip(
                  label: category == 'Todos'
                      ? 'Todos'
                      : Helpers.categoryLabel(category),
                  category: category,
                  isSelected: isSelected,
                  palette: palette,
                  onSelected: () => onCategorySelected(category),
                );
              },
            ),
          ),
          const SizedBox(height: _bottomSpacing),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _BusinessCategoryHeaderDelegate oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.palette != palette;
  }
}
