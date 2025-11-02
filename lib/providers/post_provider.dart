// lib/providers/post_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geofeed/models/post.dart'; // W3에서 만든 Post 모델
import 'package:geofeed/providers/base_provider.dart';
import 'package:geofeed/utils/view_state.dart';

class PostProvider extends BaseProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Post>>? _postsStream;
  Stream<List<Post>>? get postsStream => _postsStream;

  PostProvider() {
    // Provider가 생성되자마자 스트림을 초기화
    fetchPostsStream();
  }

  // Firestore의 'posts' 컬렉션을 실시간으로 구독하는 스트림
  void fetchPostsStream() {
    setState(ViewState.Loading);
    try {
      _postsStream = _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true) // 최신순 정렬
          .snapshots() // -> Stream<QuerySnapshot>
          .map((snapshot) {
            // QuerySnapshot을 List<Post>로 변환
            return snapshot.docs.map((doc) {
              return Post.fromFirestore(doc); // W3에서 만든 팩토리 생성자
            }).toList();
          });
      setState(ViewState.Idle);
    } catch (e) {
      setState(ViewState.Error);
    }
  }
}