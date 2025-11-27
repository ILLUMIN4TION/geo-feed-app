import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geofeed/models/post.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geofeed/providers/base_provider.dart';
import 'package:geofeed/utils/view_state.dart';

class PostProvider extends BaseProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<Post> _posts = [];
  List<Post> get posts => _posts;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  bool get isFetchingMore => _isFetchingMore;

  static const int _postsLimit = 10;

  // 🔹 최초 로드 + 새로고침
  Future<void> fetchPosts({bool refresh = false}) async {
    try {
      if (refresh) {
        _lastDocument = null;
        _posts = [];
        _hasMore = true;
        setState(ViewState.Loading); // 전체 로딩
      }

      Query query = _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(_postsLimit);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        _hasMore = false;
        setState(ViewState.Idle);
        return;
      }

      final newPosts =
      snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

      _lastDocument = snapshot.docs.last;

      if (refresh) {
        _posts = newPosts;
      } else {
        _posts.addAll(newPosts);
      }

      if (newPosts.length < _postsLimit) {
        _hasMore = false;
      }

      setState(ViewState.Idle);
    } catch (e) {
      print("Fetch Error: $e");
      setState(ViewState.Error);
    }
  }

  // 🔹 스크롤 로드 (중복 방지)
  Future<void> fetchMorePosts() async {
    if (!_hasMore || _isFetchingMore) return;

    _isFetchingMore = true;
    notifyListeners();

    try {
      await fetchPosts(refresh: false);
    } finally {
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  // --------------- 좋아요 / 삭제 / 수정 그대로 유지 ---------------

  Future<void> toggleLike(String postId, List<String> currentLikes) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final docRef = _firestore.collection('posts').doc(postId);

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final oldPost = _posts[index];
    List<String> newLikes = List.from(currentLikes);

    if (newLikes.contains(uid)) {
      newLikes.remove(uid);
    } else {
      newLikes.add(uid);
    }

    _posts[index] = oldPost.copyWith(likes: newLikes); // optimistic update
    notifyListeners();

    try {
      if (currentLikes.contains(uid)) {
        await docRef.update({'likes': FieldValue.arrayRemove([uid])});
      } else {
        await docRef.update({'likes': FieldValue.arrayUnion([uid])});
      }
    } catch (e) {
      print("Like error $e");
      _posts[index] = oldPost; // rollback
      notifyListeners();
    }
  }

  Future<bool> deletePost(String postId, String imageUrl) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();

      if (imageUrl.isNotEmpty) {
        await _storage.refFromURL(imageUrl).delete();
      }

      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
      return true;
    } catch (e) {
      print("Delete Error: $e");
      return false;
    }
  }

  Future<bool> updatePost(String postId, String newCaption) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'caption': newCaption,
      });

      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index] = _posts[index].copyWith(caption: newCaption);
        notifyListeners();
      }
      return true;
    } catch (e) {
      print("Update Error: $e");
      return false;
    }
  }
}
