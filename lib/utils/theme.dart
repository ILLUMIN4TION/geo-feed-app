import 'package:flutter/material.dart';

/// 현대적이고 세련된 앱 테마 설정
class AppTheme {
  // ===== 컬러 팔레트 =====
  
  // 메인 컬러 - 따뜻하면서도 모던한 오렌지-코랄 톤
  static const Color primaryColor = Color(0xFFFF6B35);       // 메인 오렌지
  static const Color primaryLight = Color(0xFFFFA96B);       // 밝은 오렌지
  static const Color primaryDark = Color(0xFFE5552A);        // 진한 오렌지
  
  // 보조 컬러 - 부드러운 블루
  static const Color secondaryColor = Color(0xFFA3C1FF);     // 소프트 블루
  
  // 액센트 컬러 - 따뜻한 핑크
  static const Color accentColor = Color(0xFFFF8FB1);        // 따뜻한 핑크
  
  // 중립색
  static const Color bgMain = Color(0xFFF8F9FA);             //메인 배경
  static const Color bgCard = Colors.white;                  //카드 배경
  static const Color bgSurface = Color(0xFFEEEEEE);          //표면 배경
  
  // 텍스트 색상
  static const Color textPrimary = Color(0xFF2D3436);        //진한 다크그레이
  static const Color textSecondary = Color(0xFF636E72);      //중간 그레이
  static const Color textHint = Color(0xFFB2BEC3);           //연한 그레이
  
  // 경계선 및 구분자
  static const Color borderLight = Color(0xFFE8E8E8);        //밝은 경계선
  static const Color dividerColor = Color(0xFFF0F0F0);       //구분자
  
  // 상태 색상
  static const Color successColor = Color(0xFF00B894);       //성공 초록
  static const Color warningColor = Color(0xFFFFC237);       //경고 노랑
  static const Color errorColor = Color(0xFFEA5455);         //오류 빨강
  
  // 좋아요 색상
  static const Color likeColor = Color(0xFFFF4757);          //좋아요 핑크
  
  // ===== 그라데이션 =====
  
  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const Gradient sunsetGradient = LinearGradient(
    colors: [primaryColor, accentColor],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );
  
  // ===== 테마 데이터 =====
  
  static ThemeData get lightTheme {
    final textTheme = TextTheme(
      displayLarge: const TextStyle(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -1.5),
      displayMedium: const TextStyle(fontSize: 45, fontWeight: FontWeight.w400, letterSpacing: -0.5),
      displaySmall: const TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
      
      headlineLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
      headlineMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
      headlineSmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
      
      titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
      titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      
      bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: 0.5),
      bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: 0.25),
      bodySmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, letterSpacing: 0.4),
      
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );
    
    return ThemeData(
      // 메인 컬러
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: bgSurface,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      
      // Material 3 적용
      useMaterial3: true,
      
      // 폰트 패밀리
      fontFamily: 'Roboto',
      
      // 텍스트 테마
      textTheme: textTheme,
      
      // ===== 버튼 스타일 =====
      
      // ElevatedButton - 메인 액션 버튼
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // TextButton - 보조 액션
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) => primaryColor),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      
      // OutlinedButton - 경계선 있는 버튼
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // ===== 입력 필드 스타일 =====
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textHint),
        prefixIconColor: textSecondary,
      ),
      
      // ===== 카드 스타일 =====
      
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
      
      // ===== AppBar 스타일 =====
      
      appBarTheme: AppBarTheme(
        backgroundColor: bgMain,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
      ),
      
      // ===== 바텀 네비게이션 스타일 =====
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgCard,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 24, color: textSecondary),
      ),
      
      // ===== FAB 스타일 =====
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // ===== 다이얼로그 스타일 =====
      
      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
      
      // ===== 아이콘 스타일 =====
      
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),
      
      // ===== 스네이커 바 스타일 =====
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // ===== 바텀 시트 스타일 =====
      
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bgCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        elevation: 8,
      ),
    );
  }
}