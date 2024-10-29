import 'package:flutter/material.dart';
import '../models/label_types.dart';
import 'package:intl/intl.dart';

class ScanHistoryItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? details;
  final DateTime checkIn;
  final LabelType labelType;
  final VoidCallback? onTap;

  const ScanHistoryItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.details,
    required this.checkIn,
    required this.labelType,
    this.onTap,
  });

  Color _getLabelColor() {
    switch (labelType) {
      case LabelType.fgPallet:
        return Colors.blue;
      case LabelType.roll:
        return Colors.green;
      case LabelType.fgLocation:
        return Colors.orange;
      case LabelType.paperRollLocation:
        return Colors.purple;
    }
  }

  IconData _getLabelIcon() {
    switch (labelType) {
      case LabelType.fgPallet:
        return Icons.inventory_2;
      case LabelType.roll:
        return Icons.rotate_right;
      case LabelType.fgLocation:
        return Icons.location_on;
      case LabelType.paperRollLocation:
        return Icons.location_searching;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getLabelColor();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(_getLabelIcon(), color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (details != null)
              Text(
                details!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            Text(
              'Scanned: ${DateFormat('dd/MM/yyyy HH:mm').format(checkIn)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}