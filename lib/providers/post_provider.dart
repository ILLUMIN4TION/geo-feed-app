// lib/providers/post_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geofeed/models/post.dart'; // W3에서 만든 Post 모델
import 'package:firebase_auth/firebase_auth.dart'; // Auth 임포트
import 'package:geofeed/providers/base_provider.dart';
import 'package:geofeed/utils/view_state.dart';

class PostProvider extends BaseProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Auth 인스턴스

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
  Future<void> toggleLike(String postId, List<String> currentLikes) async {
    final user = _auth.currentUser;
    if (user == null) return; // 로그인 안 했으면 무시

    final String uid = user.uid;
    final docRef = _firestore.collection('posts').doc(postId);

    try {
      if (currentLikes.contains(uid)) {
        // 이미 좋아요를 눌렀다면 -> 배열에서 제거 (좋아요 취소)
        await docRef.update({
          'likes': FieldValue.arrayRemove([uid]),
        });
      } else {
        // 안 눌렀다면 -> 배열에 추가 (좋아요)
        await docRef.update({
          'likes': FieldValue.arrayUnion([uid]),
        });
      }
      // Firestore가 업데이트되면 Stream이 자동으로 UI를 갱신하므로
      // 별도의 setState나 notifyListeners가 필요 없음!
    } catch (e) {
      print("Like Error: $e");
    }
  }
}