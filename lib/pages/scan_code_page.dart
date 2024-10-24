import 'dart:async';
import 'package:cps_dragonfly_4_mobile_app/models/fg_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/paper_roll_location_label.dart';
import 'package:cps_dragonfly_4_mobile_app/services/fg_location_label_service.dart';
import 'package:cps_dragonfly_4_mobile_app/services/fg_pallet_label_service.dart';
import 'package:cps_dragonfly_4_mobile_app/services/paper_roll_location_label_service.dart';
import 'package:cps_dragonfly_4_mobile_app/services/roll_label_service.dart';
import 'package:cps_dragonfly_4_mobile_app/widgets/scan_feedback_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cps_dragonfly_4_mobile_app/services/scan_session_service.dart';
import 'package:cps_dragonfly_4_mobile_app/models/fg_pallet_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/roll_label.dart';
import 'package:cps_dragonfly_4_mobile_app/models/label_types.dart';
import 'package:postgres/postgres.dart';

class ScanCodePage extends StatefulWidget {
  final PostgreSQLConnection connection;

  const ScanCodePage({super.key, required this.connection});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
late final ScanSessionService _scanService;
  late final FGPalletLabelService _fgPalletService;
  late final RollLabelService _rollService;
  late final FGLocationLabelService _fgLocationService;
  late final PaperRollLocationLabelService _paperRollLocationService;
  
  MobileScannerController? _controller;
  bool _isScanning = false;
  bool _isProcessing = false;

  // State variables for feedback
  String? _lastScannedCode;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.green;
  Uint8List? _lastScannedImage;
  Timer? _feedbackTimer;
  LabelType? _lastLabelType;
  DateTime _lastScanTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    _scanService = ScanSessionService(widget.connection);
    _fgPalletService = FGPalletLabelService(widget.connection);
    _rollService = RollLabelService(widget.connection);
    _fgLocationService = FGLocationLabelService(widget.connection);
    _paperRollLocationService = PaperRollLocationLabelService(widget.connection);
  }

  Future<void> _startNewSession() async {
    try {
      await _scanService.startNewSession();
      if (mounted) {
        Navigator.of(context).pop();
        _startScanning();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: ${e.toString()}')),
        );
      }
    }
  }

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
              onPressed: () async {
                await _scanService.startNewSession();
                if (mounted) {
                  Navigator.of(context).pop();
                  _startScanning();
                }
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

  Future<void> _processScannedCode(String value, Uint8List? image) async {
    // Prevent processing if already handling a scan
    if (_isProcessing) return;
    
    // Prevent rapid-fire scanning of the same code
    if (_lastScannedCode == value && 
        DateTime.now().difference(_lastScanTime).inMilliseconds < 1000) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScannedCode = value;
      _lastScannedImage = image;
      _lastScanTime = DateTime.now();
    });

    try {
      // Check for duplicates
      if (_scanService.isValueExistsInCurrentSession(value)) {
        _showFeedback('⚠️ Duplicate code in current session', const Color(0xFFFF9800));
        return;
      }

      final existsInOtherSessions = _scanService.isValueExistsInOtherSessions(value);
      final sessionId = int.parse(_scanService.currentSession?.sessionId ?? '0');

      // Try to parse and save the label
      if (await _saveLabelToDatabase(value, sessionId)) {
        if (existsInOtherSessions) {
          _showFeedback('ℹ️ Code found in previous session', const Color(0xFF2196F3));
        } else {
          _showFeedback('✅ Code successfully scanned', const Color(0xFF4CAF50));
        }
      } else {
        _showFeedback('❌ Invalid code format', const Color(0xFFF44336));
      }
    } catch (e) {
      _showFeedback('❌ Error saving scan: ${e.toString()}', const Color(0xFFF44336));
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<bool> _saveLabelToDatabase(String value, int sessionId) async {
    // Try FG Pallet Label
    final fgPalletLabel = FGPalletLabel.fromScanData(value);
    if (fgPalletLabel != null) {
      await _fgPalletService.insertLabel(fgPalletLabel, sessionId);
      _scanService.currentSession?.addScan(fgPalletLabel, LabelType.fgPallet);
      return true;
    }

    // Try Roll Label
    final rollLabel = RollLabel.fromScanData(value);
    if (rollLabel != null) {
      await _rollService.insertLabel(rollLabel, sessionId);
      _scanService.currentSession?.addScan(rollLabel, LabelType.roll);
      return true;
    }

    // Try FG Location Label
    final fgLocationLabel = FGLocationLabel.fromScanData(value);
    if (fgLocationLabel != null) {
      await _fgLocationService.insertLabel(fgLocationLabel, sessionId);
      _scanService.currentSession?.addScan(fgLocationLabel, LabelType.fgLocation);
      return true;
    }

    // Try Paper Roll Location Label
    final paperRollLocationLabel = PaperRollLocationLabel.fromScanData(value);
    if (paperRollLocationLabel != null) {
      await _paperRollLocationService.insertLabel(paperRollLocationLabel, sessionId);
      _scanService.currentSession?.addScan(paperRollLocationLabel, LabelType.paperRollLocation);
      return true;
    }

    return false;
  }


  Future<void> _stopScanning() async {
    try {
      await _scanService.endCurrentSession();
      setState(() {
        _controller?.dispose();
        _controller = null;
        _isScanning = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending session: ${e.toString()}')),
      );
    }
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

      return LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              SizedBox(
                height: constraints.maxHeight,
                width: constraints.maxWidth,
                child: MobileScanner(
                  controller: _controller!,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    final image = capture.image;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      _processScannedCode(barcodes.first.rawValue!, image);
                    }
                  },
                ),
              ),
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
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                if (_lastScannedImage != null)
                                  SizedBox(
                                    height: 80,
                                    width: 80,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        _lastScannedImage!,
                                        fit: BoxFit.cover,
                                      ),
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
                ),
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
        },
      );
    }
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
