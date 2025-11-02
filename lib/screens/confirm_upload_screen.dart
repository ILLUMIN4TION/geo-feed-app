// lib/screens/confirm_upload_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class ConfirmUploadScreen extends StatelessWidget {
  const ConfirmUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Provider의 상태(로딩)와 데이터(preparedData)를 모두 사용
    final uploadProvider = context.watch<UploadProvider>();
    final preparedData = uploadProvider.preparedData;

    // 데이터가 준비되지 않았다면 (예: 뒤로가기 후 다시 진입)
    if (preparedData == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text("데이터가 준비되지 않았습니다. 뒤로가기 해주세요."),
        ),
      );
    }

    // 2. EXIF 데이터를 위젯 리스트로 변환
    final List<Widget> exifWidgets = preparedData.exifData.entries
        .where((entry) => entry.value != null) // null 값 제외
        .map((entry) => Chip(label: Text("${entry.key}: ${entry.value}")))
        .toList();

    // 3. 지도에 표시할 마커 설정
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("공유 전 확인"),
        actions: [
          // 4. 최종 업로드 버튼
          (uploadProvider.state == ViewState.Loading)
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : TextButton(
                  onPressed: () async {
                    // 5. 'executeUpload' 실행
                    bool success = await context.read<UploadProvider>().executeUpload();
                    
                    if (success && context.mounted) {
                      // 6. 성공 시 홈 화면까지 모두 pop
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    } else if (!success && context.mounted) {
                      // 7. 실패 시 에러 표시
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.read<UploadProvider>().errorMessage ?? "최종 업로드 실패"
                          ),
                          backgroundColor: Colors.redAccent,
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
            // 1. 선택한 이미지
            Image.file(preparedData.originalFileForPreview,
                height: 300, width: double.infinity, fit: BoxFit.cover),
            
            // 2. 캡션
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(preparedData.caption.isEmpty ? "(캡션 없음)" : preparedData.caption,
                  style: const TextStyle(fontSize: 16)),
            ),
            const Divider(),
            
            // 3. EXIF 정보 (Chip)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text("촬영 정보 (EXIF)", style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(spacing: 8.0, runSpacing: 4.0, children: exifWidgets),
            ),
            const Divider(),

            // 4. 위치 정보 (지도)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text("포토스팟 위치", style: Theme.of(context).textTheme.titleMedium),
            ),
            (preparedData.location == null)
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text("사진에서 위치 정보를 찾을 수 없습니다.")))
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
                      scrollGesturesEnabled: false, // 스크롤 방지
                      zoomGesturesEnabled: false,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}