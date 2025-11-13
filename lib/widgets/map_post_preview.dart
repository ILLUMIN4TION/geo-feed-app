// lib/widgets/map_post_preview.dart

import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:geofeed/widgets/user_info_header.dart'; // 유저 헤더 재사용

class MapPostPreview extends StatelessWidget {
  final Post post;
  const MapPostPreview({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. (수정) userId -> post 객체 전체 전달
          UserInfoHeader(post: post),
          
          const SizedBox(height: 10),

          // 2. 이미지 미리보기 (가로 스크롤)
          SizedBox(
            height: 150, // 미리보기 이미지 높이
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    post.imageUrl,
                    height: 150,
                    width: 150,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                // 3. 캡션 및 EXIF 요약
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        post.caption.isEmpty ? "(캡션 없음)" : post.caption,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        // 간단한 EXIF 요약
                        "Model: ${post.exifData['Model'] ?? 'N/A'}",
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 4. 상세보기 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context); // BottomSheet 닫기
                Navigator.push( // 상세 페이지로 이동
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(post: post),
                  ),
                );
              },
              child: const Text("상세 정보 보기"),
            ),
          )
        ],
      ),
    );
  }
}