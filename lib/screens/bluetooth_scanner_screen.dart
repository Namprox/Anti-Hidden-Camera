import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/threat/threat_analyzer.dart';
import '../core/report/scan_session_store.dart';

class BluetoothScannerScreen extends StatefulWidget {
  const BluetoothScannerScreen({super.key});

  @override
  State<BluetoothScannerScreen> createState() => _BluetoothScannerScreenState();
}

// Helper Model để tránh tính Score lặp nhiều lần
class _ScoredBleResult {
  final ScanResult result;
  final ThreatScore score;

  const _ScoredBleResult({required this.result, required this.score});
}

class _BluetoothScannerScreenState extends State<BluetoothScannerScreen> {
  List<ScanResult> _scanResults = [];

  bool _isScanning = false;
  bool _hasScannedOnce = false;

  String _statusMessage = 'Sẵn sàng quét Bluetooth tầm gần';
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;

      final List<ScanResult> filteredResults = results
          .where((r) => r.rssi > -70)
          .toList();

      // Tính Score 1 lần cho mỗi thiết bị
      final List<_ScoredBleResult> scored = filteredResults.map((r) {
        final ThreatScore s = _analyzeScanResult(r);
        return _ScoredBleResult(result: r, score: s);
      }).toList();

      // Sort theo Score trước, sau đó RSSI
      scored.sort((a, b) {
        final int scoreCompare = b.score.score.compareTo(a.score.score);
        if (scoreCompare != 0) return scoreCompare;
        return b.result.rssi.compareTo(a.result.rssi);
      });

      // Update UI list
      setState(() {
        _scanResults = scored.map((e) => e.result).toList();
      });

      // Push vào ScanSessionStore (phục vụ Report)
      // NOTE: Làm ở đây để tránh gọi liên tục trong build()
      for (final item in scored) {
        final ScanResult r = item.result;
        final ThreatScore s = item.score;

        final String deviceId = r.device.remoteId.toString();
        final String name = r.device.platformName.trim();
        final bool isUnnamed = name.isEmpty;

        ScanSessionStore.instance.upsertBle(
          deviceId: deviceId,
          name: name,
          rssi: r.rssi,
          isUnnamed: isUnnamed,
          threatScore: s,
        );
      }
    });
  }

  Future<bool> _requestPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final bool bluetoothScanGranted =
        statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final bool bluetoothConnectGranted =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final bool locationGranted =
        statuses[Permission.location]?.isGranted ?? false;

    if (!bluetoothScanGranted || !bluetoothConnectGranted || !locationGranted) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Thiếu quyền Bluetooth hoặc vị trí. Hãy cấp quyền để quét thiết bị gần.';
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade800,
            content: const Text(
              'Ứng dụng cần quyền Bluetooth Scan, Bluetooth Connect và Location để quét thiết bị gần.',
            ),
            action: SnackBarAction(
              label: 'Cài đặt',
              textColor: Colors.white,
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      }

      return false;
    }

    return true;
  }

  Future<void> _startScan() async {
    final bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) return;

    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (e) {
      debugPrint('Lỗi dừng scan cũ: $e');
    }

    if (mounted) {
      setState(() {
        _isScanning = true;
        _hasScannedOnce = true;
        _scanResults.clear();
        _statusMessage = 'Đang dò sóng Bluetooth tầm gần';
      });
    }

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Lỗi quét Bluetooth: $e');

      if (mounted) {
        setState(() {
          _statusMessage =
              'Không thể bắt đầu quét Bluetooth. Hãy kiểm tra Bluetooth và quyền truy cập.';
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Lỗi quét Bluetooth: $e'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
        _statusMessage = _scanResults.isEmpty
            ? 'Không phát hiện thiết bị Bluetooth mạnh trong phạm vi gần.'
            : 'Đã phát hiện ${_scanResults.length} thiết bị Bluetooth gần.';
      });
    }
  }

  ThreatScore _analyzeScanResult(ScanResult result) {
    final String deviceName = result.device.platformName.trim();
    final String remoteId = result.device.remoteId.toString();

    final bool isUnnamedDevice = deviceName.isEmpty;

    return ThreatAnalyzer.analyzeDevice(
      ThreatDeviceInput(
        deviceId: remoteId,
        macAddress: remoteId,
        rssi: result.rssi,
        isUnnamedBluetoothDevice: isUnnamedDevice,
      ),
    );
  }

  String _getDeviceDisplayName(ScanResult result) {
    final String platformName = result.device.platformName.trim();

    if (platformName.isNotEmpty) {
      return platformName;
    }

    return 'Thiết bị không tên';
  }

  String _getDeviceSubtitle(ScanResult result, ThreatScore score) {
    final String remoteId = result.device.remoteId.toString();

    return 'MAC/ID: $remoteId\n'
        'Cường độ: ${result.rssi} dBm • ${score.levelLabel} • ${score.score}/100';
  }

  Color _colorForThreatLevel(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.safe:
        return Colors.greenAccent;
      case ThreatLevel.low:
        return Colors.yellowAccent;
      case ThreatLevel.medium:
        return Colors.orangeAccent;
      case ThreatLevel.high:
        return Colors.redAccent;
      case ThreatLevel.critical:
        return Colors.purpleAccent;
    }
  }

  IconData _iconForThreatLevel(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.safe:
        return Icons.bluetooth_connected;
      case ThreatLevel.low:
        return Icons.bluetooth_searching;
      case ThreatLevel.medium:
        return Icons.warning_amber_rounded;
      case ThreatLevel.high:
        return Icons.gpp_bad;
      case ThreatLevel.critical:
        return Icons.report;
    }
  }

  String _signalDistanceLabel(int rssi) {
    if (rssi >= -45) {
      return 'CỰC GẦN';
    }

    if (rssi >= -55) {
      return 'RẤT GẦN';
    }

    if (rssi >= -65) {
      return 'GẦN';
    }

    return 'TRONG PHẠM VI';
  }

  Color _signalColor(int rssi) {
    if (rssi >= -45) {
      return Colors.redAccent;
    }

    if (rssi >= -55) {
      return Colors.orangeAccent;
    }

    if (rssi >= -65) {
      return Colors.yellowAccent;
    }

    return Colors.lightBlueAccent;
  }

  Widget _buildThreatBadge(ThreatScore score) {
    final Color color = _colorForThreatLevel(score.level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.85), width: 1),
      ),
      child: Text(
        '${ThreatUiHelper.levelEmoji(score.level)} ${score.score}/100',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSignalBadge(int rssi) {
    final Color color = _signalColor(rssi);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.85), width: 1),
      ),
      child: Text(
        '${_signalDistanceLabel(rssi)} • $rssi dBm',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildHeaderPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.bluetooth_searching,
                color: Colors.lightBlueAccent,
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bluetooth Proximity Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Gợi ý: thiết bị không tên hoặc tín hiệu Bluetooth rất mạnh không đồng nghĩa chắc chắn là camera, nhưng là tín hiệu đáng kiểm tra khi kết hợp với Wi‑Fi, LAN, từ trường và quang học.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: ElevatedButton.icon(
        onPressed: _isScanning ? null : _startScan,
        icon: _isScanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.bluetooth),
        label: Text(
          _isScanning ? 'Đang dò sóng gần' : 'Quét Bluetooth Tầm Gần',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(55),
          backgroundColor: _isScanning
              ? Colors.grey.shade600
              : Colors.lightBlueAccent.shade400,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.grey.shade700,
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String title;
    String message;

    if (!_hasScannedOnce) {
      icon = Icons.bluetooth_disabled;
      title = 'Chưa quét Bluetooth';
      message =
          'Bấm nút quét để dò các thiết bị Bluetooth đang phát tín hiệu gần bạn.';
    } else if (_isScanning) {
      icon = Icons.bluetooth_searching;
      title = 'Đang quét';
      message =
          'Hãy di chuyển chậm quanh khu vực nghi vấn. App sẽ ưu tiên thiết bị có tín hiệu mạnh.';
    } else {
      icon = Icons.verified_user;
      title = 'Không thấy thiết bị gần';
      message =
          'Không phát hiện thiết bị Bluetooth có tín hiệu đủ mạnh trong phạm vi gần.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white24, size: 76),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanResultTile(ScanResult result) {
    final ThreatScore score = _analyzeScanResult(result);

    final String deviceName = _getDeviceDisplayName(result);
    final String remoteId = result.device.remoteId.toString();
    final bool isUnnamed = result.device.platformName.trim().isEmpty;

    final Color levelColor = _colorForThreatLevel(score.level);
    final IconData icon = _iconForThreatLevel(score.level);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: score.score >= 65
          ? const Color(0xFF2E1A1A)
          : const Color(0xFF1F1F1F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: score.score >= 65
              ? levelColor.withOpacity(0.75)
              : Colors.white.withOpacity(0.08),
          width: score.score >= 65 ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDeviceDetails(result, score),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.13),
                  shape: BoxShape.circle,
                  border: Border.all(color: levelColor.withOpacity(0.7)),
                ),
                child: Icon(icon, color: levelColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnnamed ? Colors.orangeAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _getDeviceSubtitle(result, score),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _buildThreatBadge(score),
                          _buildSignalBadge(result.rssi),
                          if (isUnnamed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.orangeAccent.withOpacity(0.85),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'KHÔNG TÊN',
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.white30,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeviceDetails(ScanResult result, ThreatScore score) {
    final String deviceName = _getDeviceDisplayName(result);
    final String remoteId = result.device.remoteId.toString();
    final bool isUnnamed = result.device.platformName.trim().isEmpty;

    final Color levelColor = _colorForThreatLevel(score.level);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: levelColor.withOpacity(0.85), width: 1.4),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _iconForThreatLevel(score.level),
                color: levelColor,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  deviceName,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSummaryBox(result, score),
                  const SizedBox(height: 14),
                  const Text(
                    'Bằng chứng phân tích',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (score.evidences.where((e) => e.score > 0).isEmpty)
                    const Text(
                      'Chưa có bằng chứng nghi vấn mạnh. Thiết bị này vẫn nên được đối chiếu với Wi‑Fi, LAN, từ trường và quang học nếu bạn đang kiểm tra khu vực nhạy cảm.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    )
                  else
                    Column(
                      children: score.evidences
                          .where((e) => e.score > 0)
                          .map((e) => _buildEvidenceItem(e))
                          .toList(),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Khuyến nghị',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    score.shortAdvice,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isUnnamed)
                    const Text(
                      'Lưu ý: Thiết bị Bluetooth không tên có thể là tai nghe, vòng đeo, remote, thiết bị IoT hoặc thiết bị BLE hợp pháp. Không nên kết luận là camera nếu chưa có thêm bằng chứng từ các module khác.',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'ID thiết bị: $remoteId',
                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'ĐÓNG',
                style: TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailSummaryBox(ScanResult result, ThreatScore score) {
    final Color levelColor = _colorForThreatLevel(score.level);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: levelColor.withOpacity(0.11),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: levelColor.withOpacity(0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ThreatUiHelper.levelEmoji(score.level)} ${score.levelLabel}',
            style: TextStyle(
              color: levelColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Điểm rủi ro: ${score.score}/100',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            score.summary,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cường độ Bluetooth: ${result.rssi} dBm • ${_signalDistanceLabel(result.rssi)}',
            style: TextStyle(
              color: _signalColor(result.rssi),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceItem(ThreatEvidence evidence) {
    final Color color = _colorForEvidenceSeverity(evidence.severity);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ThreatUiHelper.severityEmoji(evidence.severity),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evidence.title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  evidence.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '+${evidence.score} điểm • ${ThreatUiHelper.sourceLabel(evidence.source)}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForEvidenceSeverity(EvidenceSeverity severity) {
    switch (severity) {
      case EvidenceSeverity.info:
        return Colors.lightBlueAccent;
      case EvidenceSeverity.low:
        return Colors.yellowAccent;
      case EvidenceSeverity.medium:
        return Colors.orangeAccent;
      case EvidenceSeverity.high:
        return Colors.redAccent;
      case EvidenceSeverity.critical:
        return Colors.purpleAccent;
    }
  }

  Widget _buildResultsList() {
    if (_scanResults.isEmpty) {
      return Expanded(child: _buildEmptyState());
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          final ScanResult result = _scanResults[index];
          return _buildScanResultTile(result);
        },
      ),
    );
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Dò Sóng Camera Mini (Bluetooth)'),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeaderPanel(),
          _buildScanButton(),
          _buildResultsList(),
        ],
      ),
    );
  }
}