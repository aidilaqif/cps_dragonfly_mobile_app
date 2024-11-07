import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  const ScanCodePage({super.key});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Services
  final FGPalletLabelService _fgPalletService = FGPalletLabelService();
  final RollLabelService _rollService = RollLabelService();
  final FGLocationLabelService _fgLocationService = FGLocationLabelService();
  final PaperRollLocationLabelService _paperRollLocationService =
      PaperRollLocationLabelService();

  // Scanner controller
  MobileScannerController? _controller;
  bool _isScanning = false;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;

  // Animation controller
  late AnimationController _animationController;

  // Feedback state
  String? _lastScannedCode;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.green;
  Timer? _feedbackTimer;
  LabelType? _lastLabelType;
  DateTime _lastScanTime = DateTime.now();

  // Session statistics
  Map<LabelType, _ScanStats> _scanStats = {
    for (var type in LabelType.values) type: _ScanStats(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

  void _startScanning() {
    if (_controller != null) {
      _controller?.dispose();
    }

    try {
      setState(() {
        _controller = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          returnImage: true,
          formats: [
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
          for (var type in LabelType.values) type: _ScanStats(),
        };
      });
    } on Exception catch (e) {
      _showFeedback(
        'Failed to start scanner: ${e.toString()}',
        Colors.red,
      );
    }
  }

  Future<void> _processScannedCode(String value) async {
    if (!mounted) return;

    // Prevent duplicate scans and processing while busy
    if (_isProcessing ||
        (_lastScannedCode == value &&
            DateTime.now().difference(_lastScanTime).inMilliseconds < 1000)) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScannedCode = value;
      _lastScanTime = DateTime.now();
    });

    try {
      // Debug logging
      _logScanDetails(value);

      // Clean the value
      String cleanValue = value.trim().toUpperCase();

      // Try to create and save the appropriate label type
      final label = await _createAndSaveLabel(cleanValue);

      if (!mounted) return;

      if (label != null) {
        final labelType = _getLabelType(label);
        _lastLabelType = labelType;

        setState(() {
          _scanStats[labelType]!.incrementSuccess();
        });

        _showSuccessFeedback(label);
        HapticFeedback.mediumImpact();
      } else {
        _showInvalidFormatFeedback();
        HapticFeedback.heavyImpact();
        setState(() {
          if (_lastLabelType != null) {
            _scanStats[_lastLabelType]!.incrementFailure();
          }
        });
      }
    } catch (e) {
      print('Error processing scan: $e');
      if (mounted) {
        _showErrorFeedback(e);
        HapticFeedback.heavyImpact();
        setState(() {
          if (_lastLabelType != null) {
            _scanStats[_lastLabelType]!.incrementFailure();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _logScanDetails(String value) {
    print('==================== SCAN DEBUG ====================');
    print('Raw scanned value: "$value"');
    print('Value length: ${value.length}');
    print('ASCII codes: ${value.codeUnits}');
    print(
        'Hex representation: ${value.codeUnits.map((e) => '0x${e.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    print('Individual characters:');
    for (int i = 0; i < value.length; i++) {
      print('Position $i: "${value[i]}" (ASCII: ${value.codeUnits[i]})');
    }
    print('================================================');
  }

  Future<dynamic> _createAndSaveLabel(String cleanValue) async {
    // Try FG Pallet Label
    final fgPallet = FGPalletLabel.fromScanData(cleanValue);
    if (fgPallet != null) {
      return await _fgPalletService.create(fgPallet);
    }

    // Try Roll Label
    final roll = RollLabel.fromScanData(cleanValue);
    if (roll != null) {
      return await _rollService.create(roll);
    }

    // Try FG Location Label
    final fgLocation = FGLocationLabel.fromScanData(cleanValue);
    if (fgLocation != null) {
      return await _fgLocationService.create(fgLocation);
    }

    // Try Paper Roll Location Label
    final paperRollLocation = PaperRollLocationLabel.fromScanData(cleanValue);
    if (paperRollLocation != null) {
      return await _paperRollLocationService.create(paperRollLocation);
    }

    return null;
  }

  void _showSuccessFeedback(dynamic label) {
    final type = _getLabelType(label);
    final message = _getSuccessMessage(label);
    _showFeedback('✅ $message', Colors.green);
  }

  void _showInvalidFormatFeedback() {
    _showFeedback('❌ Invalid code format', Colors.red);
  }

  void _showErrorFeedback(dynamic error) {
    _showFeedback(
      '❌ Error: ${error.toString()}',
      Colors.red,
    );
  }

  void _showFeedback(String message, Color color,
      {Duration duration = const Duration(seconds: 2)}) {
    setState(() {
      _feedbackMessage = message;
      _feedbackColor = color;
    });

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  String _getSuccessMessage(dynamic label) {
    if (label is FGPalletLabel) {
      return 'Scanned Pallet: ${label.plateId}';
    } else if (label is RollLabel) {
      return 'Scanned Roll: ${label.rollId}';
    } else if (label is FGLocationLabel) {
      return 'Scanned Location: ${label.locationId}';
    } else if (label is PaperRollLocationLabel) {
      return 'Scanned Paper Roll Location: ${label.locationId}';
    }
    return 'Label scanned successfully';
  }

  LabelType _getLabelType(dynamic label) {
    if (label is FGPalletLabel) return LabelType.fgPallet;
    if (label is RollLabel) return LabelType.roll;
    if (label is FGLocationLabel) return LabelType.fgLocation;
    if (label is PaperRollLocationLabel) return LabelType.paperRollLocation;
    throw ArgumentError('Unknown label type');
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...LabelType.values.map((type) => _buildScanStatCard(type)),
              const SizedBox(height: 16),
              _buildTotalStats(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startScanning();
            },
            child: const Text('New Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildScanStatCard(LabelType type) {
    final stats = _scanStats[type]!;
    final successRate =
        stats.total == 0 ? 0 : (stats.successful / stats.total * 100);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          _getLabelTypeIcon(type),
          color: _getLabelTypeColor(type),
        ),
        title: Text(_getLabelTypeName(type)),
        subtitle: Text('Success rate: ${successRate.toStringAsFixed(1)}%'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${stats.successful}/${stats.total}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Failed: ${stats.failed}',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalStats() {
    int totalScans = 0;
    int totalSuccessful = 0;
    int totalFailed = 0;

    _scanStats.values.forEach((stats) {
      totalScans += stats.total;
      totalSuccessful += stats.successful;
      totalFailed += stats.failed;
    });

    final successRate =
        totalScans == 0 ? 0 : (totalSuccessful / totalScans * 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _buildStatRow('Total Scans', totalScans),
          _buildStatRow('Successful', totalSuccessful, Colors.green),
          _buildStatRow('Failed', totalFailed, Colors.red),
          _buildStatRow('Success Rate', '$successRate%'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
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
          decoration: const BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
            tooltip: label,
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
                color:
                    (_isScanning ? Colors.red : Colors.green).withOpacity(0.3),
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
                  color: _isProcessing ? Colors.orange : Colors.white,
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
                color: _lastLabelType != null
                    ? _getLabelTypeColor(_lastLabelType!)
                    : Colors.green,
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
            Row(
              children: [
                const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Session Stats',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _getTotalScans().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...LabelType.values.map((type) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _getLabelTypeIcon(type),
                        color: _getLabelTypeColor(type),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_scanStats[type]!.successful}',
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

  int _getTotalScans() {
    return _scanStats.values.fold(0, (sum, stats) => sum + stats.total);
  }

  IconData _getLabelTypeIcon(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return Icons.inventory_2;
      case LabelType.roll:
        return Icons.rotate_right;
      case LabelType.fgLocation:
        return Icons.location_on;
      case LabelType.paperRollLocation:
        return Icons.location_searching;
    }
  }

  String _getLabelTypeName(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return 'FG Pallet';
      case LabelType.roll:
        return 'Roll';
      case LabelType.fgLocation:
        return 'FG Location';
      case LabelType.paperRollLocation:
        return 'Paper Roll Location';
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
              _buildMainButton(),
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
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              _processScannedCode(barcodes.first.rawValue!);
            }
          },
          errorBuilder: (context, error, child) {
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
                    onPressed: () {
                      _stopScanning();
                      _startScanning();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
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

class _ScanStats {
  int successful = 0;
  int failed = 0;

  int get total => successful + failed;

  void incrementSuccess() => successful++;
  void incrementFailure() => failed++;
}

class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  ScanLinePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2;

    final y = size.height * progress;
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(size.width, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
