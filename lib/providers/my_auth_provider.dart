import 'package:firebase_auth/firebase_auth.dart';
import 'package:geofeed/providers/base_provider.dart'; 
import 'package:geofeed/utils/view_state.dart';      

class MyAuthProvider extends BaseProvider { 
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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

  // 5. 회원가입 메서드
  Future<bool> signUp({required String email, required String password}) async {
    setState(ViewState.Loading);
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      setState(ViewState.Idle);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message;
      setState(ViewState.Error);
      return false;
    }
  }
}