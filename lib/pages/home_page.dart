import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
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
  
  Map<LabelType, List<dynamic>> _labelData = {};
  Map<LabelType, bool> _isExpanded = {
    LabelType.fgPallet: true,
    LabelType.roll: true,
    LabelType.fgLocation: true,
    LabelType.paperRollLocation: true,
  };

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
        _fgPalletService.fetchLabels(),
        _rollService.fetchLabels(),
        _fgLocationService.fetchLabels(),
        _paperRollLocationService.fetchLabels(),
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
      setState(() {
        _error = 'Error loading data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM dd, yyyy HH:mm');
    return formatter.format(dateTime);
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

  Widget _buildLabelCard(dynamic label, LabelType type) {
    String title;
    String? subtitle;
    
    switch (type) {
      case LabelType.fgPallet:
        final fgLabel = label as FGPalletLabel;
        title = 'PLT#: ${fgLabel.plateId}';
        subtitle = 'WO: ${fgLabel.workOrder}';
        break;
      case LabelType.roll:
        final rollLabel = label as RollLabel;
        title = 'Roll ID: ${rollLabel.rollId}';
        break;
      case LabelType.fgLocation:
        final locationLabel = label as FGLocationLabel;
        title = 'Location: ${locationLabel.locationId}';
        break;
      case LabelType.paperRollLocation:
        final locationLabel = label as PaperRollLocationLabel;
        title = 'Location: ${locationLabel.locationId}';
        break;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: _getLabelTypeIcon(type),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            Text(
              'Scanned: ${_formatDateTime(label.timeLog)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(LabelType type, List<dynamic> items) {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded[type] = !(_isExpanded[type] ?? false);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _getLabelTypeIcon(type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getLabelTypeName(type),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${items.length} items',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _isExpanded[type] ?? false
                  ? Icons.expand_less
                  : Icons.expand_more,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelTypeSection(LabelType type) {
    final items = _labelData[type] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(type, items),
        if (_isExpanded[type] ?? false)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Column(
              children: [
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No ${_getLabelTypeName(type)} scanned yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _buildLabelCard(items[index], type),
                  ),
              ],
            ),
          ),
      ],
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...LabelType.values.map((type) {
                        final count = _labelData[type]?.length ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              _getLabelTypeIcon(type),
                              const SizedBox(width: 8),
                              Text(
                                '$count ${_getLabelTypeName(type)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Center(child: ExportToCsvButton()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Label Type Sections
              ...LabelType.values.map((type) => Column(
                children: [
                  _buildLabelTypeSection(type),
                  const SizedBox(height: 16),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}