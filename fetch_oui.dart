import 'dart:io';
import 'dart:convert';

void main() async {
  print('Đang tải dữ liệu OUI mới nhất');

  final client = HttpClient();
  try {
    // Thử kết nối đến máy chủ IEEE gốc
    final url = Uri.parse('https://standards-oui.ieee.org/oui/oui.txt');
    final request = await client.getUrl(url);

    // Giả lập danh tính trình duyệt Chrome để không bị tường lửa chặn (Lỗi 418)
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );

    final response = await request.close();

    if (response.statusCode != 200) {
      print(
        'Máy chủ IEEE từ chối (Mã lỗi: ${response.statusCode}). Đang chuyển sang Server dự phòng',
      );
      await _fetchFromFallback(client);
      return;
    }

    await _processResponse(response);
  } catch (e) {
    print('Lỗi kết nối máy chủ chính: $e. Đang chuyển sang Server dự phòng');
    await _fetchFromFallback(client);
  } finally {
    client.close();
  }
}

Future<void> _fetchFromFallback(HttpClient client) async {
  try {
    // Sử dụng máy chủ dự phòng chuyên dụng cho Developer (linuxnet.ca)
    final url = Uri.parse('https://linuxnet.ca/ieee/oui.txt');
    final request = await client.getUrl(url);

    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );

    final response = await request.close();

    if (response.statusCode != 200) {
      print(
        'Lỗi Server dự phòng: ${response.statusCode}. Vui lòng tải file thủ công!',
      );
      return;
    }

    await _processResponse(response);
  } catch (e) {
    print('Không thể tải từ Server dự phòng: $e');
  }
}

Future<void> _processResponse(HttpClientResponse response) async {
  print('Đã kết nối thành công! Đang xử lý dữ liệu');

  final lines = await response
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .toList();
  final Map<String, String> ouiMap = {};

  for (var line in lines) {
    if (line.contains('(hex)')) {
      final parts = line.split('(hex)');
      if (parts.length >= 2) {
        // Cắt khoảng trắng và bỏ dấu gạch ngang (VD: 00-1A-2B thành 001A2B)
        final mac = parts[0].trim().replaceAll('-', '').toUpperCase();
        final vendor = parts[1].trim();
        ouiMap[mac] = vendor;
      }
    }
  }

  // Đảm bảo thư mục assets tồn tại
  final assetDir = Directory('assets');
  if (!await assetDir.exists()) {
    await assetDir.create();
  }

  // Ghi file JSON
  final file = File('assets/oui_database.json');
  await file.writeAsString(jsonEncode(ouiMap));

  print(
    'Thành công rực rỡ! Đã cập nhật ${ouiMap.length} địa chỉ MAC vào file assets/oui_database.json',
  );
}