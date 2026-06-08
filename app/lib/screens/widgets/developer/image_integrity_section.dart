import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../backend/backend.dart';
import '../../../config/app_config.dart';
import '../../../domain/domain.dart';

/// Developer-only check that reconciles order image references with files on
/// disk: reports missing (referenced but absent) and orphaned (on disk but
/// unreferenced) images.
class ImageIntegritySection extends StatefulWidget {
  const ImageIntegritySection({super.key});

  @override
  State<ImageIntegritySection> createState() => _ImageIntegritySectionState();
}

class _ImageIntegritySectionState extends State<ImageIntegritySection> {
  bool _isChecking = false;
  DateTime? _lastChecked;
  int _totalRefs = 0;
  int _missingCount = 0;
  int _orphanedCount = 0;
  List<_MissingImage> _missingImages = [];

  Future<void> _check() async {
    setState(() {
      _isChecking = true;
      _missingImages = [];
    });

    try {
      final orderRepo = context.read<OrderRepository>();
      final customerRepo = context.read<CustomerRepository>();
      final orders = await orderRepo.getAllOrders();

      int totalRefs = 0;
      final missing = <_MissingImage>[];

      for (final order in orders) {
        for (final path in order.imagePaths) {
          totalRefs++;
          final exists = await File(path).exists();
          if (!exists) {
            final customer = await customerRepo.getCustomerById(order.customerId);
            missing.add(_MissingImage(
              fileName: path.split('/').last,
              orderTitle: order.title,
              customerName: customer?.name ?? 'Unknown',
            ));
          }
        }
      }

      // Check for orphaned files (on disk but not referenced by any order)
      final allLocalPaths = await ImageStorageService.getAllImagePaths();
      final referencedFileNames = orders
          .expand((o) => o.imagePaths)
          .map((p) => p.split('/').last)
          .toSet();
      final orphaned = allLocalPaths
          .where((p) => !referencedFileNames.contains(p.split('/').last))
          .length;

      if (mounted) {
        setState(() {
          _totalRefs = totalRefs;
          _missingCount = missing.length;
          _orphanedCount = orphaned;
          _missingImages = missing;
          _lastChecked = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image_search, color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Expanded(
                  child: Text('Image Integrity', style: theme.textTheme.titleMedium),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isChecking ? null : _check,
                  icon: _isChecking
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_lastChecked == null ? 'Check' : 'Refresh'),
                ),
              ],
            ),
            if (_lastChecked != null) ...[
              const SizedBox(height: AppConfig.spacing4),
              Text(
                'Last checked: ${DateFormat('h:mm a').format(_lastChecked!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppConfig.spacing12),
              if (_missingCount == 0)
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: AppConfig.spacing8),
                    Text(
                      'All $_totalRefs referenced images OK',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if (_missingCount > 0) ...[
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: AppConfig.spacing8),
                    Text(
                      '$_missingCount of $_totalRefs images missing',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConfig.spacing12),
                ...ListTile.divideTiles(
                  context: context,
                  tiles: _missingImages.map((m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.fileName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.error,
                          ),
                        ),
                        Text(
                          '${m.customerName}${m.orderTitle != null && m.orderTitle!.isNotEmpty ? ' — ${m.orderTitle}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )),
                ),
              ],
              if (_orphanedCount > 0) ...[
                const SizedBox(height: AppConfig.spacing8),
                Row(
                  children: [
                    const Icon(Icons.folder_delete_outlined, color: Colors.orange, size: 18),
                    const SizedBox(width: AppConfig.spacing8),
                    Expanded(
                      child: Text(
                        '$_orphanedCount orphaned ${_orphanedCount == 1 ? 'file' : 'files'} on disk (not referenced by any order)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingImage {
  final String fileName;
  final String? orderTitle;
  final String customerName;

  _MissingImage({
    required this.fileName,
    this.orderTitle,
    required this.customerName,
  });
}
