import 'package:flutter/material.dart';

class ExportDialog extends StatelessWidget {
  final Function() onExport;

  const ExportDialog({
    super.key,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export to Excel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The following sheets will be exported:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSheetInfo(
            'Item',
            Icons.inventory_2_outlined,
            'Label ID, Type, Location, Status, Time',
          ),
          _buildSheetInfo(
            'Roll',
            Icons.rotate_right,
            'Label ID, Code, Name, Size, Status, Time',
          ),
          _buildSheetInfo(
            'FG Pallet',
            Icons.inventory,
            'Label ID, PLT, Quantity, Work Order, Total, Status, Time',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onExport();
          },
          child: const Text('Export'),
        ),
      ],
    );
  }

  Widget _buildSheetInfo(String title, IconData icon, String fields) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  fields,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
