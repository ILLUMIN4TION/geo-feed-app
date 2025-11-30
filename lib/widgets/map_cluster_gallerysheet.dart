import 'package:flutter/material.dart';
import 'package:geofeed/models/post_cluster_item.dart';
import 'package:geofeed/widgets/map_post_preview.dart';

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
              ),
              itemBuilder: (_, index) {
                final post = posts[index];

                return GestureDetector(
                  onTap: () {
                    // 갤러리 닫으면서 선택한 post 반환
                    Navigator.pop(context, post);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      post.imageUrl,
                      fit: BoxFit.cover,
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
