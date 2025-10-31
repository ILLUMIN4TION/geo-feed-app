// lib/providers/upload_provider.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geofeed/providers/base_provider.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:image_picker/image_picker.dart';
import 'package:exif/exif.dart';
import 'package:path_provider/path_provider.dart'; // 압축을 위해 임시 디렉토리 사용
import 'package:path/path.dart' as p; // 파일 확장자 추출

class UploadProvider extends BaseProvider {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 이 함수 하나로 W3의 모든 로직을 처리합니다.
  Future<bool> pickAndUploadImage({
    required String caption, 
    // TODO: 실제 위치 데이터 (GeoPoint)도 파라미터로 받아야 함
  }) async {
    setState(ViewState.Loading);

    // 1. 이미지 선택 (image_picker)
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      _errorMessage = "이미지가 선택되지 않았습니다.";
      setState(ViewState.Idle);
      return false;
    }

    File imageFile = File(pickedFile.path);

    try {
      // 2. (R&D) EXIF 파싱 (exif) - 교수님 피드백(프라이버시) 적용
      Map<String, dynamic> exifData = await _parseExif(imageFile);

      // 3. (필수) 이미지 압축 (flutter_image_compress) - 교수님 피드백(비용) 적용
      File compressedFile = await _compressImage(imageFile);

      // 4. Firebase Storage에 압축된 파일 업로드
      String? downloadUrl = await _uploadToStorage(compressedFile);
      if (downloadUrl == null) {
        throw Exception("파일 업로드 실패");
      }
      
      // 5. Cloud Firestore에 메타데이터 저장
      await _saveToFirestore(
        caption: caption,
        imageUrl: downloadUrl,
        exifData: exifData,
      );

      setState(ViewState.Idle);
      return true;

    } catch (e) {
      _errorMessage = e.toString();
      setState(ViewState.Error);
      return false;
    }
  }

  // --- Helper Methods ---

  // (R&D) EXIF 파싱
  Future<Map<String, dynamic>> _parseExif(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final data = await readExifFromBytes(bytes);

    if (data.isEmpty) {
      return {}; // EXIF 정보가 없는 사진
    }

    // 교수님 피드백(프라이버시): 민감 정보 제외, 촬영 설정만 추출
    return {
      'Make': data['Image Make']?.toString(),
      'Model': data['Image Model']?.toString(),
      'Aperture': data['EXIF FNumber']?.toString(),
      'ShutterSpeed': data['EXIF ExposureTime']?.toString(),
      'ISO': data['EXIF ISOSpeedRatings']?.toString(),
      'FocalLength': data['EXIF FocalLength']?.toString(),
      // 'GPSLatitude': data['GPS GPSLatitude']?.toString(), // (민감) 위치는 별도 처리
    };
  }

  // (필수) 이미지 압축
  Future<File> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(dir.absolute.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80, // 80% 품질로 압축
      minWidth: 1080, // 가로 최소 1080px
      minHeight: 1080, // 세로 최소 1080px
    );

    if (result == null) {
      return file; // 압축 실패 시 원본 반환
    }
    return File(result.path);
  }

  // Storage 업로드
  Future<String?> _uploadToStorage(File file) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final ref = _storage.ref('uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    UploadTask task = ref.putFile(file);
    TaskSnapshot snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  // Firestore 저장
  Future<void> _saveToFirestore({
    required String caption,
    required String imageUrl,
    required Map<String, dynamic> exifData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('posts').add({
      'userId': user.uid,
      'imageUrl': imageUrl,
      'caption': caption,
      'exifData': exifData,
      'timestamp': FieldValue.serverTimestamp(),
      'location': const GeoPoint(37.4219983, -122.084), // TODO: 실제 위치로 변경
    });
  }
}