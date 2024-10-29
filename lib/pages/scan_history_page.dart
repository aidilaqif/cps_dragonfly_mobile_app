import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
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

class ScanHistoryPage extends StatefulWidget {
  final PostgreSQLConnection connection;

  const ScanHistoryPage({super.key, required this.connection});

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  late final FGPalletLabelService _fgPalletService;
  late final RollLabelService _rollService;
  late final FGLocationLabelService _fgLocationService;
  late final PaperRollLocationLabelService _paperRollLocationService;
  
  bool _isLoading = true;
  String? _error;
  List<dynamic> _scans = [];
  DateTimeRange? _selectedDateRange;
  List<LabelType> _selectedTypes = LabelType.values.toList();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadScans();
  }

  void _initializeServices() {
    _fgPalletService = FGPalletLabelService(widget.connection);
    _rollService = RollLabelService(widget.connection);
    _fgLocationService = FGLocationLabelService(widget.connection);
    _paperRollLocationService = PaperRollLocationLabelService(widget.connection);
  }

  Future<void> _loadScans() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      List<dynamic> allScans = [];
      
      // Load scans from each selected type
      if (_selectedTypes.contains(LabelType.fgPallet)) {
        final fgScans = await _fgPalletService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
        );
        allScans.addAll(fgScans);
      }

      if (_selectedTypes.contains(LabelType.roll)) {
        final rollScans = await _rollService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
        );
        allScans.addAll(rollScans);
      }

      if (_selectedTypes.contains(LabelType.fgLocation)) {
        final locationScans = await _fgLocationService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
        );
        allScans.addAll(locationScans);
      }

      if (_selectedTypes.contains(LabelType.paperRollLocation)) {
        final paperLocationScans = await _paperRollLocationService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,
        );
        allScans.addAll(paperLocationScans);
      }

      // Sort all scans by check-in time (most recent first)
      allScans.sort((a, b) => b.checkIn.compareTo(a.checkIn));

      setState(() {
        _scans = allScans;
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

  Widget _buildScanItem(dynamic scan) {
    String title;
    String subtitle;
    String? details;
    LabelType type;

    if (scan is FGPalletLabel) {
      title = 'PLT#: ${scan.plateId}';
      subtitle = 'Work Order: ${scan.workOrder}';
      details = 'Raw Value: ${scan.rawValue}';
      type = LabelType.fgPallet;
    } else if (scan is RollLabel) {
      title = 'Roll ID: ${scan.rollId}';
      subtitle = 'Batch: ${scan.batchNumber}';
      details = 'Sequence: ${scan.sequenceNumber}';
      type = LabelType.roll;
    } else if (scan is FGLocationLabel) {
      title = 'Location: ${scan.locationId}';
      subtitle = 'Area Type: ${scan.areaType}';
      type = LabelType.fgLocation;
    } else if (scan is PaperRollLocationLabel) {
      title = 'Location: ${scan.locationId}';
      subtitle = 'Row: ${scan.rowNumber}, Position: ${scan.positionNumber}';
      type = LabelType.paperRollLocation;
    } else {
      return const SizedBox.shrink();
    }

    return ScanHistoryItem(
      title: title,
      subtitle: subtitle,
      details: details,
      checkIn: scan.checkIn,
      labelType: type,
      onTap: () => _showScanDetails(scan),
    );
  }

  void _showScanDetails(dynamic scan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getScanTitle(scan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Scan Time', DateFormat('dd/MM/yyyy HH:mm:ss').format(scan.checkIn)),
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
          ],
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
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getScanTitle(dynamic scan) {
    if (scan is FGPalletLabel) return 'FG Pallet Label Details';
    if (scan is RollLabel) return 'Roll Label Details';
    if (scan is FGLocationLabel) return 'FG Location Label Details';
    if (scan is PaperRollLocationLabel) return 'Paper Roll Location Details';
    return 'Scan Details';
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
          Row(
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
            ],
          ),
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
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(fontSize: 16),
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
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey.withOpacity(0.05),
            ),
          ),
          const SizedBox(height: 16),
          LabelTypeFilter(
            selectedTypes: _selectedTypes,
            onTypesChanged: (types) {
              setState(() => _selectedTypes = types);
              _loadScans();
            },
          ),
        ],
      ),
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
        ],
      ),
    );
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

    final filteredScans = _getFilteredScans();

    if (filteredScans.isEmpty) {
      return EmptyState(
        message: 'No scans found${_selectedDateRange != null ? ' in selected date range' : ''}',
        icon: Icons.history,
        onRefresh: _loadScans,
      );
    }

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
                  offset: const Offset(0, -2)
                ),
              ],
            ),
            child: ExportToExcelButton(
              startDate: _selectedDateRange?.start,
              endDate: _selectedDateRange?.end,
              filterTypes: _selectedTypes,
            ),
          ),
        ],
      ),
    );
  }
}