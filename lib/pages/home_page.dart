import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:postgres/postgres.dart';
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
  final PostgreSQLConnection connection;

  const HomePage({super.key, required this.connection});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final FGPalletLabelService _fgPalletService;
  late final RollLabelService _rollService;
  late final FGLocationLabelService _fgLocationService;
  late final PaperRollLocationLabelService _paperRollLocationService;
  
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  List<LabelType> _selectedTypes = LabelType.values.toList();
  
  Map<LabelType, List<dynamic>> _labelData = {};

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
  }

  void _initializeServices() {
    _fgPalletService = FGPalletLabelService(widget.connection);
    _rollService = RollLabelService(widget.connection);
    _fgLocationService = FGLocationLabelService(widget.connection);
    _paperRollLocationService = PaperRollLocationLabelService(widget.connection);
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final futures = await Future.wait([
        if (_selectedTypes.contains(LabelType.fgPallet))
          _fgPalletService.list(
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
          ),
        if (_selectedTypes.contains(LabelType.roll))
          _rollService.list(
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
          ),
        if (_selectedTypes.contains(LabelType.fgLocation))
          _fgLocationService.list(
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
          ),
        if (_selectedTypes.contains(LabelType.paperRollLocation))
          _paperRollLocationService.list(
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
          ),
      ]);

      setState(() {
        _labelData = {};
        var index = 0;
        if (_selectedTypes.contains(LabelType.fgPallet)) {
          _labelData[LabelType.fgPallet] = futures[index++];
        }
        if (_selectedTypes.contains(LabelType.roll)) {
          _labelData[LabelType.roll] = futures[index++];
        }
        if (_selectedTypes.contains(LabelType.fgLocation)) {
          _labelData[LabelType.fgLocation] = futures[index++];
        }
        if (_selectedTypes.contains(LabelType.paperRollLocation)) {
          _labelData[LabelType.paperRollLocation] = futures[index];
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
    if (_searchQuery.isEmpty) return labels;

    return labels.where((label) {
      switch (type) {
        case LabelType.fgPallet:
          final fgLabel = label as FGPalletLabel;
          return fgLabel.plateId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 fgLabel.workOrder.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 fgLabel.rawValue.toLowerCase().contains(_searchQuery.toLowerCase());
        case LabelType.roll:
          final rollLabel = label as RollLabel;
          return rollLabel.rollId.toLowerCase().contains(_searchQuery.toLowerCase());
        case LabelType.fgLocation:
          final locationLabel = label as FGLocationLabel;
          return locationLabel.locationId.toLowerCase().contains(_searchQuery.toLowerCase());
        case LabelType.paperRollLocation:
          final locationLabel = label as PaperRollLocationLabel;
          return locationLabel.locationId.toLowerCase().contains(_searchQuery.toLowerCase());
      }
    }).toList();
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            'Filters',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
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
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search labels...',
              prefixIcon: const Icon(Icons.search),
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
              _loadData();
            },
          ),
        ],
      ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _getLabelTypeIcon(type),
                  color: _getLabelTypeColor(type),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  _getLabelTypeName(type),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getLabelTypeColor(type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filteredLabels.length}',
                    style: TextStyle(
                      color: _getLabelTypeColor(type),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredLabels.length,
            itemBuilder: (context, index) {
              final label = filteredLabels[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ScanItemCard(
                  title: _getLabelTitle(label),
                  subtitle: _getLabelSubtitle(label),
                  details: _getLabelDetails(label),
                  checkIn: label.checkIn,
                  labelType: type,
                  onTap: () => _showLabelDetails(label),
                ),
              );
            },
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
                DateFormat('dd/MM/yyyy HH:mm:ss').format(label.checkIn)
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
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
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDialogTitle(dynamic label) {
    if (label is FGPalletLabel) return 'FG Pallet Label Details';
    if (label is RollLabel) return 'Roll Label Details';
    if (label is FGLocationLabel) return 'FG Location Label Details';
    if (label is PaperRollLocationLabel) return 'Paper Roll Location Details';
    return 'Label Details';
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

  String _getLabelTitle(dynamic label) {
    if (label is FGPalletLabel) {
      return 'PLT#: ${label.plateId}';
    } else if (label is RollLabel) {
      return 'Roll ID: ${label.rollId}';
    } else {
      return 'Location: ${(label as dynamic).locationId}';
    }
  }

  String _getLabelSubtitle(dynamic label) {
    if (label is FGPalletLabel) {
      return 'Work Order: ${label.workOrder}';
    } else if (label is RollLabel) {
      return 'Batch: ${label.batchNumber}';
    } else if (label is FGLocationLabel) {
      return 'Area Type: ${label.areaType}';
    } else {
      return 'Row: ${(label as PaperRollLocationLabel).rowNumber}';
    }
  }

  String? _getLabelDetails(dynamic label) {
    if (label is FGPalletLabel) {
      return 'Raw Value: ${label.rawValue}';
    } else if (label is RollLabel) {
      return 'Sequence: ${label.sequenceNumber}';
    }
    return null;
  }

  Color _getLabelTypeColor(dynamic label) {
    if (label is FGPalletLabel) return Colors.blue;
    if (label is RollLabel) return Colors.green;
    if (label is FGLocationLabel) return Colors.orange;
    if (label is PaperRollLocationLabel) return Colors.purple;
    return Colors.grey;
  }

  IconData _getLabelTypeIcon(dynamic label) {
    if (label is FGPalletLabel) return Icons.inventory_2;
    if (label is RollLabel) return Icons.rotate_right;
    if (label is FGLocationLabel) return Icons.location_on;
    if (label is PaperRollLocationLabel) return Icons.location_searching;
    return Icons.label;
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
        message: 'No scans found${_selectedDateRange != null ? ' in selected date range' : ''}',
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