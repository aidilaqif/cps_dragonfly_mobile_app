import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/location.dart';
import '../services/api_service.dart';

class NewItemDialog extends StatefulWidget {
  final String labelId;

  const NewItemDialog({
    super.key,
    required this.labelId,
  });

  @override
  State<NewItemDialog> createState() => _NewItemDialogState();
}

class _NewItemDialogState extends State<NewItemDialog> {
  final ApiService _apiService = ApiService();
  String? selectedType;
  String? selectedLocation;
  final _formKey = GlobalKey<FormState>();
  List<Location> locations = [];
  bool isLoadingLocations = true;

  // Roll details
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _sizeController = TextEditingController();

  // FG Pallet details
  final _pltNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _totalPiecesController = TextEditingController();

  bool isLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final fetchedLocations = await _apiService.fetchLocations();
      setState(() {
        locations = fetchedLocations;
        isLoadingLocations = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error loading locations: $e';
        isLoadingLocations = false;
      });
    }
  }

  List<Location> _getFilteredLocations() {
    if (selectedType == null) return [];

    return locations.where((location) {
      if (selectedType == 'Roll') {
        return location.typeName == 'Paper Roll Location';
      } else if (selectedType == 'FG Pallet') {
        return location.typeName == 'FG Location';
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLocations = _getFilteredLocations();

    return AlertDialog(
      title: const Text('New Item Details'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Label Type',
                ),
                items: const [
                  DropdownMenuItem(value: 'Roll', child: Text('Roll')),
                  DropdownMenuItem(
                      value: 'FG Pallet', child: Text('FG Pallet')),
                ],
                validator: (value) => value == null ? 'Required' : null,
                onChanged: (value) {
                  setState(() {
                    selectedType = value;
                    selectedLocation = null; // Reset location when type changes
                  });
                },
              ),
              const SizedBox(height: 16),
              if (selectedType != null) ...[
                if (isLoadingLocations)
                  const CircularProgressIndicator()
                else
                  DropdownButtonFormField<String>(
                    value: selectedLocation,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                    ),
                    items: filteredLocations.map((location) {
                      return DropdownMenuItem(
                        value: location.locationId,
                        child: Text(location.locationId),
                      );
                    }).toList(),
                    validator: (value) => value == null ? 'Required' : null,
                    onChanged: (value) {
                      setState(() {
                        selectedLocation = value;
                      });
                    },
                  ),
              ],
              if (selectedType == 'Roll') ...[
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Code'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: _sizeController,
                  decoration: const InputDecoration(labelText: 'Size (mm)'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
              ] else if (selectedType == 'FG Pallet') ...[
                TextFormField(
                  controller: _pltNumberController,
                  decoration: const InputDecoration(labelText: 'PLT Number'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                TextFormField(
                  controller: _totalPiecesController,
                  decoration: const InputDecoration(labelText: 'Total Pieces'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _submitForm,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedLocation == null) {
      setState(() {
        error = 'Please select a location';
      });
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      Map<String, dynamic> details = {
        'location_id': selectedLocation,
      };

      if (selectedType == 'FG Pallet') {
        final pltNumber = int.tryParse(_pltNumberController.text);
        final quantity = int.tryParse(_quantityController.text);
        final totalPieces = int.tryParse(_totalPiecesController.text);

        if (pltNumber == null || quantity == null || totalPieces == null) {
          throw Exception('Invalid number format in one of the fields');
        }

        details.addAll({
          'plt_number': pltNumber,
          'quantity': quantity,
          'work_order_id': '10-2024-00047',
          'total_pieces': totalPieces,
        });
      } else {
        details.addAll({
          'code': _codeController.text,
          'name': _nameController.text,
          'size_mm': int.parse(_sizeController.text),
        });
      }

      print('Submitting form with details:');
      print(json.encode(details));

      final success = await _apiService.createItem(
        widget.labelId,
        selectedType!,
        details,
      );

      if (success) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          error = 'Failed to create item. Please check the submitted data.';
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error creating item: ${e.toString()}';
      });
      print('Error details: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _sizeController.dispose();
    _pltNumberController.dispose();
    _quantityController.dispose();
    _totalPiecesController.dispose();
    super.dispose();
  }
}
