import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:lan_scanner/lan_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/threat/threat_analyzer.dart';
import '../core/report/scan_session_store.dart';
import '../utils/oui_helper.dart';

class LanScannerScreen extends StatefulWidget {
  const LanScannerScreen({super.key});

  @override
  State<LanScannerScreen> createState() => _LanScannerScreenState();
}

class _LanScannerScreenState extends State<LanScannerScreen> {
  final List<Host> _hosts = [];
  bool _isScanning = false;
  bool _isDeepScanning = false;
  String _scanProgressText = "";

  // Bộ nhớ trạng thái UI để hỗ trợ chạy ngầm đa luồng
  final Map<String, String> _deviceLabels = {};
  final Map<String, List<int>> _devicePorts = {};
  final Map<String, bool> _analyzingStatus = {};

  // Threat Analyzer Integration
  final Map<String, ThreatScore> _threatScores = {};
  final Map<String, DateTime> _lastAnalyzedAt = {};

  // Hàm đọc bảng ARP nội bộ của hệ điều hành để tra MAC từ IP
  Future<String?> _getMacFromIp(String targetIp) async {
    try {
      if (Platform.isAndroid || Platform.isLinux) {
        // Đọc file cấu hình ARP table trên Android/Linux
        final result = await Process.run('cat', ['/proc/net/arp']);
        final lines = result.stdout.toString().split('\n');

        for (var line in lines) {
          if (line.contains(targetIp)) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final mac = parts[3].toUpperCase();
              // Bỏ qua MAC ảo hoặc chưa phân giải kịp
              if (mac != '00:00:00:00:00:00') {
                return mac;
              }
            }
          }
        }
      } else if (Platform.isMacOS || Platform.isWindows) {
        // Lệnh arp -a trên Win/Mac
        final result = await Process.run('arp', ['-a']);
        final lines = result.stdout.toString().split('\n');

        for (var line in lines) {
          if (line.contains(targetIp)) {
            final RegExp macRegex = RegExp(
              r'([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})',
            );
            final match = macRegex.firstMatch(line);
            if (match != null) {
              return match.group(0)?.replaceAll('-', ':').toUpperCase();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi đọc bảng ARP: $e');
    }
    return null;
  }

  // Quét nhanh (ICMP PING)
  Future<void> _scanLan() async {
    _prepareForScan();
    setState(() => _scanProgressText = "Đang rà soát IP mạng cục bộ");

    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP();
    if (wifiIP == null) {
      if (mounted) setState(() => _isScanning = false);
      return;
    }

    final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    final scanner = LanScanner();

    try {
      final List<Host> results = await scanner.quickIcmpScanSync(subnet);
      if (mounted) {
        setState(() {
          _hosts.addAll(results);
          _isScanning = false;
        });

        // Tự động kích hoạt quét cổng cho toàn bộ IP tìm thấy
        for (var host in results) {
          _analyzeDeviceBackground(host.internetAddress.address);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // Quét sâu (DEEP PORT SCANNING & ANTI-STEALTH)
  Future<void> _deepScanLan() async {
    _prepareForScan(isDeep: true);

    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP();
    if (wifiIP == null) {
      if (mounted) setState(() => _isDeepScanning = false);
      return;
    }

    final currentSubnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    final scanner = LanScanner();

    // BƯỚC 1: Quét ICMP nhanh để lấy nền tảng các thiết bị công khai
    setState(
      () => _scanProgressText = "1/2: Đang lấy danh sách thiết bị công khai",
    );

    try {
      final List<Host> results = await scanner.quickIcmpScanSync(
        currentSubnet,
        timeout: const Duration(seconds: 1),
      );

      if (mounted && results.isNotEmpty) {
        setState(() {
          _hosts.addAll(results);
        });

        for (var host in results) {
          _analyzeDeviceBackground(host.internetAddress.address);
        }
      }
    } catch (e) {}

    // BƯỚC 2: Tấn công TCP sâu - Ép các thiết bị Camera tàng hình (chặn Ping) phải lộ diện
    if (!mounted) return;

    setState(
      () => _scanProgressText = "2/2: Đang tấn công TCP sâu tìm Camera ẩn",
    );

    int totalIps = 254;
    int completedIps = 0;
    const int batchSize = 25; // Chia cụm đa luồng để tránh Crash Card Wi-Fi

    // Các cổng RTSP, Video Stream và Web config thông dụng nhất của Camera gián điệp
    List<int> stealthPorts = [554, 81, 8080, 37777, 1935, 8000];

    for (int i = 1; i <= totalIps; i += batchSize) {
      if (!mounted) break;

      List<Future<void>> batchFutures = [];

      for (int j = i; j < i + batchSize && j <= totalIps; j++) {
        String targetIp = "$currentSubnet.$j";

        // Bỏ qua nếu thiết bị đã được tìm thấy ở Bước 1
        if (_hosts.any((h) => h.internetAddress.address == targetIp)) {
          completedIps++;
          continue;
        }

        // Bắn Socket thẳng vào IP để kiểm tra
        batchFutures.add(
          _checkStealthDevice(targetIp, stealthPorts).then((_) {
            completedIps++;
            if (mounted) {
              setState(() {
                _scanProgressText =
                    "2/2: Quét TCP sâu ${((completedIps / totalIps) * 100).toInt()}%";
              });
            }
          }),
        );
      }

      // Đợi xử lý xong cụm 25 IP này mới bắn tiếp
      await Future.wait(batchFutures);
    }

    if (mounted) {
      setState(() {
        _isDeepScanning = false;
        _scanProgressText = "Đã hoàn tất rà quét toàn diện!";
      });
    }
  }

  // Thuật toán kiểm tra cổng bí mật đối với các IP chặn ICMP
  Future<void> _checkStealthDevice(String ip, List<int> ports) async {
    List<int> openPorts = [];

    // Tối ưu hóa: Quét song song các cổng để tiết kiệm thời gian
    List<Future<void>> portTasks = ports.map((port) async {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 400),
        );
        openPorts.add(port);
        socket.destroy();
      } catch (e) {}
    }).toList();

    await Future.wait(portTasks);

    // Nếu có cổng mở -> Lột mặt nạ thiết bị tàng hình
    if (openPorts.isNotEmpty) {
      // Đọc MAC từ bảng ARP
      final String? mac = await _getMacFromIp(ip);
      String vendor = "Không xác định";
      if (mac != null) {
        vendor = OuiHelper.lookup(mac);
      }

      final ThreatScore threatScore = ThreatAnalyzer.analyzeDevice(
        ThreatDeviceInput(
          deviceId: ip,
          ipAddress: ip,
          macAddress: mac,
          vendor: vendor,
          openPorts: openPorts,
        ),
      );

      // Cập nhật vào ScanSessionStore
      ScanSessionStore.instance.upsertLan(
        ip: ip,
        openPorts: openPorts,
        threatScore: threatScore,
      );

      if (mounted) {
        setState(() {
          // Ép thiết bị vào danh sách UI
          _hosts.add(
            Host(internetAddress: InternetAddress(ip), pingTime: Duration.zero),
          );

          _devicePorts[ip] = openPorts;
          _threatScores[ip] = threatScore;
          _lastAnalyzedAt[ip] = DateTime.now();

          // Dựa trên Score để đặt nhãn (đồng bộ toàn app)
          _deviceLabels[ip] = _labelFromThreatScore(
            ip: ip,
            openPorts: openPorts,
            threatScore: threatScore,
            isStealth: true,
          );

          _analyzingStatus[ip] = false;
        });
      }
    }
  }

  void _prepareForScan({bool isDeep = false}) {
    setState(() {
      _hosts.clear();
      _deviceLabels.clear();
      _devicePorts.clear();
      _analyzingStatus.clear();
      _threatScores.clear();
      _lastAnalyzedAt.clear();

      if (isDeep) {
        _isDeepScanning = true;
      } else {
        _isScanning = true;
      }
    });

    Permission.location.request();
  }

  // Thuật toán phân tích cổng tự động cho các thiết bị công khai
  Future<void> _analyzeDeviceBackground(String ip) async {
    setState(() {
      _analyzingStatus[ip] = true;
    });

    List<int> cameraPorts = [554, 80, 81, 8080, 1935, 5000, 8000, 37777, 8999];
    List<int> openPorts = [];

    // Tối ưu hóa: Quét song song các cổng mạng
    List<Future<void>> portTasks = cameraPorts.map((port) async {
      try {
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 600),
        );
        openPorts.add(port);
        socket.destroy();
      } catch (e) {}
    }).toList();

    await Future.wait(portTasks);

    // Đọc MAC Address từ bảng ARP để phát hiện Camera Cloud
    final String? mac = await _getMacFromIp(ip);
    String vendor = "Không xác định";
    if (mac != null) {
      vendor = OuiHelper.lookup(mac);
    }

    final ThreatScore threatScore = ThreatAnalyzer.analyzeDevice(
      ThreatDeviceInput(
        deviceId: ip,
        ipAddress: ip,
        macAddress: mac,
        vendor: vendor,
        openPorts: openPorts,
      ),
    );

    // Cập nhật vào ScanSessionStore
    ScanSessionStore.instance.upsertLan(
      ip: ip,
      openPorts: openPorts,
      threatScore: threatScore,
    );

    if (mounted) {
      setState(() {
        _devicePorts[ip] = openPorts;
        _threatScores[ip] = threatScore;
        _lastAnalyzedAt[ip] = DateTime.now();

        _deviceLabels[ip] = _labelFromThreatScore(
          ip: ip,
          openPorts: openPorts,
          threatScore: threatScore,
          isStealth: false,
        );

        _analyzingStatus[ip] = false;
      });
    }
  }

  String _labelFromThreatScore({
    required String ip,
    required List<int> openPorts,
    required ThreatScore threatScore,
    required bool isStealth,
  }) {
    // Nếu có dấu hiệu nguy hiểm nặng hoặc Score cao -> đỏ
    final bool hasStrongPorts =
        openPorts.contains(554) ||
        openPorts.contains(37777) ||
        openPorts.contains(1935);

    if (threatScore.level == ThreatLevel.critical ||
        threatScore.level == ThreatLevel.high ||
        hasStrongPorts) {
      return isStealth
          ? "🔴 CAMERA ẨN (Cố tình chặn Ping) • ${threatScore.score}/100"
          : "🔴 Camera IP / Đầu Ghi Hình • ${threatScore.score}/100";
    }

    // Trung bình -> vàng
    if (threatScore.level == ThreatLevel.medium ||
        openPorts.isNotEmpty ||
        openPorts.length >= 2) {
      return isStealth
          ? "🟡 Thiết bị Ẩn (Có cổng mở) • ${threatScore.score}/100"
          : "🟡 Thiết bị Chưa Rõ • ${threatScore.score}/100";
    }

    // Thấp / an toàn -> xanh
    if (openPorts.isEmpty) {
      return "🟢 Thiết bị An Toàn • ${threatScore.score}/100";
    }

    return "🟡 Thiết bị Chưa Rõ • ${threatScore.score}/100";
  }

  // Pop-Up hiển thị chi tiết (đã tích hợp Threat Evidence)
  void _showDeviceDetails(String ip) {
    final ports = _devicePorts[ip] ?? [];
    final label = _deviceLabels[ip] ?? "";
    final bool isDangerous = label.contains("🔴");

    final ThreatScore? score = _threatScores[ip];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(
              isDangerous ? Icons.warning_amber_rounded : Icons.check_circle,
              color: isDangerous ? Colors.redAccent : Colors.greenAccent,
              size: 30,
            ),
            const SizedBox(width: 10),
            const Text(
              'Chi tiết thiết bị',
              style: TextStyle(color: Colors.white),
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
                  'IP: $ip',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ports.isEmpty
                      ? 'Cổng mở: Không phát hiện cổng.'
                      : 'Cổng mở: ${ports.join(", ")}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                if (score != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _colorForThreatLevel(
                        score.level,
                      ).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _colorForThreatLevel(
                          score.level,
                        ).withOpacity(0.7),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ThreatUiHelper.levelEmoji(score.level)} ${score.levelLabel} • ${score.score}/100',
                          style: TextStyle(
                            color: _colorForThreatLevel(score.level),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          score.summary,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          score.shortAdvice,
                          style: const TextStyle(
                            color: Colors.white60,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      'Chưa có bằng chứng nghi vấn mạnh từ LAN.',
                      style: TextStyle(color: Colors.white54),
                    )
                  else
                    Column(
                      children: score.evidences
                          .where((e) => e.score > 0)
                          .map((e) => _buildEvidenceItem(e))
                          .toList(),
                    ),
                ] else ...[
                  Text(
                    isDangerous
                        ? 'CẢNH BÁO NGUY HIỂM:\nPhát hiện thiết bị này đang mở cổng truyền Video/Đầu ghi: ${ports.join(", ")}.\n\nNguy cơ cao là hệ thống theo dõi!'
                        : (ports.isEmpty
                              ? 'Thiết bị dân sự an toàn, không mở cổng truyền phát'
                              : 'Phát hiện cổng mở: ${ports.join(", ")}. Không có dấu hiệu rõ ràng của Camera'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
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

  @override
  Widget build(BuildContext context) {
    bool isAnyScanning = _isScanning || _isDeepScanning;

    // Sắp xếp danh sách tự động:
    // 1) Score cao lên đầu (Threat Analyzer)
    // 2) Đang phân tích
    // 3) Label cũ (đỏ/vàng/xanh)
    _hosts.sort((a, b) {
      final ipA = a.internetAddress.address;
      final ipB = b.internetAddress.address;

      final int scoreA = _threatScores[ipA]?.score ?? 0;
      final int scoreB = _threatScores[ipB]?.score ?? 0;

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }

      final bool analyzingA = _analyzingStatus[ipA] ?? false;
      final bool analyzingB = _analyzingStatus[ipB] ?? false;

      if (analyzingA != analyzingB) {
        return analyzingA ? -1 : 1;
      }

      final labelA = _deviceLabels[ipA] ?? "";
      final labelB = _deviceLabels[ipB] ?? "";

      int legacyA = labelA.contains("🔴")
          ? 3
          : (labelA.contains("🟡") ? 2 : (labelA.isEmpty ? 1 : 0));
      int legacyB = labelB.contains("🔴")
          ? 3
          : (labelB.contains("🟡") ? 2 : (labelB.isEmpty ? 1 : 0));

      return legacyB.compareTo(legacyA);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Quét Cấu Trúc Mạng (LAN)'),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isAnyScanning ? null : _scanLan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.wifi_find, size: 20),
                    label: const Text(
                      'Quét Nhanh',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent.shade400,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isAnyScanning ? null : _deepScanLan,
                    icon: _isDeepScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.travel_explore, size: 20),
                    label: const Text(
                      'Quét Sâu TCP',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isAnyScanning || _analyzingStatus.containsValue(true))
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                isAnyScanning
                    ? _scanProgressText
                    : "Đang phân tích các cổng dịch vụ ngầm",
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _hosts.length,
              itemBuilder: (context, index) {
                final ip = _hosts[index].internetAddress.address;

                final bool isAnalyzing = _analyzingStatus[ip] ?? false;
                final bool isAnalyzed = _deviceLabels.containsKey(ip);

                final ThreatScore? score = _threatScores[ip];
                final int scoreValue = score?.score ?? 0;
                final ThreatLevel level = score?.level ?? ThreatLevel.safe;

                String titleText = ip;
                String subtitleText = 'Đang xếp hàng';
                Widget leadingIcon = const Icon(
                  Icons.router,
                  color: Colors.orangeAccent,
                );

                if (isAnalyzing) {
                  subtitleText = 'Đang phân tích bảo mật';
                  leadingIcon = const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.tealAccent,
                      strokeWidth: 2,
                    ),
                  );
                } else if (isAnalyzed) {
                  final String currentLabel = _deviceLabels[ip]!;
                  final List<int> ports = _devicePorts[ip] ?? [];

                  titleText = currentLabel;
                  subtitleText = ports.isEmpty
                      ? 'IP: $ip • Score: $scoreValue/100'
                      : 'IP: $ip • Mở: ${ports.join(", ")} • Score: $scoreValue/100';

                  if (currentLabel.contains("🔴")) {
                    leadingIcon = const Icon(
                      Icons.gpp_bad,
                      color: Colors.redAccent,
                      size: 28,
                    );
                  } else if (currentLabel.contains("🟢")) {
                    leadingIcon = const Icon(
                      Icons.verified,
                      color: Colors.greenAccent,
                      size: 28,
                    );
                  } else {
                    leadingIcon = const Icon(
                      Icons.help_center,
                      color: Colors.orangeAccent,
                      size: 28,
                    );
                  }
                }

                Color cardColor = const Color(0xFF1F1F1F);
                if (isAnalyzed && (_deviceLabels[ip] ?? '').contains("🔴")) {
                  cardColor = const Color(0xFF2E1A1A);
                } else if (isAnalyzed) {
                  cardColor = const Color(0xFF262626);
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isAnalyzed
                          ? _colorForThreatLevel(level).withOpacity(0.35)
                          : Colors.transparent,
                      width: isAnalyzed ? 1 : 0,
                    ),
                  ),
                  child: ListTile(
                    leading: leadingIcon,
                    title: Text(
                      titleText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isAnalyzed ? Colors.white : Colors.white70,
                      ),
                    ),
                    subtitle: Text(
                      subtitleText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                    trailing: isAnalyzed
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _colorForThreatLevel(
                                level,
                              ).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _colorForThreatLevel(
                                  level,
                                ).withOpacity(0.6),
                              ),
                            ),
                            child: Text(
                              '${ThreatUiHelper.levelEmoji(level)} $scoreValue',
                              style: TextStyle(
                                color: _colorForThreatLevel(level),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : null,
                    onTap: isAnalyzed ? () => _showDeviceDetails(ip) : null,
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