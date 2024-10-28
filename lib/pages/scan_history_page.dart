import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import '../services/scan_session_service.dart';
import '../models/scan_session.dart';
import '../models/label_types.dart';
import '../models/fg_pallet_label.dart';
import '../models/roll_label.dart';
import '../models/fg_location_label.dart';
import '../models/paper_roll_location_label.dart';
import '../widgets/export_to_csv_button.dart';
import 'package:intl/intl.dart';

class ScanHistoryPage extends StatefulWidget {
  final PostgreSQLConnection connection;

  const ScanHistoryPage({super.key, required this.connection});

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  late final ScanSessionService _scanService;
  LabelType? _selectedType;
  bool _isLoading = true;
  String? _error;
  List<ScanSession> _sessions = [];
  bool _showRescanOnly = false; // New filter for rescans

  @override
  void initState() {
    super.initState();
    _scanService = ScanSessionService(widget.connection);
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final sessions = await _scanService.fetchSessions();
      setState(() {
        _sessions = sessions;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading sessions: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  List<dynamic> _getFilteredScans(ScanSession session) {
    if (_selectedType == null) return session.scans;
    
    return session.scans.where((scan) {
      switch (_selectedType!) {
        case LabelType.fgPallet:
          return scan is FGPalletLabel;
        case LabelType.roll:
          return scan is RollLabel;
        case LabelType.fgLocation:
          return scan is FGLocationLabel;
        case LabelType.paperRollLocation:
          return scan is PaperRollLocationLabel;
      }
    }).toList();
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM dd, yyyy HH:mm');
    return formatter.format(dateTime);
  }

  String _getScanDetails(dynamic scan) {
    if (scan is FGPalletLabel) {
      return 'Plate ID: ${scan.plateId}\nWork Order: ${scan.workOrder}';
    } else if (scan is RollLabel) {
      return 'Roll ID: ${scan.rollId}';
    } else if (scan is FGLocationLabel) {
      return 'Location: ${scan.locationId}';
    } else if (scan is PaperRollLocationLabel) {
      return 'Location: ${scan.locationId}';
    }
    return 'Unknown scan type';
  }

  String _getSessionScanCounts(ScanSession session) {
    if (_selectedType != null) {
      final count = session.scanCounts[_selectedType] ?? 0;
      return '$count ${_getLabelTypeName(_selectedType!)}${count != 1 ? 's' : ''}';
    }
    
    final counts = session.scanCounts.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.value} ${_getLabelTypeName(e.key)}${e.value != 1 ? 's' : ''}')
        .join(', ');
    
    return counts.isEmpty ? 'No scans' : counts;
  }

  Widget _buildScanItem(dynamic scan, bool isRescan) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(
          _getScanDetails(scan),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scanned at: ${_formatDateTime(scan.timeLog)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (isRescan)
              Text(
                'Rescan',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRescan)
              Container(
                margin: const EdgeInsets.only(right: 8),
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
            _getScanTypeIcon(scan),
          ],
        ),
      ),
    );
  }


  Icon _getScanTypeIcon(dynamic scan) {
    if (scan is FGPalletLabel) {
      return const Icon(Icons.inventory_2, color: Colors.blue);
    } else if (scan is RollLabel) {
      return const Icon(Icons.rotate_right, color: Colors.green);
    } else if (scan is FGLocationLabel) {
      return const Icon(Icons.location_on, color: Colors.orange);
    } else if (scan is PaperRollLocationLabel) {
      return const Icon(Icons.location_searching, color: Colors.purple);
    }
    return const Icon(Icons.help_outline, color: Colors.grey);
  }

  Widget _buildSessionCard(ScanSession session, int index) {
    final filteredScans = _getFilteredScans(session);
    
    if (filteredScans.isEmpty) {
      return const SizedBox.shrink();
    }

    // Count new scans and rescans
    int newScans = 0;
    int rescans = 0;
    for (var scan in filteredScans) {
      if (_isRescan(scan, session)) {
        rescans++;
      } else {
        newScans++;
      }
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Session ${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (session == _scanService.currentSession)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Current',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Started: ${_formatDateTime(session.startTime)}',
              style: const TextStyle(fontSize: 12),
            ),
            Row(
              children: [
                Text(
                  'New Scans: $newScans',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rescans: $rescans',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExportToCsvButton(
              sessions: [session],
              filterTypes: _selectedType != null ? [_selectedType!] : null,
              showIcon: false,
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredScans.length,
            itemBuilder: (context, index) {
              final scan = filteredScans[index];
              final isRescan = _isRescan(scan, session);
              return _buildScanItem(scan, isRescan);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  bool _isRescan(dynamic scan, ScanSession session) {
    String scanId = _getScanId(scan);
    // Check if this scan appears earlier in the same session or in previous sessions
    bool foundEarlier = false;
    
    // Check in current session
    for (var existingScan in session.scans) {
      if (_getScanId(existingScan) == scanId && existingScan.timeLog.isBefore(scan.timeLog)) {
        foundEarlier = true;
        break;
      }
    }
    
    // Check in previous sessions if not found in current
    if (!foundEarlier) {
      for (var prevSession in _sessions) {
        if (prevSession == session) break; // Stop at current session
        for (var existingScan in prevSession.scans) {
          if (_getScanId(existingScan) == scanId) {
            foundEarlier = true;
            break;
          }
        }
        if (foundEarlier) break;
      }
    }
    
    return foundEarlier;
  }

  String _getScanId(dynamic scan) {
    if (scan is FGPalletLabel) return scan.rawValue;
    if (scan is RollLabel) return scan.rollId;
    if (scan is FGLocationLabel) return scan.locationId;
    if (scan is PaperRollLocationLabel) return scan.locationId;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<LabelType?>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Filter by type',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.only(left: 10, right: 1),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All')),
                          ...LabelType.values.map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(_getLabelTypeName(type)),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    ExportToCsvButton(
                      sessions: _sessions,
                      filterTypes: _selectedType != null ? [_selectedType!] : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Show Rescans Only'),
                  value: _showRescanOnly,
                  onChanged: (value) {
                    setState(() {
                      _showRescanOnly = value;
                    });
                  },
                  dense: true,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) =>
                  _buildSessionCard(_sessions[index], index),
            ),
          ),
        ],
      ),
    );
  }
}