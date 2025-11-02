import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

// UploadProvider가 임시로 들고 있을 데이터 모델
class UploadData {
  final File compressedFile;      // 1. 압축된 이미지 파일
  final String caption;           // 2. 캡션
  final Map<String, dynamic> exifData; // 3. 촬영 설정 (EXIF)
  final GeoPoint? location;       // 4. 위치 (GPS)
  final File originalFileForPreview; // 5. (추가) 확인 화면에서 보여줄 원본

  UploadData({
    required this.compressedFile,
    required this.caption,
    required this.exifData,
    this.location,
    required this.originalFileForPreview,
  });
}