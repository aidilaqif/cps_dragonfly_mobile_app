import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fg_location_label.dart';
import '../models/fg_pallet_label.dart';
import '../models/paper_roll_location_label.dart';
import '../models/roll_label.dart';
import '../models/label_types.dart';
import '../services/fg_pallet_label_service.dart';
import '../services/roll_label_service.dart';
import '../services/fg_location_label_service.dart';
import '../services/paper_roll_location_label_service.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/label_type_filter.dart';
import '../widgets/scan_history_item.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/export_to_excel_button.dart';
import 'package:share_plus/share_plus.dart';

class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({super.key});

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  // Services
  final FGPalletLabelService _fgPalletService = FGPalletLabelService();
  final RollLabelService _rollService = RollLabelService();
  final FGLocationLabelService _fgLocationService = FGLocationLabelService();
  final PaperRollLocationLabelService _paperRollLocationService =
      PaperRollLocationLabelService();

  // State variables
  bool _isLoading = true;
  String? _error;
  List<dynamic> _scans = [];
  Map<String, int> _statusCounts = {};
  Map<LabelType, int> _typeCounts = {};
  DateTimeRange? _selectedDateRange;
  List<LabelType> _selectedTypes = LabelType.values.toList();
  String _searchQuery = '';
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  Future<void> _loadScans() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      List<dynamic> allScans = [];
      Map<String, int> newStatusCounts = {};
      Map<LabelType, int> newTypeCounts = {};

      // Load scans from each selected type
      if (_selectedTypes.contains(LabelType.fgPallet)) {
        final fgScans = await _fgPalletService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
          status: _selectedStatus,
        );
        allScans.addAll(fgScans);
        newTypeCounts[LabelType.fgPallet] = fgScans.length;
      }

      if (_selectedTypes.contains(LabelType.roll)) {
        final rollScans = await _rollService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
          status: _selectedStatus,
        );
        allScans.addAll(rollScans);
        newTypeCounts[LabelType.roll] = rollScans.length;
      }

      if (_selectedTypes.contains(LabelType.fgLocation)) {
        final locationScans = await _fgLocationService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
          status: _selectedStatus,
        );
        allScans.addAll(locationScans);
        newTypeCounts[LabelType.fgLocation] = locationScans.length;
      }

      if (_selectedTypes.contains(LabelType.paperRollLocation)) {
        final paperLocationScans = await _paperRollLocationService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
          status: _selectedStatus,
        );
        allScans.addAll(paperLocationScans);
        newTypeCounts[LabelType.paperRollLocation] = paperLocationScans.length;
      }

      // Sort all scans by check-in time (most recent first)
      allScans.sort((a, b) => b.checkIn.compareTo(a.checkIn));

      // Calculate status counts
      for (var scan in allScans) {
        final status = scan.status ?? 'Unknown';
        newStatusCounts[status] = (newStatusCounts[status] ?? 0) + 1;
      }

      setState(() {
        _scans = allScans;
        _statusCounts = newStatusCounts;
        _typeCounts = newTypeCounts;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading scan history: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getFilteredScans() {
    if (_searchQuery.isEmpty) return _scans;

    return _scans.where((scan) {
      final query = _searchQuery.toLowerCase();
      if (scan is FGPalletLabel) {
        return scan.plateId.toLowerCase().contains(query) ||
            scan.workOrder.toLowerCase().contains(query) ||
            scan.rawValue.toLowerCase().contains(query);
      } else if (scan is RollLabel) {
        return scan.rollId.toLowerCase().contains(query);
      } else if (scan is FGLocationLabel || scan is PaperRollLocationLabel) {
        return (scan as dynamic).locationId.toLowerCase().contains(query);
      }
      return false;
    }).toList();
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
              _loadScans();
            },
            onClearRange: () {
              setState(() => _selectedDateRange = null);
              _loadScans();
            },
          ),
          const SizedBox(height: 16),
          _buildSearchField(),
          const SizedBox(height: 16),
          _buildStatusFilter(),
          const SizedBox(height: 16),
          LabelTypeFilter(
            selectedTypes: _selectedTypes,
            onTypesChanged: (types) {
              setState(() => _selectedTypes = types);
              _loadScans();
            },
            typeCounts: _typeCounts,
            showCount: true,
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
          'Filter History',
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Total: ${_scans.length}',
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
        hintText: 'Search scans...',
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

  Widget _buildStatusFilter() {
    final statuses = _statusCounts.keys.toList()..sort();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in statuses)
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(status),
                  size: 16,
                  color: _selectedStatus == status ? Colors.white : null,
                ),
                const SizedBox(width: 4),
                Text(status),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _selectedStatus == status
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _statusCounts[status].toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: _selectedStatus == status
                          ? Colors.white
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            selected: _selectedStatus == status,
            onSelected: (selected) {
              setState(() {
                _selectedStatus = selected ? status : null;
              });
              _loadScans();
            },
            backgroundColor: Colors.grey[200],
            selectedColor: _getStatusColor(status),
            checkmarkColor: Colors.white,
          ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Icons.check_circle;
      case 'checked out':
        return Icons.shopping_cart;
      case 'lost':
        return Icons.error;
      case 'unresolved':
        return Icons.help;
      default:
        return Icons.circle;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  Widget _buildScansList() {
    final filteredScans = _getFilteredScans();

    // Group scans by date
    final groupedScans = <DateTime, List<dynamic>>{};
    for (var scan in filteredScans) {
      final date = DateTime(
        scan.checkIn.year,
        scan.checkIn.month,
        scan.checkIn.day,
      );
      groupedScans.putIfAbsent(date, () => []).add(scan);
    }

    final dates = groupedScans.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final scans = groupedScans[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateGroupHeader(date),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scans.length,
              itemBuilder: (context, index) {
                final scan = scans[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: _buildScanItem(scan),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateGroupHeader(DateTime date) {
    final isToday = DateTime.now().difference(date).inDays == 0;
    final isYesterday = DateTime.now().difference(date).inDays == 1;

    String dateText;
    if (isToday) {
      dateText = 'Today';
    } else if (isYesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('EEEE, MMMM d, yyyy').format(date);
    }

    final scanCount = _scans.where((scan) {
      final scanDate = DateTime(
        scan.checkIn.year,
        scan.checkIn.month,
        scan.checkIn.day,
      );
      return scanDate == date;
    }).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            dateText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$scanCount scans',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanItem(dynamic scan) {
    final labelType = _getLabelTypeForScan(scan);

    return ScanHistoryItem(
      title: _getScanTitle(scan),
      subtitle: _getScanSubtitle(scan),
      details: _getScanDetails(scan),
      checkIn: scan.checkIn,
      labelType: labelType,
      status: scan.status,
      onTap: () => _showScanDetails(scan),
    );
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

  void _showScanDetails(dynamic scan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getLabelTypeIcon(_getLabelTypeForScan(scan)),
              color: _getLabelTypeColor(_getLabelTypeForScan(scan)),
            ),
            const SizedBox(width: 8),
            Text(_getDialogTitle(scan)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                'Scan Time',
                DateFormat('dd/MM/yyyy HH:mm:ss').format(scan.checkIn),
              ),
              const SizedBox(height: 8),
              if (scan is FGPalletLabel) ...[
                _buildDetailRow('Plate ID', scan.plateId),
                _buildDetailRow('Work Order', scan.workOrder),
                _buildDetailRow('Raw Value', scan.rawValue),
              ] else if (scan is RollLabel) ...[
                _buildDetailRow('Roll ID', scan.rollId),
                _buildDetailRow('Batch Number', scan.batchNumber),
                _buildDetailRow('Sequence Number', scan.sequenceNumber),
              ] else if (scan is FGLocationLabel) ...[
                _buildDetailRow('Location ID', scan.locationId),
                _buildDetailRow('Area Type', scan.areaType),
              ] else if (scan is PaperRollLocationLabel) ...[
                _buildDetailRow('Location ID', scan.locationId),
                _buildDetailRow('Row', scan.rowNumber),
                _buildDetailRow('Position', scan.positionNumber),
              ],
              const SizedBox(height: 16),
              _buildStatusSection(scan),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _updateStatus(scan),
            child: const Text('Update Status'),
          ),
          TextButton(
            onPressed: () => _shareScanDetails(scan),
            child: const Text('Share'),
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

  Widget _buildStatusSection(dynamic scan) {
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
                  color: _getStatusColor(scan.status ?? 'Unknown'),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                scan.status ?? 'Unknown',
                style: const TextStyle(fontSize: 16),
              ),
              const Spacer(),
              Text(
                'Updated: ${DateFormat('dd/MM/yyyy HH:mm').format(scan.statusUpdatedAt ?? scan.checkIn)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (scan.statusNotes != null && scan.statusNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: ${scan.statusNotes}',
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

  Future<void> _updateStatus(dynamic scan) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatusUpdateDialog(
        currentStatus: scan.status,
        currentNotes: scan.statusNotes,
      ),
    );

    if (result != null) {
      try {
        setState(() => _isLoading = true);

        if (scan is FGPalletLabel) {
          await _fgPalletService.updateStatus(
            scan.plateId,
            result['status']!,
            notes: result['notes'],
          );
        } else if (scan is RollLabel) {
          await _rollService.updateStatus(
            scan.rollId,
            result['status']!,
            notes: result['notes'],
          );
        } else if (scan is FGLocationLabel) {
          await _fgLocationService.updateStatus(
            scan.locationId,
            result['status']!,
            notes: result['notes'],
          );
        } else if (scan is PaperRollLocationLabel) {
          await _paperRollLocationService.updateStatus(
            scan.locationId,
            result['status']!,
            notes: result['notes'],
          );
        }

        await _loadScans();

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

  void _shareScanDetails(dynamic scan) {
    final details = _formatScanDetailsForSharing(scan);
    Share.share(details, subject: 'Scan Details');
  }

  String _formatScanDetailsForSharing(dynamic scan) {
    final buffer = StringBuffer();
    buffer.writeln('Scan Details');
    buffer.writeln('-------------');
    buffer.writeln('Type: ${_getLabelTypeName(_getLabelTypeForScan(scan))}');
    buffer.writeln(
        'Scan Time: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(scan.checkIn)}');

    if (scan is FGPalletLabel) {
      buffer.writeln('Plate ID: ${scan.plateId}');
      buffer.writeln('Work Order: ${scan.workOrder}');
      buffer.writeln('Raw Value: ${scan.rawValue}');
    } else if (scan is RollLabel) {
      buffer.writeln('Roll ID: ${scan.rollId}');
      buffer.writeln('Batch Number: ${scan.batchNumber}');
      buffer.writeln('Sequence Number: ${scan.sequenceNumber}');
    } else if (scan is FGLocationLabel) {
      buffer.writeln('Location ID: ${scan.locationId}');
      buffer.writeln('Area Type: ${scan.areaType}');
    } else if (scan is PaperRollLocationLabel) {
      buffer.writeln('Location ID: ${scan.locationId}');
      buffer.writeln('Row: ${scan.rowNumber}');
      buffer.writeln('Position: ${scan.positionNumber}');
    }

    buffer.writeln('Status: ${scan.status ?? 'Unknown'}');
    if (scan.statusNotes != null && scan.statusNotes!.isNotEmpty) {
      buffer.writeln('Notes: ${scan.statusNotes}');
    }

    return buffer.toString();
  }

  String _getLabelTypeName(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return 'FG Pallet';
      case LabelType.roll:
        return 'Roll';
      case LabelType.fgLocation:
        return 'FG Location';
      case LabelType.paperRollLocation:
        return 'Paper Roll Location';
    }
  }

  String _getScanTitle(dynamic scan) {
    if (scan is FGPalletLabel) {
      return 'PLT#: ${scan.plateId}';
    } else if (scan is RollLabel) {
      return 'Roll ID: ${scan.rollId}';
    } else {
      return 'Location: ${(scan as dynamic).locationId}';
    }
  }

  String _getScanSubtitle(dynamic scan) {
    if (scan is FGPalletLabel) {
      return 'Work Order: ${scan.workOrder}';
    } else if (scan is RollLabel) {
      return 'Batch: ${scan.batchNumber}';
    } else if (scan is FGLocationLabel) {
      return 'Area Type: ${scan.areaType}';
    } else {
      return 'Row: ${(scan as PaperRollLocationLabel).rowNumber}';
    }
  }

  String? _getScanDetails(dynamic scan) {
    if (scan is FGPalletLabel) {
      return 'Raw Value: ${scan.rawValue}';
    } else if (scan is RollLabel) {
      return 'Sequence: ${scan.sequenceNumber}';
    }
    return null;
  }

  String _getDialogTitle(dynamic scan) {
    if (scan is FGPalletLabel) return 'FG Pallet Label Details';
    if (scan is RollLabel) return 'Roll Label Details';
    if (scan is FGLocationLabel) return 'FG Location Label Details';
    if (scan is PaperRollLocationLabel) return 'Paper Roll Location Details';
    return 'Label Details';
  }

  LabelType _getLabelTypeForScan(dynamic scan) {
    if (scan is FGPalletLabel) return LabelType.fgPallet;
    if (scan is RollLabel) return LabelType.roll;
    if (scan is FGLocationLabel) return LabelType.fgLocation;
    if (scan is PaperRollLocationLabel) return LabelType.paperRollLocation;
    throw ArgumentError('Unknown scan type');
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
        onRetry: _loadScans,
      );
    }

    if (_scans.isEmpty) {
      return EmptyState(
        message:
            'No scans found${_selectedDateRange != null ? ' in selected date range' : ''}',
        icon: Icons.history,
        onRefresh: _loadScans,
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadScans,
              child: _buildScansList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ExportToExcelButton(
              startDate: _selectedDateRange?.start,
              endDate: _selectedDateRange?.end,
              filterTypes: _selectedTypes,
              customText: 'Export History',
            ),
          ),
        ],
      ),
    );
  }
}

class StatusUpdateDialog extends StatefulWidget {
  final String? currentStatus;
  final String? currentNotes;

  const StatusUpdateDialog({
    super.key,
    this.currentStatus,
    this.currentNotes,
  });

  @override
  State<StatusUpdateDialog> createState() => _StatusUpdateDialogState();
}

class _StatusUpdateDialogState extends State<StatusUpdateDialog> {
  late String _selectedStatus;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus ?? 'Available';
    _notesController = TextEditingController(text: widget.currentNotes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final status in [
                'Available',
                'Checked out',
                'Lost',
                'Unresolved'
              ])
                FilterChip(
                  label: Text(status),
                  selected: _selectedStatus == status,
                  onSelected: (selected) {
                    setState(() => _selectedStatus = status);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'status': _selectedStatus,
            'notes': _notesController.text.trim(),
          }),
          child: const Text('Update'),
        ),
      ],
    );
  }
}
