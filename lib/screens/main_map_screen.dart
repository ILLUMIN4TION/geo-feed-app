import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class MainMapScreen extends StatelessWidget {
  const MainMapScreen({super.key});

  // (W4) List<Post>를 Set<Marker>로 변환하는 헬퍼 함수
  Set<Marker> _createMarkers(List<Post> posts) {
    return posts
        .where((post) => post.location != null) // 1. 위치 정보가 있는 게시물만 필터링
        .map((post) {
          return Marker(
            markerId: MarkerId(post.id),
            position: LatLng(
              post.location.latitude,
              post.location.longitude,
            ),
            infoWindow: InfoWindow(
              title: post.caption.isNotEmpty ? post.caption : "포토스팟",
              snippet: "탭하여 상세 정보 보기", // TODO: 탭 이벤트 구현
            ),
            // TODO: (선택) 마커 탭 시, 해당 게시물 상세 팝업 표시
            onTap: () {
              // print("Tapped on post: ${post.id}");
            },
          );
        })
        .toSet(); // 2. Set으로 변환
  }

  @override
  Widget build(BuildContext context) {
    // 3. PostProvider의 스트림에 접근 (listen: true로 설정하여 변화 감지)
    final postStream = context.watch<PostProvider>().postsStream;

    return StreamBuilder<List<Post>>(
      stream: postStream, // 4. 실시간 게시물 스트림 구독
      builder: (context, snapshot) {
        // 5. 로딩 중
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // 6. 에러 발생
        if (snapshot.hasError) {
          return const Center(child: Text("데이터를 불러오는 데 실패했습니다."));
        }

        // 7. 데이터 수신 성공
        final posts = snapshot.data!;
        final markers = _createMarkers(posts); // 헬퍼 함수 호출

        return GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(37.5665, 126.9780), // 8. 초기 카메라 위치 (서울)
            zoom: 12,
          ),
          markers: markers, // 9. 생성된 마커(핀) 세트 표시
        );
      },
    );
  }
}