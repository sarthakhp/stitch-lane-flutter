import 'package:flutter/material.dart';

import '../../../backend/models/customer.dart';
import '../../../config/app_config.dart';
import '../streaming_voice_bottom_sheet.dart';

/// Full-pane customer picker: search (with voice), an always-present "create"
/// action, and a recent-first, browsable list. Replaces the old autocomplete
/// dropdown so the create action can never be hidden by an empty result, and
/// so a no-match becomes a one-tap "create this name".
///
/// Pure UI — the parent decides what selecting / creating means via callbacks.
class CustomerPicker extends StatefulWidget {
  final List<Customer> customers;
  final ValueChanged<Customer> onSelected;

  /// Create a new customer. [prefillName] carries the current search text when
  /// the user creates from a no-match state, so they don't retype it.
  final ValueChanged<String?> onCreateNew;

  final bool enabled;

  const CustomerPicker({
    super.key,
    required this.customers,
    required this.onSelected,
    required this.onCreateNew,
    this.enabled = true,
  });

  @override
  State<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<CustomerPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> get _filtered {
    final byRecent = List<Customer>.from(widget.customers)
      ..sort((a, b) => b.created.compareTo(a.created));
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return byRecent;
    return byRecent.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.phoneNumber?.contains(_query.trim()) ?? false);
    }).toList();
  }

  Future<void> _voiceSearch() async {
    final result = await StreamingVoiceBottomSheet.show(context);
    if (!mounted || result == null) return;
    final text = result.text.trim();
    if (text.isEmpty) return;
    _searchController.text = text;
    setState(() => _query = text);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(
          controller: _searchController,
          enabled: widget.enabled,
          onChanged: (v) => setState(() => _query = v),
          onClear: () {
            _searchController.clear();
            setState(() => _query = '');
          },
          onVoice: widget.enabled ? _voiceSearch : null,
        ),
        const SizedBox(height: AppConfig.spacing12),
        _CreateTile(
          onTap: widget.enabled ? () => widget.onCreateNew(null) : null,
        ),
        const SizedBox(height: AppConfig.spacing8),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyState(
                  query: _query.trim(),
                  hasAnyCustomers: widget.customers.isNotEmpty,
                  onCreate: () =>
                      widget.onCreateNew(_query.trim().isEmpty ? null : _query.trim()),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    return _CustomerRow(
                      customer: c,
                      onTap: widget.enabled ? () => widget.onSelected(c) : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onVoice;

  const _SearchField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onClear,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search name or phone…',
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasText)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear',
                onPressed: onClear,
              ),
            if (onVoice != null)
              IconButton(
                icon: const Icon(Icons.mic),
                tooltip: 'Search by voice',
                onPressed: onVoice,
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  final VoidCallback? onTap;
  const _CreateTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConfig.spacing16,
            vertical: AppConfig.spacing12,
          ),
          child: Row(
            children: [
              Icon(Icons.person_add, color: colorScheme.primary),
              const SizedBox(width: AppConfig.spacing16),
              Text(
                'New customer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onTap;

  const _CustomerRow({required this.customer, required this.onTap});

  String get _initials {
    final parts = customer.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPhone =
        customer.phoneNumber != null && customer.phoneNumber!.isNotEmpty;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing8,
        vertical: AppConfig.spacing4,
      ),
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        child: Text(_initials),
      ),
      title: Text(
        customer.name,
        style: theme.textTheme.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: hasPhone ? Text(customer.phoneNumber!) : null,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  final bool hasAnyCustomers;
  final VoidCallback onCreate;

  const _EmptyState({
    required this.query,
    required this.hasAnyCustomers,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = query.isNotEmpty;
    final title = hasQuery
        ? 'No customer named "$query"'
        : (hasAnyCustomers ? 'No matches' : 'No customers yet');

    // Center when there's room, but stay scrollable so it never overflows when
    // the keyboard shrinks the available height.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConfig.spacing24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_search_outlined,
                        size: 48, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: AppConfig.spacing12),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConfig.spacing16),
                    FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.person_add),
                      label: Text(
                          hasQuery ? 'Create "$query"' : 'Create new customer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
