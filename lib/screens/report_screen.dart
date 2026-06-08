import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/report/scan_session_store.dart';
import '../core/threat/threat_analyzer.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ScanSessionStore _store = ScanSessionStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
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
    final color = _colorForEvidenceSeverity(evidence.severity);

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
                  softWrap: true,
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

  Widget _buildScoreBadge(ThreatScore score) {
    final c = _colorForThreatLevel(score.level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.7)),
      ),
      child: Text(
        '${ThreatUiHelper.levelEmoji(score.level)} ${score.score}/100 • ${score.levelLabel}',
        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12.5),
      ),
    );
  }

  void _showThreatDetailsDialog(
    String title,
    ThreatScore score, {
    String? subtitle,
  }) {
    final c = _colorForThreatLevel(score.level);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.withOpacity(0.85), width: 1.2),
        ),
        title: Row(
          children: [
            Icon(Icons.security, color: c),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: c, fontWeight: FontWeight.bold),
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
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, height: 1.35),
                    softWrap: true,
                  ),
                  const SizedBox(height: 10),
                ],
                _buildScoreBadge(score),
                const SizedBox(height: 10),
                Text(
                  score.summary,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                  softWrap: true,
                ),
                const SizedBox(height: 10),
                Text(
                  score.shortAdvice,
                  style: const TextStyle(
                    color: Colors.white60,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Evidence',
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
                        .take(10)
                        .map(_buildEvidenceItem)
                        .toList(),
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

  Future<void> _copyJsonReport() async {
    final report = _store.buildReport();
    final jsonText = report.toJsonPretty();

    await Clipboard.setData(ClipboardData(text: jsonText));

    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.teal,
        content: Text('Đã copy báo cáo JSON vào clipboard.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _resetSession() {
    _store.resetSession();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.orange,
        content: Text('Đã reset phiên quét.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeader(ScanSessionReport report) {
    final overall = report.overallScore;
    final c = _colorForThreatLevel(overall.level);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BÁO CÁO TỔNG HỢP (PHIÊN HIỆN TẠI)',
            style: TextStyle(
              color: c,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildScoreBadge(overall),
          const SizedBox(height: 10),
          Text(
            overall.summary,
            style: const TextStyle(color: Colors.white70, height: 1.35),
            softWrap: true,
          ),
          const SizedBox(height: 10),
          Text(
            overall.shortAdvice,
            style: const TextStyle(
              color: Colors.white60,
              height: 1.35,
              fontStyle: FontStyle.italic,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 12),
          Text(
            'SessionId: ${report.meta.sessionId}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          Text(
            'Started: ${report.meta.startedAt}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _smallChip('Wi‑Fi: ${report.wifi.length}'),
              _smallChip('LAN: ${report.lan.length}'),
              _smallChip('BLE: ${report.ble.length}'),
              _smallChip('Từ trường: ${report.magneticLatest == null ? 0 : 1}'),
              _smallChip('Quang học: không thu thập'),
              _smallChip('Lính gác: không thu thập'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _copyJsonReport,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text(
                    'COPY JSON',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resetSession,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text(
                    'RESET PHIÊN',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }

  // Widget tùy chỉnh cho card nghi vấn
  Widget _buildSuspectCard({
    required String title,
    required String subtitle,
    required ThreatScore score,
    required VoidCallback onTap,
  }) {
    final c = _colorForThreatLevel(score.level);
    final lines = subtitle
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    return Card(
      color: const Color(0xFF1F1F1F),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.withOpacity(0.35), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.report, color: c),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line.trim(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildScoreBadge(score),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSuspects(ScanSessionReport report) {
    final wifiTop = _store.topWifi(limit: 5);
    final lanTop = _store.topLan(limit: 5);
    final bleTop = _store.topBle(limit: 5);
    final magnetic = report.magneticLatest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Top mục tiêu nghi vấn'),
        if (wifiTop.isEmpty &&
            lanTop.isEmpty &&
            bleTop.isEmpty &&
            magnetic == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Chưa có dữ liệu trong phiên hiện tại. Hãy chạy Wi‑Fi Radar / LAN / BLE / Từ trường trước.',
              style: TextStyle(color: Colors.white54, height: 1.35),
            ),
          ),

        // Wi-Fi
        if (wifiTop.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Wi‑Fi Radar',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        for (final w in wifiTop)
          _buildSuspectCard(
            title: w.ssid,
            subtitle:
                'BSSID: ${w.bssid}\nVendor: ${w.vendor}\nRSSI: ${w.rssi} dBm • ${w.frequency} MHz',
            score: w.threatScore,
            onTap: () => _showThreatDetailsDialog(
              'Wi‑Fi: ${w.ssid}',
              w.threatScore,
              subtitle:
                  'BSSID: ${w.bssid}\nVendor: ${w.vendor}\nRSSI: ${w.rssi} dBm • ${w.frequency} MHz',
            ),
          ),

        // LAN
        if (lanTop.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Text(
              'LAN Scanner',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        for (final l in lanTop)
          _buildSuspectCard(
            title: 'IP: ${l.ip}',
            subtitle: l.openPorts.isEmpty
                ? 'Không phát hiện cổng mở'
                : 'Cổng mở: ${l.openPorts.join(", ")}',
            score: l.threatScore,
            onTap: () => _showThreatDetailsDialog(
              'LAN: ${l.ip}',
              l.threatScore,
              subtitle: l.openPorts.isEmpty
                  ? 'Không phát hiện cổng mở'
                  : 'Cổng mở: ${l.openPorts.join(", ")}',
            ),
          ),

        // BLE
        if (bleTop.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Text(
              'Bluetooth (BLE)',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        for (final b in bleTop)
          _buildSuspectCard(
            title: b.name,
            subtitle:
                'ID: ${b.deviceId}\nRSSI: ${b.rssi} dBm • ${b.isUnnamed ? "Không tên" : "Có tên"}',
            score: b.threatScore,
            onTap: () => _showThreatDetailsDialog(
              'BLE: ${b.name}',
              b.threatScore,
              subtitle:
                  'ID: ${b.deviceId}\nRSSI: ${b.rssi} dBm • ${b.isUnnamed ? "Không tên" : "Có tên"}',
            ),
          ),

        // Magnetometer
        if (magnetic != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: const [
                Text(
                  'Từ trường (Magnetometer)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (magnetic != null)
          _buildSuspectCard(
            title: 'Delta: +${magnetic.delta.toStringAsFixed(1)} µT',
            subtitle:
                'Baseline: ${magnetic.baseline.toStringAsFixed(1)} µT\nFluctuation: ${magnetic.fluctuation.toStringAsFixed(1)} µT',
            score: magnetic.threatScore,
            onTap: () => _showThreatDetailsDialog(
              'Từ trường',
              magnetic.threatScore,
              subtitle:
                  'Baseline: ${magnetic.baseline.toStringAsFixed(1)} µT\nDelta: +${magnetic.delta.toStringAsFixed(1)} µT\nFluctuation: ${magnetic.fluctuation.toStringAsFixed(1)} µT',
            ),
          ),
      ],
    );
  }

  Widget _buildEvidenceSection() {
    final evidences = _store.allPositiveEvidences();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Evidence tổng hợp (4 nguồn)'),
        if (evidences.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Chưa có evidence nào được ghi nhận trong phiên hiện tại.',
              style: TextStyle(color: Colors.white54, height: 1.35),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Column(
              children: evidences.take(30).map(_buildEvidenceItem).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _store.buildReport();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Báo cáo tổng hợp'),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildHeader(report),
          _buildTopSuspects(report),
          const SizedBox(height: 6),
          _buildEvidenceSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}