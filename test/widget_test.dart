import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:check_hidden_camera/main.dart';

void main() {
  testWidgets('Kiểm tra khởi động App và Thanh điều hướng (Smoke Test)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const UltimateScannerApp());

    expect(find.text('Từ Trường'), findsOneWidget);
    expect(find.text('Quang Học/IR'), findsOneWidget);
    expect(find.text('Quét LAN'), findsOneWidget);
    expect(find.text('Quét BLE'), findsOneWidget);
    expect(find.text('Quét Từ Trường Vật Lý'), findsOneWidget);
  });
}