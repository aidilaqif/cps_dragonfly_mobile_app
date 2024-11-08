import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  String? selectedType;
  final _formKey = GlobalKey<FormState>();

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
  Widget build(BuildContext context) {
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
                  });
                },
              ),
              const SizedBox(height: 16),
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

  // new_item_dialog.dart

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final apiService = ApiService();

      Map<String, dynamic> details;
      if (selectedType == 'FG Pallet') {
        // Convert string inputs to appropriate types
        final pltNumber = int.tryParse(_pltNumberController.text);
        final quantity = int.tryParse(_quantityController.text);
        final totalPieces = int.tryParse(_totalPiecesController.text);

        if (pltNumber == null || quantity == null || totalPieces == null) {
          throw Exception('Invalid number format in one of the fields');
        }

        details = {
          'plt_number': pltNumber,
          'quantity': quantity,
          'work_order_id': '10-2024-00047', // Add work order ID if needed
          'total_pieces': totalPieces
        };

        print('Submitting FG Pallet with details:'); // Debug log
        print(json.encode(details)); // Debug log
      } else {
        // Roll details handling (keep existing code)
        details = {
          'code': _codeController.text,
          'name': _nameController.text,
          'size_mm': int.parse(_sizeController.text),
        };
      }

      final success = await apiService.createItem(
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
      print('Error details: $e'); // Debug log
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
