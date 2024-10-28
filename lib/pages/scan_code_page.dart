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
import 'package:intl/intl.dart';

class ScanCodePage extends StatefulWidget {
  final PostgreSQLConnection connection;

  const ScanCodePage({super.key, required this.connection});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> with WidgetsBindingObserver {
  late final ScanSessionService _scanService;
  late final FGPalletLabelService _fgPalletService;
  late final RollLabelService _rollService;
  late final FGLocationLabelService _fgLocationService;
  late final PaperRollLocationLabelService _paperRollLocationService;
  
  MobileScannerController? _controller;
  bool _isScanning = false;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  bool _isRescan = false;

  // State variables for feedback
  String? _lastScannedCode;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.green;
  Uint8List? _lastScannedImage;
  Timer? _feedbackTimer;
  LabelType? _lastLabelType;
  DateTime _lastScanTime = DateTime.now();
  String? _previousSessionId;

  // Session statistics
  Map<LabelType, int> _sessionStats = {
    for (var type in LabelType.values) type: 0
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
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
    _scanService = ScanSessionService(widget.connection);
    _fgPalletService = FGPalletLabelService(widget.connection);
    _rollService = RollLabelService(widget.connection);
    _fgLocationService = FGLocationLabelService(widget.connection);
    _paperRollLocationService = PaperRollLocationLabelService(widget.connection);
  }

  Future<void> _showSessionDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Scanning Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Would you like to start a new scanning session or continue the previous one?'),
              if (_scanService.sessions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Last session: ${_formatDateTime(_scanService.sessions.first.startTime)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('New Session'),
              onPressed: () async {
                await _startNewSession();
              },
            ),
            if (_scanService.sessions.isNotEmpty)
              TextButton(
                child: const Text('Continue Last'),
                onPressed: () {
                  _scanService.continueLastSession();
                  Navigator.of(context).pop();
                  _startScanning();
                  _showFeedback('Continuing last session', Colors.blue);
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _startNewSession() async {
    try {
      setState(() => _isProcessing = true);
      await _scanService.startNewSession();
      if (mounted) {
        Navigator.of(context).pop();
        _startScanning();
        _showFeedback('New session started', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
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
      // Reset session stats
      _sessionStats = {
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
      _isRescan = false; // Reset rescan status
      _previousSessionId = null;
    });

    try {
      // Get current session ID
      final sessionId = int.parse(_scanService.currentSession?.sessionId ?? '0');
      if (sessionId == 0) {
        throw Exception('No active session');
      }

      // Try to parse and save the label
      final labelType = await _saveLabelToDatabase(value, sessionId);
      
      if (labelType != null) {
        _lastLabelType = labelType;
        setState(() {
          // Only increment counter for new scans, not rescans
          if (!_isRescan) {
            _sessionStats[labelType] = (_sessionStats[labelType] ?? 0) + 1;
          }
        });

        // Determine appropriate feedback message
        String message;
        Color color;

        if (_isRescan) {
          if (_previousSessionId != null && _previousSessionId != sessionId.toString()) {
            message = '⚠️ Rescanned from previous session';
            color = const Color(0xFFFF9800); // Orange for warning
          } else {
            message = '🔄 Label rescanned';
            color = const Color(0xFF2196F3); // Blue for info
          }
        } else {
          message = '✅ ${_getLabelTypeName(labelType)} scanned';
          color = const Color(0xFF4CAF50); // Green for success
        }

        _showFeedback(message, color);
      } else {
        _showFeedback(
          '❌ Invalid code format', 
          const Color(0xFFF44336),
        );
      }
    } catch (e) {
      _showFeedback(
        '❌ Error: ${e.toString()}', 
        const Color(0xFFF44336),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }


  // Future<bool> _checkForDuplicate(String value) async {
  //   try {
  //     // Try each label type
  //     if (FGPalletLabel.fromScanData(value) != null) {
  //       return _scanService.isValueExistsInOtherSessions(value);
  //     }
  //     if (RollLabel.fromScanData(value) != null) {
  //       return _scanService.isValueExistsInOtherSessions(value);
  //     }
  //     if (FGLocationLabel.fromScanData(value) != null) {
  //       return _scanService.isValueExistsInOtherSessions(value);
  //     }
  //     if (PaperRollLocationLabel.fromScanData(value) != null) {
  //       return _scanService.isValueExistsInOtherSessions(value);
  //     }
  //   } catch (e) {
  //     print('Error checking for duplicates: $e');
  //   }
  //   return false;
  // }

  Future<LabelType?> _saveLabelToDatabase(String value, int sessionId) async {
    try {
      // Try FG Pallet Label
      final fgPalletLabel = FGPalletLabel.fromScanData(value);
      if (fgPalletLabel != null) {
        await _fgPalletService.create(fgPalletLabel, sessionId);
        // Check if this was a rescan by looking at the session's scans
        _checkRescanStatus(value, LabelType.fgPallet);
        return LabelType.fgPallet;
      }

      // Try Roll Label
      final rollLabel = RollLabel.fromScanData(value);
      if (rollLabel != null) {
        await _rollService.create(rollLabel, sessionId);
        _checkRescanStatus(value, LabelType.roll);
        return LabelType.roll;
      }

      // Try FG Location Label
      final fgLocationLabel = FGLocationLabel.fromScanData(value);
      if (fgLocationLabel != null) {
        await _fgLocationService.create(fgLocationLabel, sessionId);
        _checkRescanStatus(value, LabelType.fgLocation);
        return LabelType.fgLocation;
      }

      // Try Paper Roll Location Label
      final paperRollLocationLabel = PaperRollLocationLabel.fromScanData(value);
      if (paperRollLocationLabel != null) {
        await _paperRollLocationService.create(paperRollLocationLabel, sessionId);
        _checkRescanStatus(value, LabelType.paperRollLocation);
        return LabelType.paperRollLocation;
      }

      return null;
    } catch (e) {
      print('Error saving label: $e');
      rethrow;
    }
  }

  void _checkRescanStatus(String value, LabelType type) {
    // Check if this value exists in the current session
    if (_scanService.isValueExistsInCurrentSession(value)) {
      setState(() {
        _isRescan = true;
        _previousSessionId = _scanService.currentSession?.sessionId;
      });
      return;
    }

    // Check if this value exists in other sessions
    if (_scanService.isValueExistsInOtherSessions(value)) {
      setState(() {
        _isRescan = true;
        // Find the session ID where this value was first scanned
        for (var session in _scanService.sessions) {
          if (session != _scanService.currentSession && 
              _checkValueInSession(value, session)) {
            _previousSessionId = session.sessionId;
            break;
          }
        }
      });
    }
  }

  bool _checkValueInSession(String value, dynamic session) {
    return session.scans.any((scan) {
      if (scan is FGPalletLabel) return scan.rawValue == value;
      if (scan is RollLabel) return scan.rollId == value;
      if (scan is FGLocationLabel) return scan.locationId == value;
      if (scan is PaperRollLocationLabel) return scan.locationId == value;
      return false;
    });
  }

  Future<void> _stopScanning() async {
    try {
      await _scanService.endCurrentSession();
      setState(() {
        _controller?.dispose();
        _controller = null;
        _isScanning = false;
        _lastScannedCode = null;
        _lastScannedImage = null;
        _lastLabelType = null;
      });
      
      if (mounted) {
        _showSessionSummary();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending session: ${e.toString()}')),
      );
    }
  }

  void _showSessionSummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Summary'),
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
                    '${_sessionStats[type]} ${_getLabelTypeName(type)}${_sessionStats[type] != 1 ? 's' : ''}',
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
                  '${_sessionStats[type]}',
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

  Widget _buildScanPreview(dynamic label, LabelType type) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_lastScannedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _lastScannedImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _getLabelTypeIcon(type),
                        const SizedBox(width: 8),
                        Text(
                          _getLabelTypeName(type),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isRescan)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Rescan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildLabelDetails(label, type),
                  ],
                ),
              ),
            ],
          ),
          if (_isRescan && _previousSessionId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Previously scanned in Session $_previousSessionId',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Clear'),
                onPressed: () {
                  setState(() {
                    _lastScannedCode = null;
                    _lastScannedImage = null;
                    _lastLabelType = null;
                    _isRescan = false;
                    _previousSessionId = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabelDetails(dynamic label, LabelType type) {
    final TextStyle labelStyle = TextStyle(
      fontSize: 12,
      color: Colors.grey[600],
    );
    final TextStyle valueStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    switch (type) {
      case LabelType.fgPallet:
        final fgLabel = label as FGPalletLabel;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plate ID', style: labelStyle),
            Text(fgLabel.plateId, style: valueStyle),
            const SizedBox(height: 4),
            Text('Work Order', style: labelStyle),
            Text(fgLabel.workOrder, style: valueStyle),
          ],
        );

      case LabelType.roll:
        final rollLabel = label as RollLabel;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Roll ID', style: labelStyle),
            Text(rollLabel.rollId, style: valueStyle),
          ],
        );

      case LabelType.fgLocation:
        final locationLabel = label as FGLocationLabel;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location ID', style: labelStyle),
            Text(locationLabel.locationId, style: valueStyle),
          ],
        );

      case LabelType.paperRollLocation:
        final locationLabel = label as PaperRollLocationLabel;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location ID', style: labelStyle),
            Text(locationLabel.locationId, style: valueStyle),
          ],
        );
    }
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

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isScanning) {
      return Scaffold(
        body: Center(
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
              const SizedBox(height: 8),
              Text(
                'Start a new session or continue the last one',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showSessionDialog,
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
        ),
      );
    }

    return Scaffold(
      body: Stack(
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

          // Last scanned preview
          if (_lastScannedCode != null && _lastLabelType != null)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: _buildScanPreview(
                _parseLabel(_lastScannedCode!),
                _lastLabelType!,
              ),
            ),

          // Scanner controls
          _buildScannerControls(),
        ],
      ),
    );
  }

  dynamic _parseLabel(String value) {
    final fgPallet = FGPalletLabel.fromScanData(value);
    if (fgPallet != null) return fgPallet;

    final roll = RollLabel.fromScanData(value);
    if (roll != null) return roll;

    final fgLocation = FGLocationLabel.fromScanData(value);
    if (fgLocation != null) return fgLocation;

    final paperRollLocation = PaperRollLocationLabel.fromScanData(value);
    if (paperRollLocation != null) return paperRollLocation;

    return null;
  }
}