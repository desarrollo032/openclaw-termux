import 'package:flutter/material.dart';
import '../app.dart';
import '../models/optional_package.dart';
import '../services/package_service.dart';
import 'package_install_screen.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  Map<String, bool> _statuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final statuses = await PackageService.checkAllStatuses();
    if (mounted) {
      setState(() {
        _statuses = statuses;
        _loading = false;
      });
    }
  }

  Future<void> _navigateToInstall(
    OptionalPackage package, {
    bool isUninstall = false,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PackageInstallScreen(
          package: package,
          isUninstall: isUninstall,
        ),
      ),
    );
    if (result == true) _refreshStatuses();
  }

  void _confirmUninstall(OptionalPackage package) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Desinstalar ${package.name}?'),
        content: Text('Esto eliminará ${package.name} del entorno Ubuntu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToInstall(package, isUninstall: true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusAmber,
            ),
            child: const Text('Desinstalar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Paquetes Opcionales')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshStatuses,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // Header description
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.primary.withAlpha(15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: theme.colorScheme.primary.withAlpha(180),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Herramientas de desarrollo para instalar dentro del entorno Ubuntu. '
                            'Cada paquete se instala de forma independiente.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats row
                  _buildStatsRow(theme, isDark),
                  const SizedBox(height: 16),

                  // Package cards
                  for (final pkg in OptionalPackage.all)
                    _buildPackageCard(theme, pkg, isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsRow(ThemeData theme, bool isDark) {
    final installedCount = OptionalPackage.all
        .where((pkg) => _statuses[pkg.id] == true)
        .length;
    final totalCount = OptionalPackage.all.length;

    return Row(
      children: [
        _statChip(
          Icons.check_circle_outline,
          '$installedCount de $totalCount instalados',
          AppColors.statusGreen,
          theme,
        ),
        const SizedBox(width: 8),
        _statChip(
          Icons.extension_outlined,
          '${OptionalPackage.all.length} paquetes disponibles',
          theme.colorScheme.primary,
          theme,
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(ThemeData theme, OptionalPackage package, bool isDark) {
    final installed = _statuses[package.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: installed
            ? () => _confirmUninstall(package)
            : () => _navigateToInstall(package),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon with gradient-ish background
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: installed
                          ? AppColors.statusGreen.withAlpha(15)
                          : package.color.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: installed
                          ? Border.all(color: AppColors.statusGreen.withAlpha(40))
                          : null,
                    ),
                    child: Icon(
                      installed ? Icons.check_circle : package.icon,
                      color: installed ? AppColors.statusGreen : package.color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                package.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (installed)
                              _buildBadge(
                                'Instalado',
                                AppColors.statusGreen,
                                theme,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          package.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.storage_outlined,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              package.estimatedSize,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.code_outlined,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'apt',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Action button
                  installed
                      ? IconButton(
                          onPressed: () => _confirmUninstall(package),
                          icon: Icon(
                            Icons.delete_outline,
                            color: AppColors.statusAmber.withAlpha(180),
                            size: 22,
                          ),
                          tooltip: 'Desinstalar',
                        )
                      : FilledButton.tonal(
                          onPressed: () => _navigateToInstall(package),
                          child: const Text('Instalar'),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
