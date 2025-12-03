import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/widgets/user_info_header.dart';
import 'package:shimmer/shimmer.dart';

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
                  child: CachedNetworkImage(
                    imageUrl: post.getImageUrl(useThumbnail: true),
                    height: 150,
                    width: 150, // 표시 크기는 150x150 정사각형
                    fit: BoxFit.cover, // 비율 유지하며 꽉 채우기 (짤림 발생)
                    
                    // ★ [수정] memCacheHeight 제거 -> 비율 유지
                    // 300 정도로 설정하면 레티나 디스플레이에서도 선명함
                    memCacheWidth: 300, 
                    
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        height: 150,
                        width: 150,
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      width: 150,
                      color: Colors.grey[200],
                      child: const Icon(Icons.error),
                    ),
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