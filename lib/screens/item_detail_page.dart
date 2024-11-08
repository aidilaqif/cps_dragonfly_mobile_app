// lib/screens/item_detail_page.dart
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';

class ItemDetailPage extends StatefulWidget {
  final Item item;

  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final ApiService _apiService = ApiService();
  bool isLoading = false;
  String? error;
  late String currentStatus;
  late String currentLocation;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.item.status;
    currentLocation = widget.item.location;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final success = await _apiService.updateItemStatus(
        widget.item.labelId,
        newStatus,
      );

      if (success) {
        setState(() {
          currentStatus = newStatus;
          isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateLocation(String newLocation) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final success = await _apiService.updateItemLocation(
        widget.item.labelId,
        newLocation,
      );

      if (success) {
        setState(() {
          currentLocation = newLocation;
          isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating location: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusOption('Available'),
              _buildStatusOption('Checked Out'),
              _buildStatusOption('Lost'),
              _buildStatusOption('Unresolved'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusOption(String status) {
    return ListTile(
      title: Text(status),
      leading: Radio<String>(
        value: status,
        groupValue: currentStatus,
        onChanged: (String? value) {
          Navigator.pop(context);
          if (value != null) {
            _updateStatus(value);
          }
        },
      ),
      onTap: () {
        Navigator.pop(context);
        _updateStatus(status);
      },
    );
  }

  void _showLocationUpdateDialog() async {
    try {
      final locations = await _apiService.fetchLocations();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Update Location'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: locations.length,
                itemBuilder: (context, index) {
                  final location = locations[index];
                  return ListTile(
                    title: Text(location.locationId),
                    subtitle: Text(location.typeName),
                    onTap: () {
                      Navigator.pop(context);
                      _updateLocation(location.locationId);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading locations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildStatusSection(),
                const SizedBox(height: 16),
                _buildLocationSection(),
                if (widget.item.labelType == 'Roll') ...[
                  const SizedBox(height: 24),
                  _buildRollDetailsCard(),
                ] else if (widget.item.labelType == 'FG Pallet') ...[
                  const SizedBox(height: 24),
                  _buildPalletDetailsCard(),
                ],
              ],
            ),
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

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.item.labelId,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                _buildStatusChip(currentStatus),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow(
              icon: Icons.category_outlined,
              label: 'Type',
              value: widget.item.labelType,
            ),
            _buildDetailRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: currentLocation,
            ),
            _buildDetailRow(
              icon: Icons.access_time,
              label: 'Last Scan',
              value: DateFormatter.formatDateTime(widget.item.lastScanTime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.edit_note),
        title: const Text('Update Status'),
        subtitle: Text('Current: $currentStatus'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: _showStatusUpdateDialog,
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.location_on),
        title: const Text('Update Location'),
        subtitle: Text('Current: $currentLocation'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: _showLocationUpdateDialog,
      ),
    );
  }

  Widget _buildRollDetailsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Roll Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(height: 24),
            // Add roll-specific details here when available
            Text('Additional roll details will be displayed here'),
          ],
        ),
      ),
    );
  }

  Widget _buildPalletDetailsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pallet Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(height: 24),
            // Add pallet-specific details here when available
            Text('Additional pallet details will be displayed here'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
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

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status.toLowerCase()) {
      case 'available':
        chipColor = Colors.green;
        break;
      case 'checked out':
        chipColor = Colors.orange;
        break;
      case 'lost':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  String _formatDateTime(String dateTime) {
    final dt = DateTime.parse(dateTime);
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute}';
  }
}
