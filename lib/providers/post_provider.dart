// lib/providers/post_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geofeed/models/post.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geofeed/providers/base_provider.dart';
import 'package:geofeed/utils/view_state.dart';

class PostProvider extends BaseProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Auth 인스턴스
  final FirebaseStorage _storage = FirebaseStorage.instance; // 2. Storage 인스턴스

  Stream<List<Post>>? _postsStream;
  Stream<List<Post>>? get postsStream => _postsStream;

  PostProvider() {
    // Provider가 생성되자마자 스트림을 초기화
    fetchPostsStream();
  }

  // 1. Firestore의 'posts' 컬렉션을 실시간으로 구독하는 스트림
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

  //2. 좋아요 토글
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
      // Firestore가 업데이트되면 Stream이 자동으로 UI를 갱신
    } catch (e) {
      print("Like Error: $e");
    }
  }


  // 3. 게시물 삭제 기능
  Future<bool> deletePost(String postId, String imageUrl) async {
    try {
      // Firestore 문서 삭제
      await _firestore.collection('posts').doc(postId).delete();

      // Storage 이미지 파일 삭제
      if (imageUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          // 이미지가 이미 없거나 권한 문제 등은 무시
          print("Image Delete Error: $e");
        }
      }
      return true;
    } catch (e) {
      print("Delete Error: $e");
      return false;
    }
  }

  // 4.  게시물 수정 기능 (캡션만)
  Future<bool> updatePost(String postId, String newCaption) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'caption': newCaption,
      });
      return true;
    } catch (e) {
      print("Update Error: $e");
      return false;
    }
  }
}