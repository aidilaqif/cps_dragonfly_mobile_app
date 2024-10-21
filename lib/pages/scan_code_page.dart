import 'dart:async';
import 'dart:typed_data';
import 'package:cps_dragonfly_4_mobile_app/models/fg_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/paper_roll_location_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // State variables for feedback
  String? _lastScannedCode;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.green;
  Uint8List? _lastScannedImage;
  Timer? _feedbackTimer;
  LabelType? _lastLabelType;
  DateTime _lastScanTime = DateTime.now();

  @override
  void dispose() {
    _controller?.dispose();
    _feedbackTimer?.cancel();
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
    void _showFeedback(String message, Color color, {Duration duration = const Duration(seconds: 2)}) {
    setState(() {
      _feedbackMessage = message;
      _feedbackColor = color;
    });

    // Vibrate feedback based on the type of message
    HapticFeedback.mediumImpact();

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  void _processScannedCode(String value, Uint8List? image) {
    // Prevent rapid-fire scanning of the same code
    if (_lastScannedCode == value && 
        DateTime.now().difference(_lastScanTime).inMilliseconds < 1000) {
      return;
    }

    setState(() {
      _lastScannedCode = value;
      _lastScannedImage = image;
      _lastScanTime = DateTime.now();
    });

    // Check for duplicates in current session
    if (_scanService.isValueExistsInCurrentSession(value)) {
      _showFeedback('⚠️ Duplicate code in current session', const Color(0xFFFF9800));
      return;
    }

    // Check if exists in other sessions
    bool existsInOtherSessions = _scanService.isValueExistsInOtherSessions(value);

    // Process the scanned code
    bool processed = _scanService.addScan(value);
    _lastLabelType = _getLabelTypeFromValue(value);

    if (processed) {
      if (existsInOtherSessions) {
        _showFeedback('ℹ️ Code found in previous session', 
            const Color(0xFF2196F3)); // Blue
      } else {
        _showFeedback('✅ Code successfully scanned', 
            const Color(0xFF4CAF50)); // Green
      }
    } else {
      _showFeedback('❌ Invalid code format', 
          const Color(0xFFF44336)); // Red
    }
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
              _processScannedCode(barcodes.first.rawValue!, image);
            }
          },
        ), // Enhanced feedback overlay
        if (_feedbackMessage != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _feedbackColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _feedbackMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Enhanced last scan result panel
        if (_lastScannedCode != null)
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (_lastScannedImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _lastScannedImage!,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildScanDetails(_lastScannedCode!, _lastLabelType),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Enhanced stop button
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton.icon(
              onPressed: _stopScanning,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Scanning'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                elevation: 4,
              ),
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
    if (FGLocationLabel.fromScanData(value) != null) {
      return LabelType.fgLocation;
    }
    if (PaperRollLocationLabel.fromScanData(value) != null) {
      return LabelType.paperRollLocation;
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
    final TextStyle labelStyle = TextStyle(
      fontSize: 14,
      color: Colors.grey[600],
    );
    final TextStyle valueStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );

    if (type == LabelType.fgPallet) {
      final label = FGPalletLabel.fromScanData(value);
      if (label != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Label Type: ${_getLabelTypeName(type!)}', style: labelStyle,),
            const SizedBox(height: 4),
            Text('Plate ID: ${label.plateId}', style: valueStyle,),
            const SizedBox(height: 4),
            Text('Work Order: ${label.workOrder}', style: valueStyle,),
          ],
        );
      }
    } else if (type == LabelType.roll) {
      final label = RollLabel.fromScanData(value);
      if (label != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Label Type: ${_getLabelTypeName(type!)}', style: labelStyle,),
            const SizedBox(height: 4),
            Text('Roll ID: ${label.rollId}', style: valueStyle,),
          ],
        );
      }
    }else if (type == LabelType.fgLocation){
      final label = FGLocationLabel.fromScanData(value);
      if (label != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Label Type: ${_getLabelTypeName(type!)}', style: labelStyle,),
            const SizedBox(height: 4),
            Text('Location ID: ${label.locationId}', style: valueStyle,),
          ],
        );
      }
    }else if (type == LabelType.paperRollLocation){
      final label = PaperRollLocationLabel.fromScanData(value);
      if (label != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Label Type: ${_getLabelTypeName(type!)}', style: labelStyle,),
            const SizedBox(height: 4),
            Text('Location ID: ${label.locationId}', style: valueStyle,),
          ],
        );
      }
    }
    return Text('Raw Value: $value');
  }
}
//   void _showResultDialog(
//     String title,
//     String value,
//     LabelType? type,
//     Uint8List? image, {
//     bool isDuplicate = false,
//     bool isInvalid = false,
//   }) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(
//           title,
//           style: TextStyle(
//             color: isInvalid
//                 ? Colors.red
//                 : isDuplicate
//                     ? Colors.orange
//                     : Colors.green,
//           ),
//         ),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               if (image != null)
//                 Image.memory(
//                   image,
//                   height: 200,
//                   width: 200,
//                   fit: BoxFit.contain,
//                 ),
//               const SizedBox(height: 16),
//               if (isInvalid)
//                 const Text(
//                   'The scanned code format is not recognized.',
//                   style: TextStyle(color: Colors.red),
//                 )
//               else
//                 _buildScanDetails(value, type),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Continue Scanning'),
//           ),
//         ],
//       ),
//     );
//   }
// }