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
  bool _isFilterExpanded = false;
  String? _error;
  Map<LabelType, List<dynamic>> _labelData = {};
  Map<LabelType, int> _labelCounts = {};
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
        final future = _fgPalletService.list();
        futures.add(future);
        typeToFuture[LabelType.fgPallet] = future;
      }

      if (_selectedTypes.contains(LabelType.roll)) {
        final future = _rollService.list();
        futures.add(future);
        typeToFuture[LabelType.roll] = future;
      }

      if (_selectedTypes.contains(LabelType.fgLocation)) {
        final future = _fgLocationService.list();
        futures.add(future);
        typeToFuture[LabelType.fgLocation] = future;
      }

      if (_selectedTypes.contains(LabelType.paperRollLocation)) {
        final future = _paperRollLocationService.list();
        futures.add(future);
        typeToFuture[LabelType.paperRollLocation] = future;
      }

      // Wait for all futures to complete
      final results = await Future.wait(futures);

      setState(() {
        _labelData = {};
        _labelCounts = {};

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

  Widget _buildFilterSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360; // Breakpoint for small screens

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isFilterExpanded = !_isFilterExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmallScreen ? 8 : 12,
              ),
              child: _buildFilterHeader(isSmallScreen),
            ),
          ),
          ClipRect(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              offset: _isFilterExpanded ? Offset.zero : const Offset(0, -1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isFilterExpanded ? 1.0 : 0.0,
                child: _isFilterExpanded
                    ? Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          top: isSmallScreen ? 4 : 8,
                        ),
                        child: LabelTypeFilter(
                          selectedTypes: _selectedTypes,
                          onTypesChanged: (types) {
                            setState(() => _selectedTypes = types);
                            _loadData();
                          },
                          typeCounts: _labelCounts,
                          compactMode: isSmallScreen,
                        ),
                      )
                    : const SizedBox(height: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(bool isSmallScreen) {
    final total = _labelCounts.values.fold(0, (sum, count) => sum + count);

    return Row(
      children: [
        Icon(
          Icons.filter_list,
          color: Theme.of(context).primaryColor,
          size: isSmallScreen ? 20 : 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Text(
                'Filter Labels',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isFilterExpanded ? Icons.expand_less : Icons.expand_more,
                color: Theme.of(context).primaryColor,
                size: isSmallScreen ? 20 : 24,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 12,
            vertical: isSmallScreen ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSmallScreen) const Text('Total: '),
              Text(
                total.toString(),
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildScanItem(dynamic label) {
    if (label is RollLabel) {
      return ScanItemCard(
        title: 'Roll ID: ${label.rollId}',
        subtitle: 'Batch: ${label.batchNumber}',
        details: 'Sequence: ${label.sequenceNumber}',
        checkIn: label.checkIn,
        labelType: LabelType.roll,
        onTap: () => _showLabelDetails(label),
      );
    }

    if (label is FGPalletLabel) {
      return ScanItemCard(
        title: 'PLT#: ${label.plateId}',
        subtitle: 'Work Order: ${label.workOrder}',
        details: 'Raw Value: ${label.rawValue}',
        checkIn: label.checkIn,
        labelType: LabelType.fgPallet,
        onTap: () => _showLabelDetails(label),
      );
    }

    if (label is FGLocationLabel) {
      return ScanItemCard(
        title: 'Location: ${label.locationId}',
        subtitle: 'Area Type: ${label.areaType}',
        details: null,
        checkIn: label.checkIn,
        labelType: LabelType.fgLocation,
        onTap: () => _showLabelDetails(label),
      );
    }

    if (label is PaperRollLocationLabel) {
      return ScanItemCard(
        title: 'Location: ${label.locationId}',
        subtitle: 'Row: ${label.rowNumber}',
        details: 'Position: ${label.positionNumber}',
        checkIn: label.checkIn,
        labelType: LabelType.paperRollLocation,
        onTap: () => _showLabelDetails(label),
      );
    }

    return const SizedBox.shrink();
  }

  // Update _buildLabelSection to be responsive
  Widget _buildLabelSection(LabelType type) {
    final labels = _labelData[type] ?? [];
    if (labels.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      margin: EdgeInsets.only(
        bottom: isSmallScreen ? 8 : 16,
        top: isSmallScreen ? 4 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: isSmallScreen ? 4 : 8,
            ),
            child: _buildSectionHeader(type, labels.length, isSmallScreen),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: labels.length,
            itemBuilder: (context, index) {
              final label = labels[index];
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.02,
                  vertical: isSmallScreen ? 2 : 4,
                ),
                child: _buildScanItem(label),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(LabelType type, int count, bool isSmallScreen) {
    return Row(
      children: [
        CircleAvatar(
          radius: isSmallScreen ? 16 : 20,
          backgroundColor: _getLabelTypeColor(type).withOpacity(0.1),
          child: Icon(
            _getLabelTypeIcon(type),
            color: _getLabelTypeColor(type),
            size: isSmallScreen ? 16 : 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _getLabelTypeName(type),
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 12,
            vertical: isSmallScreen ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: _getLabelTypeColor(type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: _getLabelTypeColor(type),
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 12 : 14,
            ),
          ),
        ),
      ],
    );
  }

  void _showLabelDetails(dynamic label) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 24,
          vertical: isSmallScreen ? 24 : 40,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDetailHeader(label, isSmallScreen),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMainDetails(label, isSmallScreen),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                      _buildStatusSection(label, isSmallScreen),
                    ],
                  ),
                ),
              ),
              _buildDetailActions(label, isSmallScreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailHeader(dynamic label, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color:
            _getLabelTypeColor(_getLabelTypeForLabel(label)).withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(
            _getLabelTypeIcon(_getLabelTypeForLabel(label)),
            color: _getLabelTypeColor(_getLabelTypeForLabel(label)),
            size: isSmallScreen ? 24 : 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getDialogTitle(label),
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: _getLabelTypeColor(_getLabelTypeForLabel(label)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: isSmallScreen ? 20 : 24,
          ),
        ],
      ),
    );
  }

  Widget _buildMainDetails(dynamic label, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(
          'Scan Time',
          DateFormat('dd/MM/yyyy HH:mm:ss').format(label.checkIn),
          isSmallScreen,
        ),
        const SizedBox(height: 8),
        if (label is FGPalletLabel) ...[
          _buildDetailRow('Plate ID', label.plateId, isSmallScreen),
          _buildDetailRow('Work Order', label.workOrder, isSmallScreen),
          _buildDetailRow('Raw Value', label.rawValue, isSmallScreen),
        ] else if (label is RollLabel) ...[
          _buildDetailRow('Roll ID', label.rollId, isSmallScreen),
          _buildDetailRow('Batch Number', label.batchNumber, isSmallScreen),
          _buildDetailRow(
              'Sequence Number', label.sequenceNumber, isSmallScreen),
        ] else if (label is FGLocationLabel) ...[
          _buildDetailRow('Location ID', label.locationId, isSmallScreen),
          _buildDetailRow('Area Type', label.areaType, isSmallScreen),
        ] else if (label is PaperRollLocationLabel) ...[
          _buildDetailRow('Location ID', label.locationId, isSmallScreen),
          _buildDetailRow('Row', label.rowNumber, isSmallScreen),
          _buildDetailRow('Position', label.positionNumber, isSmallScreen),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 100 : 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                fontSize: isSmallScreen ? 13 : 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(dynamic label, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: isSmallScreen ? 10 : 12,
                height: isSmallScreen ? 10 : 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(label.status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label.status ?? 'Unknown',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
              const Spacer(),
              if (label.statusUpdatedAt != null)
                Text(
                  'Updated: ${DateFormat('dd/MM/yyyy HH:mm').format(label.statusUpdatedAt!)}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          if (label.statusNotes != null && label.statusNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 13 : 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.statusNotes!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isSmallScreen ? 13 : 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailActions(dynamic label, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _shareDetails(label),
            icon: Icon(
              Icons.share,
              size: isSmallScreen ? 18 : 20,
            ),
            label: Text(
              'Share',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareDetails(dynamic label) {
    final details = _formatDetailsForSharing(label);
    Share.share(details, subject: 'Label Details');
  }

  String _formatDetailsForSharing(dynamic label) {
    final buffer = StringBuffer();
    buffer.writeln('Label Details');
    buffer.writeln('-------------');
    buffer.writeln('Type: ${_getLabelTypeName(_getLabelTypeForLabel(label))}');
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

  IconData _getLabelTypeIcon(LabelType type) {
    switch (type) {
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

  Color _getLabelTypeColor(LabelType type) {
    switch (type) {
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

  LabelType _getLabelTypeForLabel(dynamic label) {
    if (label is FGPalletLabel) return LabelType.fgPallet;
    if (label is RollLabel) return LabelType.roll;
    if (label is FGLocationLabel) return LabelType.fgLocation;
    if (label is PaperRollLocationLabel) return LabelType.paperRollLocation;
    throw ArgumentError('Unknown label type');
  }

  String _getDialogTitle(dynamic label) {
    if (label is FGPalletLabel) return 'FG Pallet Label Details';
    if (label is RollLabel) return 'Roll Label Details';
    if (label is FGLocationLabel) return 'FG Location Label Details';
    if (label is PaperRollLocationLabel) return 'Paper Roll Location Details';
    return 'Label Details';
  }

  Future<void> _updateStatus(
      dynamic label, String status, String? notes) async {
    try {
      setState(() => _isLoading = true);

      if (label is FGPalletLabel) {
        await _fgPalletService.updateStatus(label.plateId, status,
            notes: notes);
      } else if (label is RollLabel) {
        await _rollService.updateStatus(label.rollId, status, notes: notes);
      } else if (label is FGLocationLabel) {
        await _fgLocationService.updateStatus(label.locationId, status,
            notes: notes);
      } else if (label is PaperRollLocationLabel) {
        await _paperRollLocationService.updateStatus(label.locationId, status,
            notes: notes);
      }

      await _loadData();

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
        message: 'No labels found',
        icon: Icons.inventory_2,
        onRefresh: _loadData,
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            _buildFilterSection(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: EdgeInsets.only(
                    bottom: padding.bottom + 16,
                    left: screenWidth * 0.02,
                    right: screenWidth * 0.02,
                  ),
                  children: [
                    ...LabelType.values
                        .where((type) => _selectedTypes.contains(type))
                        .map(_buildLabelSection),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                        vertical: 16,
                      ),
                      child: ExportToExcelButton(
                        filterTypes: _selectedTypes,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
