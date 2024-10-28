import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:postgres/postgres.dart';
import 'package:intl/intl.dart';
import '../models/fg_location_label.dart';
import '../models/paper_roll_location_label.dart';
import '../models/fg_pallet_label.dart';
import '../models/roll_label.dart';
import '../models/label_types.dart';
import '../services/fg_location_label_service.dart';
import '../services/fg_pallet_label_service.dart';
import '../services/paper_roll_location_label_service.dart';
import '../services/roll_label_service.dart';
import '../widgets/scan_feedback_overlay.dart';

class ScanCodePage extends StatefulWidget {
  final PostgreSQLConnection connection;

  const ScanCodePage({super.key, required this.connection});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> with WidgetsBindingObserver {
  late final FGPalletLabelService _fgPalletService;
  late final RollLabelService _rollService;
  late final FGLocationLabelService _fgLocationService;
  late final PaperRollLocationLabelService _paperRollLocationService;
  
  MobileScannerController? _controller;
  bool _isScanning = false;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;

  // State variables for feedback
  String? _lastScannedCode;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.green;
  Uint8List? _lastScannedImage;
  Timer? _feedbackTimer;
  LabelType? _lastLabelType;
  DateTime _lastScanTime = DateTime.now();
  
  // Statistics for current scanning session
  Map<LabelType, int> _scanStats = {
    for (var type in LabelType.values) type: 0
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _startScanning();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller?.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.start();
    }
  }

  void _initializeServices() {
    _fgPalletService = FGPalletLabelService(widget.connection);
    _rollService = RollLabelService(widget.connection);
    _fgLocationService = FGLocationLabelService(widget.connection);
    _paperRollLocationService = PaperRollLocationLabelService(widget.connection);
  }

  void _startScanning() {
    setState(() {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: true,
        facing: _isFrontCamera ? CameraFacing.front : CameraFacing.back,
        torchEnabled: _isFlashOn,
      );
      _isScanning = true;
      _scanStats = {
        for (var type in LabelType.values) type: 0
      };
    });
  }

  void _showFeedback(String message, Color color, {Duration duration = const Duration(seconds: 2)}) {
    setState(() {
      _feedbackMessage = message;
      _feedbackColor = color;
    });

    // Vibration feedback based on the type of message
    if (color == Colors.green) {
      HapticFeedback.mediumImpact();
    } else if (color == Colors.red) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  Future<void> _processScannedCode(String value, Uint8List? image) async {
    // Prevent processing if already handling a scan or too rapid scanning
    if (_isProcessing || 
        (_lastScannedCode == value && 
         DateTime.now().difference(_lastScanTime).inMilliseconds < 1000)) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScannedCode = value;
      _lastScannedImage = image;
      _lastScanTime = DateTime.now();
    });

    try {
      final labelType = await _saveLabelToDatabase(value);
      
      if (labelType != null) {
        _lastLabelType = labelType;
        setState(() {
          _scanStats[labelType] = (_scanStats[labelType] ?? 0) + 1;
        });

        _showFeedback(
          '✅ ${_getLabelTypeName(labelType)} scanned',
          Colors.green,
        );
      } else {
        _showFeedback(
          '❌ Invalid code format', 
          Colors.red,
        );
      }
    } catch (e) {
      _showFeedback(
        '❌ Error: ${e.toString()}', 
        Colors.red,
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<LabelType?> _saveLabelToDatabase(String value) async {
    try {
      // Try FG Pallet Label
      final fgPalletLabel = FGPalletLabel.fromScanData(value);
      if (fgPalletLabel != null) {
        await _fgPalletService.create(fgPalletLabel);
        return LabelType.fgPallet;
      }

      // Try Roll Label
      final rollLabel = RollLabel.fromScanData(value);
      if (rollLabel != null) {
        await _rollService.create(rollLabel);
        return LabelType.roll;
      }

      // Try FG Location Label
      final fgLocationLabel = FGLocationLabel.fromScanData(value);
      if (fgLocationLabel != null) {
        await _fgLocationService.create(fgLocationLabel);
        return LabelType.fgLocation;
      }

      // Try Paper Roll Location Label
      final paperRollLocationLabel = PaperRollLocationLabel.fromScanData(value);
      if (paperRollLocationLabel != null) {
        await _paperRollLocationService.create(paperRollLocationLabel);
        return LabelType.paperRollLocation;
      }

      return null;
    } catch (e) {
      print('Error saving label: $e');
      rethrow;
    }
  }

  void _stopScanning() {
    setState(() {
      _controller?.dispose();
      _controller = null;
      _isScanning = false;
      _lastScannedCode = null;
      _lastScannedImage = null;
      _lastLabelType = null;
    });
    
    if (mounted) {
      _showScanSummary();
    }
  }

  void _showScanSummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...LabelType.values.map((type) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _getLabelTypeIcon(type),
                  const SizedBox(width: 8),
                  Text(
                    '${_scanStats[type]} ${_getLabelTypeName(type)}${_scanStats[type] != 1 ? 's' : ''}',
                  ),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerControls() {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isFlashOn = !_isFlashOn;
                _controller?.toggleTorch();
              });
            },
          ),
          ElevatedButton.icon(
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
            ),
          ),
          IconButton(
            icon: Icon(
              _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isFrontCamera = !_isFrontCamera;
                _controller?.switchCamera();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStats() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...LabelType.values.map((type) => Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _getLabelTypeIcon(type),
                const SizedBox(width: 8),
                Text(
                  '${_scanStats[type]}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Icon _getLabelTypeIcon(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return const Icon(Icons.inventory_2, color: Colors.blue);
      case LabelType.roll:
        return const Icon(Icons.rotate_right, color: Colors.green);
      case LabelType.fgLocation:
        return const Icon(Icons.location_on, color: Colors.orange);
      case LabelType.paperRollLocation:
        return const Icon(Icons.location_searching, color: Colors.purple);
    }
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

  @override
  Widget build(BuildContext context) {
    if (!_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'Ready to Scan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startScanning,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Scanning'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Scanner
        MobileScanner(
          controller: _controller!,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            final Uint8List? image = capture.image;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              _processScannedCode(barcodes.first.rawValue!, image);
            }
          },
        ),

        // Scan overlay
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isProcessing ? Colors.orange : Colors.white,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Feedback message
        if (_feedbackMessage != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: ScanFeedbackOverlay(
              message: _feedbackMessage!,
              color: _feedbackColor,
            ),
          ),

        // Session stats
        _buildSessionStats(),

        // Scanner controls
        _buildScannerControls(),
      ],
    );
  }
}