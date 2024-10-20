import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cps_dragonfly_4_mobile_app/services/scan_service.dart';
import 'package:cps_dragonfly_4_mobile_app/models/fg_pallet_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/roll_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';

class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  final ScanService _scanService = ScanService();
  MobileScannerController? _controller;
  bool _isScanning = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: true,
      );
      _isScanning = true;
    });
  }

  Future<void> _showSessionDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Scanning Session'),
          content: const Text('Would you like to start a new scanning session or continue the previous one?'),
          actions: <Widget>[
            TextButton(
              child: const Text('New Session'),
              onPressed: () {
                _scanService.startNewSession();
                Navigator.of(context).pop();
                _startScanning();
              },
            ),
            if (_scanService.sessions.isNotEmpty)
              TextButton(
                child: const Text('Continue Last'),
                onPressed: () {
                  _scanService.continueLastSession();
                  Navigator.of(context).pop();
                  _startScanning();
                },
              ),
          ],
        );
      },
    );
  }

  void _stopScanning() {
    setState(() {
      _controller?.dispose();
      _controller = null;
      _isScanning = false;
    });
    _scanService.endCurrentSession();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isScanning) {
      return Center(
        child: ElevatedButton(
          onPressed: _showSessionDialog,
          child: const Text('Start Scanning'),
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            final image = capture.image;
            
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              final value = barcodes.first.rawValue!;
              
              // Check if exists in current session
              if (_scanService.isValueExistsInCurrentSession(value)) {
                _showResultDialog(
                  'Duplicate in Current Session',
                  value,
                  null,
                  image,
                  isDuplicate: true,
                );
                return;
              }

              // Check if exists in other sessions
              bool existsInOtherSessions = _scanService.isValueExistsInOtherSessions(value);

              // Process the scanned code
              bool processed = _scanService.processScannedCode(value);
              if (processed) {
                _showResultDialog(
                  existsInOtherSessions ? 'Found in Previous Session' : 'New Code',
                  value,
                  _getLabelTypeFromValue(value),
                  image,
                  isDuplicate: existsInOtherSessions,
                );
              } else {
                _showResultDialog(
                  'Invalid Format',
                  value,
                  null,
                  image,
                  isInvalid: true,
                );
              }
            }
          },
        ),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton(
              onPressed: _stopScanning,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Stop Scanning'),
            ),
          ),
        ),
      ],
    );
  }

  LabelType? _getLabelTypeFromValue(String value) {
    if (FGPalletLabel.fromScanData(value) != null) {
      return LabelType.fgPallet;
    }
    if (RollLabel.fromScanData(value) != null) {
      return LabelType.roll;
    }
    return null;
  }

  String _getLabelTypeName(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return 'FG Pallet Label';
      case LabelType.roll:
        return 'Roll Label';
      case LabelType.fgLocation:
        return 'FG Location Label';
      case LabelType.paperRollLocation:
        return 'Paper Roll Location Label';
    }
  }

  Widget _buildScanDetails(String value, LabelType? type) {
    if (type == null) {
      return Text('Raw Value: $value');
    }
    if (type == LabelType.fgPallet) {
      final label = FGPalletLabel.fromScanData(value);
      if (label != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Label Type: ${_getLabelTypeName(type)}'),
            Text('Plate ID: ${label.plateId}'),
            Text('Work Order: ${label.workOrder}'),
          ],
        );
      }
    } else if (type == LabelType.roll) {
        final label = RollLabel.fromScanData(value);
        if (label != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Label Type: ${_getLabelTypeName(type)}'),
              Text('Roll ID: ${label.rollId}'),
            ],
          );
        }
      }

    return Text('Raw Value: $value');
  }

  void _showResultDialog(
    String title,
    String value,
    LabelType? type,
    Uint8List? image, {
    bool isDuplicate = false,
    bool isInvalid = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(
            color: isInvalid
                ? Colors.red
                : isDuplicate
                    ? Colors.orange
                    : Colors.green,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null)
                Image.memory(
                  image,
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                ),
              const SizedBox(height: 16),
              if (isInvalid)
                const Text(
                  'The scanned code format is not recognized.',
                  style: TextStyle(color: Colors.red),
                )
              else
                _buildScanDetails(value, type),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Scanning'),
          ),
        ],
      ),
    );
  }
}