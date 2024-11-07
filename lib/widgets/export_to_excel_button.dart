import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/label_types.dart';
import '../services/csv_export_service.dart';

class ExportToExcelButton extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<LabelType>? filterTypes;
  final bool showIcon;
  final String? customText;
  final VoidCallback? onExportStart;
  final VoidCallback? onExportComplete;
  final Function(String)? onError;

  const ExportToExcelButton({
    super.key,
    this.startDate,
    this.endDate,
    this.filterTypes,
    this.showIcon = true,
    this.customText,
    this.onExportStart,
    this.onExportComplete,
    this.onError,
  });

  // Add this new method for exporting data
  Future<String> exportData() async {
    try {
      final filePath = await CsvExportService().exportToExcel(
        startDate: startDate,
        endDate: endDate,
        filterTypes: filterTypes,
      );

      await Share.shareXFiles([XFile(filePath)]);
      return filePath;
    } catch (e) {
      throw Exception('Export failed: $e');
    }
  }

  @override
  State<ExportToExcelButton> createState() => _ExportToExcelButtonState();
}

class _ExportToExcelButtonState extends State<ExportToExcelButton> {
  bool _isExporting = false;

  Future<void> _handleExport() async {
    if (_isExporting) return;

    try {
      setState(() => _isExporting = true);
      widget.onExportStart?.call();

      await widget.exportData();

      if (mounted) {
        widget.onExportComplete?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        widget.onError?.call(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isExporting ? null : _handleExport,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showIcon)
            _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
          if (widget.showIcon) const SizedBox(width: 8),
          Text(
            _isExporting
                ? 'Exporting...'
                : widget.customText ?? 'Export to Excel',
          ),
        ],
      ),
    );
  }
}
