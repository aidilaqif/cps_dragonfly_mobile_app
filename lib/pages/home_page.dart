import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/fg_pallet_label.dart';
import '../models/fg_location_label.dart';
import '../models/paper_roll_location_label.dart';
import '../models/roll_label.dart';
import '../models/label_types.dart';
import '../services/fg_pallet_label_service.dart';
import '../services/roll_label_service.dart';
import '../services/fg_location_label_service.dart';
import '../services/paper_roll_location_label_service.dart';
import '../widgets/scan_item_card.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/label_type_filter.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/export_to_excel_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Services
  final FGPalletLabelService _fgPalletService = FGPalletLabelService();
  final RollLabelService _rollService = RollLabelService();
  final FGLocationLabelService _fgLocationService = FGLocationLabelService();
  final PaperRollLocationLabelService _paperRollLocationService =
      PaperRollLocationLabelService();

  // State variables
  bool _isLoading = true;
  String? _error;
  Map<LabelType, List<dynamic>> _labelData = {};
  Map<LabelType, int> _labelCounts = {}; // Added this line
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  List<LabelType> _selectedTypes = LabelType.values.toList();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final futures = <Future>[];
      final Map<LabelType, Future> typeToFuture = {};

      // Add futures based on selected types
      if (_selectedTypes.contains(LabelType.fgPallet)) {
        final future = _fgPalletService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
        );
        futures.add(future);
        typeToFuture[LabelType.fgPallet] = future;
      }

      if (_selectedTypes.contains(LabelType.roll)) {
        final future = _rollService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
        );
        futures.add(future);
        typeToFuture[LabelType.roll] = future;
      }

      if (_selectedTypes.contains(LabelType.fgLocation)) {
        final future = _fgLocationService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
        );
        futures.add(future);
        typeToFuture[LabelType.fgLocation] = future;
      }

      if (_selectedTypes.contains(LabelType.paperRollLocation)) {
        final future = _paperRollLocationService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
        );
        futures.add(future);
        typeToFuture[LabelType.paperRollLocation] = future;
      }

      // Wait for all futures to complete
      final results = await Future.wait(futures);

      setState(() {
        _labelData = {};
        _labelCounts = {}; // Make sure this variable is defined in your state

        var index = 0;
        if (_selectedTypes.contains(LabelType.fgPallet)) {
          _labelData[LabelType.fgPallet] = results[index];
          _labelCounts[LabelType.fgPallet] = results[index].length;
          index++;
        }

        if (_selectedTypes.contains(LabelType.roll)) {
          _labelData[LabelType.roll] = results[index];
          _labelCounts[LabelType.roll] = results[index].length;
          index++;
        }

        if (_selectedTypes.contains(LabelType.fgLocation)) {
          _labelData[LabelType.fgLocation] = results[index];
          _labelCounts[LabelType.fgLocation] = results[index].length;
          index++;
        }

        if (_selectedTypes.contains(LabelType.paperRollLocation)) {
          _labelData[LabelType.paperRollLocation] = results[index];
          _labelCounts[LabelType.paperRollLocation] = results[index].length;
        }
      });
    } catch (e) {
      setState(() => _error = 'Error loading data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getFilteredLabels(LabelType type) {
    final labels = _labelData[type] ?? [];

    if (_searchQuery.isEmpty) {
      return labels;
    }

    final filtered = labels.where((label) {
      final query = _searchQuery.toLowerCase();

      if (label is FGPalletLabel) {
        return label.plateId.toLowerCase().contains(query) ||
            label.workOrder.toLowerCase().contains(query) ||
            label.rawValue.toLowerCase().contains(query);
      } else if (label is RollLabel) {
        return label.rollId.toLowerCase().contains(query);
      } else if (label is FGLocationLabel || label is PaperRollLocationLabel) {
        return (label as dynamic).locationId.toLowerCase().contains(query);
      }
      return false;
    }).toList();
    return filtered;
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterHeader(),
          const SizedBox(height: 16),
          DateRangeSelector(
            selectedRange: _selectedDateRange,
            onRangeSelected: (range) {
              setState(() => _selectedDateRange = range);
              _loadData();
            },
            onClearRange: () {
              setState(() => _selectedDateRange = null);
              _loadData();
            },
          ),
          const SizedBox(height: 16),
          _buildSearchField(),
          const SizedBox(height: 16),
          LabelTypeFilter(
            selectedTypes: _selectedTypes,
            onTypesChanged: (types) {
              setState(() => _selectedTypes = types);
              _loadData();
            },
            typeCounts: _labelCounts,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Row(
      children: [
        Icon(
          Icons.filter_list,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          'Filter Scan History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const Spacer(),
        _buildTotalCount(),
      ],
    );
  }

  Widget _buildTotalCount() {
    final total = _labelCounts.values.fold(0, (sum, count) => sum + count);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Total: $total',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search labels...',
        prefixIcon: Icon(
          Icons.search,
          color: Theme.of(context).primaryColor,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _searchQuery = ''),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildScanItem(dynamic label) {

    final title = _getLabelTitle(label);
    final subtitle = _getLabelSubtitle(label);
    final details = _getLabelDetails(label);

    if (label is RollLabel) {
      return ScanItemCard(
        title: 'Roll ID: ${label.rollId}',
        subtitle: 'Batch: ${label.batchNumber}',
        details: 'Sequence: ${label.sequenceNumber}',
        checkIn: label.checkIn,
        labelType: LabelType.roll,
        onTap: () => _showScanDetails(label),
      );
    }

    if (label is FGPalletLabel) {
      return ScanItemCard(
        title: 'PLT#: ${label.plateId}',
        subtitle: 'Work Order: ${label.workOrder}',
        details: 'Raw Value: ${label.rawValue}',
        checkIn: label.checkIn,
        labelType: LabelType.fgPallet,
        onTap: () => _showScanDetails(label),
      );
    }

    if (label is FGLocationLabel) {

      return ScanItemCard(
        title: label.locationId.isNotEmpty
            ? 'Location: ${label.locationId}'
            : 'Location: N/A',
        subtitle: 'Area Type: ${label.areaType}',
        details: null,
        checkIn: label.checkIn,
        labelType: LabelType.fgLocation,
        onTap: () => _showScanDetails(label),
      );
    }

    if (label is PaperRollLocationLabel) {

      final locationText = label.locationId.isNotEmpty
          ? 'Location: ${label.locationId}'
          : 'Location: N/A';
      final rowText =
          label.rowNumber.isNotEmpty ? 'Row: ${label.rowNumber}' : 'Row: N/A';
      final positionText = label.positionNumber.isNotEmpty
          ? 'Position: ${label.positionNumber}'
          : null;

      return ScanItemCard(
        title: locationText,
        subtitle: rowText,
        details: positionText,
        checkIn: label.checkIn,
        labelType: LabelType.paperRollLocation,
        onTap: () => _showScanDetails(label),
      );
    }

    return ScanItemCard(
      title: title,
      subtitle: subtitle,
      details: details,
      checkIn: label.checkIn,
      labelType: _getLabelTypeForScan(label),
      onTap: () => _showScanDetails(label),
    );
  }

  Widget _buildLabelSection(LabelType type) {
    final filteredLabels = _getFilteredLabels(type);
    if (filteredLabels.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(type, filteredLabels.length),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredLabels.length,
            itemBuilder: (context, index) {
              final label = filteredLabels[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _buildScanItem(label),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(LabelType type, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _getLabelTypeColor(type).withOpacity(0.1),
            child: Icon(
              _getLabelTypeIcon(type),
              color: _getLabelTypeColor(type),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _getLabelTypeName(type),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getLabelTypeColor(type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: _getLabelTypeColor(type),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLabelDetails(dynamic label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getLabelTypeIcon(label),
              color: _getLabelTypeColor(label),
            ),
            const SizedBox(width: 8),
            Text(_getDialogTitle(label)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                'Scan Time',
                DateFormat('dd/MM/yyyy HH:mm:ss').format(label.checkIn),
              ),
              const SizedBox(height: 8),
              if (label is FGPalletLabel) ...[
                _buildDetailRow('Plate ID', label.plateId),
                _buildDetailRow('Work Order', label.workOrder),
                _buildDetailRow('Raw Value', label.rawValue),
              ] else if (label is RollLabel) ...[
                _buildDetailRow('Roll ID', label.rollId),
                _buildDetailRow('Batch Number', label.batchNumber),
                _buildDetailRow('Sequence Number', label.sequenceNumber),
              ] else if (label is FGLocationLabel) ...[
                _buildDetailRow('Location ID', label.locationId),
                _buildDetailRow('Area Type', label.areaType),
              ] else if (label is PaperRollLocationLabel) ...[
                _buildDetailRow('Location ID', label.locationId),
                _buildDetailRow('Row', label.rowNumber),
                _buildDetailRow('Position', label.positionNumber),
              ],
              const SizedBox(height: 16),
              _buildStatusSection(label),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _showExportDialog(label),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(dynamic label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(label.status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label.status ?? 'Unknown',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          if (label.statusNotes != null && label.statusNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: ${label.statusNotes}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showUpdateStatusDialog(dynamic label) async {
    final selectedStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in [
              'Available',
              'Checked out',
              'Lost',
              'Unresolved'
            ])
              ListTile(
                title: Text(status),
                leading: Radio<String>(
                  value: status,
                  groupValue: label.status,
                  onChanged: (value) => Navigator.pop(context, value),
                ),
              ),
          ],
        ),
      ),
    );

    if (selectedStatus != null && selectedStatus != label.status) {
      try {
        setState(() => _isLoading = true);

        if (label is FGPalletLabel) {
          await _fgPalletService.updateStatus(label.plateId, selectedStatus);
        } else if (label is RollLabel) {
          await _rollService.updateStatus(label.rollId, selectedStatus);
        } else if (label is FGLocationLabel) {
          await _fgLocationService.updateStatus(
              label.locationId, selectedStatus);
        } else if (label is PaperRollLocationLabel) {
          await _paperRollLocationService.updateStatus(
              label.locationId, selectedStatus);
        }

        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating status: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showScanDetails(dynamic label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getLabelTypeIcon(label),
              color: _getLabelTypeColor(label),
            ),
            const SizedBox(width: 8),
            Text(_getDialogTitle(label)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                'Scan Time',
                DateFormat('dd/MM/yyyy HH:mm:ss').format(label.checkIn),
              ),
              const SizedBox(height: 8),
              if (label is FGPalletLabel) ...[
                _buildDetailRow('Plate ID', label.plateId),
                _buildDetailRow('Work Order', label.workOrder),
                _buildDetailRow('Raw Value', label.rawValue),
              ] else if (label is RollLabel) ...[
                _buildDetailRow('Roll ID', label.rollId),
                _buildDetailRow('Batch Number', label.batchNumber),
                _buildDetailRow('Sequence Number', label.sequenceNumber),
              ] else if (label is FGLocationLabel) ...[
                _buildDetailRow('Location ID', label.locationId),
                _buildDetailRow('Area Type', label.areaType),
              ] else if (label is PaperRollLocationLabel) ...[
                _buildDetailRow('Location ID', label.locationId),
                _buildDetailRow('Row', label.rowNumber),
                _buildDetailRow('Position', label.positionNumber),
              ],
              const SizedBox(height: 16),
              _buildStatusSection(label),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(dynamic label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export as Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportSingle(label);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Details'),
              onTap: () {
                Navigator.pop(context);
                _shareLabelDetails(label);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSingle(dynamic label) async {
    try {
      final labelType = _getLabelTypeForObject(label);

      final exporter = ExportToExcelButton(
        startDate: label.checkIn,
        endDate: label.checkIn,
        filterTypes: [labelType],
      );

      await exporter.exportData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export successful')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _shareLabelDetails(dynamic label) {
    String details = _formatLabelDetailsForSharing(label);
    Share.share(details, subject: 'Label Details');
  }

  String _formatLabelDetailsForSharing(dynamic label) {
    final buffer = StringBuffer();
    buffer.writeln('Label Details');
    buffer.writeln('-------------');
    buffer.writeln('Type: ${_getLabelTypeName(_getLabelTypeForObject(label))}');
    buffer.writeln(
        'Scan Time: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(label.checkIn)}');

    if (label is FGPalletLabel) {
      buffer.writeln('Plate ID: ${label.plateId}');
      buffer.writeln('Work Order: ${label.workOrder}');
      buffer.writeln('Raw Value: ${label.rawValue}');
    } else if (label is RollLabel) {
      buffer.writeln('Roll ID: ${label.rollId}');
      buffer.writeln('Batch Number: ${label.batchNumber}');
      buffer.writeln('Sequence Number: ${label.sequenceNumber}');
    } else if (label is FGLocationLabel) {
      buffer.writeln('Location ID: ${label.locationId}');
      buffer.writeln('Area Type: ${label.areaType}');
    } else if (label is PaperRollLocationLabel) {
      buffer.writeln('Location ID: ${label.locationId}');
      buffer.writeln('Row: ${label.rowNumber}');
      buffer.writeln('Position: ${label.positionNumber}');
    }

    buffer.writeln('Status: ${label.status ?? "Unknown"}');
    if (label.statusNotes != null && label.statusNotes!.isNotEmpty) {
      buffer.writeln('Notes: ${label.statusNotes}');
    }

    return buffer.toString();
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'checked out':
        return Colors.orange;
      case 'lost':
        return Colors.red;
      case 'unresolved':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  LabelType _getLabelTypeForObject(dynamic label) {
    if (label is FGPalletLabel) return LabelType.fgPallet;
    if (label is RollLabel) return LabelType.roll;
    if (label is FGLocationLabel) return LabelType.fgLocation;
    if (label is PaperRollLocationLabel) return LabelType.paperRollLocation;
    throw ArgumentError('Unknown label type');
  }

  String _getLabelTypeName(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return 'FG Pallet Labels';
      case LabelType.roll:
        return 'Roll Labels';
      case LabelType.fgLocation:
        return 'FG Location Labels';
      case LabelType.paperRollLocation:
        return 'Paper Roll Location Labels';
    }
  }

  IconData _getLabelTypeIcon(dynamic label) {
    if (label is FGPalletLabel) return Icons.inventory_2;
    if (label is RollLabel) return Icons.rotate_right;
    if (label is FGLocationLabel) return Icons.location_on;
    if (label is PaperRollLocationLabel) return Icons.location_searching;
    return Icons.label;
  }

  Color _getLabelTypeColor(dynamic label) {
    if (label is FGPalletLabel) return Colors.blue;
    if (label is RollLabel) return Colors.green;
    if (label is FGLocationLabel) return Colors.orange;
    if (label is PaperRollLocationLabel) return Colors.purple;
    return Colors.grey;
  }

  String _getLabelTitle(dynamic label) {

    if (label is FGPalletLabel) {
      return 'PLT#: ${label.plateId}';
    } else if (label is RollLabel) {
      return 'Roll ID: ${label.rollId}';
    } else if (label is FGLocationLabel || label is PaperRollLocationLabel) {
      final locationId = (label as dynamic).locationId;
      return 'Location: $locationId';
    }
    return 'Unknown Label';
  }

  String _getLabelSubtitle(dynamic label) {

    if (label is RollLabel) {
      final subtitle =
          'Batch: ${label.batchNumber}\nSequence: ${label.sequenceNumber}';
      return subtitle;
    } else if (label is FGPalletLabel) {
      return 'Work Order: ${label.workOrder}';
    } else if (label is FGLocationLabel) {
      return 'Area Type: ${label.areaType}';
    } else if (label is PaperRollLocationLabel) {
      return 'Row: ${label.rowNumber}';
    }
    return '';
  }

  String? _getLabelDetails(dynamic label) {

    if (label is FGPalletLabel) {
      return 'Raw Value: ${label.rawValue}';
    } else if (label is RollLabel) {
      return 'Sequence: ${label.sequenceNumber}';
    }
    return null;
  }

  LabelType _getLabelTypeForScan(dynamic label) {

    if (label is FGPalletLabel) return LabelType.fgPallet;
    if (label is RollLabel) return LabelType.roll;
    if (label is FGLocationLabel) return LabelType.fgLocation;
    if (label is PaperRollLocationLabel) return LabelType.paperRollLocation;
    throw ArgumentError('Unknown label type for: ${label.runtimeType}');
  }

  String _getDialogTitle(dynamic label) {
    if (label is FGPalletLabel) return 'FG Pallet Label Details';
    if (label is RollLabel) return 'Roll Label Details';
    if (label is FGLocationLabel) return 'FG Location Label Details';
    if (label is PaperRollLocationLabel) return 'Paper Roll Location Details';
    return 'Label Details';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadData,
      );
    }

    final hasData = _labelData.values.any((list) => list.isNotEmpty);
    if (!hasData) {
      return EmptyState(
        message:
            'No scans found${_selectedDateRange != null ? ' in selected date range' : ''}',
        icon: Icons.inventory_2,
        onRefresh: _loadData,
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  ...LabelType.values
                      .where((type) => _selectedTypes.contains(type))
                      .map(_buildLabelSection),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ExportToExcelButton(
                      startDate: _selectedDateRange?.start,
                      endDate: _selectedDateRange?.end,
                      filterTypes: _selectedTypes,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
