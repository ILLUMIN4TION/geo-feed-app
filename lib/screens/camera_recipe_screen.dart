import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

class CameraRecipeScreen extends StatefulWidget {
  final Post targetPost;

  const CameraRecipeScreen({super.key, required this.targetPost});

  @override
  State<CameraRecipeScreen> createState() => _CameraRecipeScreenState();
}

class _CameraRecipeScreenState extends State<CameraRecipeScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // 줌 레벨
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;

  // 노출 보정
  double _minExposureOffset = 0.0;
  double _maxExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;

  // 포커스 모드
  FocusMode _currentFocusMode = FocusMode.auto;

  // 플래시 모드
  FlashMode _currentFlashMode = FlashMode.off;

  // UI 표시 옵션
  bool _showControls = true;
  bool _showGridLines = true;
  bool _showHistogram = false;

  // 포커스 인디케이터
  Offset? _focusPoint;
  bool _showFocusIndicator = false;

  // 히스토그램 데이터
  List<int>? _histogramData;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) return;

    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) return;

    _controller = CameraController(
      _cameras![0],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();

    _minZoomLevel = await _controller!.getMinZoomLevel();
    _maxZoomLevel = await _controller!.getMaxZoomLevel();
    _minExposureOffset = await _controller!.getMinExposureOffset();
    _maxExposureOffset = await _controller!.getMaxExposureOffset();

    _applyAutoSettings();

    // 히스토그램 업데이트를 위한 스트림 시작
    if (_showHistogram) {
      _startHistogramUpdates();
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  void _startHistogramUpdates() {
    // 히스토그램은 성능상 주기적으로 업데이트
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _showHistogram && _controller != null) {
        _updateHistogram();
        _startHistogramUpdates();
      }
    });
  }

  Future<void> _updateHistogram() async {
    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage != null) {
        final histogram = List<int>.filled(256, 0);

        // 간단한 밝기 히스토그램 계산
        for (int y = 0; y < decodedImage.height; y += 4) {
          for (int x = 0; x < decodedImage.width; x += 4) {
            final pixel = decodedImage.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();
            final brightness = ((r + g + b) / 3).round().clamp(0, 255);
            histogram[brightness]++;
          }
        }

        if (mounted) {
          setState(() {
            _histogramData = histogram;
          });
        }
      }
    } catch (e) {
      // 히스토그램 업데이트 실패는 무시
    }
  }

  void _applyAutoSettings() {
    final focalStr = widget.targetPost.exifData['FocalLength']?.toString() ?? '';
    if (focalStr.isNotEmpty) {
      final double? targetFocal =
      double.tryParse(focalStr.replaceAll(RegExp(r'[^0-9.]'), ''));

      if (targetFocal != null) {
        if (targetFocal > 30) {
          _currentZoomLevel = 2.0;
        } else {
          _currentZoomLevel = 1.0;
        }

        if (_currentZoomLevel < _minZoomLevel) _currentZoomLevel = _minZoomLevel;
        if (_currentZoomLevel > _maxZoomLevel) _currentZoomLevel = _maxZoomLevel;

        _controller!.setZoomLevel(_currentZoomLevel);
      }
    }

    final isoStr = widget.targetPost.exifData['ISO']?.toString() ?? '';
    if (isoStr.isNotEmpty) {
      final int? targetISO = int.tryParse(isoStr.replaceAll(RegExp(r'[^0-9]'), ''));

      if (targetISO != null) {
        if (targetISO > 800) {
          _currentExposureOffset = _maxExposureOffset * 0.3;
        } else if (targetISO < 200) {
          _currentExposureOffset = _minExposureOffset * 0.3;
        }

        _controller!.setExposureOffset(_currentExposureOffset);
      }
    }
  }

  void _onTapToFocus(TapDownDetails details, BoxConstraints constraints) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );

    _controller!.setFocusPoint(offset);
    _controller!.setExposurePoint(offset);

    setState(() {
      _focusPoint = details.localPosition;
      _showFocusIndicator = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showFocusIndicator = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final exif = widget.targetPost.exifData;
    final iso = exif['ISO']?.toString() ?? 'Auto';
    final shutter = exif['ShutterSpeed']?.toString() ?? 'Auto';
    final aperture = exif['Aperture']?.toString() ?? 'Auto';
    final focal = exif['FocalLength']?.toString() ?? 'Auto';

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 카메라 프리뷰 + 탭투포커스
              GestureDetector(
                onTapDown: (details) => _onTapToFocus(details, constraints),
                child: Center(child: CameraPreview(_controller!)),
              ),

              // 그리드 라인
              if (_showGridLines) _buildGridLines(constraints),

              // 포커스 인디케이터
              if (_showFocusIndicator && _focusPoint != null)
                _buildFocusIndicator(),

              // 상단 컨트롤 버튼들
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _showGridLines ? Icons.grid_on : Icons.grid_off,
                              color: Colors.white,
                              size: 26,
                            ),
                            onPressed: () {
                              setState(() {
                                _showGridLines = !_showGridLines;
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              _showHistogram ? Icons.bar_chart : Icons.show_chart,
                              color: Colors.white,
                              size: 26,
                            ),
                            onPressed: () {
                              setState(() {
                                _showHistogram = !_showHistogram;
                                if (_showHistogram) {
                                  _startHistogramUpdates();
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              _showControls ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white,
                              size: 26,
                            ),
                            onPressed: () {
                              setState(() {
                                _showControls = !_showControls;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 히스토그램 (좌측 상단)
              if (_showHistogram && _histogramData != null)
                Positioned(
                  top: 120,
                  left: 20,
                  child: _buildHistogram(),
                ),

              // 목표 EXIF 정보 (우측 상단)
              if (_showControls)
                Positioned(
                  top: 120,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildGuideChip("ISO", iso, Colors.orangeAccent),
                      const SizedBox(height: 8),
                      _buildGuideChip("Shutter", shutter, Colors.blueAccent),
                      const SizedBox(height: 8),
                      _buildGuideChip("Aperture", aperture, Colors.greenAccent),
                      const SizedBox(height: 8),
                      _buildGuideChip("Focal", focal, Colors.purpleAccent),
                    ],
                  ),
                ),

              // 좌측 하단 퀵 컨트롤
              if (_showControls)
                Positioned(
                  left: 20,
                  bottom: 200,
                  child: Column(
                    children: [
                      _buildQuickControlButton(
                        icon: _getFlashIcon(),
                        label: _getFlashLabel(),
                        onTap: _cycleFlashMode,
                      ),
                      const SizedBox(height: 15),
                      _buildQuickControlButton(
                        icon: _getFocusIcon(),
                        label: _getFocusLabel(),
                        onTap: _cycleFocusMode,
                      ),
                    ],
                  ),
                ),

              // 하단 슬라이더 컨트롤
              if (_showControls)
                Positioned(
                  bottom: 150,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      const Text(
                        "목표 설정값과 비슷하게 찍어보세요!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),

                      _buildSliderControl(
                        label: "Zoom",
                        value: _currentZoomLevel,
                        min: _minZoomLevel,
                        max: _maxZoomLevel,
                        displayValue: "${_currentZoomLevel.toStringAsFixed(1)}x",
                        color: Colors.yellowAccent,
                        onChanged: (value) {
                          setState(() {
                            _currentZoomLevel = value;
                            _controller!.setZoomLevel(value);
                          });
                        },
                      ),

                      const SizedBox(height: 8),

                      _buildSliderControl(
                        label: "노출",
                        value: _currentExposureOffset,
                        min: _minExposureOffset,
                        max: _maxExposureOffset,
                        displayValue: _currentExposureOffset > 0
                            ? "+${_currentExposureOffset.toStringAsFixed(1)}"
                            : _currentExposureOffset.toStringAsFixed(1),
                        color: Colors.orangeAccent,
                        onChanged: (value) {
                          setState(() {
                            _currentExposureOffset = value;
                            _controller!.setExposureOffset(value);
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // 촬영 버튼
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      try {
                        final image = await _controller!.takePicture();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("촬영 완료! ${image.path}"),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        print(e);
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.transparent,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 그리드 라인 빌더
  Widget _buildGridLines(BoxConstraints constraints) {
    return IgnorePointer(
      child: SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: CustomPaint(
          painter: GridPainter(),
        ),
      ),
    );
  }

  // 포커스 인디케이터
  Widget _buildFocusIndicator() {
    return Positioned(
      left: _focusPoint!.dx - 40,
      top: _focusPoint!.dy - 40,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.yellowAccent, width: 2),
          borderRadius: BorderRadius.circular(40),
        ),
        child: const Icon(
          Icons.center_focus_strong,
          color: Colors.yellowAccent,
          size: 30,
        ),
      ),
    );
  }

  // 히스토그램 빌더
  Widget _buildHistogram() {
    if (_histogramData == null) return const SizedBox.shrink();

    final maxValue = _histogramData!.reduce((a, b) => a > b ? a : b);

    return Container(
      width: 150,
      height: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Histogram",
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              painter: HistogramPainter(_histogramData!, maxValue),
              size: const Size(134, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label ",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                displayValue,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 30,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: Colors.white30,
                thumbColor: color,
                overlayColor: color.withOpacity(0.3),
                trackHeight: 2,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cycleFlashMode() {
    setState(() {
      switch (_currentFlashMode) {
        case FlashMode.off:
          _currentFlashMode = FlashMode.auto;
          break;
        case FlashMode.auto:
          _currentFlashMode = FlashMode.always;
          break;
        case FlashMode.always:
          _currentFlashMode = FlashMode.torch;
          break;
        case FlashMode.torch:
          _currentFlashMode = FlashMode.off;
          break;
      }
      _controller!.setFlashMode(_currentFlashMode);
    });
  }

  IconData _getFlashIcon() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.flashlight_on;
    }
  }

  String _getFlashLabel() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return "OFF";
      case FlashMode.auto:
        return "AUTO";
      case FlashMode.always:
        return "ON";
      case FlashMode.torch:
        return "TORCH";
    }
  }

  void _cycleFocusMode() {
    setState(() {
      switch (_currentFocusMode) {
        case FocusMode.auto:
          _currentFocusMode = FocusMode.locked;
          break;
        case FocusMode.locked:
          _currentFocusMode = FocusMode.auto;
          break;
      }
      _controller!.setFocusMode(_currentFocusMode);
    });
  }

  IconData _getFocusIcon() {
    switch (_currentFocusMode) {
      case FocusMode.auto:
        return Icons.center_focus_strong;
      case FocusMode.locked:
        return Icons.center_focus_weak;
    }
  }

  String _getFocusLabel() {
    switch (_currentFocusMode) {
      case FocusMode.auto:
        return "AF";
      case FocusMode.locked:
        return "MF";
    }
  }
}

// 그리드 라인 페인터 (3분할 법칙)
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;

    // 세로선 2개
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // 가로선 2개
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 히스토그램 페인터
class HistogramPainter extends CustomPainter {
  final List<int> data;
  final int maxValue;

  HistogramPainter(this.data, this.maxValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final barWidth = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final barHeight = (data[i] / maxValue) * size.height;
      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}