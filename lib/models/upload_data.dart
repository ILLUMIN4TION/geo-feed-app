import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

// UploadProvider가 임시로 들고 있을 데이터 모델
class UploadData {
  final File compressedFile;      // 1. 압축된 이미지 파일
  final String caption;           // 2. 캡션
  final Map<String, dynamic> exifData; // 3. 촬영 설정 (EXIF)
  final GeoPoint? location; // 이게 바뀔 수 있음
  final File originalFileForPreview; // 5. (추가) 확인 화면에서 보여줄 원본

  UploadData({
    required this.compressedFile,
    required this.caption,
    required this.exifData,
    this.location,
    required this.originalFileForPreview,
  });


  // 값을 변경해서 새로운 객체를 만드는 메서드
  UploadData copyWith({
    GeoPoint? location,
  }) {
    return UploadData(
      compressedFile: compressedFile,
      caption: caption,
      exifData: exifData,
      location: location ?? this.location, // 새 값이 있으면 쓰고, 없으면 기존 값 유지
      originalFileForPreview: originalFileForPreview,
    );
  }
}