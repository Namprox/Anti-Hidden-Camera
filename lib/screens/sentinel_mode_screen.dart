import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:check_hidden_camera/utils/oui_helper.dart';

// Model dữ liệu nhật ký báo động
class ThreatLog {
  final String timestamp;
  final String ssid;
  final String bssid;
  final String vendor;
  final int level;

  ThreatLog({
    required this.timestamp,
    required this.ssid,
    required this.bssid,
    required this.vendor,
    required this.level,
  });

  // Chuyển Object thành Map để lưu vào JSON
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'ssid': ssid,
      'bssid': bssid,
      'vendor': vendor,
      'level': level,
    };
  }

  // Chuyển từ Map trong JSON ngược lại thành Object để hiển thị lên UI
  factory ThreatLog.fromMap(Map<String, dynamic> map) {
    return ThreatLog(
      timestamp: map['timestamp'] ?? '',
      ssid: map['ssid'] ?? '',
      bssid: map['bssid'] ?? '',
      vendor: map['vendor'] ?? '',
      level: map['level'] ?? -100,
    );
  }
}

class SentinelModeScreen extends StatefulWidget {
  const SentinelModeScreen({super.key});

  @override
  State<SentinelModeScreen> createState() => _SentinelModeScreenState();
}

class _SentinelModeScreenState extends State<SentinelModeScreen> {
  bool _isGuarding = false;
  Timer? _guardTimer;
  StreamSubscription? _subscription;

  // Dữ liệu nền: Lưu trữ những MAC Address đã có sẵn khi vừa vào phòng
  final Set<String> _baselineMacs = {};

  // Trạng thái báo động
  bool _isAlarmTriggered = false;
  String _threatDetails = "";

  // Bộ phát âm thanh còi hú và âm lượng
  late AudioPlayer _audioPlayer;
  double _originalVolume = 0.5;

  // Danh sách nhật ký hiển thị trên giao diện
  List<ThreatLog> _logsHistory = [];

  @override
  void initState() {
    super.initState();
    OuiHelper.initDatabase();
    _audioPlayer = AudioPlayer();
    _loadLogsHistory();
  }

  // Tải nhật ký từ bộ nhớ máy
  Future<void> _loadLogsHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedLogs = prefs.getStringList('sentinel_threat_logs');

    if (savedLogs != null) {
      setState(() {
        _logsHistory = savedLogs
            .map((item) => ThreatLog.fromMap(json.decode(item)))
            .toList();
        // Đảo ngược danh sách để nhật ký mới nhất hiện lên đầu
        _logsHistory = _logsHistory.reversed.toList();
      });
    }
  }

  // Ghi nhật ký mới vào bộ nhớ
  Future<void> _saveNewLog(WiFiAccessPoint ap, String vendor) async {
    final prefs = await SharedPreferences.getInstance();

    // Lấy thời gian hiện tại lúc phát hiện xâm nhập
    final now = DateTime.now();
    final String timeString =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} - ${now.day}/${now.month}/${now.year}";

    final newLog = ThreatLog(
      timestamp: timeString,
      ssid: ap.ssid.isEmpty ? "MẠNG WI-FI ẨN" : ap.ssid,
      bssid: ap.bssid,
      vendor: vendor,
      level: ap.level,
    );

    // Đọc danh sách cũ, thêm phần tử mới, lưu lại cứng
    final List<String> currentLogs =
        prefs.getStringList('sentinel_threat_logs') ?? [];
    currentLogs.add(json.encode(newLog.toMap()));
    await prefs.setStringList('sentinel_threat_logs', currentLogs);

    // Cập nhật lại danh sách hiển thị trên UI công khai
    await _loadLogsHistory();
  }

  // Xóa toàn bộ nhật ký
  Future<void> _clearLogsHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sentinel_threat_logs');
    setState(() {
      _logsHistory.clear();
    });
  }

  Future<void> _playSiren() async {
    _originalVolume = await PerfectVolumeControl.getVolume();
    await PerfectVolumeControl.setVolume(0.9); // Cưỡng chế đẩy volume lên 90%
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('audio/Rap_Cham_Thoi.mp3'));
  }

  Future<void> _stopSiren() async {
    await _audioPlayer.stop();
    await PerfectVolumeControl.setVolume(_originalVolume);
  }

  Future<void> _startGuarding() async {
    WakelockPlus.enable();

    setState(() {
      _isGuarding = true;
      _isAlarmTriggered = false;
      _baselineMacs.clear();
      _threatDetails = "";
    });

    final canScan = await WiFiScan.instance.canStartScan();
    if (canScan == CanStartScan.yes) {
      await WiFiScan.instance.startScan();
    }

    _subscription = WiFiScan.instance.onScannedResultsAvailable.listen((
      results,
    ) {
      if (!mounted) return;

      if (_baselineMacs.isEmpty) {
        setState(() {
          for (var ap in results) {
            _baselineMacs.add(ap.bssid);
          }
        });
      } else {
        _checkForIntruders(results);
      }
    });

    _guardTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
      }
    });
  }

  void _checkForIntruders(List<WiFiAccessPoint> currentResults) {
    for (var ap in currentResults) {
      if (ap.level < -75) continue;

      if (!_baselineMacs.contains(ap.bssid)) {
        String vendor = OuiHelper.lookup(ap.bssid);
        String lowerSsid = ap.ssid.toLowerCase();

        bool isDangerous =
            vendor.contains("Espressif") ||
            vendor.contains("Tuya") ||
            vendor.contains("Xiongmai") ||
            lowerSsid.contains("cam") ||
            ap.ssid.isEmpty;

        if (isDangerous) {
          // 1. Chụp ảnh hiện trường: Ghi dữ liệu vào file bảo mật tức thì trước khi hú còi
          _saveNewLog(ap, vendor);

          // 2. Thay đổi trạng thái UI
          setState(() {
            _isAlarmTriggered = true;
            _threatDetails =
                "PHÁT HIỆN THIẾT BỊ MỚI BẬT!\n\nSSID: ${ap.ssid.isEmpty ? "MẠNG ẨN" : ap.ssid}\nMAC: ${ap.bssid}\nNhà SX: $vendor\nTín hiệu: ${ap.level} dBm";
            _stopGuarding();
          });

          _playSiren();
          break;
        }
      }
    }
  }

  void _stopGuarding() {
    WakelockPlus.disable();
    _guardTimer?.cancel();
    _subscription?.cancel();
    setState(() => _isGuarding = false);
  }

  @override
  void dispose() {
    _stopGuarding();
    _stopSiren();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = _isAlarmTriggered
        ? Colors.redAccent.shade700
        : const Color(0xFF000000);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: _isAlarmTriggered ? _buildAlarmUI() : _buildGuardUI(),
        ),
      ),
    );
  }

  Widget _buildGuardUI() {
    return Stack(
      children: [
        // Nút xem lịch sử nhật ký (Góc trên bên phải, mờ chống chói mắt ban đêm)
        if (!_isGuarding)
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(
                Icons.history_edu,
                color: Colors.white30,
                size: 28,
              ),
              onPressed: _showLogsHistoryBottomSheet,
            ),
          ),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isGuarding ? Icons.shield : Icons.shield_outlined,
                size: 100,
                color: _isGuarding
                    ? Colors.tealAccent.withOpacity(0.3)
                    : Colors.white24,
              ),
              const SizedBox(height: 20),
              Text(
                _isGuarding ? "ĐANG CANH GÁC" : "CHẾ ĐỘ LÍNH GÁC ĐÊM",
                style: TextStyle(
                  color: _isGuarding
                      ? Colors.tealAccent.withOpacity(0.5)
                      : Colors.white54,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isGuarding) ...[
                const SizedBox(height: 10),
                const Text(
                  "Màn hình sẽ luôn sáng để radar hoạt động.\nHãy cắm sạc và úp điện thoại xuống.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white24),
                ),
              ],
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: _isGuarding ? _stopGuarding : _startGuarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isGuarding
                      ? Colors.redAccent.withOpacity(0.2)
                      : Colors.teal.shade800,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  _isGuarding ? "TẮT CANH GÁC" : "KÍCH HOẠT BẢO VỆ",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmUI() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 120,
            color: Colors.white,
          ),
          const SizedBox(height: 20),
          const Text(
            "BÁO ĐỘNG XÂM NHẬP!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              _threatDetails,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              _stopSiren();
              setState(() => _isAlarmTriggered = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: const Text(
              "TẮT BÁO ĐỘNG",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  // Bảng điều khiển xem chi tiết lịch sử nhật ký truy vết
  void _showLogsHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Nhật Ký Cảnh Báo",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_logsHistory.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(
                            Icons.delete_sweep,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          label: const Text(
                            "Xóa",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          onPressed: () async {
                            await _clearLogsHistory();
                            setBottomSheetState(() {});
                          },
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _logsHistory.isEmpty
                        ? const Center(
                            child: Text(
                              "Hệ thống sạch. Chưa phát hiện đột biến sóng nào ban đêm.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white30,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _logsHistory.length,
                            itemBuilder: (context, index) {
                              final log = _logsHistory[index];
                              return Card(
                                color: const Color(0xFF221414),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(
                                    color: Colors.red,
                                    width: 0.5,
                                  ),
                                ),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.gpp_bad,
                                    color: Colors.redAccent,
                                    size: 28,
                                  ),
                                  title: Text(
                                    log.ssid,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        "Thời gian: ${log.timestamp}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        "Địa chỉ MAC: ${log.bssid}",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        "Nhà SX: ${log.vendor}",
                                        style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        "Tín hiệu lúc bật: ${log.level} dBm",
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}