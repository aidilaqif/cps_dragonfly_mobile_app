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

  Widget _buildLabelSection(LabelType type) {
    final filteredLabels = _getFilteredLabels(type);
    if (filteredLabels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            _getLabelTypeName(type),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredLabels.length,
          itemBuilder: (context, index) {
            final label = filteredLabels[index];
            return ScanItemCard(
              title: _getLabelTitle(label),
              subtitle: _getLabelSubtitle(label),
              details: _getLabelDetails(label),
              checkIn: label.checkIn,
              labelType: type,
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
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
                  border: const OutlineInputBorder(),
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
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              children: [
                ...LabelType.values
                    .where((type) => _selectedTypes.contains(type))
                    .map(_buildLabelSection),
                Padding(
                  padding: const EdgeInsets.all(16),
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
    );
  }
}