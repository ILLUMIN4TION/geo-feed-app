import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';

class ClusterPostBottomSheet extends StatelessWidget {
  final List<Post> posts;

  const ClusterPostBottomSheet({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("이 지역에 있는 게시글 ${posts.length}개",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, index) {
                final post = posts[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    post.imageUrl,
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: posts.length,
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
