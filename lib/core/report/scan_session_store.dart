import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../threat/threat_analyzer.dart';

enum ReportSource { wifi, lan, bluetooth, magnetometer }

class SessionMeta {
  final String sessionId;
  final DateTime startedAt;

  SessionMeta({required this.sessionId, required this.startedAt});

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'startedAt': startedAt.toIso8601String(),
  };

  factory SessionMeta.fromMap(Map<String, dynamic> map) {
    return SessionMeta(
      sessionId: map['sessionId'] ?? '',
      startedAt: DateTime.tryParse(map['startedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class WifiObservation {
  final String bssid;
  final String ssid;
  final String vendor;
  final int rssi;
  final int frequency;
  final bool isHiddenSsid;

  final ThreatScore threatScore;
  final DateTime lastSeen;

  const WifiObservation({
    required this.bssid,
    required this.ssid,
    required this.vendor,
    required this.rssi,
    required this.frequency,
    required this.isHiddenSsid,
    required this.threatScore,
    required this.lastSeen,
  });

  WifiObservation copyWith({
    String? bssid,
    String? ssid,
    String? vendor,
    int? rssi,
    int? frequency,
    bool? isHiddenSsid,
    ThreatScore? threatScore,
    DateTime? lastSeen,
  }) {
    return WifiObservation(
      bssid: bssid ?? this.bssid,
      ssid: ssid ?? this.ssid,
      vendor: vendor ?? this.vendor,
      rssi: rssi ?? this.rssi,
      frequency: frequency ?? this.frequency,
      isHiddenSsid: isHiddenSsid ?? this.isHiddenSsid,
      threatScore: threatScore ?? this.threatScore,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  ThreatDeviceInput toThreatInput() {
    return ThreatDeviceInput(
      deviceId: bssid,
      macAddress: bssid,
      ssid: ssid,
      vendor: vendor,
      rssi: rssi,
      frequency: frequency,
      isHiddenSsid: isHiddenSsid,
      isNewAfterBaseline: false,
    );
  }

  Map<String, dynamic> toMap() => {
    'bssid': bssid,
    'ssid': ssid,
    'vendor': vendor,
    'rssi': rssi,
    'frequency': frequency,
    'isHiddenSsid': isHiddenSsid,
    'threatScore': threatScore.toMap(),
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory WifiObservation.fromMap(Map<String, dynamic> map) {
    return WifiObservation(
      bssid: map['bssid'] ?? '',
      ssid: map['ssid'] ?? '',
      vendor: map['vendor'] ?? '',
      rssi: map['rssi'] ?? -100,
      frequency: map['frequency'] ?? 0,
      isHiddenSsid: map['isHiddenSsid'] ?? false,
      threatScore: ThreatScore.fromMap(
        Map<String, dynamic>.from(map['threatScore'] ?? {}),
      ),
      lastSeen: DateTime.tryParse(map['lastSeen'] ?? '') ?? DateTime.now(),
    );
  }
}

class LanObservation {
  final String ip;
  final List<int> openPorts;
  final ThreatScore threatScore;
  final DateTime lastSeen;

  const LanObservation({
    required this.ip,
    required this.openPorts,
    required this.threatScore,
    required this.lastSeen,
  });

  LanObservation copyWith({
    String? ip,
    List<int>? openPorts,
    ThreatScore? threatScore,
    DateTime? lastSeen,
  }) {
    return LanObservation(
      ip: ip ?? this.ip,
      openPorts: openPorts ?? this.openPorts,
      threatScore: threatScore ?? this.threatScore,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  ThreatDeviceInput toThreatInput() {
    return ThreatDeviceInput(deviceId: ip, ipAddress: ip, openPorts: openPorts);
  }

  Map<String, dynamic> toMap() => {
    'ip': ip,
    'openPorts': openPorts,
    'threatScore': threatScore.toMap(),
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory LanObservation.fromMap(Map<String, dynamic> map) {
    return LanObservation(
      ip: map['ip'] ?? '',
      openPorts: ((map['openPorts'] ?? []) as List)
          .map((e) => e as int)
          .toList(),
      threatScore: ThreatScore.fromMap(
        Map<String, dynamic>.from(map['threatScore'] ?? {}),
      ),
      lastSeen: DateTime.tryParse(map['lastSeen'] ?? '') ?? DateTime.now(),
    );
  }
}

class BleObservation {
  final String deviceId;
  final String name;
  final int rssi;
  final bool isUnnamed;
  final ThreatScore threatScore;
  final DateTime lastSeen;

  const BleObservation({
    required this.deviceId,
    required this.name,
    required this.rssi,
    required this.isUnnamed,
    required this.threatScore,
    required this.lastSeen,
  });

  BleObservation copyWith({
    String? deviceId,
    String? name,
    int? rssi,
    bool? isUnnamed,
    ThreatScore? threatScore,
    DateTime? lastSeen,
  }) {
    return BleObservation(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isUnnamed: isUnnamed ?? this.isUnnamed,
      threatScore: threatScore ?? this.threatScore,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  ThreatDeviceInput toThreatInput() {
    return ThreatDeviceInput(
      deviceId: deviceId,
      macAddress: deviceId,
      rssi: rssi,
      isUnnamedBluetoothDevice: isUnnamed,
    );
  }

  Map<String, dynamic> toMap() => {
    'deviceId': deviceId,
    'name': name,
    'rssi': rssi,
    'isUnnamed': isUnnamed,
    'threatScore': threatScore.toMap(),
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory BleObservation.fromMap(Map<String, dynamic> map) {
    return BleObservation(
      deviceId: map['deviceId'] ?? '',
      name: map['name'] ?? '',
      rssi: map['rssi'] ?? -100,
      isUnnamed: map['isUnnamed'] ?? false,
      threatScore: ThreatScore.fromMap(
        Map<String, dynamic>.from(map['threatScore'] ?? {}),
      ),
      lastSeen: DateTime.tryParse(map['lastSeen'] ?? '') ?? DateTime.now(),
    );
  }
}

class MagneticObservation {
  final double baseline;
  final double delta;
  final double fluctuation;
  final ThreatScore threatScore;
  final DateTime lastSeen;

  const MagneticObservation({
    required this.baseline,
    required this.delta,
    required this.fluctuation,
    required this.threatScore,
    required this.lastSeen,
  });

  MagneticObservation copyWith({
    double? baseline,
    double? delta,
    double? fluctuation,
    ThreatScore? threatScore,
    DateTime? lastSeen,
  }) {
    return MagneticObservation(
      baseline: baseline ?? this.baseline,
      delta: delta ?? this.delta,
      fluctuation: fluctuation ?? this.fluctuation,
      threatScore: threatScore ?? this.threatScore,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  ThreatDeviceInput toThreatInput() {
    return ThreatDeviceInput(
      magneticDelta: delta,
      magneticFluctuation: fluctuation,
    );
  }

  Map<String, dynamic> toMap() => {
    'baseline': baseline,
    'delta': delta,
    'fluctuation': fluctuation,
    'threatScore': threatScore.toMap(),
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory MagneticObservation.fromMap(Map<String, dynamic> map) {
    return MagneticObservation(
      baseline: (map['baseline'] ?? 0.0).toDouble(),
      delta: (map['delta'] ?? 0.0).toDouble(),
      fluctuation: (map['fluctuation'] ?? 0.0).toDouble(),
      threatScore: ThreatScore.fromMap(
        Map<String, dynamic>.from(map['threatScore'] ?? {}),
      ),
      lastSeen: DateTime.tryParse(map['lastSeen'] ?? '') ?? DateTime.now(),
    );
  }
}

class ScanSessionReport {
  final SessionMeta meta;

  final List<WifiObservation> wifi;
  final List<LanObservation> lan;
  final List<BleObservation> ble;
  final MagneticObservation? magneticLatest;

  final ThreatScore overallScore;

  ScanSessionReport({
    required this.meta,
    required this.wifi,
    required this.lan,
    required this.ble,
    required this.magneticLatest,
    required this.overallScore,
  });

  Map<String, dynamic> toMap() => {
    'meta': meta.toMap(),
    'overallScore': overallScore.toMap(),
    'wifi': wifi.map((e) => e.toMap()).toList(),
    'lan': lan.map((e) => e.toMap()).toList(),
    'ble': ble.map((e) => e.toMap()).toList(),
    'magnetometer': magneticLatest?.toMap(),
  };

  String toJsonPretty() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toMap());
  }
}

class ScanSessionStore extends ChangeNotifier {
  ScanSessionStore._internal() {
    startNewSession();
  }

  static final ScanSessionStore instance = ScanSessionStore._internal();

  late SessionMeta _meta;

  final Map<String, WifiObservation> _wifiByBssid = {};
  final Map<String, LanObservation> _lanByIp = {};
  final Map<String, BleObservation> _bleById = {};

  MagneticObservation? _magneticLatest;

  SessionMeta get meta => _meta;

  List<WifiObservation> get wifiAll => _wifiByBssid.values.toList();

  List<LanObservation> get lanAll => _lanByIp.values.toList();

  List<BleObservation> get bleAll => _bleById.values.toList();

  MagneticObservation? get magneticLatest => _magneticLatest;

  void startNewSession() {
    final now = DateTime.now();
    _meta = SessionMeta(
      sessionId: now.millisecondsSinceEpoch.toString(),
      startedAt: now,
    );
    _wifiByBssid.clear();
    _lanByIp.clear();
    _bleById.clear();
    _magneticLatest = null;
    notifyListeners();
  }

  void resetSession() {
    startNewSession();
  }

  // Upsert Methods
  void upsertWifi({
    required String bssid,
    required String ssid,
    required String vendor,
    required int rssi,
    required int frequency,
    required bool isHiddenSsid,
    required ThreatScore threatScore,
  }) {
    final now = DateTime.now();

    final normalizedSsid = ssid.isEmpty ? 'MẠNG ẨN' : ssid;

    final existing = _wifiByBssid[bssid];

    if (existing == null) {
      _wifiByBssid[bssid] = WifiObservation(
        bssid: bssid,
        ssid: normalizedSsid,
        vendor: vendor,
        rssi: rssi,
        frequency: frequency,
        isHiddenSsid: isHiddenSsid,
        threatScore: threatScore,
        lastSeen: now,
      );
    } else {
      // Giữ RSSI "mạnh nhất" (gần nhất) hoặc cập nhật RSSI mới
      // Ở đây: Cập nhật theo RSSI mới để Real-time, nhưng giữ vendor/RSSI
      _wifiByBssid[bssid] = existing.copyWith(
        ssid: normalizedSsid,
        vendor: vendor,
        rssi: rssi,
        frequency: frequency,
        isHiddenSsid: isHiddenSsid,
        threatScore: threatScore,
        lastSeen: now,
      );
    }

    notifyListeners();
  }

  void upsertLan({
    required String ip,
    required List<int> openPorts,
    required ThreatScore threatScore,
  }) {
    final now = DateTime.now();
    final portsSorted = openPorts.toSet().toList()..sort();

    final existing = _lanByIp[ip];
    if (existing == null) {
      _lanByIp[ip] = LanObservation(
        ip: ip,
        openPorts: portsSorted,
        threatScore: threatScore,
        lastSeen: now,
      );
    } else {
      _lanByIp[ip] = existing.copyWith(
        openPorts: portsSorted,
        threatScore: threatScore,
        lastSeen: now,
      );
    }

    notifyListeners();
  }

  void upsertBle({
    required String deviceId,
    required String name,
    required int rssi,
    required bool isUnnamed,
    required ThreatScore threatScore,
  }) {
    final now = DateTime.now();
    final normalizedName = name.trim().isEmpty
        ? 'Thiết bị không tên'
        : name.trim();

    final existing = _bleById[deviceId];
    if (existing == null) {
      _bleById[deviceId] = BleObservation(
        deviceId: deviceId,
        name: normalizedName,
        rssi: rssi,
        isUnnamed: isUnnamed,
        threatScore: threatScore,
        lastSeen: now,
      );
    } else {
      _bleById[deviceId] = existing.copyWith(
        name: normalizedName,
        rssi: rssi,
        isUnnamed: isUnnamed,
        threatScore: threatScore,
        lastSeen: now,
      );
    }

    notifyListeners();
  }

  void upsertMagnetometer({
    required double baseline,
    required double delta,
    required double fluctuation,
    required ThreatScore threatScore,
  }) {
    final now = DateTime.now();

    _magneticLatest = MagneticObservation(
      baseline: baseline,
      delta: delta,
      fluctuation: fluctuation,
      threatScore: threatScore,
      lastSeen: now,
    );

    notifyListeners();
  }

  // Report Build
  ThreatScore _calculateOverallScore() {
    final inputs = <ThreatDeviceInput>[];

    for (final w in _wifiByBssid.values) {
      inputs.add(w.toThreatInput());
    }

    for (final l in _lanByIp.values) {
      inputs.add(l.toThreatInput());
    }

    for (final b in _bleById.values) {
      inputs.add(b.toThreatInput());
    }

    if (_magneticLatest != null) {
      inputs.add(_magneticLatest!.toThreatInput());
    }

    if (inputs.isEmpty) {
      // Ko có dữ liệu -> safe Score mặc định
      return ThreatAnalyzer.analyzeDevice(const ThreatDeviceInput());
    }

    return ThreatAnalyzer.analyzeRoom(inputs);
  }

  List<WifiObservation> topWifi({int limit = 8}) {
    final list = wifiAll;
    list.sort((a, b) => b.threatScore.score.compareTo(a.threatScore.score));
    return list.take(limit).toList();
  }

  List<LanObservation> topLan({int limit = 8}) {
    final list = lanAll;
    list.sort((a, b) => b.threatScore.score.compareTo(a.threatScore.score));
    return list.take(limit).toList();
  }

  List<BleObservation> topBle({int limit = 8}) {
    final list = bleAll;
    list.sort((a, b) => b.threatScore.score.compareTo(a.threatScore.score));
    return list.take(limit).toList();
  }

  ScanSessionReport buildReport() {
    final overall = _calculateOverallScore();

    final wifi = wifiAll
      ..sort((a, b) => b.threatScore.score.compareTo(a.threatScore.score));
    final lan = lanAll
      ..sort((a, b) => b.threatScore.score.compareTo(a.threatScore.score));
    final ble = bleAll
      ..sort((a, b) => b.threatScore.score.compareTo(a.threatScore.score));

    return ScanSessionReport(
      meta: _meta,
      wifi: wifi,
      lan: lan,
      ble: ble,
      magneticLatest: _magneticLatest,
      overallScore: overall,
    );
  }

  // Tổng hợp evidence toàn phiên (lọc Score > 0), dùng để render nhanh trong report
  List<ThreatEvidence> allPositiveEvidences() {
    final evidences = <ThreatEvidence>[];

    for (final w in _wifiByBssid.values) {
      evidences.addAll(w.threatScore.evidences.where((e) => e.score > 0));
    }
    for (final l in _lanByIp.values) {
      evidences.addAll(l.threatScore.evidences.where((e) => e.score > 0));
    }
    for (final b in _bleById.values) {
      evidences.addAll(b.threatScore.evidences.where((e) => e.score > 0));
    }
    if (_magneticLatest != null) {
      evidences.addAll(
        _magneticLatest!.threatScore.evidences.where((e) => e.score > 0),
      );
    }

    evidences.sort((a, b) => b.score.compareTo(a.score));
    return evidences;
  }
}