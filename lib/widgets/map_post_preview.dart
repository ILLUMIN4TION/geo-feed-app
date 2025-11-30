// lib/widgets/map_post_preview.dart
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/widgets/user_info_header.dart';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: UserInfoHeader(
                  post: post,
                  shouldPopOnDelete: true,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  // 닫기 버튼: 갤러리로 돌아가는 신호
                  Navigator.pop(context, "backToGallery");
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: 150,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        post.caption.isEmpty ? "(캡션 없음)" : post.caption,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Model: ${post.exifData['Model'] ?? 'N/A'}",
                        style:
                        const TextStyle(fontSize: 13, color: Colors.grey),
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

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // 여기서 Post를 반환하면 호출자(=MainMapScreen)가 받아서 상세로 push함
                Navigator.pop(context, post);
              },
              child: const Text("상세 정보 보기"),
            ),
          ),
        ],
      ),
    );
  }
}