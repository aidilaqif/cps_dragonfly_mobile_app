import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:intl/intl.dart';
import '../services/fg_pallet_label_service.dart';
import '../services/roll_label_service.dart';
import '../services/fg_location_label_service.dart';
import '../services/paper_roll_location_label_service.dart';
import '../models/fg_pallet_label.dart';
import '../models/roll_label.dart';
import '../models/fg_location_label.dart';
import '../models/paper_roll_location_label.dart';
import '../models/label_types.dart';
import '../widgets/export_to_csv_button.dart';

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
  Map<LabelType, bool> _isExpanded = {
    for (var type in LabelType.values) type: true
  };
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
        _fgPalletService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,  // This parameter name now matches
        ),
        _rollService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,  // This parameter name now matches
        ),
        _fgLocationService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,  // This parameter name now matches
        ),
        _paperRollLocationService.list(
          startDate: _selectedDateRange?.start,
          endDate: _selectedDateRange?.end,  // This parameter name now matches
        ),
      ]);

      setState(() {
        _labelData = {
          LabelType.fgPallet: futures[0],
          LabelType.roll: futures[1],
          LabelType.fgLocation: futures[2],
          LabelType.paperRollLocation: futures[3],
        };
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
                 fgLabel.workOrder.toLowerCase().contains(_searchQuery.toLowerCase());
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

  Widget _buildLabelCard(dynamic label, LabelType type) {
    final isRescan = label.isRescan;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: _getLabelTypeIcon(type),
        title: Text(
          _getLabelTitle(label, type),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type == LabelType.fgPallet)
              Text(
                'Work Order: ${(label as FGPalletLabel).workOrder}',
                style: const TextStyle(fontSize: 14),
              ),
            Text(
              'Scanned: ${_formatDateTime(label.timeLog)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (isRescan)
              Text(
                'Rescan',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSection(LabelType type) {
    final filteredLabels = _getFilteredLabels(type);
    
    if (filteredLabels.isEmpty) return const SizedBox.shrink();

    final rescanCount = filteredLabels.where((l) => l.isRescan).length;
    final totalScans = filteredLabels.length;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          ListTile(
            leading: _getLabelTypeIcon(type),
            title: Text(
              _getLabelTypeName(type),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '$totalScans scans (${rescanCount > 0 ? '$rescanCount rescans, ' : ''}'
              '${totalScans - rescanCount} unique)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${filteredLabels.length} items',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded[type] == true ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() => _isExpanded[type] = !(_isExpanded[type] ?? false));
                  },
                ),
              ],
            ),
          ),
          if (_isExpanded[type] == true)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredLabels.length,
              itemBuilder: (context, index) => _buildLabelCard(
                filteredLabels[index], 
                type,
              ),
            ),
        ],
      ),
    );
  }

  String _getLabelTitle(dynamic label, LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return 'PLT#: ${(label as FGPalletLabel).plateId}';
      case LabelType.roll:
        return 'Roll ID: ${(label as RollLabel).rollId}';
      case LabelType.fgLocation:
        return 'Location: ${(label as FGLocationLabel).locationId}';
      case LabelType.paperRollLocation:
        return 'Location: ${(label as PaperRollLocationLabel).locationId}';
    }
  }

  Icon _getLabelTypeIcon(LabelType type) {
    switch (type) {
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

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
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
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ...LabelType.values.map(_buildTypeSection),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ExportToCsvButton(
                    filterTypes: LabelType.values.toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}