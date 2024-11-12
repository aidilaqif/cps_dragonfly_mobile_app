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

class _ScanCodePageState extends State<ScanCodePage> with WidgetsBindingObserver, TickerProviderStateMixin {
  late final FGPalletLabelService _fgPalletService;
  late final RollLabelService _rollService;
  late final FGLocationLabelService _fgLocationService;
  late final PaperRollLocationLabelService _paperRollLocationService;

  MobileScannerController? _controller;
  bool _isScanning = false;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;

  late AnimationController _animationController;

  // State variables for feedback
  String? _lastScannedCode;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.green;
  Timer? _feedbackTimer;
  Uint8List? _lastScannedImage;
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

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startScanning();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopScanning();
    _feedbackTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        if (_controller != null) {
          _controller?.stop();
        }
        break;
      case AppLifecycleState.resumed:
        if (_controller != null && _isScanning) {
          _controller?.start();
        }
        break;
      default:
        break;
    }
  }

  void _initializeServices() {
    _fgPalletService = FGPalletLabelService(widget.connection);
    _rollService = RollLabelService(widget.connection);
    _fgLocationService = FGLocationLabelService(widget.connection);
    _paperRollLocationService = PaperRollLocationLabelService(widget.connection);
  }

  void _startScanning() {
    if (_controller != null) {
      _controller?.dispose();
    }

    try {
      setState(() {
        _controller = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          returnImage: true,
          formats: const [
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.code93,
          BarcodeFormat.codabar,
          BarcodeFormat.ean8,
          BarcodeFormat.ean13,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.qrCode,
        ],
          facing: _isFrontCamera ? CameraFacing.front : CameraFacing.back,
          torchEnabled: _isFlashOn,
        );
        _isScanning = true;
        _scanStats = {
          for (var type in LabelType.values) type: 0
        };
      });
    } on Exception catch (e) {
      _showFeedback(
        'Failed to start scanner: ${e.toString()}',
        Colors.red,
      );
    }
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
    if (!mounted) return;
    
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
      // Detailed debug logging
      print('==================== SCAN DEBUG ====================');
      print('Raw scanned value: "$value"');
      print('Value length: ${value.length}');
      print('ASCII codes: ${value.codeUnits}');
      print('Hex representation: ${value.codeUnits.map((e) => '0x${e.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      print('Individual characters:');
      for (int i = 0; i < value.length; i++) {
        print('Position $i: "${value[i]}" (ASCII: ${value.codeUnits[i]})');
      }
      
      // Cleanup the value by trimming whitespace and converting to uppercase
      String cleanValue = value.trim().toUpperCase();
      print('\nCleaned value: "$cleanValue"');
      print('Cleaned length: ${cleanValue.length}');
      
      // Test each label type
      bool isValidFGLocation = RegExp(r'^[A-Z](\d{2})?$').hasMatch(cleanValue);
      bool isValidPaperRollLocation = RegExp(r'^[A-Z]\d$').hasMatch(cleanValue);
      
      print('\nValidation Results:');
      print('Is valid FG Location? $isValidFGLocation');
      print('Is valid Paper Roll Location? $isValidPaperRollLocation');
      
      // Try parsing with each label type
      final fgLocation = FGLocationLabel.fromScanData(cleanValue);
      final paperRollLocation = PaperRollLocationLabel.fromScanData(cleanValue);
      final fgPallet = FGPalletLabel.fromScanData(cleanValue);
      final roll = RollLabel.fromScanData(cleanValue);
      
      print('\nParse Results:');
      print('FG Location parse: ${fgLocation != null ? 'Success' : 'Failed'}');
      print('Paper Roll Location parse: ${paperRollLocation != null ? 'Success' : 'Failed'}');
      print('FG Pallet parse: ${fgPallet != null ? 'Success' : 'Failed'}');
      print('Roll parse: ${roll != null ? 'Success' : 'Failed'}');
      print('================================================');

      final labelType = await _saveLabelToDatabase(cleanValue);
      
      if (!mounted) return;
      
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
      print('Error processing scan: $e');
      if (mounted) {
        _showFeedback(
          '❌ Error: ${e.toString()}', 
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
    if (_controller != null) {
      _controller?.dispose();
      _controller = null;
    }
    
    if (mounted) {
      setState(() {
        _isScanning = false;
        _lastScannedCode = null;
        _lastScannedImage = null;
        _lastLabelType = null;
      });
      
      _showScanSummary();
    }
  }

  void _showScanSummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.summarize,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            const Text('Scan Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...LabelType.values.map((type) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getLabelTypeColor(type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _getLabelTypeIcon(type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getLabelTypeName(type),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_scanStats[type]} scan${_scanStats[type] != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildScannerControls() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
              label: _isFlashOn ? 'Flash On' : 'Flash Off',
              onPressed: () {
                setState(() {
                  _isFlashOn = !_isFlashOn;
                  _controller?.toggleTorch();
                });
              },
            ),
            _buildMainButton(),
            _buildControlButton(
              icon: _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
              label: _isFrontCamera ? 'Front Cam' : 'Back Cam',
              onPressed: () {
                setState(() {
                  _isFrontCamera = !_isFrontCamera;
                  _controller?.switchCamera();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMainButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: _isScanning ? Colors.red : Colors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (_isScanning ? Colors.red : Colors.green).withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
              ),
            ],
          ),
          child: MaterialButton(
            onPressed: _isScanning ? _stopScanning : _startScanning,
            shape: const CircleBorder(),
            child: Icon(
              _isScanning ? Icons.stop : Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isScanning ? 'Stop' : 'Start',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
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
                  color: _isProcessing 
                      ? Colors.orange 
                      : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_isProcessing ? Colors.orange : Colors.white)
                        .withOpacity(0.3),
                    spreadRadius: 3,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Scan lines animation
          if (!_isProcessing) _buildScanAnimation(),
        ],
      ),
    );
  }

  Widget _buildScanAnimation() {
    return Center(
      child: SizedBox(
        width: 250,
        height: 250,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              painter: ScanLinePainter(
                progress: _animationController.value,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSessionStats() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Stats',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...LabelType.values.map((type) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _getLabelTypeIcon(type),
                  const SizedBox(width: 8),
                  Text(
                    '${_scanStats[type]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getLabelTypeName(type),
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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

  Color _getLabelTypeColor(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return Colors.blue;
      case LabelType.roll:
        return Colors.green;
      case LabelType.fgLocation:
        return Colors.orange;
      case LabelType.paperRollLocation:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isScanning) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ready to Scan',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to start scanning labels',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _startScanning,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Scanning'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            final Uint8List? image = capture.image;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              _processScannedCode(barcodes.first.rawValue!, image);
            }
          },
          errorBuilder: (context, error, child){
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: (){
                      _stopScanning();
                      _startScanning();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  )
                ],
              )
            );
          },
        ),
        _buildScannerOverlay(),
        _buildSessionStats(),
        if (_feedbackMessage != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 100,
            left: 20,
            right: 20,
            child: ScanFeedbackOverlay(
              message: _feedbackMessage!,
              color: _feedbackColor,
            ),
          ),
        _buildScannerControls(),
      ],
    );
  }
}

// Custom painter for scan line animation
class ScanLinePainter extends CustomPainter {
  final double progress;

  ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..strokeWidth = 2;

    // Calculate y position based on animation progress
    final y = size.height * progress;
  
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(size.width, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

