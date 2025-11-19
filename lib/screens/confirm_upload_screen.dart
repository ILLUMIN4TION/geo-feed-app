import 'package:flutter/material.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/screens/home_screen.dart'; // HomeScreen (GlobalKey 사용)
import 'package:geofeed/utils/view_state.dart';
import 'package:geofeed/widgets/loading_overlay.dart'; // 로딩 오버레이
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class ConfirmUploadScreen extends StatelessWidget {
  const ConfirmUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uploadProvider = context.watch<UploadProvider>();
    final preparedData = uploadProvider.preparedData;

    // 1. 데이터 유효성 검사 (비정상 접근 방지)
    if (preparedData == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("데이터가 준비되지 않았습니다. 뒤로가기 해주세요.")),
      );
    }

    // 2. EXIF 위젯 리스트 생성
    final List<Widget> exifWidgets = preparedData.exifData.entries
        .where((entry) => entry.value != null && entry.value.toString() != 'N/A')
        .map((entry) => Chip(label: Text("${entry.key}: ${entry.value}")))
        .toList();

    // 3. 지도 마커 생성
    final Set<Marker> markers = {};
    if (preparedData.location != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("upload-spot"),
          position: LatLng(
            preparedData.location!.latitude,
            preparedData.location!.longitude,
          ),
        ),
      );
    }

    // 4. (정책) 업로드 가능 여부 확인
    // EXIF 정보나 위치 정보 중 하나라도 있어야 업로드 가능
    final bool hasExifInfo = exifWidgets.isNotEmpty;
    final bool hasLocation = preparedData.location != null;
    final bool canUpload = hasExifInfo || hasLocation;

    // 로딩 중일 때도 화면을 유지하기 위해 Stack 사용
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("공유 전 확인"),
            actions: [
              // 5. (정책) 로딩 중이 아니고 && 업로드 조건 만족 시 버튼 표시
              if (uploadProvider.state != ViewState.Loading && canUpload)
                TextButton(
                  onPressed: () async {
                    // 업로드 실행
                    bool success = await context.read<UploadProvider>().executeUpload();

                    if (success && context.mounted) {
                      // 성공 시 피드 탭(1번)으로 변경
                      HomeScreen.homeKey.currentState?.changeTab(1);

                      // 홈 화면까지 복귀
                      Navigator.of(context).popUntil((route) => route.isFirst);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("업로드 완료!"), backgroundColor: Colors.green),
                      );
                    } else if (!success && context.mounted) {
                      // 실패 시 에러 표시
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.read<UploadProvider>().errorMessage ?? "업로드 실패"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "공유하기",
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                )
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지 미리보기
                Image.file(
                  preparedData.originalFileForPreview,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),

                // 캡션
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    preparedData.caption.isEmpty ? "(캡션 없음)" : preparedData.caption,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const Divider(),

                // 6. (정책) 업로드 불가 시 경고 메시지 표시
                if (!canUpload)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(height: 8),
                        Text(
                          "촬영 정보(EXIF)나 위치 정보가 없는 사진은\n업로드할 수 없습니다.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "다른 사진을 선택해주세요.",
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // EXIF 정보
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Text("촬영 정보 (EXIF)", style: Theme.of(context).textTheme.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
                  child: exifWidgets.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text("이 사진에는 촬영 정보가 없습니다.", style: TextStyle(color: Colors.grey)),
                    ),
                  )
                      : Wrap(spacing: 8.0, runSpacing: 4.0, children: exifWidgets),
                ),
                const Divider(),

                // 위치 정보 (지도)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text("포토스팟 위치", style: Theme.of(context).textTheme.titleMedium),
                ),
                (preparedData.location == null)
                    ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text("사진에서 위치 정보를 찾을 수 없습니다.")),
                )
                    : Container(
                  height: 250,
                  padding: const EdgeInsets.all(12.0),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        preparedData.location!.latitude,
                        preparedData.location!.longitude,
                      ),
                      zoom: 15,
                    ),
                    markers: markers,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 7. 로딩 오버레이 (맨 위에 표시)
        if (uploadProvider.state == ViewState.Loading)
          const LoadingOverlay(),
      ],
    );
  }
}