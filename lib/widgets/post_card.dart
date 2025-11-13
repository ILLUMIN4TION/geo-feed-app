import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/widgets/user_info_header.dart';


class PostCard extends StatelessWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
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

          // 3. 캡션
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              post.caption.isEmpty ? "(캡션 없음)" : post.caption,
              style: const TextStyle(fontSize: 15.0),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // EXIF 오버레이 위젯 빌더
  Widget _buildExifOverlay(BuildContext context, Map<String, dynamic> exifData) {
    // 원본 데이터 추출 및 포매팅
    final apertureText = _formatAperture(exifData['Aperture']?.toString() ?? 'N/A');
    final shutterText = _formatShutterSpeed(exifData['ShutterSpeed']?.toString() ?? 'N/A');
    final isoText = (exifData['ISO']?.toString() ?? 'N/A') == 'N/A' ? 'N/A' : 'ISO ${exifData['ISO']}';
    final focalLengthText = _formatFocalLength(exifData['FocalLength']?.toString() ?? 'N/A');
    final modelText = exifData['Model']?.toString() ?? ''; // 모델은 따로 처리

    // 유효한 데이터가 하나도 없는지 확인
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
              Row(
                children: [
                  _exifIconText(Icons.camera_alt_outlined, apertureText),
                  const SizedBox(width: 20),
                  _exifIconText(Icons.shutter_speed_outlined, shutterText),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _exifIconText(Icons.iso_outlined, isoText),
                  const SizedBox(width: 20),
                  _exifIconText(Icons.center_focus_weak_outlined, focalLengthText),
                ],
              ),
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

  //  초점 거리 포매터
  String _formatFocalLength(String text) {
    if (text == 'N/A' || text.isEmpty) return 'N/A'; // 빈 값 처리
    if (text.endsWith('mm')) return text;

    try {
      double value;
      if (text.contains('/')) {
        final parts = text.split('/');
        value = double.parse(parts[0]) / double.parse(parts[1]);
      } else {
        value = double.parse(text);
      }
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}mm'; 
    } catch (e) {
      return text;
    }
  }

  //  조리개 포매터
  String _formatAperture(String text) {
    if (text == 'N/A' || text.isEmpty) return 'N/A';
    if (text.startsWith('f/')) return text;

    try {
      double value;
      if (text.contains('/')) {
        final parts = text.split('/');
        value = double.parse(parts[0]) / double.parse(parts[1]);
      } else {
        value = double.parse(text);
      }
      return 'f/${value.toStringAsFixed(1)}';
    } catch (e) {
      return text;
    }
  }

  // 셔터스피드 포매터
  String _formatShutterSpeed(String text) {
    if (text == 'N/A' || text.isEmpty) return 'N/A';
    if (text.endsWith('s')) return text;

    try {
      if (text.contains('/')) {
        final parts = text.split('/');
        double value = double.parse(parts[0]) / double.parse(parts[1]);
        
        if (value < 1.0) {
          return '1/${(1 / value).round()}s';
        } else {
          return '${value.toStringAsFixed(1)}s';
        }
      } else {
         double value = double.parse(text);
         return '${value.toStringAsFixed(1)}s';
      }
    } catch (e) {
      return '${text}s';
    }
  }
}