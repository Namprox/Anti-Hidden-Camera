import 'dart:async';
import 'dart:math';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../core/threat/threat_analyzer.dart';
import '../core/report/scan_session_store.dart';

class MagnetometerScreen extends StatefulWidget {
  const MagnetometerScreen({super.key});

  @override
  State<MagnetometerScreen> createState() => _MagnetometerScreenState();
}

class _MagnetometerScreenState extends State<MagnetometerScreen> {
  double _rawMagneticValue = 0.0;
  double _baselineValue = 0.0;
  double _deltaValue = 0.0;

  // Hàng đợi lưu lịch sử để tính độ biến thiên (Dao động)
  final Queue<double> _historyQueue = Queue<double>();
  double _fluctuation = 0.0;
  String _signalType = "Đang chờ dữ liệu";

  String _alertMessage = "Đang khởi tạo";
  Color _alertColor = Colors.grey;
  StreamSubscription<MagnetometerEvent>? _sub;

  // Threat Analyzer Integration
  ThreatScore? _threatScore;

  // Throttle để tránh cập nhật ScanSessionStore quá thường xuyên
  DateTime _lastStoreUpdate = DateTime.now();
  static const Duration _storeUpdateInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _listenToMagnetometer();
  }

  void _listenToMagnetometer() {
    _sub = magnetometerEventStream().listen((event) {
      if (!mounted) return;

      final double value = sqrt(
        (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
      );

      // Quản lý cửa sổ lịch sử (Lưu 15 mẫu gần nhất, tương đương khoảng 0.5 giây)
      _historyQueue.addLast(value);
      if (_historyQueue.length > 15) {
        _historyQueue.removeFirst();
      }

      // Tính toán độ biến thiên (Max - Min trong khung thời gian)
      if (_historyQueue.length == 15) {
        final double maxVal = _historyQueue.reduce(max);
        final double minVal = _historyQueue.reduce(min);
        _fluctuation = maxVal - minVal;
      }

      setState(() {
        _rawMagneticValue = value;

        if (_baselineValue == 0.0) {
          _baselineValue = value;
        }

        _deltaValue = (value - _baselineValue).abs();

        // Thuật toán phân loại & cảnh báo
        if (_deltaValue > 40) {
          _alertColor = Colors.redAccent;
          // Phân loại dựa trên độ dao động
          if (_fluctuation > 15) {
            // Dao động mạnh
            _alertMessage = "Báo động: Từ trường cao (Nhiễu điện AC/Dây điện)";
            _signalType =
                "ĐẶC TÍNH: Dòng điện xoay chiều / Môi trường rung lắc";
          } else {
            // Cực kỳ tĩnh
            _alertMessage = "NGUY HIỂM: Từ trường TĨNH tập trung!";
            _signalType =
                "ĐẶC TÍNH: Nam châm tĩnh / Linh kiện điện tử DC (Rất nghi ngờ Camera)";
          }
        } else if (_deltaValue > 20) {
          _alertMessage = "Cảnh báo: Có biến động từ tính nhẹ";
          _alertColor = Colors.orangeAccent;
          _signalType = "ĐẶC TÍNH: Mức độ thấp, cần quét sát hơn";
        } else {
          _alertMessage = "An toàn: Mức nền ổn định";
          _alertColor = Colors.greenAccent;
          _signalType = "ĐẶC TÍNH: Không phát hiện vật thể từ tính";
        }

        // Tích hợp Threat Analyzer
        _threatScore = ThreatAnalyzer.analyzeDevice(
          ThreatDeviceInput(
            magneticDelta: _deltaValue,
            magneticFluctuation: _fluctuation,
          ),
        );

        // Cập nhật vào ScanSessionStore (có throttle)
        final now = DateTime.now();
        if (now.difference(_lastStoreUpdate) >= _storeUpdateInterval) {
          _lastStoreUpdate = now;
          ScanSessionStore.instance.upsertMagnetometer(
            baseline: _baselineValue,
            delta: _deltaValue,
            fluctuation: _fluctuation,
            threatScore: _threatScore!,
          );
        }
      });
    });
  }

  void _setBaseline() {
    setState(() {
      _baselineValue = _rawMagneticValue;
      _deltaValue = 0.0;
      _historyQueue.clear();

      // Cập nhật ThreatScore sau khi reset baseline
      _threatScore = ThreatAnalyzer.analyzeDevice(
        ThreatDeviceInput(
          magneticDelta: _deltaValue,
          magneticFluctuation: _fluctuation,
        ),
      );
    });

    // Cập nhật store ngay sau khi baseline thay đổi
    ScanSessionStore.instance.upsertMagnetometer(
      baseline: _baselineValue,
      delta: _deltaValue,
      fluctuation: _fluctuation,
      threatScore: _threatScore!,
    );
    _lastStoreUpdate = DateTime.now();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã cân bằng mốc môi trường thành công!'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // UI HELPERS
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

  Widget _buildThreatBadge() {
    final ThreatScore score =
        _threatScore ??
        ThreatAnalyzer.analyzeDevice(
          ThreatDeviceInput(
            magneticDelta: _deltaValue,
            magneticFluctuation: _fluctuation,
          ),
        );

    final Color color = _colorForThreatLevel(score.level);

    return GestureDetector(
      onTap: () => _showThreatDetails(score),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF121212).withOpacity(0.75),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.85), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ThreatUiHelper.levelEmoji(score.level),
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(width: 6),
            Text(
              '${score.score}/100',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.info_outline, color: Colors.white54, size: 17),
          ],
        ),
      ),
    );
  }

  void _showThreatDetails(ThreatScore score) {
    final Color levelColor = _colorForThreatLevel(score.level);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: levelColor.withOpacity(0.85), width: 1.2),
          ),
          title: Row(
            children: [
              Icon(Icons.radar, color: levelColor),
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
                  const SizedBox(height: 12),
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
                      'Chưa có bằng chứng nghi vấn mạnh từ từ trường.',
                      style: TextStyle(color: Colors.white54),
                    )
                  else
                    Column(
                      children: score.evidences
                          .where((e) => e.score > 0)
                          .map((e) => _buildEvidenceItem(e))
                          .toList(),
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    'Thông số hiện tại',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Baseline: ${_baselineValue.toStringAsFixed(1)} µT\n'
                    'Delta: ${_deltaValue.toStringAsFixed(1)} µT\n'
                    'Fluctuation: ${_fluctuation.toStringAsFixed(1)} µT',
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThreatScore score =
        _threatScore ??
        ThreatAnalyzer.analyzeDevice(
          ThreatDeviceInput(
            magneticDelta: _deltaValue,
            magneticFluctuation: _fluctuation,
          ),
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Quét Từ Trường Vật Lý'),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(child: _buildThreatBadge()),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '+${_deltaValue.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: _alertColor,
              ),
            ),
            const Text(
              'ĐỘ LỆCH (µT)',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 18),

            // Dòng hiển thị Score ngắn ngay trong body
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _colorForThreatLevel(score.level).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _colorForThreatLevel(score.level).withOpacity(0.55),
                ),
              ),
              child: Text(
                '${ThreatUiHelper.levelEmoji(score.level)} ${score.levelLabel} • ${score.score}/100',
                style: TextStyle(
                  color: _colorForThreatLevel(score.level),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 22),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _alertColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _alertColor, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    _alertMessage,
                    style: TextStyle(
                      fontSize: 18,
                      color: _alertColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _signalType,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    'Mức nền phòng: ${_baselineValue.toStringAsFixed(1)} µT',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Độ nhiễu dao động (Fluctuation): ${_fluctuation.toStringAsFixed(1)} µT',
                    style: TextStyle(
                      color: _fluctuation > 15
                          ? Colors.orangeAccent
                          : Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton.icon(
              onPressed: _setBaseline,
              icon: const Icon(Icons.sync, color: Colors.black),
              label: const Text(
                'CÂN BẰNG MÔI TRƯỜNG',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
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
}