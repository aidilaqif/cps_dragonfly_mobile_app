import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../widgets/export_dialog.dart';
import '../widgets/item_card.dart';
import '../widgets/filter_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  List<Item> items = [];
  List<Location> locations = [];
  bool isLoading = true;
  String? error;

  // Filter states
  String? selectedType;
  String? selectedStatus;
  String? selectedLocation;
  bool isFilterVisible = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      fetchItems(),
      _fetchLocations(),
    ]);
  }

  Future<void> _fetchLocations() async {
    try {
      final fetchedLocations = await _apiService.fetchLocations();
      setState(() {
        locations = fetchedLocations;
      });
    } catch (e) {
      print('Error fetching locations: $e');
    }
  }

  Future<void> fetchItems() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final fetchedItems = await _apiService.fetchItems();
      setState(() {
        items = fetchedItems;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  List<Item> get filteredItems {
    return items.where((item) {
      bool matchesType = selectedType == null || item.labelType == selectedType;
      bool matchesStatus =
          selectedStatus == null || item.status == selectedStatus;
      bool matchesLocation =
          selectedLocation == null || item.location == selectedLocation;
      return matchesType && matchesStatus && matchesLocation;
    }).toList();
  }

  int get activeFilterCount {
    return [selectedType, selectedStatus, selectedLocation]
        .where((filter) => filter != null)
        .length;
  }

  void _toggleFilters() {
    setState(() {
      isFilterVisible = !isFilterVisible;
    });
  }

  void _clearFilters() {
    setState(() {
      selectedType = null;
      selectedStatus = null;
      selectedLocation = null;
    });
  }

  Future<void> _exportData() async {
    try {
      setState(() => isLoading = true);
      await _apiService.exportToCSV();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => ExportDialog(
        onExport: _exportData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CPS Inventory'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _toggleFilters,
                tooltip: 'Toggle Filters',
              ),
              if (activeFilterCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      activeFilterCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: isLoading ? null : _showExportDialog,
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              FilterWidget(
                selectedType: selectedType,
                selectedStatus: selectedStatus,
                selectedLocation: selectedLocation,
                locations: locations,
                onTypeChanged: (value) => setState(() => selectedType = value),
                onStatusChanged: (value) =>
                    setState(() => selectedStatus = value),
                onLocationChanged: (value) =>
                    setState(() => selectedLocation = value),
                onClearFilters: _clearFilters,
                isVisible: isFilterVisible,
                activeFilterCount: activeFilterCount,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: fetchItems,
                  child: _buildItemsList(),
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchItems,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final items = filteredItems;

    if (items.isEmpty) {
      return const Center(
        child: Text('No items found'),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ItemCard(item: item);
      },
    );
  }
}
