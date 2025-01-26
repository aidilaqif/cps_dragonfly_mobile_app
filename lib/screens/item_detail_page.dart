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
  Map<String, dynamic>? palletDetails;
  Map<String, dynamic>? rollDetails;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.item.status;
    currentLocation = widget.item.location;
    _fetchItemDetails();
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

  Future<void> _fetchItemDetails() async {
    try {
      setState(() => isLoading = true);
      final details = await _apiService.checkItemExists(widget.item.labelId);

      if (details['exists'] == true &&
          details['item'] != null &&
          details['item']['details'] != null) {
        setState(() {
          if (widget.item.labelType == 'Roll') {
            rollDetails = details['item']['details'] as Map<String, dynamic>;
          } else if (widget.item.labelType == 'FG Pallet') {
            palletDetails = details['item']['details'] as Map<String, dynamic>;
          }
        });
      }
    } catch (e) {
      print('Error fetching item details: $e');
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() => isLoading = false);
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
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0XFF030128),
        title: const Text(
          'Item Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
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
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
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
        title: const Text('Update Status', style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),),
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
        title: const Text('Update Location',style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Roll Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (rollDetails != null) ...[
              // Roll specifications
              Text(
                'Specifications',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      icon: Icons.qr_code,
                      label: 'Code',
                      value: rollDetails!['code'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      icon: Icons.label,
                      label: 'Name',
                      value: rollDetails!['name'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      icon: Icons.straighten,
                      label: 'Size',
                      value: '${rollDetails!['size_mm'] ?? 'N/A'} mm',
                    ),
                  ],
                ),
              ),

              // Tracking Information
              const SizedBox(height: 24),
              Text(
                'Tracking Information',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildTrackingInfo(
                      icon: Icons.copy,
                      label: 'Label ID',
                      value: widget.item.labelId,
                    ),
                    const Divider(height: 16),
                    _buildTrackingInfo(
                      icon: Icons.location_on,
                      label: 'Location',
                      value: currentLocation,
                    ),
                    const Divider(height: 16),
                    _buildTrackingInfo(
                      icon: Icons.access_time,
                      label: 'Last Updated',
                      value: DateFormatter.formatDateTime(
                          widget.item.lastScanTime),
                    ),
                  ],
                ),
              ),

              // Status section
              const SizedBox(height: 24),
              Text(
                'Current Status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(currentStatus).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(currentStatus),
                      color: _getStatusColor(currentStatus),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentStatus,
                      style: TextStyle(
                        color: _getStatusColor(currentStatus),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!isLoading) ...[
              const Center(
                child: Text('No roll details available'),
              ),
            ],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pallet Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (palletDetails != null) ...[
              _buildDetailRow(
                icon: Icons.numbers,
                label: 'PLT Number',
                value: '${palletDetails!['plt_number'] ?? 'N/A'}',
              ),
              _buildDetailRow(
                icon: Icons.shopping_cart,
                label: 'Quantity',
                value: '${palletDetails!['quantity'] ?? 0} pcs',
              ),
              _buildDetailRow(
                icon: Icons.assignment,
                label: 'Work Order ID',
                value: palletDetails!['work_order_id'] ?? 'N/A',
              ),
              _buildDetailRow(
                icon: Icons.inventory_2,
                label: 'Total Pieces',
                value: '${palletDetails!['total_pieces'] ?? 0} pcs',
              ),

              // Calculate and show completion percentage
              if (palletDetails!['total_pieces'] != null &&
                  palletDetails!['quantity'] != null &&
                  palletDetails!['total_pieces'] != 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Completion Progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (palletDetails!['quantity'] as num) /
                      (palletDetails!['total_pieces'] as num),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${((palletDetails!['quantity'] as num) / (palletDetails!['total_pieces'] as num) * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],

              // Additional metadata
              const SizedBox(height: 24),
              Text(
                'Tracking Information',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildTrackingInfo(
                      icon: Icons.copy,
                      label: 'Label ID',
                      value: widget.item.labelId,
                    ),
                    const Divider(height: 16),
                    _buildTrackingInfo(
                      icon: Icons.location_on,
                      label: 'Location',
                      value: currentLocation,
                    ),
                    const Divider(height: 16),
                    _buildTrackingInfo(
                      icon: Icons.access_time,
                      label: 'Last Updated',
                      value: DateFormatter.formatDateTime(
                          widget.item.lastScanTime),
                    ),
                  ],
                ),
              ),
            ] else if (!isLoading) ...[
              const Center(
                child: Text('No pallet details available'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
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
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
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
        chipColor = Color(0XFF34B57E);
        break;
      case 'checked out':
        chipColor = Colors.deepOrange;
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'checked out':
        return Colors.orange;
      case 'lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Icons.check_circle;
      case 'checked out':
        return Icons.shopping_cart;
      case 'lost':
        return Icons.error;
      default:
        return Icons.help;
    }
  }
}
