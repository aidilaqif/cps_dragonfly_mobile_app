import 'package:flutter/material.dart';
import '../models/location.dart';
import '../services/api_service.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final ApiService _apiService = ApiService();
  bool isLoading = true;
  String? error;
  List<Location> locations = [];

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final fetchedLocations = await _apiService.fetchLocations();
      setState(() {
        locations = fetchedLocations;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _addLocation(String locationId, String typeName) async {
    try {
      await _apiService.createLocation(locationId, typeName);
      _fetchLocations(); // Refresh the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding location: $e')),
        );
      }
    }
  }

  void _showAddLocationDialog() {
    final locationIdController = TextEditingController();
    final typeNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: locationIdController,
              decoration: const InputDecoration(
                labelText: 'Location ID',
                hintText: 'Enter location ID',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: typeNameController,
              decoration: const InputDecoration(
                labelText: 'Location Type',
                hintText: 'Enter location type',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addLocation(
                locationIdController.text,
                typeNameController.text,
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Locations'),
      ),
      body: _buildBody(),
      floatingActionButton: SizedBox(
        width: 150,
        child: FloatingActionButton(
          onPressed: _showAddLocationDialog,
          child: Text('Add New Location'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchLocations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (locations.isEmpty) {
      return const Center(
        child: Text('No locations found'),
      );
    }

    return ListView.builder(
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final location = locations[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(location.locationId),
            subtitle: Text(location.typeName),
          ),
        );
      },
    );
  }
}