import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:check_hidden_camera/utils/oui_helper.dart';
import '../core/threat/threat_analyzer.dart';
import '../core/report/scan_session_store.dart';

class WifiRadarScreen extends StatefulWidget {
  const WifiRadarScreen({super.key});

  @override
  State<WifiRadarScreen> createState() => _WifiRadarScreenState();
}

class _WifiRadarScreenState extends State<WifiRadarScreen> {
  List<WiFiAccessPoint> _accessPoints = [];
  bool _isRadarActive = false;
  StreamSubscription<List<WiFiAccessPoint>>? _subscription;
  Timer? _radarTimer;

  // Ống dẫn dữ liệu trực tiếp: Dùng để bơm sóng mới thẳng vào Popup
  final ValueNotifier<List<WiFiAccessPoint>> _accessPointsNotifier =
      ValueNotifier([]);

  // Threat Analyzer Cache
  final Map<String, ThreatScore> _scoreCache = {};
  DateTime _lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    // Thay đổi logic khởi tạo: Load xong Database rồi mới bật bộ lắng nghe
    _initRadarSystem();
  }

  Future<void> _initRadarSystem() async {
    // Gọi hàm load file JSON vào RAM
    await OuiHelper.initDatabase();
    _startListeningToScanResults();
  }

  void _startListeningToScanResults() {
    _subscription = WiFiScan.instance.onScannedResultsAvailable.listen((
      results,
    ) {
      if (!mounted) return;

      // Lọc RSSI đủ mạnh
      final filtered = results.where((ap) => ap.level >= -75).toList();

      // Tính ThreatScore cho từng AP và cache (giảm tính toán lặp)
      // Cập nhật cache theo nhịp scan
      _updateScoreCache(filtered);

      // Sort ưu tiên Score trước, sau đó RSSI
      filtered.sort((a, b) {
        final sa = _scoreCache[a.bssid]?.score ?? 0;
        final sb = _scoreCache[b.bssid]?.score ?? 0;

        if (sa != sb) return sb.compareTo(sa);
        return b.level.compareTo(a.level);
      });

      setState(() {
        _accessPoints = filtered;

        // Bơm dữ liệu mới vào ống dẫn để Popup nhận được
        _accessPointsNotifier.value = List.from(_accessPoints);
      });
    });
  }

  void _updateScoreCache(List<WiFiAccessPoint> aps) {
    // Mỗi lượt scan đều có thể đổi RSSI => Score có thể đổi
    // Để đơn giản và đúng realtime, ta update toàn bộ trong danh sách lọc
    _lastCacheUpdate = DateTime.now();

    for (final ap in aps) {
      final vendor = OuiHelper.lookup(ap.bssid);

      final ThreatScore score = ThreatAnalyzer.analyzeDevice(
        ThreatDeviceInput(
          deviceId: ap.bssid,
          macAddress: ap.bssid,
          ssid: ap.ssid,
          vendor: vendor,
          rssi: ap.level,
          frequency: ap.frequency,
          isHiddenSsid: ap.ssid.isEmpty,
          isNewAfterBaseline: false,
        ),
      );

      _scoreCache[ap.bssid] = score;

      // Cập nhật vào ScanSessionStore
      ScanSessionStore.instance.upsertWifi(
        bssid: ap.bssid,
        ssid: ap.ssid,
        vendor: vendor,
        rssi: ap.level,
        frequency: ap.frequency,
        isHiddenSsid: ap.ssid.isEmpty,
        threatScore: score,
      );
    }
  }

  Future<void> _toggleRadarMode() async {
    if (await Permission.location.request().isDenied) return;

    setState(() {
      if (_isRadarActive) {
        _radarTimer?.cancel();
        _isRadarActive = false;
      } else {
        _isRadarActive = true;
        _executeWifiScan();
        _radarTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
          _executeWifiScan();
        });
      }
    });
  }

  Future<void> _executeWifiScan() async {
    final canScan = await WiFiScan.instance.canStartScan();

    if (canScan == CanStartScan.yes) {
      await WiFiScan.instance.startScan();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hệ thống đang nghẽn sóng (Bị giới hạn Throttling), đang đợi lượt quét tiếp theo',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _subscription?.cancel();
    _accessPointsNotifier.dispose();
    super.dispose();
  }

  // Threat UI HELPERS

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

  Widget _buildEvidenceItem(ThreatEvidence evidence) {
    final Color color = _colorForEvidenceSeverity(evidence.severity);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evidence.title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  evidence.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    height: 1.35,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
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

  void _showEvidenceDialog(WiFiAccessPoint ap) {
    final ThreatScore? score = _scoreCache[ap.bssid];

    if (score == null) return;

    final Color levelColor = _colorForThreatLevel(score.level);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: levelColor.withOpacity(0.85), width: 1.2),
        ),
        title: Row(
          children: [
            Icon(Icons.security, color: levelColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${score.levelLabel} • ${score.score}/100',
                style: TextStyle(
                  color: levelColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
                Text(
                  score.summary,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 10),
                Text(
                  score.shortAdvice,
                  style: const TextStyle(
                    color: Colors.white60,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Bằng chứng (Evidence)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (score.evidences.where((e) => e.score > 0).isEmpty)
                  const Text(
                    'Chưa có bằng chứng nghi vấn mạnh.',
                    style: TextStyle(color: Colors.white54),
                  )
                else
                  Column(
                    children: score.evidences
                        .where((e) => e.score > 0)
                        .take(8)
                        .map((e) => _buildEvidenceItem(e))
                        .toList(),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'Thông số mạng',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'SSID: ${ap.ssid.isEmpty ? "MẠNG ẨN" : ap.ssid}\n'
                  'BSSID: ${ap.bssid}\n'
                  'RSSI: ${ap.level} dBm\n'
                  'Freq: ${ap.frequency} MHz\n'
                  'Cache time: ${_lastCacheUpdate.hour.toString().padLeft(2, '0')}:${_lastCacheUpdate.minute.toString().padLeft(2, '0')}:${_lastCacheUpdate.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, height: 1.35),
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
      ),
    );
  }

  Widget _buildRiskBadge(ThreatScore score) {
    final Color c = _colorForThreatLevel(score.level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.65)),
      ),
      child: Text(
        '${ThreatUiHelper.levelEmoji(score.level)} ${score.score}',
        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  // Thuật toán phân tích tên mạng + vendor + FSPL
  Map<String, dynamic> _analyzeWifiNetwork(WiFiAccessPoint ap) {
    String ssid = ap.ssid.isEmpty ? "MẠNG WI-FI ẨN (Hidden SSID)" : ap.ssid;
    String lowerSsid = ssid.toLowerCase();

    // Vendor từ OUI
    String vendorName = OuiHelper.lookup(ap.bssid);

    // ThreatScore từ cache
    final ThreatScore score =
        _scoreCache[ap.bssid] ??
        ThreatAnalyzer.analyzeDevice(
          ThreatDeviceInput(
            deviceId: ap.bssid,
            macAddress: ap.bssid,
            ssid: ap.ssid,
            vendor: vendorName,
            rssi: ap.level,
            frequency: ap.frequency,
            isHiddenSsid: ap.ssid.isEmpty,
          ),
        );

    bool isSuspicious =
        score.level == ThreatLevel.high ||
        score.level == ThreatLevel.critical ||
        score.level == ThreatLevel.medium;

    String warningText = "Trạm phát bình thường";
    Color iconColor = _colorForThreatLevel(score.level);
    IconData icon = Icons.wifi;

    // GIỮ heuristic cũ để tạo text "thuyết phục", nhưng màu/độ nghi vấn dựa trên Score
    if (vendorName.contains("Espressif") ||
        vendorName.contains("Tuya") ||
        vendorName.contains("Hikvision") ||
        vendorName.contains("Xiongmai") ||
        vendorName.contains("Dahua")) {
      warningText = "🔴 PHÁT HIỆN LỖ HỔNG: Phần cứng thuộc về ($vendorName)";
      icon = Icons.gpp_bad;
    } else {
      if (lowerSsid.contains("cam") ||
          lowerSsid.contains("ipc") ||
          lowerSsid.contains("mv") ||
          lowerSsid.contains("v380")) {
        warningText = "🔴 TÊN MẠNG RẤT KHẢ NGHI (Dấu hiệu Camera)";
        icon = Icons.camera_indoor;
      } else if (ap.ssid.isEmpty) {
        warningText = "🟡 MẠNG ẨN TÊN (Kẻ gian hay dùng để giấu)";
        icon = Icons.visibility_off;
      } else if (RegExp(r'^[0-9A-F]{6,}$').hasMatch(ssid)) {
        warningText = "🟡 TÊN MẠNG LÀ MÃ SỐ LẠ (Có thể là ID Camera)";
        icon = Icons.help_outline;
      } else if (!vendorName.contains("Không có") &&
          !vendorName.contains("không hợp lệ")) {
        warningText = "Nhà sản xuất: $vendorName";
        icon = Icons.wifi;
      }
    }

    // Xử lý 5GHz/2.4GHz
    double referencePower;
    double environmentalFactor;
    String bandLabel;

    if (ap.frequency >= 5000) {
      referencePower = -52.0;
      environmentalFactor = 3.2;
      bandLabel = "5GHz";
    } else {
      referencePower = -45.0;
      environmentalFactor = 2.5;
      bandLabel = "2.4GHz";
    }

    double rssi = ap.level.toDouble();
    double rawDistance = pow(
      10.0,
      (referencePower - rssi) / (10 * environmentalFactor),
    ).toDouble();

    String estimatedMeters = rawDistance.toStringAsFixed(1);

    String distanceStatus;
    if (rawDistance < 1.0) {
      distanceStatus = "CỰC KỲ GẦN (< 1m) - Tìm ngay!";
    } else if (rawDistance <= 3.0) {
      distanceStatus = "TRONG PHÒNG (~ $estimatedMeters mét)";
    } else {
      distanceStatus = "Khá xa (~ $estimatedMeters mét)";
    }

    return {
      "name": ssid,
      "warning": warningText,
      "color": iconColor,
      "icon": icon,
      "distanceStatus": distanceStatus,
      "isSuspicious": isSuspicious,
      "estimatedMeters": estimatedMeters,
      "band": bandLabel,
      "vendor": vendorName,
      "score": score,
    };
  }

  // Popup đã được nâng cấp để nghe dữ liệu Real-time + ThreatScore
  void _showTrackingDialog(
    WiFiAccessPoint target,
    Map<String, dynamic> initialAnalysis,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return ValueListenableBuilder<List<WiFiAccessPoint>>(
          valueListenable: _accessPointsNotifier,
          builder: (context, currentAccessPoints, child) {
            WiFiAccessPoint currentTarget = currentAccessPoints.firstWhere(
              (ap) => ap.bssid == target.bssid,
              orElse: () => target,
            );

            // Update Score Real-time
            final ThreatScore score =
                _scoreCache[currentTarget.bssid] ??
                (initialAnalysis["score"] as ThreatScore);

            // Tính toán lại khoảng cách Real-time
            double referencePower = currentTarget.frequency >= 5000
                ? -52.0
                : -45.0;
            double environmentalFactor = currentTarget.frequency >= 5000
                ? 3.2
                : 2.5;
            double rssi = currentTarget.level.toDouble();

            double rawDistance = pow(
              10.0,
              (referencePower - rssi) / (10 * environmentalFactor),
            ).toDouble();

            Color barColor;
            String instruction;

            if (rawDistance < 1.0) {
              barColor = Colors.redAccent;
              instruction =
                  "MỤC TIÊU NGAY TRƯỚC MẮT\nDùng đèn Flash rà lỗ ống kính ngay!";
            } else if (rawDistance <= 2.5) {
              barColor = Colors.orangeAccent;
              instruction = "ĐANG ĐI ĐÚNG HƯỚNG\nTiếp tục tiến lại gần vật thể";
            } else {
              barColor = Colors.tealAccent;
              instruction =
                  "QUÉT MÁY SANG CÁC HƯỚNG KHÁC\nTìm điểm có khoảng cách ngắn nhất";
            }

            double signalPercent = (100 - (currentTarget.level.abs() - 40))
                .clamp(0, 100)
                .toDouble();

            final Color riskColor = _colorForThreatLevel(score.level);

            return AlertDialog(
              backgroundColor: const Color(0xFF121212),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: barColor, width: 2),
              ),
              title: const Text(
                'ĐANG KHÓA MỤC TIÊU',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    initialAnalysis["name"],
                    style: TextStyle(
                      color: initialAnalysis["color"],
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Địa chỉ MAC: ${currentTarget.bssid}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 10),

                  // Risk badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: riskColor.withOpacity(0.6)),
                    ),
                    child: Text(
                      '${ThreatUiHelper.levelEmoji(score.level)} ${score.levelLabel} • ${score.score}/100',
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    '${rawDistance.toStringAsFixed(1)} m',
                    style: TextStyle(
                      color: barColor,
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'ƯỚC TÍNH KHOẢNG CÁCH VẬT LÝ',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),

                  LinearProgressIndicator(
                    value: signalPercent / 100,
                    backgroundColor: Colors.grey.shade900,
                    color: barColor,
                    minHeight: 16,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tín hiệu: ${currentTarget.level} dBm (${initialAnalysis["band"]}) \nHiệu suất sóng: ${signalPercent.toInt()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: barColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      instruction,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: barColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Evidence button
                  TextButton.icon(
                    onPressed: () => _showEvidenceDialog(currentTarget),
                    icon: const Icon(Icons.receipt_long, color: Colors.white70),
                    label: const Text(
                      'XEM BẰNG CHỨNG',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      'HỦY THEO DÕI',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Radar Sóng Wi-Fi & 4G AP'),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _toggleRadarMode,
              icon: _isRadarActive
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.radar),
              label: Text(
                _isRadarActive
                    ? 'RADAR ĐANG CHẠY REAL-TIME'
                    : 'KÍCH HOẠT RADAR LIÊN TỤC',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(55),
                backgroundColor: _isRadarActive
                    ? Colors.redAccent
                    : Colors.purpleAccent.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _accessPoints.length,
              itemBuilder: (context, index) {
                final ap = _accessPoints[index];
                final analysis = _analyzeWifiNetwork(ap);
                final ThreatScore score = analysis["score"] as ThreatScore;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: analysis["isSuspicious"]
                      ? const Color(0xFF2E1A1A)
                      : const Color(0xFF1F1F1F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: analysis["isSuspicious"]
                          ? (analysis["color"] as Color).withOpacity(0.5)
                          : Colors.white10,
                      width: analysis["isSuspicious"] ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      analysis["icon"] as IconData,
                      color: analysis["color"] as Color,
                      size: 32,
                    ),
                    title: Text(
                      analysis["name"] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: analysis["color"] as Color,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          analysis["warning"] as String,
                          style: TextStyle(
                            color: analysis["color"] as Color,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildRiskBadge(score),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Định vị: ${analysis["distanceStatus"]}\nSóng: ${ap.level} dBm | ${ap.frequency} MHz (${analysis["band"]})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Địa chỉ MAC: ${ap.bssid}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.my_location,
                      color: Colors.white30,
                      size: 22,
                    ),
                    onTap: () => _showTrackingDialog(ap, analysis),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}