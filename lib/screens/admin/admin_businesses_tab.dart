import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/business_model.dart';
import '../../providers/admin_business_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../utils/helpers.dart';
import '../../utils/secure_delete_flow.dart';
import '../../widgets/admin_search_field.dart';
import '../../widgets/custom_app_bar.dart';

class AdminBusinessesTab extends StatefulWidget {
  const AdminBusinessesTab({super.key});

  @override
  State<AdminBusinessesTab> createState() => _AdminBusinessesTabState();
}

class _AdminBusinessesTabState extends State<AdminBusinessesTab> {
  final _secureDeleteFlow = SecureDeleteFlow();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBusinessProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BusinessModel> _filteredBusinesses(List<BusinessModel> businesses) {
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

  Future<void> _handleRefresh() async {
    await context.read<AdminBusinessProvider>().refresh();
  }

  Future<void> _confirmDelete(BusinessModel business) async {
    final result = await _secureDeleteFlow.confirmAndAuthenticate(
      context: context,
      resourceType: 'negocio',
      itemName: business.name,
      summary:
          'Vas a eliminar un negocio afiliado y toda su información en SAINTS.',
      consequences: [
        'Se borrará "${business.name}" del directorio de negocios.',
        'Se eliminará su foto de portada si existe.',
        'Los operadores vinculados perderán la referencia a este negocio.',
        'Esta acción no se puede deshacer.',
      ],
    );

    if (!mounted || result != SecureDeleteResult.approved) {
      if (mounted) {
        await showSecureDeleteFeedback(context, result, deleteSucceeded: false);
      }
      return;
    }

    final provider = context.read<AdminBusinessProvider>();
    final success = await provider.deleteBusiness(business.id);

    if (!mounted) {
      return;
    }

    await showSecureDeleteFeedback(
      context,
      result,
      deleteSucceeded: success,
      deleteError: provider.error,
    );
  }

  Widget _refreshableBody({required Widget child}) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminBusinessProvider>();
    final palette = context.palette;
    final allBusinesses = provider.businesses;
    final filteredBusinesses = _filteredBusinesses(allBusinesses);

    if (provider.isLoading && allBusinesses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSearchFieldStateful(
          controller: _searchController,
          hintText: 'Buscar por nombre, categoría o descuento',
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        if (provider.error != null && allBusinesses.isEmpty)
          Expanded(
            child: _refreshableBody(
              child: Center(
                child: EmptyStateCard(
                  icon: Icons.cloud_off_rounded,
                  message: 'No pudimos cargar los negocios',
                  subtitle: provider.error,
                  actionLabel: 'Reintentar',
                  onAction: _handleRefresh,
                ),
              ),
            ),
          )
        else if (allBusinesses.isEmpty)
          Expanded(
            child: _refreshableBody(
              child: Center(
                child: EmptyStateCard(
                  icon: Icons.storefront_outlined,
                  message: 'No hay negocios registrados',
                  subtitle:
                      'Agrega el primero desde el tab Negocios con el botón + Negocio.',
                  actionLabel: 'Agregar negocio',
                  onAction: () => context.push('/admin/businesses/new'),
                ),
              ),
            ),
          )
        else if (filteredBusinesses.isEmpty)
          Expanded(
            child: _refreshableBody(
              child: Center(
                child: EmptyStateCard(
                  icon: Icons.search_off_rounded,
                  message: 'Sin resultados',
                  subtitle:
                      'No encontramos negocios para "$_searchQuery". Prueba con otro nombre o categoría.',
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                itemCount: filteredBusinesses.length,
                itemBuilder: (context, index) {
                  final business = filteredBusinesses[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(AppSpacing.md),
                      leading: CircleAvatar(
                        backgroundColor: palette.iconButtonBackground,
                        backgroundImage: business.imageUrl != null
                            ? NetworkImage(business.imageUrl!)
                            : null,
                        child: business.imageUrl == null
                            ? Icon(
                                Icons.storefront_rounded,
                                color: palette.textMuted,
                              )
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
                        '${Helpers.categoryLabel(business.category)} · '
                        '${business.discount.isEmpty ? 'Sin descuento' : business.discount}',
                        style: TextStyle(color: palette.textMuted),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => _confirmDelete(business),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: palette.textMuted,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: palette.textMuted,
                          ),
                        ],
                      ),
                      onTap: () =>
                          context.push('/admin/businesses/${business.id}/edit'),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
