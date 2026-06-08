import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class OuiHelper {
  static Map<String, String> _ouiMap = {};

  // Hàm chạy ngầm ở một Isolate khác (Luồng phụ) để ko làm đơ giao diện
  static Map<String, String> _parseJsonInBackground(String jsonString) {
    // Phân tích chuỗi JSON khổng lồ
    final Map<String, dynamic> parsed = json.decode(jsonString);

    // Ép kiểu toàn bộ về Map<String, String>
    return parsed.map(
      (key, value) => MapEntry(key.toUpperCase(), value.toString()),
    );
  }

  // Hàm khởi tạo đọc file JSON 35.000 dòng từ bộ nhớ máy
  static Future<void> initDatabase() async {
    try {
      // 1. Đọc file text thô từ bộ nhớ
      final String jsonString = await rootBundle.loadString(
        'assets/oui_database.json',
      );

      // 2. Ném khối Text khổng lồ sang luồng phụ để giải mã JSON (chống giật lag UI)
      _ouiMap = await compute(_parseJsonInBackground, jsonString);

      debugPrint("Đã tải thành công ${_ouiMap.length} mã OUI vào bộ nhớ RAM.");
    } catch (e) {
      debugPrint("Lỗi tải Database OUI: $e");
      _ouiMap = {};
    }
  }

  // Hàm tra cứu địa chỉ MAC với độ phức tạp O(1)
  static String lookup(String mac) {
    if (mac.isEmpty) return "Thiết bị ẩn danh / MAC Ảo";

    String cleanMac = mac.toUpperCase().replaceAll(
      ":",
      "",
    ); // Xóa dấu hai chấm nếu có

    // Cắt lấy 6 ký tự đầu tiên (Mã OUI chuẩn) - Ví dụ từ "7C:7B:68:..." thành "7C7B68"
    if (cleanMac.length >= 6) {
      String oui = cleanMac.substring(0, 6);

      // Nếu file JSON trên mạng định dạng có dấu ":" (VD: "7C:7B:68") thì dùng dòng dưới
      String formattedOui =
          "${oui.substring(0, 2)}:${oui.substring(2, 4)}:${oui.substring(4, 6)}";

      // Tìm kiếm trong từ điển
      return _ouiMap[formattedOui] ??
          _ouiMap[oui] ??
          "Nhà sản xuất không xác định (Có thể là MAC Ảo)";
    }
    return "Địa chỉ MAC không hợp lệ";
  }
}