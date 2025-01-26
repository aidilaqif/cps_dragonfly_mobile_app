import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../widgets/new_item_dialog.dart';

class ScanPage extends StatefulWidget {
  final VoidCallback onScanSuccess;

  const ScanPage({
    super.key,
    required this.onScanSuccess,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ApiService _apiService = ApiService();
  final MobileScannerController _scannerController = MobileScannerController();
  String _lastScan = '';
  bool _isLoading = false;
  String? _error;
  String? _success;
  bool _isScanning = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isLoading) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? barcodeScanRes = barcodes.first.rawValue;
    if (barcodeScanRes == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _success = null;
        _lastScan = barcodeScanRes;
      });

      // Extract label ID from scan value
      String labelId;
      if (barcodeScanRes.contains('-')) {
        // FG Pallet format: 2410-000008-10202400047
        labelId = barcodeScanRes.split('-').sublist(0, 2).join('-');
      } else {
        // Roll format: 24B00012
        labelId = barcodeScanRes;
      }

      print('Scanned Label ID: $labelId'); // Debug log

      // Check if item exists
      final result = await _apiService.checkItemExists(labelId);
      final bool exists = result['exists'] as bool;
      print('Item exists: $exists'); // Debug log

      if (!exists) {
        // Show dialog to create new item
        if (mounted) {
          setState(() => _isScanning = false);
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => NewItemDialog(labelId: labelId),
          );

          print('Dialog result: $result'); // Debug log

          if (result == true) {
            setState(() {
              _success = 'Successfully added new item: $labelId';
              widget.onScanSuccess();
            });
          }
        }
      } else {
        // Update existing item status
        final success =
            await _apiService.updateItemStatus(labelId, 'Available');
        print('Update status result: $success'); // Debug log

        if (success) {
          setState(() {
            _success = 'Successfully updated item: $labelId';
            widget.onScanSuccess();
          });
        }
      }
    } catch (e) {
      print('Error in scan detection: $e'); // Debug log
      setState(() {
        _error = 'Error: $e';
        _success = null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text('Scan Inventory Items',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600
          ),
          ),
          backgroundColor: const Color(0XFF030128),
        ),
        Expanded(
          child: _isScanning
              ? Stack(
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            color: Colors.white,
                            icon: const Icon(Icons.flash_on),
                            onPressed: () => _scannerController.toggleTorch(),
                          ),
                          IconButton(
                            color: Colors.white,
                            icon: const Icon(Icons.flip_camera_ios),
                            onPressed: () => _scannerController.switchCamera(),
                          ),
                          IconButton(
                            color: Colors.white,
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _isScanning = false),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _isScanning = true),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Start Scanning'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (_lastScan.isNotEmpty) ...[
                        Text('Last scan: $_lastScan'),
                        const SizedBox(height: 16),
                      ],
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      if (_success != null)
                        Text(
                          _success!,
                          style: const TextStyle(color: Colors.green),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
