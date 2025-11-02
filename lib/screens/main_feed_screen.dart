import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/widgets/post_card.dart'; // 1. 방금 만든 PostCard 임포트
import 'package:provider/provider.dart';

class MainFeedScreen extends StatelessWidget {
  const MainFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. PostProvider의 스트림에 접근 (watch)
    final postStream = context.watch<PostProvider>().postsStream;

    return StreamBuilder<List<Post>>(
      stream: postStream, // 3. 실시간 게시물 스트림 구독
      builder: (context, snapshot) {
        // 4. 로딩 중
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // 5. 에러 발생
        if (snapshot.hasError) {
          return const Center(child: Text("데이터를 불러오는 데 실패했습니다."));
        }

        final posts = snapshot.data!;

        // 6. 데이터가 없을 때
        if (posts.isEmpty) {
          return const Center(
            child: Text(
              "아직 게시물이 없습니다.\n첫 번째 포토스팟을 공유해보세요!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        // 7. ListView로 피드 표시
        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(post: post); // 8. PostCard 위젯 사용
          },
        );
      },
    );
  }
}