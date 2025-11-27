import 'package:firebase_auth/firebase_auth.dart';
import 'package:geofeed/providers/base_provider.dart'; 
import 'package:geofeed/utils/view_state.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io'; //File을 사용하기 위한 임포트
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:google_sign_in/google_sign_in.dart'; 

class MyAuthProvider extends BaseProvider { 
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; //프로필 이미지 적용을 위한 스토리지 인스턴스 생성
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // 파이어스토어 인스턴스 생성
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // 2. GoogleSignIn 인스턴스

  // 3. 로그아웃 메서드 (HomeScreen에서 사용)
  Future<void> signOut() async {
    await _auth.signOut();
    // StreamProvider가 상태를 감지하므로 notifyListeners() 불필요
  }

  // 4. 로그인 메서드
  Future<bool> signIn({required String email, required String password}) async {
    setState(ViewState.Loading); // 상태를 '로딩 중'으로 변경
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      setState(ViewState.Idle); // 상태를 '대기'로 변경
      return true; 
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message;
      setState(ViewState.Error); // 상태를 '에러'로 변경
      return false; 
    }
  }

  // 5. 회원가입 메서드 (수정)
  Future<bool> signUp({
    required String email, 
    required String password, 
    required String username // 1. 닉네임 파라미터 추가
  }) async {
    setState(ViewState.Loading);
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // 2. 닉네임과 함께 유저 정보 저장
      if (userCredential.user != null) {
        await _createUserDataInFirestore(userCredential.user!, email, username);
      }

      setState(ViewState.Idle);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message;
      setState(ViewState.Error);
      return false;
    }
  }
  // 6. (신규) Google 로그인 메서드
  Future<bool> signInWithGoogle() async {
    setState(ViewState.Loading);
    try {
      // 6-1. Google 로그인 창 띄우기
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // 사용자가 팝업을 닫은 경우
        setState(ViewState.Idle);
        return false;
      }

      // 6-2. Google 계정 정보로 Firebase 인증 토큰 받기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 6-3. Firebase에 로그인 (또는 자동 회원가입)
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // 6-4.  ******이게 첫 로그인(회원가입)인지 확인******
        if (userCredential.additionalUserInfo?.isNewUser == true) {
          // 6-5. 첫 로그인이라면, Firestore에 유저 정보 저장
          await _createUserDataInGoogleSignIn(user);
        }
      }
      
      setState(ViewState.Idle);
      return true;

    } catch (e) {
      _errorMessage = e.toString();
      setState(ViewState.Error);
      return false;
    }
  }

  // 7.  Google 로그인 유저를 위한 Firestore 문서 생성 헬퍼
  Future<void> _createUserDataInGoogleSignIn(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email, // Google 계정 이메일
      'username': user.displayName ?? "Google 사용자", // Google 계정 이름
      'profileImageUrl': user.photoURL, // Google 계정 프로필 사진
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 8. Firestore 'users' 컬렉션에 유저 문서 생성 헬퍼
  Future<void> _createUserDataInFirestore(User user, String email, String username) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'username': username, // 3. 임시 닉네임 대신 전달받은 닉네임 사용
      'profileImageUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }


  // 9.팔로우/언팔로우 토글 기능 (팔로우 불가능한 안정 장치에 대한 처리)
  Future<void> toggleFollow(String targetUserId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final String myUid = user.uid;

    if (myUid == targetUserId) return;

    final myDocRef = _firestore.collection('users').doc(myUid);
    final targetDocRef = _firestore.collection('users').doc(targetUserId);

    try {
      final mySnapshot = await myDocRef.get();

      // (수정) 내 문서가 아예 없으면(구형 계정), 빈 문서라도 생성해줌 (Self-healing)
      if (!mySnapshot.exists) {
        await myDocRef.set({
          'uid': myUid,
          'email': user.email,
          'username': 'Unknown User', // 임시 이름
          'following': [],
          'followers': [],
        });
      }

      // 데이터 다시 가져오기 (생성되었을 수도 있으므로)
      // snapshot.data()가 null일 경우를 대비해 안전하게 처리
      final data = mySnapshot.exists ? mySnapshot.data() : null;
      final List<dynamic> myFollowing = (data != null && data.containsKey('following'))
          ? data['following']
          : [];

      // (수정) update 대신 set(..., SetOptions(merge: true)) 사용
      // set + merge는 문서가 있으면 업데이트하고, 없으면 만들면서 필드를 추가합니다.
      // 에러 방지에 훨씬 효과적입니다.

      if (myFollowing.contains(targetUserId)) {
        // 언팔로우 (Remove)
        await myDocRef.set({
          'following': FieldValue.arrayRemove([targetUserId])
        }, SetOptions(merge: true));

        await targetDocRef.set({
          'followers': FieldValue.arrayRemove([myUid])
        }, SetOptions(merge: true));
      } else {
        // 팔로우 (Union)
        await myDocRef.set({
          'following': FieldValue.arrayUnion([targetUserId])
        }, SetOptions(merge: true));

        await targetDocRef.set({
          'followers': FieldValue.arrayUnion([myUid])
        }, SetOptions(merge: true));
      }

      notifyListeners();
    } catch (e) {
      print("Follow Error: $e");
      _errorMessage = "팔로우 처리 중 오류가 발생했습니다.";
      // (선택) 사용자에게 에러 메시지 토스트 띄우기 등
    }
  }

  // 10. 프로필 업데이트 기능
  Future<bool> updateProfile({
    required String newUsername,
    File? newProfileImage, // 이미지는 변경 안 할 수도 있으니 nullable
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    setState(ViewState.Loading);

    try {
      Map<String, dynamic> updateData = {
        'username': newUsername,
      };

      // 1. 새 이미지가 있다면 Storage에 업로드하고 URL 받기
      if (newProfileImage != null) {
        final ref = _storage.ref('user_profiles/${user.uid}.jpg');
        await ref.putFile(newProfileImage);
        final String downloadUrl = await ref.getDownloadURL();

        updateData['profileImageUrl'] = downloadUrl;
      }

      // 2. Firestore 문서 업데이트
      await _firestore.collection('users').doc(user.uid).update(updateData);

      setState(ViewState.Idle);
      return true;

    } catch (e) {
      print("Profile Update Error: $e");
      _errorMessage = "프로필 수정 실패";
      setState(ViewState.Error);
      return false;
    }
  }
  
  
}