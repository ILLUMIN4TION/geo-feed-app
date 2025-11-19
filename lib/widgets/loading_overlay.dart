// lib/widgets/loading_overlay.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 뒷배경을 흐리게 처리
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),
        // 2. 중앙에 로딩 인디케이터와 텍스트 표시
        const Center(
          child: Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("처리 중입니다..."),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}