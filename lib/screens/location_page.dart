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
        backgroundColor: const Color(0XFF030128),
        title: const Text(
          'Locations',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: SizedBox(
        width: 150,
        child: FloatingActionButton(
          backgroundColor: const Color(0XFF584ADD),
          onPressed: _showAddLocationDialog,
          child: const Text(
            'Add New Location',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Container(
        color: const Color(0XFFF4F4F4),
        height: double.infinity,
        child: Center(
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
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(
              Icons.location_on,
              color: Colors.redAccent,
            ),
            title: Text(
              location.locationId,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              location.typeName,
              style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: Color(0XFF9D9DA1),
                  fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}
