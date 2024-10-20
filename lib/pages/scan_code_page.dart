import 'dart:typed_data';

import 'package:cps_dragonfly_4_mobile_app/services/scan_service.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';


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
              final type = barcodes.first.type.name;
              
              // Check if exists in current session
              if (_scanService.isValueExistsInCurrentSession(value)) {
                _showResultDialog('Duplicate in Current Session', value, type, image);
                return;
              }

              // Check if exists in other sessions
              bool existsInOtherSessions = _scanService.isValueExistsInOtherSessions(value);
              
              // Add to current session
              bool added = _scanService.addScan(value, type);
              if (added) {
                _showResultDialog(
                  existsInOtherSessions ? 'Found in Previous Session' : 'New Code',
                  value,
                  type,
                  image,
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

  void _showResultDialog(String title, String value, String type, Uint8List? image) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null) 
              Image.memory(
                image,
                height: 200,
                width: 200,
                fit: BoxFit.contain,
              ),
            Text('Value: $value'),
            Text('Type: $type'),
          ],
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