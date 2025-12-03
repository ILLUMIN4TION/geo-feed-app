import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geofeed/models/post_cluster_item.dart';
import 'package:shimmer/shimmer.dart';

class MapClusterGallerySheet extends StatelessWidget {
  final List<PostClusterItem> items;

  const MapClusterGallerySheet({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final posts = items.map((e) => e.post).toList();

    return Container(
      height: 350,
      padding: const EdgeInsets.only(top: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Text(
            "이 지역에 있는 게시글 ${posts.length}개",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: GridView.builder(
              itemCount: posts.length,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 갤러리 형태
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0, // 1:1 정사각형 그리드
              ),
              itemBuilder: (_, index) {
                final post = posts[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context, post);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: post.getImageUrl(useThumbnail: true),
                      fit: BoxFit.cover, // 넘치는 부분은 잘라냄 (비율 유지)
                      
                      // ★ [수정] memCacheHeight 제거 -> 비율 유지하며 너비만 300으로 맞춤
                      memCacheWidth: 300, 
                      
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}