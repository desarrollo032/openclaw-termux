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
        title: Text('Uninstall ${package.name}?'),
        content: Text('This will remove ${package.name} from the environment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToInstall(package, isUninstall: true);
            },
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Optional Packages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Development tools you can install inside the Ubuntu environment.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final pkg in OptionalPackage.all)
                  _buildPackageCard(theme, pkg),
              ],
            ),
    );
  }

  Widget _buildPackageCard(ThemeData theme, OptionalPackage package) {
    final installed = _statuses[package.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: package.color.withAlpha(15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(package.icon, color: package.color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        package.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (installed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.statusGreen.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Installed',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.statusGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.storage_outlined, size: 12,
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(120)),
                      const SizedBox(width: 4),
                      Text(
                        package.estimatedSize,
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
            const SizedBox(width: 8),
            installed
                ? OutlinedButton(
                    onPressed: () => _confirmUninstall(package),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusAmber,
                      side: const BorderSide(color: AppColors.statusAmber),
                    ),
                    child: const Text('Remove'),
                  )
                : FilledButton(
                    onPressed: () => _navigateToInstall(package),
                    child: const Text('Install'),
                  ),
          ],
        ),
      ),
    );
  }
}
