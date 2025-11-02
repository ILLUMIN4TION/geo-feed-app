import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    // EXIF 데이터를 보기 좋게 텍스트로 변환
    final exifInfo = (post.exifData.entries)
        .where((entry) => entry.value != null && entry.value.isNotEmpty)
        .map((entry) => "${entry.key}: ${entry.value}")
        .join("  |  "); // 예: ISO: 100 | Aperture: f/2.8

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 2.0,
      clipBehavior: Clip.antiAlias, // 이미지 모서리를 둥글게
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 게시물 이미지
          Image.network(
            post.imageUrl,
            width: double.infinity,
            height: 300, // 고정 높이
            fit: BoxFit.cover,
            // 이미지 로딩 중
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 300,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            // 에러 발생 시
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 300,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          ),

          // 2. EXIF 정보 (핵심)
          if (exifInfo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Text(
                exifInfo,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          const Divider(height: 1),

          // 3. 캡션
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              post.caption.isEmpty ? "(캡션 없음)" : post.caption,
              style: const TextStyle(fontSize: 15.0),
            ),
          ),
          
          // TODO: (W5) 좋아요, 댓글 버튼 등
        ],
      ),
    );
  }
}