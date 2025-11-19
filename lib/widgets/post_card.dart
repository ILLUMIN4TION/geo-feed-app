import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/widgets/user_info_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:provider/provider.dart';
import 'package:geofeed/widgets/expandable_caption.dart';


class PostCard extends StatelessWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {

    // 4. 현재 로그인한 유저 ID 가져오기
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    // 5. 내가 좋아요를 눌렀는지 확인
    final bool isLiked = post.likes.contains(currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      elevation: 1.0,
      clipBehavior: Clip.antiAlias,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. (수정) userId -> post 객체 전체 전달
          UserInfoHeader(post: post),

          // 2. 이미지 + EXIF 오버레이 스택
          GestureDetector(
            onTap: () {
              // 상세 페이지로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailScreen(post: post),
                ),
              );
              
              print("Tapped on post: ${post.id}");
            },
            child: Stack(
              children: [
                // 베이스 이미지
                Image.network(
                  post.imageUrl,
                  width: double.infinity,
                  height: 350,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 350,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 350,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                ),

                //EXIF 오버레이
                _buildExifOverlay(context, post.exifData),
              ],
            ),
          ),

          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.black,
                ),
                onPressed: () {
                  // PostProvider의 toggleLike 호출
                  context.read<PostProvider>().toggleLike(post.id, post.likes);
                },
              ),
              // 좋아요 개수 표시
              Text(
                "${post.likes.length}명",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              const Spacer(), // 오른쪽으로 밀기

              // (선택 사항) 북마크 아이콘 (기능 없음)
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                onPressed: () {},
              ),
            ],
          ),

          // 3. 캡션
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: post.caption.isEmpty
                ? const SizedBox.shrink() // 캡션 없으면 숨김
                : ExpandableCaption(text: post.caption), // 2. ExpandableCaption 사용
          ),
        ],
      ),
    );
  }

  // EXIF 오버레이 위젯 빌더
  Widget _buildExifOverlay(BuildContext context, Map<String, dynamic> exifData) {
    // 1. (수정) Firestore에 저장된 포맷팅된 값을 그대로 가져옴
    final apertureText = exifData['Aperture']?.toString() ?? 'N/A';
    final shutterText = exifData['ShutterSpeed']?.toString() ?? 'N/A';

    // 2. (수정) ISO는 Number 타입이므로 toString()으로 변환
    final isoRaw = exifData['ISO'];
    final isoText = (isoRaw == null) ? 'N/A' : 'ISO ${isoRaw.toString()}';

    final focalLengthText = exifData['FocalLength']?.toString() ?? 'N/A';
    final modelText = exifData['Model']?.toString() ?? '';

    final bool noExifData = apertureText == 'N/A' &&
        shutterText == 'N/A' &&
        isoText == 'N/A' &&
        focalLengthText == 'N/A' &&
        modelText.isEmpty;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        //  그라데이션을 더 강하게 하여 대비 향상
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],  //TODO Deprecated use <- 수정할 수 있으면 해보기
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 필요한 만큼만 공간 차지
          children: [
            // (신규) 데이터가 없다면 "정보 없음" 표시
            if (noExifData)
              Text(
                "촬영 정보 없음",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  shadows: [
                    Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54),
                  ],
                ),
              )
            // 첫 번째 줄: 조리개, 셔터스피드
           else ...[
              Wrap( // (수정) Wrap으로 변경하여 4개 표시
                spacing: 16.0,
                runSpacing: 8.0,
                children: [
                  _exifIconText(Icons.camera_alt_outlined, apertureText),
                  _exifIconText(Icons.shutter_speed_outlined, shutterText),
                  _exifIconText(Icons.iso_outlined, isoText),
                  _exifIconText(Icons.center_focus_weak_outlined, focalLengthText),
                ],
              ),
              const SizedBox(height: 8),
              if (modelText.isNotEmpty && modelText != 'N/A')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    modelText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [
                        Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // EXIF 아이콘 + 텍스트 헬퍼 (텍스트 그림자 추가)
  Widget _exifIconText(IconData icon, String text) {
    if (text == 'N/A') return const SizedBox.shrink(); // N/A는 표시하지 않음

    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18, shadows: const [ 
          Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54),
        ]),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 14, 
            fontWeight: FontWeight.w500,
            shadows: [ // 
              Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54),
            ],
          ),
        ),
      ],
    );
  }
}