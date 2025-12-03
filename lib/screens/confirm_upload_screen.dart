import 'package:flutter/material.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/screens/home_screen.dart';
import 'package:geofeed/screens/location_picker_screen.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:geofeed/widgets/loading_overlay.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // GeoPoint 때문에 필요
import 'package:provider/provider.dart';

class ConfirmUploadScreen extends StatelessWidget {
  const ConfirmUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uploadProvider = context.watch<UploadProvider>();
    final preparedData = uploadProvider.preparedData;

    // 데이터가 없거나 로딩 중일 때 처리
    if (preparedData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("공유 전 확인")),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("데이터를 준비하는 중..."),
            ],
          ),
        ),
      );
    }

    final List<Widget> exifWidgets = preparedData.exifData.entries
        .where((entry) => entry.value != null && entry.value.toString() != 'N/A')
        .map((entry) => Chip(label: Text("${entry.key}: ${entry.value}")))
        .toList();

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

    final bool hasLocation = preparedData.location != null;
    final bool canUpload = hasLocation;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("공유 전 확인"),
            actions: [
              if (uploadProvider.state != ViewState.Loading && canUpload)
                TextButton(
                  onPressed: () async {
                    // 1. 업로드 실행
                    bool success = await context.read<UploadProvider>().executeUpload();

                    if (success && context.mounted) {
                      // ★ [핵심 수정] 업로드 성공 시 즉시 데이터를 새로고침합니다.
                      // await를 써서 데이터 로드가 끝난 뒤 화면을 닫을 수도 있고,
                      // 사용자 경험을 위해 요청만 보내고 화면을 닫을 수도 있습니다.
                      // 여기서는 요청을 보내놓고 화면을 닫습니다. (비동기)
                      
                      final postProvider = context.read<PostProvider>();
                      
                      // 지도 마커 새로고침 (이게 있어야 맵으로 돌아갔을 때 마커가 뜸)
                      postProvider.fetchMapPosts(); 
                      
                      // 피드 목록 새로고침 (피드 탭으로 갔을 때 최신글 보이게)
                      postProvider.fetchPosts(refresh: true);

                      // (선택사항) 만약 업로드 후 무조건 피드 탭으로 보내고 싶다면 아래 주석 해제
                      // HomeScreen.homeKey.currentState?.changeTab(1);

                      // 스낵바 표시
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("업로드 완료!"),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.only(
                            bottom: 90,
                            left: 16,
                            right: 16,
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );

                      // 화면 닫기 (메인 화면으로 복귀)
                      // popUntil을 사용하여 UploadScreen, ConfirmScreen 등을 한 번에 닫음
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      
                    } else if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              context.read<UploadProvider>().errorMessage ?? "업로드 실패"
                          ),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.only(
                            bottom: 90,
                            left: 16,
                            right: 16,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "공유하기",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                    preparedData.caption.isEmpty
                        ? "(캡션 없음)"
                        : preparedData.caption,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const Divider(),
                // 위치 수동 설정 UI
                if (!hasLocation)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.add_location_alt,
                            color: Colors.orange, size: 40),
                        const SizedBox(height: 8),
                        const Text(
                          "위치 정보가 없는 사진입니다.",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text("지도를 움직여 포토스팟을 지정해주세요."),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.map),
                          label: const Text("위치 직접 설정하기"),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LocationPickerScreen(),
                              ),
                            );
                            if (result != null && result is LatLng) {
                              context.read<UploadProvider>().updateLocation(
                                GeoPoint(result.latitude, result.longitude),
                              );
                            }
                          },
                        )
                      ],
                    ),
                  ),
                // EXIF 정보
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Text("촬영 정보 (EXIF)",
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
                  child: exifWidgets.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        "이 사진에는 촬영 정보가 없습니다.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                      : Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: exifWidgets,
                  ),
                ),
                const Divider(),
                // 지도
                if (hasLocation) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text("포토스팟 위치",
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Container(
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
                ]
              ],
            ),
          ),
        ),
        if (uploadProvider.state == ViewState.Loading) const LoadingOverlay(),
      ],
    );
  }
}