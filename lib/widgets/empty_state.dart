import 'package:flutter/material.dart';
import '../models/label_types.dart';

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onRefresh;
  final String? subtitle;
  final Widget? actionButton;
  final bool showRefreshButton;
  final bool animate;

  const EmptyState({
    super.key,
    required this.message,
    required this.icon,
    this.onRefresh,
    this.subtitle,
    this.actionButton,
    this.showRefreshButton = true,
    this.animate = true,
  });

  // Factory constructor for label type specific empty states
  factory EmptyState.forLabelType({
    required LabelType labelType,
    DateTime? startDate,
    DateTime? endDate,
    VoidCallback? onRefresh,
    Widget? actionButton,
  }) {
    String message;
    String? subtitle;
    IconData icon;

    switch (labelType) {
      case LabelType.fgPallet:
        message = 'No FG Pallet Labels Found';
        icon = Icons.inventory_2;
        subtitle = 'Start scanning FG pallet labels to see them here';
        break;
      case LabelType.roll:
        message = 'No Roll Labels Found';
        icon = Icons.rotate_right;
        subtitle = 'Start scanning roll labels to see them here';
        break;
      case LabelType.fgLocation:
        message = 'No FG Location Labels Found';
        icon = Icons.location_on;
        subtitle = 'Start scanning FG location labels to see them here';
        break;
      case LabelType.paperRollLocation:
        message = 'No Paper Roll Location Labels Found';
        icon = Icons.location_searching;
        subtitle = 'Start scanning paper roll location labels to see them here';
        break;
    }

    // Add date range information if provided
    if (startDate != null || endDate != null) {
      subtitle = '${subtitle ?? ''}\nNo scans found in selected date range';
    }

    return EmptyState(
      message: message,
      icon: icon,
      subtitle: subtitle,
      onRefresh: onRefresh,
      actionButton: actionButton,
    );
  }

  // Factory for search results
  factory EmptyState.noSearchResults({
    required String searchTerm,
    VoidCallback? onRefresh,
    Widget? actionButton,
  }) {
    return EmptyState(
      message: 'No Results Found',
      icon: Icons.search_off_rounded,
      subtitle: 'No items match "$searchTerm"\nTry using different keywords',
      onRefresh: onRefresh,
      actionButton: actionButton,
      showRefreshButton: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (animate) ...[
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
                child: _buildIcon(),
              ),
            ] else ...[
              _buildIcon(),
            ],
            const SizedBox(height: 24),
            Text(
              message,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            if (showRefreshButton && onRefresh != null)
              _buildRefreshButton(context),
            if (actionButton != null) ...[
              const SizedBox(height: 16),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 48,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh),
      label: const Text('Refresh'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}