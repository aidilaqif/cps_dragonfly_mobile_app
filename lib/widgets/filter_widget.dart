import 'package:flutter/material.dart';
import '../models/location.dart';

class FilterWidget extends StatefulWidget {
  final String? selectedType;
  final String? selectedStatus;
  final String? selectedLocation;
  final List<Location> locations;
  final Function(String?) onTypeChanged;
  final Function(String?) onStatusChanged;
  final Function(String?) onLocationChanged;
  final VoidCallback onClearFilters;
  final bool isVisible;
  final int activeFilterCount;

  const FilterWidget({
    super.key,
    this.selectedType,
    this.selectedStatus,
    this.selectedLocation,
    required this.locations,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onLocationChanged,
    required this.onClearFilters,
    required this.isVisible,
    required this.activeFilterCount,
  });

  @override
  State<FilterWidget> createState() => _FilterWidgetState();
}

class _FilterWidgetState extends State<FilterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FilterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _animation,
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onClearFilters,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTypeFilter(),
                    const SizedBox(width: 8),
                    _buildStatusFilter(),
                    const SizedBox(width: 8),
                    _buildLocationFilter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: widget.selectedType,
        hint: const Text('Type'),
        underline: const SizedBox(),
        items: <String>['Roll', 'FG Pallet'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList()
          ..insert(
            0,
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Types'),
            ),
          ),
        onChanged: widget.onTypeChanged,
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: widget.selectedStatus,
        hint: const Text('Status'),
        underline: const SizedBox(),
        items: <String>['Available', 'Checked Out', 'Lost', 'Unresolved']
            .map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList()
          ..insert(
            0,
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Status'),
            ),
          ),
        onChanged: widget.onStatusChanged,
      ),
    );
  }

  Widget _buildLocationFilter() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: widget.selectedLocation,
        hint: const Text('Location'),
        underline: const SizedBox(),
        items: widget.locations.map((location) {
          return DropdownMenuItem<String>(
            value: location.locationId,
            child: Text(location.locationId),
          );
        }).toList()
          ..insert(
            0,
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Locations'),
            ),
          ),
        onChanged: widget.onLocationChanged,
      ),
    );
  }
}
