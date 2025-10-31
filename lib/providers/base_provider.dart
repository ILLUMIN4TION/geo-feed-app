import 'package:flutter/material.dart';
import 'package:geofeed/utils/view_state.dart'; // 방금 만든 enum

// 모든 Provider가 이 클래스를 상속(extends)받게 됩니다.
class BaseProvider extends ChangeNotifier {

  ViewState _state = ViewState.Idle; // 기본 상태는 '대기'

  ViewState get state => _state;

  // 상태를 변경하는 공용 메서드
  // (예: 로딩 시작, 로딩 끝, 에러 발생)
  void setState(ViewState newState) {
    _state = newState;
    notifyListeners(); // 상태 변경을 UI에 알림
  }
}