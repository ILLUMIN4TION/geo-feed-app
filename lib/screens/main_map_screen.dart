import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/post_provider.dart';
// import 'package:geofeed/screens/post_detail_screen.dart'; 
import 'package:geofeed/widgets/map_post_preview.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class MainMapScreen extends StatelessWidget {
  const MainMapScreen({super.key});

  // List<Post>를 Set<Marker>로 변환하는 헬퍼 
  Set<Marker> _createMarkers(BuildContext context, List<Post> posts) {
    return posts
        .where((post) => post.location != null)
        .map((post) {
          return Marker(
            markerId: MarkerId(post.id),
            position: LatLng(
              post.location.latitude,
              post.location.longitude,
            ),
            onTap: () {
              // 4. (신규) BottomSheet 띄우는 함수 호출
              _showPostPreviewSheet(context, post);
            },
          );
        })
        .toSet();
  }

  // 5. (신규) ModalBottomSheet를 띄우는 헬퍼 함수
  void _showPostPreviewSheet(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder( // 모서리 둥글게
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // 6. 1단계에서 만든 위젯 반환
        return MapPostPreview(post: post);
      },
    );
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
        final markers = _createMarkers(context, posts);

        return GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(37.5665, 126.9780), //TODO 8. 초기 카메라 위치 (서울) <- 현재 위치로 수정해야함
            zoom: 12,
          ),
          markers: markers, // 9. 생성된 마커(핀) 세트 표시

          //내 위치를 점으로 표시하는 기능 사용
          myLocationEnabled: true, 
          
          //내 위치로 이동 버튼 사용
          myLocationButtonEnabled: true,
        );
      },
    );
  }
}