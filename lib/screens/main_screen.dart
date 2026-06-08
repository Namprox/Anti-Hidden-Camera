import 'package:flutter/material.dart';
import 'magnetometer_screen.dart';
import 'camera_scanner_screen.dart';
import 'lan_scanner_screen.dart';
import 'bluetooth_scanner_screen.dart';
import 'wifi_radar_screen.dart';
import 'sentinel_mode_screen.dart';
import 'report_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MagnetometerScreen(),
    const CameraScannerScreen(),
    const LanScannerScreen(),
    const BluetoothScannerScreen(),
    const WifiRadarScreen(),
    const SentinelModeScreen(),
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.radar, 'label': 'Từ Trường', 'color': Colors.tealAccent},
    {'icon': Icons.camera, 'label': 'Quang Học', 'color': Colors.blueAccent},
    {
      'icon': Icons.device_hub,
      'label': 'Quét LAN',
      'color': Colors.purpleAccent,
    },
    {
      'icon': Icons.bluetooth_searching,
      'label': 'Quét BLE',
      'color': Colors.lightBlueAccent,
    },
    {
      'icon': Icons.wifi_tethering,
      'label': 'Radar Wi-Fi',
      'color': Colors.orangeAccent,
    },
    {'icon': Icons.security, 'label': 'Lính Gác', 'color': Colors.redAccent},
    {
      'icon': Icons.assessment,
      'label': 'Báo cáo tổng hợp',
      'color': Colors.greenAccent,
    },
  ];

  void _selectScreen(int index) {
    if (index == _menuItems.length - 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReportScreen()),
      );
      return;
    }

    setState(() {
      _currentIndex = index;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(_menuItems[_currentIndex]['label']),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF252525),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, color: Colors.tealAccent, size: 32),
                      SizedBox(width: 14),
                      Text(
                        'Anti Hidden Camera',
                        style: TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = _currentIndex == index;
                  return ListTile(
                    leading: Icon(item['icon'], color: item['color']),
                    title: Text(
                      item['label'],
                      style: TextStyle(
                        color: isSelected ? item['color'] : Colors.white70,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    tileColor: isSelected
                        ? item['color'].withOpacity(0.12)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () => _selectScreen(index),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Phiên bản 1.0.0',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
    );
  }
}