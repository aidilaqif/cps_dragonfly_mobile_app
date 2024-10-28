import 'package:flutter/material.dart';
import '../models/label_types.dart';
import 'styled_card.dart';

class ScanItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? details;
  final DateTime checkIn;
  final LabelType labelType;
  final VoidCallback? onTap;

  const ScanItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.details,
    required this.checkIn,
    required this.labelType,
    this.onTap,
  });

  Icon _getLabelTypeIcon() {
    switch (labelType) {
      case LabelType.fgPallet:
        return const Icon(Icons.inventory_2, color: Colors.blue);
      case LabelType.roll:
        return const Icon(Icons.rotate_right, color: Colors.green);
      case LabelType.fgLocation:
        return const Icon(Icons.location_on, color: Colors.orange);
      case LabelType.paperRollLocation:
        return const Icon(Icons.location_searching, color: Colors.purple);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      onTap: onTap,
      child: Row(
        children: [
          _getLabelTypeIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (details != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    details!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Scanned: ${_formatDateTime(checkIn)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}