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

  // 피드용 게시글 (무한스크롤)
  List<Post> _posts = [];
  List<Post> get posts => _posts;

  // 지도용 게시글 (위치 정보 있는 전체)
  List<Post> _mapPosts = [];
  List<Post> get mapPosts => _mapPosts;

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
        setState(ViewState.Loading);
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

  // 🔹 지도용: 위치 정보 있는 게시글 전체 로드
  Future<void> fetchMapPosts() async {
    try {
      // 위치 정보가 있는 게시글만 쿼리
      final snapshot = await _firestore
          .collection('posts')
          .where('location', isNotEqualTo: null)
          .orderBy('location') // where 사용 시 orderBy 필요
          .orderBy('timestamp', descending: true)
          .get();

      _mapPosts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

      notifyListeners();
    } catch (e) {
      print("Map Posts Fetch Error: $e");
    }
  }

  // 🔹 지도와 피드 둘 다 새로고침
  Future<void> refreshAll() async {
    await Future.wait([
      fetchPosts(refresh: true),
      fetchMapPosts(),
    ]);
  }

  // --------------- 좋아요 / 삭제 / 수정 (개선) ---------------

  Future<void> toggleLike(String postId, List<String> currentLikes) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final docRef = _firestore.collection('posts').doc(postId);

    // 피드와 지도 양쪽 업데이트
    final feedIndex = _posts.indexWhere((p) => p.id == postId);
    final mapIndex = _mapPosts.indexWhere((p) => p.id == postId);

    Post? oldFeedPost;
    Post? oldMapPost;

    List<String> newLikes = List.from(currentLikes);

    if (newLikes.contains(uid)) {
      newLikes.remove(uid);
    } else {
      newLikes.add(uid);
    }

    // Optimistic update
    if (feedIndex != -1) {
      oldFeedPost = _posts[feedIndex];
      _posts[feedIndex] = oldFeedPost.copyWith(likes: newLikes);
    }
    if (mapIndex != -1) {
      oldMapPost = _mapPosts[mapIndex];
      _mapPosts[mapIndex] = oldMapPost.copyWith(likes: newLikes);
    }
    notifyListeners();

    try {
      if (currentLikes.contains(uid)) {
        await docRef.update({'likes': FieldValue.arrayRemove([uid])});
      } else {
        await docRef.update({'likes': FieldValue.arrayUnion([uid])});
      }
    } catch (e) {
      print("Like error $e");
      // Rollback
      if (feedIndex != -1 && oldFeedPost != null) {
        _posts[feedIndex] = oldFeedPost;
      }
      if (mapIndex != -1 && oldMapPost != null) {
        _mapPosts[mapIndex] = oldMapPost;
      }
      notifyListeners();
    }
  }

  Future<bool> deletePost(String postId, String imageUrl) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();

      if (imageUrl.isNotEmpty) {
        await _storage.refFromURL(imageUrl).delete();
      }

      // 피드와 지도 양쪽에서 삭제
      _posts.removeWhere((p) => p.id == postId);
      _mapPosts.removeWhere((p) => p.id == postId);
      notifyListeners();
      return true;
    } catch (e) {
      print("Delete Error: $e");
      return false;
    }
  }

  Future<Post?> updatePost(String postId, String newCaption) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'caption': newCaption,
      });

      Post? updatedPost;

      // 피드 업데이트
      final feedIndex = _posts.indexWhere((p) => p.id == postId);
      if (feedIndex != -1) {
        _posts[feedIndex] = _posts[feedIndex].copyWith(caption: newCaption);
        updatedPost = _posts[feedIndex];
      }

      // 지도 업데이트
      final mapIndex = _mapPosts.indexWhere((p) => p.id == postId);
      if (mapIndex != -1) {
        _mapPosts[mapIndex] = _mapPosts[mapIndex].copyWith(caption: newCaption);
        updatedPost = _mapPosts[mapIndex];
      }

      notifyListeners();
      return updatedPost;
    } catch (e) {
      print("Update Error: $e");
      return null;
    }
  }

  // 🔹 새 게시글 추가 시 지도에도 반영
  void addNewPost(Post post) {
    _posts.insert(0, post);

    // 위치 정보가 있으면 지도에도 추가
    if (post.location != null) {
      _mapPosts.insert(0, post);
    }

    notifyListeners();
  }
}