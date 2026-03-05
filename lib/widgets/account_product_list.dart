import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/account.dart';
import '../services/enrollment_service.dart';

/// Read-only per-account product list used for search results.
/// Displays products as single horizontal rows grouped under a store header.
class AccountProductList extends StatefulWidget {
  final Account account;
  final List<Product> products;
  final VoidCallback? onViewAll;
  final void Function(String accountId, bool enrolled)? onEnrollmentChanged;

  const AccountProductList({
    super.key,
    required this.account,
    required this.products,
    this.onViewAll,
    this.onEnrollmentChanged,
  });

  @override
  State<AccountProductList> createState() => _AccountProductListState();
}

class _AccountProductListState extends State<AccountProductList> {
  bool _working = false;

  Color _accentFromId(BuildContext ctx, String id) {
    final palette = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.purple.shade600,
      Colors.orange.shade600,
      Colors.teal.shade600,
      Colors.indigo.shade600,
    ];
    if (id.isEmpty) return Theme.of(ctx).colorScheme.primary;
    final sum = id.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[sum % palette.length];
  }

  bool get _isEnrolled => EnrollmentService.instance.isEnrolled(widget.account.id);

  Future<void> _enroll() async {
    setState(() {
      _working = true;
    });
    // optimistic: update service immediately so other listeners update
    EnrollmentService.instance.enrollAccount(widget.account.id);
    widget.onEnrollmentChanged?.call(widget.account.id, true);
    try {
      // EnrollmentService handles network; we await briefly if needed
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (_) {}
    if (mounted) setState(() => _working = false);
  }

  Future<void> _unenroll() async {
    setState(() {
      _working = true;
    });
    EnrollmentService.instance.unenrollAccount(widget.account.id);
    widget.onEnrollmentChanged?.call(widget.account.id, false);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (_) {}
    if (mounted) setState(() => _working = false);
  }

  Future<void> _confirmUnenroll() async {
    final doIt = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Unenroll from organization?'),
          content: Text('Remove ${widget.account.name} from your enrollments?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unenroll')),
          ],
        );
      },
    );
    if (doIt == true) {
      await _unenroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFromId(context, widget.account.id);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Store header with subtle accent background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 28,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.account.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (widget.onViewAll != null) TextButton(onPressed: widget.onViewAll, child: const Text('View')),
                const SizedBox(width: 8),
                // Enrollment controls
                if (_working)
                  const SizedBox(width: 36, height: 36, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                else ...[
                  if (!_isEnrolled)
                    IconButton(
                      tooltip: 'Enroll',
                      onPressed: _enroll,
                      icon: Icon(Icons.how_to_reg, color: accent),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Enrolled', style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      tooltip: 'Unenroll',
                      onPressed: _confirmUnenroll,
                      icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).iconTheme.color),
                    ),
                  ]
                ],
              ],
            ),
          ),

          // Products list (read-only rows)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: widget.products.map((p) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.06)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          color: Theme.of(context).cardColor,
                          width: 84,
                          height: 84,
                          child: p.imageUrl != null
                              ? Image.network(p.imageUrl!, fit: BoxFit.cover)
                              : Icon(Icons.image_outlined, size: 36, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name + optional description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            if (p.description?.isNotEmpty == true) ...[
                              const SizedBox(height: 6),
                              Text(p.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ],
                        ),
                      ),

                      // Price (right aligned)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(p.formattedPrice, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: accent, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
