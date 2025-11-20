import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraRecipeScreen extends StatefulWidget {
  final Post targetPost; // 따라 할 사진의 정보

  const CameraRecipeScreen({super.key, required this.targetPost});

  @override
  State<CameraRecipeScreen> createState() => _CameraRecipeScreenState();
}

class _CameraRecipeScreenState extends State<CameraRecipeScreen>{
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // 줌 레벨 관리
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // 1. 카메라 권한 요청
    var status = await Permission.camera.request();
    if (!status.isGranted) return;

    // 2. 기기의 사용 가능한 카메라 목록 가져오기
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) return;

    // 3. 후면 카메라 선택 및 컨트롤러 초기화
    _controller = CameraController(
      _cameras![0], // 보통 0번이 후면 메인 카메라
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();

    // 줌 레벨 범위 가져오기
    _minZoomLevel = await _controller!.getMinZoomLevel();
    _maxZoomLevel = await _controller!.getMaxZoomLevel();

    // (심화: 반자동 보정 - 줌)
    // 목표 초점 거리(Focal Length)를 기반으로 줌 레벨 추정 (단순 예시)
    // 실제로는 기기별 센서 크기 등 복잡한 계산이 필요하지만 여기선 단순화
    _applyAutoZoom();

    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  void _applyAutoZoom() {
    final focalStr = widget.targetPost.exifData['FocalLength']?.toString() ?? '';
    if (focalStr.isNotEmpty) {
      // "4.4mm" -> 4.4
      final double? targetFocal = double.tryParse(focalStr.replaceAll(RegExp(r'[^0-9.]'), ''));

      if (targetFocal != null) {
        // 가정: 스마트폰 기본 화각(1배)의 초점거리가 약 24~26mm(35mm 환산)라고 가정할 때
        // 하지만 EXIF에 저장된 값은 실제 초점거리(Real Focal Length)이므로 기기마다 다름
        // 여기서는 단순히 "값이 크면 줌을 조금 당긴다" 정도의 UX만 구현

        // 예시 로직: 50mm 이상이면 2배 줌
        // (정확한 구현을 위해서는 35mm 환산 초점거리를 구하거나 기기 정보를 알아야 함)
        if (targetFocal > 30) { // 망원 느낌
          _currentZoomLevel = 2.0;
        } else {
          _currentZoomLevel = 1.0;
        }

        // 범위 제한
        if (_currentZoomLevel < _minZoomLevel) _currentZoomLevel = _minZoomLevel;
        if (_currentZoomLevel > _maxZoomLevel) _currentZoomLevel = _maxZoomLevel;

        _controller!.setZoomLevel(_currentZoomLevel);
      }
    }
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

    // 따라 할 EXIF 정보 추출
    final exif = widget.targetPost.exifData;
    final iso = exif['ISO']?.toString() ?? 'Auto';
    final shutter = exif['ShutterSpeed']?.toString() ?? 'Auto';
    final aperture = exif['Aperture']?.toString() ?? 'Auto';
    final focal = exif['FocalLength']?.toString() ?? 'Auto';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 카메라 프리뷰 (전체 화면)
          Center(child: CameraPreview(_controller!)),

          // 2. 상단 닫기 버튼
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 3. (핵심) 레시피 오버레이 (따라 하기 가이드)
          Positioned(
            top: 100,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildGuideChip("ISO", iso),
                const SizedBox(height: 8),
                _buildGuideChip("Shutter", shutter),
                const SizedBox(height: 8),
                _buildGuideChip("Aperture", aperture),
                const SizedBox(height: 8),
                _buildGuideChip("Focal", focal),
              ],
            ),
          ),

          // 4. 하단 촬영 버튼
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
                        const SnackBar(content: Text("촬영 완료! 갤러리에 저장되지 않음 (MVP)")),
                      );
                      // 여기서 UploadScreen으로 이동하거나 갤러리 저장 로직 추가 가능
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

          // 5. 안내 문구 및 줌 조절
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
                const SizedBox(height: 10),
                // 줌 슬라이더
                SizedBox(
                  width: 300,
                  child: Slider(
                    value: _currentZoomLevel,
                    min: _minZoomLevel,
                    max: _maxZoomLevel,
                    activeColor: Colors.yellowAccent,
                    inactiveColor: Colors.white30,
                    onChanged: (value) {
                      setState(() {
                        _currentZoomLevel = value;
                        _controller!.setZoomLevel(value);
                      });
                    },
                  ),
                ),
                Text(
                  "Zoom: ${_currentZoomLevel.toStringAsFixed(1)}x",
                  style: const TextStyle(color: Colors.white),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.yellowAccent.withOpacity(0.5)),
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
            style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}