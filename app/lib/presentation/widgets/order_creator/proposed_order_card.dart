import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../config/app_config.dart';
import '../../../domain/models/order_proposal.dart';
import '../order_images_section.dart';
import 'editable_markdown_field.dart';

/// Inline-editable card for one [ProposedOrder]. All edits flow up through
/// the `onEdit` / `onRemove` callbacks — the widget itself is stateless w.r.t.
/// the proposal data; it only owns the [TextEditingController]s so the
/// keyboard / cursor work correctly across rebuilds.
class ProposedOrderCard extends StatefulWidget {
  final ProposedOrder order;
  final bool enabled;
  final void Function({
    String? title,
    int? value,
    bool clearValue,
    DateTime? dueDate,
    String? description,
    bool clearDescription,
    List<String>? imagePaths,
  }) onEdit;
  final VoidCallback onRemove;

  const ProposedOrderCard({
    super.key,
    required this.order,
    required this.enabled,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  State<ProposedOrderCard> createState() => _ProposedOrderCardState();
}

class _ProposedOrderCardState extends State<ProposedOrderCard> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _valueCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.order.title ?? '');
    _valueCtrl = TextEditingController(text: widget.order.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant ProposedOrderCard old) {
    super.didUpdateWidget(old);
    // External updates (AI feedback round) flow in via widget.order. Only
    // overwrite the field if the incoming value differs from what the user
    // currently has in the textbox — keeps caret/selection stable when the
    // tailor is mid-typing and the parent rebuilds for an unrelated reason.
    final incomingTitle = widget.order.title ?? '';
    if (_titleCtrl.text != incomingTitle && old.order.title != widget.order.title) {
      _titleCtrl.text = incomingTitle;
    }
    final incomingValue = widget.order.value?.toString() ?? '';
    if (_valueCtrl.text != incomingValue && old.order.value != widget.order.value) {
      _valueCtrl.text = incomingValue;
    }
    // Notes sync is handled inside EditableMarkdownField (it owns its own
    // controller), so nothing to do here for the description.
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      // No date yet → open the picker a week out as a convenient starting
      // point, but nothing is stored until the tailor actually picks.
      initialDate: widget.order.dueDate ??
          DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    widget.onEdit(dueDate: DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasDue = widget.order.dueDate != null;
    final dueLabel = hasDue
        ? DateFormat('MMM d, y').format(widget.order.dueDate!)
        : 'Set due date';
    final isValueTbd = widget.order.value == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    enabled: widget.enabled,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Blouse',
                      isDense: true,
                    ),
                    style: textTheme.titleMedium,
                    onChanged: (v) => widget.onEdit(title: v),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  onPressed: widget.enabled ? widget.onRemove : null,
                  tooltip: 'Remove this order',
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing12),
            Row(
              // Top-align: when the Due field shows its "Required" error text
              // it grows taller than the Price field, and centering would
              // shove the Price label/value down out of line with "Due".
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _valueCtrl,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixText: '₹',
                      isDense: true,
                      helperText: isValueTbd ? 'TBD' : null,
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null) {
                        widget.onEdit(clearValue: true);
                      } else {
                        widget.onEdit(value: parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppConfig.spacing12),
                Expanded(
                  child: InkWell(
                    onTap: widget.enabled ? _pickDueDate : null,
                    borderRadius:
                        BorderRadius.circular(AppConfig.buttonBorderRadius),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Due',
                        isDense: true,
                        // Flag the empty state so the tailor knows a date is
                        // needed before she can create the order.
                        errorText: hasDue ? null : 'Required',
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: hasDue
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.error,
                          ),
                          const SizedBox(width: AppConfig.spacing8),
                          Expanded(
                            child: Text(
                              dueLabel,
                              style: textTheme.bodyMedium?.copyWith(
                                color: hasDue ? null : colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing12),
            EditableMarkdownField(
              value: widget.order.description ?? '',
              enabled: widget.enabled,
              labelText: 'Notes',
              hintText: 'Fabric, style, customization (optional)',
              minLines: 1,
              maxLines: 6,
              onChanged: (v) {
                if (v.trim().isEmpty) {
                  widget.onEdit(clearDescription: true);
                } else {
                  widget.onEdit(description: v);
                }
              },
            ),
            const SizedBox(height: AppConfig.spacing12),
            OrderImagesSection(
              imagePaths: widget.order.imagePaths,
              onImagesChanged: (paths) => widget.onEdit(imagePaths: paths),
            ),
          ],
        ),
      ),
    );
  }
}
