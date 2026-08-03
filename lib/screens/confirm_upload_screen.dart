import 'package:flutter/material.dart';
import 'package:geofeed/providers/upload_provider.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/screens/location_picker_screen.dart';
import 'package:geofeed/utils/theme.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:geofeed/widgets/loading_overlay.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor)),
              const SizedBox(height: 16),
              Text("데이터를 준비하는 중...", style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    final List<Widget> exifWidgets = preparedData.exifData.entries
        .where((entry) => entry.value != null && entry.value.toString() != 'N/A')
        .map((entry) => Chip(
          label: Text("${entry.key}: ${entry.value}", style: const TextStyle(fontSize: 12)),
          backgroundColor: AppTheme.bgSurface,
          labelStyle: TextStyle(color: AppTheme.textSecondary),
        ))
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
                    bool success = await context.read<UploadProvider>().executeUpload();

                    if (success && context.mounted) {
                      final postProvider = context.read<PostProvider>();
                      postProvider.fetchMapPosts(); 
                      postProvider.fetchPosts(refresh: true);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("업로드 완료!"),
                          backgroundColor: AppTheme.successColor,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
                          duration: const Duration(seconds: 2),
                        ),
                      );

                      Navigator.of(context).popUntil((route) => route.isFirst);
                      
                    } else if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.read<UploadProvider>().errorMessage ?? "업로드 실패"),
                          backgroundColor: AppTheme.errorColor,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "공유하기",
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
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
                // 이미지 미리보기 - 모던한 디자인
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Image.file(
                      preparedData.originalFileForPreview,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // 캡션 - 모던한 카드 스타일
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    preparedData.caption.isEmpty ? "(캡션 없음)" : preparedData.caption,
                    style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                  ),
                ),
                Divider(height: 2, color: AppTheme.borderLight),
                // 위치 수동 설정 UI
                if (!hasLocation)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.add_location_alt, color: AppTheme.warningColor, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          "위치 정보가 없는 사진입니다.",
                          style: TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const Text("지도를 움직여 포토스팟을 지정해주세요.", style: TextStyle(fontSize: 13)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text("위치 직접 설정하기", style: TextStyle(fontSize: 14)),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("촬영 정보 (EXIF)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: exifWidgets.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text("이 사진에는 촬영 정보가 없습니다.", style: TextStyle(color: AppTheme.textHint))),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: exifWidgets,
                        ),
                ),
                Divider(height: 2, color: AppTheme.borderLight),
                // 지도
                if (hasLocation) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text("포토스팟 위치", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  ),
                  Container(
                    height: 250,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(preparedData.location!.latitude, preparedData.location!.longitude),
                        zoom: 15,
                      ),
                      markers: markers,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        if (uploadProvider.state == ViewState.Loading) const LoadingOverlay(),
      ],
    );
  }
}