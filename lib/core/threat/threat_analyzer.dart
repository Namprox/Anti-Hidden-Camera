import 'dart:convert';

enum ThreatSource {
  wifi,
  lan,
  bluetooth,
  magnetometer,
  optical,
  sentinel,
  manual,
  unknown,
}

enum ThreatLevel { safe, low, medium, high, critical }

enum VendorCategory {
  camera,
  recorder,
  iot,
  router,
  phone,
  computer,
  printer,
  smartTv,
  audio,
  unknown,
}

enum EvidenceSeverity { info, low, medium, high, critical }

class ThreatEvidence {
  final ThreatSource source;
  final EvidenceSeverity severity;
  final String title;
  final String description;
  final int score;
  final DateTime createdAt;

  final String? deviceId;
  final String? ipAddress;
  final String? macAddress;
  final String? ssid;
  final String? vendor;
  final int? rssi;
  final int? port;
  final String? rawValue;

  const ThreatEvidence({
    required this.source,
    required this.severity,
    required this.title,
    required this.description,
    required this.score,
    required this.createdAt,
    this.deviceId,
    this.ipAddress,
    this.macAddress,
    this.ssid,
    this.vendor,
    this.rssi,
    this.port,
    this.rawValue,
  });

  ThreatEvidence copyWith({
    ThreatSource? source,
    EvidenceSeverity? severity,
    String? title,
    String? description,
    int? score,
    DateTime? createdAt,
    String? deviceId,
    String? ipAddress,
    String? macAddress,
    String? ssid,
    String? vendor,
    int? rssi,
    int? port,
    String? rawValue,
  }) {
    return ThreatEvidence(
      source: source ?? this.source,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      score: score ?? this.score,
      createdAt: createdAt ?? this.createdAt,
      deviceId: deviceId ?? this.deviceId,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      ssid: ssid ?? this.ssid,
      vendor: vendor ?? this.vendor,
      rssi: rssi ?? this.rssi,
      port: port ?? this.port,
      rawValue: rawValue ?? this.rawValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'source': source.name,
      'severity': severity.name,
      'title': title,
      'description': description,
      'score': score,
      'createdAt': createdAt.toIso8601String(),
      'deviceId': deviceId,
      'ipAddress': ipAddress,
      'macAddress': macAddress,
      'ssid': ssid,
      'vendor': vendor,
      'rssi': rssi,
      'port': port,
      'rawValue': rawValue,
    };
  }

  factory ThreatEvidence.fromMap(Map<String, dynamic> map) {
    return ThreatEvidence(
      source: ThreatParser.parseSource(map['source']),
      severity: ThreatParser.parseSeverity(map['severity']),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      score: map['score'] ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      deviceId: map['deviceId'],
      ipAddress: map['ipAddress'],
      macAddress: map['macAddress'],
      ssid: map['ssid'],
      vendor: map['vendor'],
      rssi: map['rssi'],
      port: map['port'],
      rawValue: map['rawValue'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ThreatEvidence.fromJson(String source) {
    return ThreatEvidence.fromMap(json.decode(source));
  }
}

class ThreatScore {
  final int score;
  final ThreatLevel level;
  final String title;
  final String summary;
  final List<ThreatEvidence> evidences;
  final DateTime createdAt;

  const ThreatScore({
    required this.score,
    required this.level,
    required this.title,
    required this.summary,
    required this.evidences,
    required this.createdAt,
  });

  bool get isSafe => level == ThreatLevel.safe;

  bool get isLow => level == ThreatLevel.low;

  bool get isMedium => level == ThreatLevel.medium;

  bool get isHigh => level == ThreatLevel.high;

  bool get isCritical => level == ThreatLevel.critical;

  String get levelLabel {
    switch (level) {
      case ThreatLevel.safe:
        return 'AN TOÀN TƯƠNG ĐỐI';
      case ThreatLevel.low:
        return 'RỦI RO THẤP';
      case ThreatLevel.medium:
        return 'CẦN KIỂM TRA';
      case ThreatLevel.high:
        return 'NGHI VẤN CAO';
      case ThreatLevel.critical:
        return 'CỰC KỲ NGHI VẤN';
    }
  }

  String get shortAdvice {
    switch (level) {
      case ThreatLevel.safe:
        return 'Chưa thấy dấu hiệu đáng ngại. Vẫn nên kiểm tra thủ công các vị trí nhạy cảm.';
      case ThreatLevel.low:
        return 'Có một vài tín hiệu nhẹ. Nên kiểm tra thêm bằng quang học và từ trường.';
      case ThreatLevel.medium:
        return 'Có dấu hiệu cần chú ý. Hãy kiểm tra vật lý khu vực có tín hiệu mạnh hoặc thiết bị lạ.';
      case ThreatLevel.high:
        return 'Có nhiều bằng chứng nghi vấn. Nên rà kỹ ổ điện, đầu báo khói, router, khe tường, vật trang trí.';
      case ThreatLevel.critical:
        return 'Có nhiều tín hiệu nghi vấn mạnh. Nên dừng sử dụng khu vực nhạy cảm và kiểm tra kỹ bằng nhiều phương pháp.';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'level': level.name,
      'title': title,
      'summary': summary,
      'createdAt': createdAt.toIso8601String(),
      'evidences': evidences.map((e) => e.toMap()).toList(),
    };
  }

  factory ThreatScore.fromMap(Map<String, dynamic> map) {
    return ThreatScore(
      score: map['score'] ?? 0,
      level: ThreatParser.parseLevel(map['level']),
      title: map['title'] ?? '',
      summary: map['summary'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      evidences: ((map['evidences'] ?? []) as List)
          .map(
            (item) => ThreatEvidence.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ThreatScore.fromJson(String source) {
    return ThreatScore.fromMap(json.decode(source));
  }
}

class ThreatDeviceInput {
  final String? deviceId;
  final String? ipAddress;
  final String? macAddress;
  final String? ssid;
  final String? vendor;
  final int? rssi;
  final int? frequency;
  final List<int> openPorts;

  final bool isNewAfterBaseline;
  final bool isHiddenSsid;
  final bool isUnnamedBluetoothDevice;
  final bool isTrustedDevice;

  final double? magneticDelta;
  final double? magneticFluctuation;

  final bool opticalUserMarkedSuspicious;
  final String? opticalNote;

  const ThreatDeviceInput({
    this.deviceId,
    this.ipAddress,
    this.macAddress,
    this.ssid,
    this.vendor,
    this.rssi,
    this.frequency,
    this.openPorts = const [],
    this.isNewAfterBaseline = false,
    this.isHiddenSsid = false,
    this.isUnnamedBluetoothDevice = false,
    this.isTrustedDevice = false,
    this.magneticDelta,
    this.magneticFluctuation,
    this.opticalUserMarkedSuspicious = false,
    this.opticalNote,
  });

  String get bestDeviceId {
    if (deviceId != null && deviceId!.trim().isNotEmpty) {
      return deviceId!.trim();
    }

    if (macAddress != null && macAddress!.trim().isNotEmpty) {
      return macAddress!.trim();
    }

    if (ipAddress != null && ipAddress!.trim().isNotEmpty) {
      return ipAddress!.trim();
    }

    if (ssid != null && ssid!.trim().isNotEmpty) {
      return ssid!.trim();
    }

    return 'unknown-device';
  }
}

class ThreatAnalyzer {
  static const int maxScore = 100;

  /// Phân tích một thiết bị hoặc một tín hiệu đơn lẻ
  static ThreatScore analyzeDevice(ThreatDeviceInput input) {
    final List<ThreatEvidence> evidences = [];

    if (input.isTrustedDevice) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.manual,
          severity: EvidenceSeverity.info,
          title: 'Thiết bị đã được đánh dấu an toàn',
          description:
              'Thiết bị này nằm trong danh sách tin cậy nên điểm nghi vấn sẽ được giảm mạnh.',
          score: -50,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          ipAddress: input.ipAddress,
          macAddress: input.macAddress,
          ssid: input.ssid,
          vendor: input.vendor,
        ),
      );
    }

    evidences.addAll(_analyzeVendor(input));
    evidences.addAll(_analyzeSsid(input));
    evidences.addAll(_analyzeRssi(input));
    evidences.addAll(_analyzePorts(input));
    evidences.addAll(_analyzeSentinel(input));
    evidences.addAll(_analyzeBluetooth(input));
    evidences.addAll(_analyzeMagnetometer(input));
    evidences.addAll(_analyzeOptical(input));

    return _buildScore(evidences);
  }

  /// Phân tích nhiều thiết bị và tạo điểm tổng thể cho cả phòng/khu vực
  static ThreatScore analyzeRoom(List<ThreatDeviceInput> devices) {
    final List<ThreatEvidence> allEvidences = [];

    for (final device in devices) {
      final ThreatScore deviceScore = analyzeDevice(device);
      allEvidences.addAll(deviceScore.evidences);
    }

    return _buildScore(allEvidences, isRoomReport: true);
  }

  static List<ThreatEvidence> _analyzeVendor(ThreatDeviceInput input) {
    final List<ThreatEvidence> evidences = [];
    final String vendor = input.vendor?.trim() ?? '';

    if (vendor.isEmpty) {
      return evidences;
    }

    final VendorCategory category = classifyVendor(vendor);

    switch (category) {
      case VendorCategory.camera:
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.wifi,
            severity: EvidenceSeverity.high,
            title: 'Nhà sản xuất thuộc nhóm camera/IP camera',
            description:
                'Vendor "$vendor" có liên quan đến nhóm thiết bị camera hoặc giám sát.',
            score: 30,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: vendor,
          ),
        );
        break;

      case VendorCategory.recorder:
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.lan,
            severity: EvidenceSeverity.high,
            title: 'Nhà sản xuất thuộc nhóm đầu ghi/NVR/DVR',
            description:
                'Vendor "$vendor" có liên quan đến đầu ghi hình hoặc hệ thống giám sát.',
            score: 30,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: vendor,
          ),
        );
        break;

      case VendorCategory.iot:
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.wifi,
            severity: EvidenceSeverity.medium,
            title: 'Nhà sản xuất thuộc nhóm IoT',
            description:
                'Vendor "$vendor" thuộc nhóm IoT. Không nhất thiết là camera, nhưng cần kiểm tra nếu xuất hiện bất thường.',
            score: 18,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: vendor,
          ),
        );
        break;

      case VendorCategory.router:
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.wifi,
            severity: EvidenceSeverity.info,
            title: 'Nhà sản xuất có thể là router/thiết bị mạng',
            description:
                'Vendor "$vendor" thường gặp ở thiết bị mạng. Điểm nghi vấn thấp nếu không có dấu hiệu khác.',
            score: 3,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: vendor,
          ),
        );
        break;

      case VendorCategory.phone:
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.wifi,
            severity: EvidenceSeverity.info,
            title: 'Nhà sản xuất có thể là điện thoại/thiết bị cá nhân',
            description:
                'Vendor "$vendor" thường gặp ở thiết bị cá nhân. Điểm nghi vấn rất thấp nếu không có dấu hiệu khác.',
            score: 2,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: vendor,
          ),
        );
        break;

      case VendorCategory.computer:
      case VendorCategory.printer:
      case VendorCategory.smartTv:
      case VendorCategory.audio:
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.wifi,
            severity: EvidenceSeverity.info,
            title: 'Vendor thuộc nhóm thiết bị dân dụng',
            description:
                'Vendor "$vendor" thường gặp ở thiết bị dân dụng. Vẫn cần kiểm tra nếu có port hoặc tín hiệu đáng ngờ.',
            score: 2,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: vendor,
          ),
        );
        break;

      case VendorCategory.unknown:
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.wifi,
            severity: EvidenceSeverity.low,
            title: 'Nhà sản xuất không rõ hoặc chưa phân loại',
            description:
                'Vendor "$vendor" chưa được phân loại rõ. Nên kết hợp thêm LAN, Wi-Fi RSSI và kiểm tra vật lý.',
            score: 8,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: vendor,
          ),
        );
        break;
    }

    return evidences;
  }

  static List<ThreatEvidence> _analyzeSsid(ThreatDeviceInput input) {
    final List<ThreatEvidence> evidences = [];
    final String ssid = input.ssid?.trim() ?? '';
    final String lowerSsid = ssid.toLowerCase();

    if (input.isHiddenSsid || ssid.isEmpty) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.wifi,
          severity: EvidenceSeverity.medium,
          title: 'Mạng Wi-Fi ẩn tên',
          description:
              'Thiết bị phát Wi-Fi không công khai SSID. Đây có thể là cấu hình hợp lệ, nhưng cũng thường được dùng để giảm khả năng bị phát hiện.',
          score: 18,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          ipAddress: input.ipAddress,
          macAddress: input.macAddress,
          ssid: ssid.isEmpty ? 'Hidden SSID' : ssid,
          vendor: input.vendor,
        ),
      );
    }

    if (lowerSsid.contains('cam') ||
        lowerSsid.contains('camera') ||
        lowerSsid.contains('ipc') ||
        lowerSsid.contains('ipcam') ||
        lowerSsid.contains('v380') ||
        lowerSsid.contains('yoosee') ||
        lowerSsid.contains('dvr') ||
        lowerSsid.contains('nvr') ||
        lowerSsid.contains('xmeye') ||
        lowerSsid.contains('360eye')) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.wifi,
          severity: EvidenceSeverity.high,
          title: 'Tên Wi-Fi có dấu hiệu camera',
          description:
              'SSID "$ssid" chứa từ khóa thường gặp ở camera/IP camera hoặc đầu ghi.',
          score: 28,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          ipAddress: input.ipAddress,
          macAddress: input.macAddress,
          ssid: ssid,
          vendor: input.vendor,
        ),
      );
    }

    if (ssid.isNotEmpty && RegExp(r'^[0-9A-Fa-f]{6,}$').hasMatch(ssid)) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.wifi,
          severity: EvidenceSeverity.medium,
          title: 'Tên Wi-Fi dạng mã số lạ',
          description:
              'SSID "$ssid" có dạng chuỗi mã số/hex. Một số thiết bị IoT hoặc camera dùng kiểu đặt tên này.',
          score: 15,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          ipAddress: input.ipAddress,
          macAddress: input.macAddress,
          ssid: ssid,
          vendor: input.vendor,
        ),
      );
    }

    return evidences;
  }

  static List<ThreatEvidence> _analyzeRssi(ThreatDeviceInput input) {
    final List<ThreatEvidence> evidences = [];
    final int? rssi = input.rssi;

    if (rssi == null) {
      return evidences;
    }

    if (rssi >= -45) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.wifi,
          severity: EvidenceSeverity.high,
          title: 'Tín hiệu rất mạnh',
          description:
              'RSSI $rssi dBm cho thấy thiết bị có thể đang ở rất gần. RSSI chỉ là ước lượng tương đối vì còn phụ thuộc vật cản và công suất phát.',
          score: 18,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          ipAddress: input.ipAddress,
          macAddress: input.macAddress,
          ssid: input.ssid,
          vendor: input.vendor,
          rssi: rssi,
        ),
      );
    } else if (rssi >= -60) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.wifi,
          severity: EvidenceSeverity.medium,
          title: 'Tín hiệu khá mạnh',
          description:
              'RSSI $rssi dBm cho thấy thiết bị có thể ở trong cùng phòng hoặc gần khu vực kiểm tra.',
          score: 10,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          ipAddress: input.ipAddress,
          macAddress: input.macAddress,
          ssid: input.ssid,
          vendor: input.vendor,
          rssi: rssi,
        ),
      );
    } else if (rssi >= -75) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.wifi,
          severity: EvidenceSeverity.low,
          title: 'Tín hiệu trong phạm vi theo dõi',
          description:
              'RSSI $rssi dBm đủ để theo dõi, nhưng chưa phải bằng chứng mạnh.',
          score: 4,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          ipAddress: input.ipAddress,
          macAddress: input.macAddress,
          ssid: input.ssid,
          vendor: input.vendor,
          rssi: rssi,
        ),
      );
    }

    return evidences;
  }

  static List<ThreatEvidence> _analyzePorts(ThreatDeviceInput input) {
    final List<ThreatEvidence> evidences = [];
    final List<int> ports = input.openPorts.toSet().toList()..sort();

    if (ports.isEmpty) {
      return evidences;
    }

    for (final int port in ports) {
      if (port == 554) {
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.lan,
            severity: EvidenceSeverity.critical,
            title: 'Phát hiện cổng RTSP 554',
            description:
                'Cổng 554 thường dùng cho luồng video RTSP trên camera IP hoặc thiết bị giám sát.',
            score: 38,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: input.vendor,
            port: port,
          ),
        );
      } else if (port == 37777) {
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.lan,
            severity: EvidenceSeverity.critical,
            title: 'Phát hiện cổng 37777',
            description:
                'Cổng 37777 thường gặp ở một số đầu ghi/camera giám sát. Đây là dấu hiệu nghi vấn mạnh.',
            score: 35,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: input.vendor,
            port: port,
          ),
        );
      } else if (port == 1935) {
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.lan,
            severity: EvidenceSeverity.high,
            title: 'Phát hiện cổng streaming 1935',
            description:
                'Cổng 1935 thường liên quan đến streaming RTMP. Cần kiểm tra thêm nếu xuất hiện cùng các dấu hiệu camera khác.',
            score: 25,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: input.vendor,
            port: port,
          ),
        );
      } else if (port == 8000 || port == 8080 || port == 81 || port == 80) {
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.lan,
            severity: EvidenceSeverity.medium,
            title: 'Phát hiện cổng web/config',
            description:
                'Cổng $port có thể là giao diện cấu hình web. Không đủ kết luận là camera, nhưng đáng chú ý nếu đi kèm RTSP/vendor/SSID nghi vấn.',
            score: 12,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: input.vendor,
            port: port,
          ),
        );
      } else if (port == 5000 || port == 8999) {
        evidences.add(
          ThreatEvidence(
            source: ThreatSource.lan,
            severity: EvidenceSeverity.medium,
            title: 'Phát hiện cổng dịch vụ phụ',
            description:
                'Cổng $port có thể thuộc thiết bị media, NAS, IoT hoặc camera. Cần kiểm tra cùng các bằng chứng khác.',
            score: 8,
            createdAt: DateTime.now(),
            deviceId: input.bestDeviceId,
            ipAddress: input.ipAddress,
            macAddress: input.macAddress,
            ssid: input.ssid,
            vendor: input.vendor,
            port: port,
          ),
        );
      }
    }

    if (ports.length >= 2) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.lan,
          severity: EvidenceSeverity.high,
          title: 'Thiết bị mở nhiều cổng dịch vụ',
          description:
              'Thiết bị mở nhiều cổng: ${ports.join(", ")}. Nếu có cổng video hoặc vendor nghi vấn, cần kiểm tra kỹ.',
          score: 18,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          ipAddress: input.ipAddress,
          macAddress: input.macAddress,
          ssid: input.ssid,
          vendor: input.vendor,
          rawValue: ports.join(', '),
        ),
      );
    }

    return evidences;
  }

  static List<ThreatEvidence> _analyzeSentinel(ThreatDeviceInput input) {
    final List<ThreatEvidence> evidences = [];

    if (input.isNewAfterBaseline) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.sentinel,
          severity: EvidenceSeverity.high,
          title: 'Thiết bị mới xuất hiện sau baseline',
          description:
              'Thiết bị này không nằm trong danh sách nền ban đầu và xuất hiện sau khi chế độ canh gác đã bật.',
          score: 25,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          ipAddress: input.ipAddress,
          macAddress: input.macAddress,
          ssid: input.ssid,
          vendor: input.vendor,
          rssi: input.rssi,
        ),
      );
    }

    return evidences;
  }

  static List<ThreatEvidence> _analyzeBluetooth(ThreatDeviceInput input) {
    final List<ThreatEvidence> evidences = [];

    if (input.isUnnamedBluetoothDevice) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.bluetooth,
          severity: EvidenceSeverity.medium,
          title: 'Thiết bị Bluetooth không tên',
          description:
              'Một thiết bị Bluetooth không công khai tên. Đây không phải bằng chứng chắc chắn, nhưng đáng chú ý nếu tín hiệu gần.',
          score: 12,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          macAddress: input.macAddress,
          vendor: input.vendor,
          rssi: input.rssi,
        ),
      );
    }

    if (input.rssi != null && input.rssi! >= -50) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.bluetooth,
          severity: EvidenceSeverity.medium,
          title: 'Bluetooth tín hiệu rất gần',
          description:
              'RSSI Bluetooth ${input.rssi} dBm cho thấy thiết bị có thể ở rất gần vị trí quét.',
          score: 10,
          createdAt: DateTime.now(),
          deviceId: input.bestDeviceId,
          macAddress: input.macAddress,
          vendor: input.vendor,
          rssi: input.rssi,
        ),
      );
    }

    return evidences;
  }

  static List<ThreatEvidence> _analyzeMagnetometer(ThreatDeviceInput input) {
    final List<ThreatEvidence> evidences = [];

    final double? delta = input.magneticDelta;
    final double? fluctuation = input.magneticFluctuation;

    if (delta == null) {
      return evidences;
    }

    if (delta > 40 && fluctuation != null && fluctuation <= 15) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.magnetometer,
          severity: EvidenceSeverity.high,
          title: 'Từ trường tĩnh tập trung',
          description:
              'Độ lệch từ trường ${delta.toStringAsFixed(1)} µT và dao động thấp ${fluctuation.toStringAsFixed(1)} µT. Đây có thể là nam châm hoặc linh kiện điện tử DC gần cảm biến.',
          score: 25,
          createdAt: DateTime.now(),
          rawValue:
              'delta=${delta.toStringAsFixed(1)}, fluctuation=${fluctuation.toStringAsFixed(1)}',
        ),
      );
    } else if (delta > 40 && fluctuation != null && fluctuation > 15) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.magnetometer,
          severity: EvidenceSeverity.medium,
          title: 'Từ trường cao nhưng dao động mạnh',
          description:
              'Độ lệch từ trường ${delta.toStringAsFixed(1)} µT nhưng dao động ${fluctuation.toStringAsFixed(1)} µT. Có thể liên quan đến dây điện AC, thiết bị điện hoặc môi trường nhiễu.',
          score: 12,
          createdAt: DateTime.now(),
          rawValue:
              'delta=${delta.toStringAsFixed(1)}, fluctuation=${fluctuation.toStringAsFixed(1)}',
        ),
      );
    } else if (delta > 20) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.magnetometer,
          severity: EvidenceSeverity.low,
          title: 'Biến động từ tính nhẹ',
          description:
              'Độ lệch từ trường ${delta.toStringAsFixed(1)} µT. Nên quét sát hơn để xác nhận.',
          score: 6,
          createdAt: DateTime.now(),
          rawValue: 'delta=${delta.toStringAsFixed(1)}',
        ),
      );
    }

    return evidences;
  }

  static List<ThreatEvidence> _analyzeOptical(ThreatDeviceInput input) {
    final List<ThreatEvidence> evidences = [];

    if (input.opticalUserMarkedSuspicious) {
      evidences.add(
        ThreatEvidence(
          source: ThreatSource.optical,
          severity: EvidenceSeverity.high,
          title: 'Người dùng đánh dấu điểm quang học nghi vấn',
          description: input.opticalNote?.trim().isNotEmpty == true
              ? input.opticalNote!.trim()
              : 'Người dùng phát hiện điểm phản xạ hoặc điểm sáng nghi vấn khi quét bằng camera.',
          score: 25,
          createdAt: DateTime.now(),
          rawValue: input.opticalNote,
        ),
      );
    }

    return evidences;
  }

  static ThreatScore _buildScore(
    List<ThreatEvidence> evidences, {
    bool isRoomReport = false,
  }) {
    final List<ThreatEvidence> sortedEvidences = List.from(evidences)
      ..sort((a, b) => b.score.compareTo(a.score));

    int score = 0;

    for (final evidence in sortedEvidences) {
      score += evidence.score;
    }

    score = score.clamp(0, maxScore);

    final ThreatLevel level = _levelFromScore(score);

    final String title = isRoomReport
        ? _roomTitleFromLevel(level)
        : _deviceTitleFromLevel(level);

    final String summary = _summaryFromLevel(level, score, sortedEvidences);

    return ThreatScore(
      score: score,
      level: level,
      title: title,
      summary: summary,
      evidences: sortedEvidences,
      createdAt: DateTime.now(),
    );
  }

  static ThreatLevel _levelFromScore(int score) {
    if (score >= 85) {
      return ThreatLevel.critical;
    }

    if (score >= 65) {
      return ThreatLevel.high;
    }

    if (score >= 40) {
      return ThreatLevel.medium;
    }

    if (score >= 15) {
      return ThreatLevel.low;
    }

    return ThreatLevel.safe;
  }

  static String _deviceTitleFromLevel(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.safe:
        return 'Thiết bị có rủi ro thấp';
      case ThreatLevel.low:
        return 'Thiết bị có vài dấu hiệu nhẹ';
      case ThreatLevel.medium:
        return 'Thiết bị cần kiểm tra thêm';
      case ThreatLevel.high:
        return 'Thiết bị nghi vấn cao';
      case ThreatLevel.critical:
        return 'Thiết bị cực kỳ nghi vấn';
    }
  }

  static String _roomTitleFromLevel(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.safe:
        return 'Khu vực an toàn tương đối';
      case ThreatLevel.low:
        return 'Khu vực có rủi ro thấp';
      case ThreatLevel.medium:
        return 'Khu vực cần kiểm tra thêm';
      case ThreatLevel.high:
        return 'Khu vực có nghi vấn cao';
      case ThreatLevel.critical:
        return 'Khu vực cực kỳ nghi vấn';
    }
  }

  static String _summaryFromLevel(
    ThreatLevel level,
    int score,
    List<ThreatEvidence> evidences,
  ) {
    final int positiveEvidenceCount = evidences
        .where((e) => e.score > 0)
        .length;

    switch (level) {
      case ThreatLevel.safe:
        return 'Điểm rủi ro $score/100. Chưa có bằng chứng mạnh. Số tín hiệu đáng chú ý: $positiveEvidenceCount.';
      case ThreatLevel.low:
        return 'Điểm rủi ro $score/100. Có một số dấu hiệu nhẹ, nên kiểm tra thêm nếu đang ở môi trường nhạy cảm.';
      case ThreatLevel.medium:
        return 'Điểm rủi ro $score/100. Có nhiều tín hiệu cần chú ý. Nên kết hợp quét LAN, Wi-Fi, từ trường và quang học.';
      case ThreatLevel.high:
        return 'Điểm rủi ro $score/100. Có bằng chứng nghi vấn cao. Nên kiểm tra vật lý kỹ các vị trí gần nguồn tín hiệu.';
      case ThreatLevel.critical:
        return 'Điểm rủi ro $score/100. Có nhiều bằng chứng nghi vấn mạnh. Nên xử lý thận trọng và xác minh bằng nhiều phương pháp.';
    }
  }

  static VendorCategory classifyVendor(String vendor) {
    final String lower = vendor.toLowerCase();

    if (_containsAny(lower, [
      'hikvision',
      'dahua',
      'vivotek',
      'axis',
      'xiongmai',
      'xm',
      'mobotix',
      'bosch security',
      'hanwha',
      'uniview',
      'avigilon',
      'geovision',
      'tiandy',
      'tvt',
      'sricam',
      'foscam',
      'wansview',
      'reolink',
      'ezviz',
      'arlo',
      'wyze',
      'imou',
      'yoosee',
      'ip camera',
      'netcam',
      'camtech',
      'pixord',
      'vstarcam',
      'tenda technology camera',
    ])) {
      return VendorCategory.camera;
    }

    if (_containsAny(lower, [
      'nvr',
      'dvr',
      'digital video recorder',
      'network video recorder',
      'surveillance',
      'video recorder',
      'xmeye',
    ])) {
      return VendorCategory.recorder;
    }

    if (_containsAny(lower, [
      'tuya',
      'espressif',
      'sonoff',
      'shelly',
      'smart home',
      'iot',
      'esp32',
      'esp8266',
      'broadlink',
      'aqara',
      'yeelight',
    ])) {
      return VendorCategory.iot;
    }

    if (_containsAny(lower, [
      'tp-link',
      'tplink',
      'd-link',
      'linksys',
      'netgear',
      'asus',
      'cisco',
      'huawei',
      'zte',
      'mikrotik',
      'ubiquiti',
      'ruijie',
      'totolink',
      'mercury',
      'tenda',
      'zyxel',
      'juniper',
      'draytek',
      'router',
      'gateway',
      'access point',
      'ap ',
    ])) {
      return VendorCategory.router;
    }

    if (_containsAny(lower, [
      'apple',
      'samsung',
      'xiaomi',
      'oppo',
      'vivo',
      'oneplus',
      'realme',
      'sony mobile',
      'google',
      'motorola',
      'honor',
      'nokia',
      'lg electronics',
    ])) {
      return VendorCategory.phone;
    }

    if (_containsAny(lower, [
      'intel',
      'dell',
      'hewlett packard',
      'hp ',
      'lenovo',
      'asus computer',
      'acer',
      'microsoft',
      'msi',
      'gigabyte',
      'asrock',
      'vmware',
      'parallels',
    ])) {
      return VendorCategory.computer;
    }

    if (_containsAny(lower, [
      'canon',
      'epson',
      'brother',
      'lexmark',
      'xerox',
      'ricoh',
      'fuji xerox',
      'kyocera',
    ])) {
      return VendorCategory.printer;
    }

    if (_containsAny(lower, [
      'lg innotek',
      'lg electronics',
      'samsung electronics',
      'sony corporation',
      'tcl',
      'hisense',
      'philips',
      'sharp',
      'panasonic',
      'tv',
      'smart tv',
    ])) {
      return VendorCategory.smartTv;
    }

    if (_containsAny(lower, [
      'sonos',
      'jbl',
      'bose',
      'anker',
      'audio',
      'speaker',
      'soundbar',
    ])) {
      return VendorCategory.audio;
    }

    return VendorCategory.unknown;
  }

  static bool _containsAny(String input, List<String> keywords) {
    for (final String keyword in keywords) {
      if (input.contains(keyword.toLowerCase())) {
        return true;
      }
    }

    return false;
  }
}

class ThreatParser {
  static ThreatSource parseSource(dynamic value) {
    final String text = value?.toString() ?? '';

    for (final item in ThreatSource.values) {
      if (item.name == text) {
        return item;
      }
    }

    return ThreatSource.unknown;
  }

  static ThreatLevel parseLevel(dynamic value) {
    final String text = value?.toString() ?? '';

    for (final item in ThreatLevel.values) {
      if (item.name == text) {
        return item;
      }
    }

    return ThreatLevel.safe;
  }

  static EvidenceSeverity parseSeverity(dynamic value) {
    final String text = value?.toString() ?? '';

    for (final item in EvidenceSeverity.values) {
      if (item.name == text) {
        return item;
      }
    }

    return EvidenceSeverity.info;
  }
}

class ThreatUiHelper {
  static String sourceLabel(ThreatSource source) {
    switch (source) {
      case ThreatSource.wifi:
        return 'Wi-Fi';
      case ThreatSource.lan:
        return 'LAN';
      case ThreatSource.bluetooth:
        return 'Bluetooth';
      case ThreatSource.magnetometer:
        return 'Từ trường';
      case ThreatSource.optical:
        return 'Quang học';
      case ThreatSource.sentinel:
        return 'Lính gác';
      case ThreatSource.manual:
        return 'Người dùng';
      case ThreatSource.unknown:
        return 'Không rõ';
    }
  }

  static String severityLabel(EvidenceSeverity severity) {
    switch (severity) {
      case EvidenceSeverity.info:
        return 'Thông tin';
      case EvidenceSeverity.low:
        return 'Thấp';
      case EvidenceSeverity.medium:
        return 'Trung bình';
      case EvidenceSeverity.high:
        return 'Cao';
      case EvidenceSeverity.critical:
        return 'Rất cao';
    }
  }

  static String levelEmoji(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.safe:
        return '🟢';
      case ThreatLevel.low:
        return '🟡';
      case ThreatLevel.medium:
        return '🟠';
      case ThreatLevel.high:
        return '🔴';
      case ThreatLevel.critical:
        return '🚨';
    }
  }

  static String severityEmoji(EvidenceSeverity severity) {
    switch (severity) {
      case EvidenceSeverity.info:
        return 'ℹ️';
      case EvidenceSeverity.low:
        return '🟡';
      case EvidenceSeverity.medium:
        return '🟠';
      case EvidenceSeverity.high:
        return '🔴';
      case EvidenceSeverity.critical:
        return '🚨';
    }
  }
}