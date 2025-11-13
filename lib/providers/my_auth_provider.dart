import 'package:firebase_auth/firebase_auth.dart';
import 'package:geofeed/providers/base_provider.dart'; 
import 'package:geofeed/utils/view_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:google_sign_in/google_sign_in.dart'; 

class MyAuthProvider extends BaseProvider { 
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // 2. Firestore 인스턴스 추가
  
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
      // 1. Google 로그인 창 띄우기
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // 사용자가 팝업을 닫은 경우
        setState(ViewState.Idle);
        return false;
      }

      // 2. Google 계정 정보로 Firebase 인증 토큰 받기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Firebase에 로그인 (또는 자동 회원가입)
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // 4. (중요) 이게 첫 로그인(회원가입)인지 확인
        if (userCredential.additionalUserInfo?.isNewUser == true) {
          // 5. 첫 로그인이라면, Firestore에 유저 정보 저장
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

  // 7. (신규) Google 로그인 유저를 위한 Firestore 문서 생성 헬퍼
  Future<void> _createUserDataInGoogleSignIn(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email, // Google 계정 이메일
      'username': user.displayName ?? "Google 사용자", // Google 계정 이름
      'profileImageUrl': user.photoURL, // Google 계정 프로필 사진
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 6. Firestore 'users' 컬렉션에 유저 문서 생성 헬퍼 (수정)
  Future<void> _createUserDataInFirestore(User user, String email, String username) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'username': username, // 3. 임시 닉네임 대신 전달받은 닉네임 사용
      'profileImageUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  
}