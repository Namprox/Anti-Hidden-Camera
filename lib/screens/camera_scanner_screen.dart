import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/globals.dart';

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  CameraController? _controller;

  bool _isFlashing = false;
  bool _isFrontCamera = false;
  bool _showInfoOverlay = false;

  Timer? _flashTimer;

  // Chạm để Focus
  Offset? _focusPointOnScreen;
  bool _showFocusIndicator = false;
  bool _isFocusing = false;
  Timer? _focusIndicatorTimer;
  Timer? _lockFocusTimer;

  @override
  void initState() {
    super.initState();
    _initCamera(0);
  }

  Future<void> _initCamera(int camIndex) async {
    if (globalCameras.isEmpty) return;

    // Tránh lỗi nếu máy ko có đủ camera trước/sau
    if (camIndex < 0 || camIndex >= globalCameras.length) {
      camIndex = 0;
      _isFrontCamera = false;
    }

    // 1. Lưu tạm controller cũ
    final CameraController? oldController = _controller;

    // 2. Ép UI phải hiện vòng xoay Loading ngay lập tức để tránh lỗi màn hình đỏ
    if (mounted) {
      setState(() {
        _controller = null;
        _isFlashing = false;
        _focusPointOnScreen = null;
        _showFocusIndicator = false;
        _isFocusing = false;
      });
    }

    // 3. Hủy các timer đang chạy
    _flashTimer?.cancel();
    _focusIndicatorTimer?.cancel();
    _lockFocusTimer?.cancel();

    // 4. Tiêu diệt controller cũ một cách an toàn
    if (oldController != null) {
      try {
        await oldController.setFlashMode(FlashMode.off);
      } catch (_) {}

      await oldController.dispose();
    }

    // 5. Khởi tạo controller mới
    final CameraController newController = CameraController(
      globalCameras[camIndex],
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await newController.initialize();

      // Tắt flash mặc định sau khi mở camera
      try {
        await newController.setFlashMode(FlashMode.off);
      } catch (e) {
        debugPrint('Thiết bị không hỗ trợ tắt flash lúc khởi tạo: $e');
      }

      // Khóa Focus ban đầu để hạn chế tự lấy nét liên tục
      // Khi người dùng chạm màn hình, app sẽ mở Focus ngắn hạn rồi khóa lại
      try {
        await newController.setFocusMode(FocusMode.locked);
      } catch (e) {
        debugPrint('Thiết bị không hỗ trợ khóa Focus: $e');
      }

      // Khóa exposure ban đầu nếu thiết bị hỗ trợ
      try {
        await newController.setExposureMode(ExposureMode.locked);
      } catch (e) {
        debugPrint('Thiết bị không hỗ trợ khóa Exposure: $e');
      }
    } catch (e) {
      debugPrint('Lỗi khởi tạo camera: $e');
    }

    // 6. Cập nhật lại UI với camera mới đã sẵn sàng
    if (mounted) {
      setState(() {
        _controller = newController;
      });
    }
  }

  Future<void> _handleTapToFocus(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final Offset localPosition = details.localPosition;

    final double screenWidth = constraints.maxWidth;
    final double screenHeight = constraints.maxHeight;

    if (screenWidth <= 0 || screenHeight <= 0) return;

    // camera plugin dùng tọa độ chuẩn hóa từ 0.0 -> 1.0
    final double dx = (localPosition.dx / screenWidth).clamp(0.0, 1.0);
    final double dy = (localPosition.dy / screenHeight).clamp(0.0, 1.0);

    final Offset normalizedPoint = Offset(dx, dy);

    setState(() {
      _focusPointOnScreen = localPosition;
      _showFocusIndicator = true;
      _isFocusing = true;
    });

    _focusIndicatorTimer?.cancel();
    _lockFocusTimer?.cancel();

    try {
      // 1. Đặt điểm lấy nét theo vị trí người dùng chạm
      await _controller!.setFocusPoint(normalizedPoint);

      // 2. Đặt điểm đo sáng theo vị trí người dùng chạm
      try {
        await _controller!.setExposurePoint(normalizedPoint);
      } catch (e) {
        debugPrint('Thiết bị không hỗ trợ set Exposure Point: $e');
      }

      // 3. Mở Focus Auto ngắn hạn để camera thực hiện lấy nét tại điểm đã chọn sau đó sẽ khóa lại bằng timer phía dưới
      try {
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (e) {
        debugPrint('Thiết bị không hỗ trợ FocusMode.auto: $e');
      }

      // 4. Mở Exposure Auto ngắn hạn để đo sáng tại điểm đã chọn
      try {
        await _controller!.setExposureMode(ExposureMode.auto);
      } catch (e) {
        debugPrint('Thiết bị không hỗ trợ ExposureMode.auto: $e');
      }

      // 5. Sau một nhịp ngắn, khóa Focus/Exposure lại để camera ko tự nhảy nét
      _lockFocusTimer = Timer(const Duration(milliseconds: 700), () async {
        if (!mounted ||
            _controller == null ||
            !_controller!.value.isInitialized) {
          return;
        }

        try {
          await _controller!.setFocusMode(FocusMode.locked);
        } catch (e) {
          debugPrint('Thiết bị không hỗ trợ khóa Focus sau khi chạm: $e');
        }

        try {
          await _controller!.setExposureMode(ExposureMode.locked);
        } catch (e) {
          debugPrint('Thiết bị không hỗ trợ khóa Exposure sau khi chạm: $e');
        }

        if (mounted) {
          setState(() {
            _isFocusing = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Lỗi lấy nét thủ công: $e');

      if (mounted) {
        setState(() {
          _isFocusing = false;
        });
      }
    }

    // Ẩn vòng tròn Focus sau khi hiển thị
    _focusIndicatorTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() {
          _showFocusIndicator = false;
        });
      }
    });
  }

  void _switchCamera() {
    _flashTimer?.cancel();
    _focusIndicatorTimer?.cancel();
    _lockFocusTimer?.cancel();

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isFlashing = false;
      _focusPointOnScreen = null;
      _showFocusIndicator = false;
      _isFocusing = false;
    });

    final int camIndex = _isFrontCamera ? 1 : 0;
    _initCamera(camIndex);
  }

  void _toggleStrobe() {
    if (_controller == null ||
        _isFrontCamera ||
        !_controller!.value.isInitialized) {
      return;
    }

    setState(() => _isFlashing = !_isFlashing);

    if (_isFlashing) {
      // Tạo nhịp nháy chớp tắt liên tục mỗi 150ms
      _flashTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
        if (_controller != null && _controller!.value.isInitialized) {
          _controller!.setFlashMode(
            timer.tick % 2 == 0 ? FlashMode.torch : FlashMode.off,
          );
        }
      });
    } else {
      // Hủy timer và tắt đèn
      _flashTimer?.cancel();

      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.setFlashMode(FlashMode.off);
      }
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _focusIndicatorTimer?.cancel();
    _lockFocusTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildCameraPreviewWithTapToFocus() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _handleTapToFocus(details, constraints),
            child: Stack(
              children: [
                // Camera Preview giữ nguyên cách fix tỷ lệ cũ
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize!.height,
                        height: _controller!.value.previewSize!.width,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                ),

                // Vòng tròn hiển thị điểm lấy nét
                if (_focusPointOnScreen != null && _showFocusIndicator)
                  Positioned(
                    left: _focusPointOnScreen!.dx - 38,
                    top: _focusPointOnScreen!.dy - 38,
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: _isFocusing ? 76 : 64,
                        height: _isFocusing ? 76 : 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.tealAccent,
                            width: 2,
                          ),
                          color: Colors.black.withOpacity(0.18),
                        ),
                        child: Center(
                          child: Icon(
                            _isFocusing
                                ? Icons.center_focus_strong
                                : Icons.check,
                            color: Colors.tealAccent,
                            size: _isFocusing ? 32 : 28,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Dòng hướng dẫn chạm để lấy nét
                Positioned(
                  top: MediaQuery.of(context).padding.top + 55,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 45),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: const Text(
                        'Chạm vào màn hình để lấy nét thủ công',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isFrontCamera ? null : _toggleStrobe,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFlashing ? Colors.redAccent : Colors.teal,
                disabledBackgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _isFlashing ? Icons.flash_off : Icons.flash_on,
                color: Colors.white,
              ),
              label: Text(
                _isFlashing ? 'TẮT STROBE' : 'BẬT STROBE',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Nút Dò hồng ngoại / Switch Camera
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _switchCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              label: Text(
                _isFrontCamera
                    ? 'Chuyển cam sau (Strobe)'
                    : 'Chuyển Cam trước (Dò hồng ngoại)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(
            Icons.info_outline,
            color: Colors.tealAccent,
            size: 28,
          ),
          onPressed: () {
            setState(() => _showInfoOverlay = true);
          },
        ),
      ),
    );
  }

  Widget _buildInfoOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() => _showInfoOverlay = false);
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.tealAccent,
                  size: 60,
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.tealAccent),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'HƯỚNG DẪN:\n\n'
                    '1. Tắt hoàn toàn đèn phòng (tối đen)\n\n'
                    '2. Quét chậm camera trước qua các góc khả nghi\n\n'
                    '3. Chạm vào điểm nghi vấn trên màn hình để lấy nét thủ công\n\n'
                    '4. Tìm các đốm sáng trắng/tím lấp lánh qua màn hình (mắt thường không thấy)\n\n'
                    '5. Dùng Strobe (Cam Sau) để tìm phản xạ ống kính\n\n\n',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.tealAccent),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Lớp 1: Camera Preview + Tap To Focus
          _buildCameraPreviewWithTapToFocus(),

          // Lớp 2: Nút bấm cố định ở đáy màn hình
          _buildBottomControls(),

          // Lớp 3: Icon Info ở Top-Left
          _buildInfoButton(),

          // Lớp 4: Overlay hướng dẫn
          if (_showInfoOverlay) _buildInfoOverlay(),
        ],
      ),
    );
  }
}