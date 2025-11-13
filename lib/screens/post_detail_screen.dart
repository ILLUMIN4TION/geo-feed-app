// lib/screens/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/widgets/user_info_header.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PostDetailScreen extends StatelessWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    // 1. EXIF 데이터를 위젯 리스트로 변환
    final List<Widget> exifWidgets = post.exifData.entries
        .where((entry) => entry.value != null && entry.value.isNotEmpty)
        .map((entry) => Chip(label: Text("${entry.key}: ${entry.value}")))
        .toList();

    // 2. 지도에 표시할 마커 설정
    final Set<Marker> markers = {};
    if (post.location != null) {
      markers.add(
        Marker(
          markerId: MarkerId(post.id),
          position: LatLng(
            post.location.latitude,
            post.location.longitude,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("포스트 상세 정보"),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. (수정) userId -> post 객체 전체 전달
            UserInfoHeader(post: post),

            // 게시물 이미지
            Image.network(
              post.imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            
            // 캡션
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(post.caption.isEmpty ? "(캡션 없음)" : post.caption,
                  style: const TextStyle(fontSize: 16)),
            ),
            const Divider(),
            
            // --- (수정된 부분) EXIF 정보 ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("촬영 정보 (EXIF)", style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              // 3. EXIF 정보가 비었는지 확인
              child: exifWidgets.isEmpty
                  ? const Padding( // 4. 비어있다면: "정보 없음" 표시
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text("이 사진에는 촬영 정보가 없습니다.",
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : Wrap( // 5. 비어있지 않다면: Chip 표시
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: exifWidgets,
                    ),
            ),
            // --- (여기까지 수정) ---
            const Divider(),

            // 위치 정보 (지도)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("포토스팟 위치", style: Theme.of(context).textTheme.titleMedium),
            ),
            (post.location == null)
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text("이 사진에는 위치 정보가 없습니다.")))
                : Container(
                    height: 250,
                    margin: const EdgeInsets.all(16.0),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          post.location!.latitude,
                          post.location!.longitude,
                        ),
                        zoom: 15,
                      ),
                      markers: markers,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}