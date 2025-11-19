import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geofeed/models/upload_data.dart';
import 'package:geofeed/providers/base_provider.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:image_picker/image_picker.dart';
import 'package:exif/exif.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

class UploadProvider extends BaseProvider {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  File? _pickedImageFile;
  File? get pickedImageFile => _pickedImageFile;

  UploadData? _preparedData;
  UploadData? get preparedData => _preparedData;

  // 이미지 선택 (갤러리 또는 카메라)
  Future<void> pickImageForPreview({required ImageSource source}) async {
    // 1. 위치 권한 요청 (Android 10+의 Scoped Storage 정책 대응 및 GeoPoint 추출을 위해)
    var status = await Permission.location.request();

    // 2. 권한이 승인되었을 때만 이미지 선택 진행
    if (status.isGranted) {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        _pickedImageFile = File(pickedFile.path);
        notifyListeners();
      }
    } else {
      _errorMessage = "위치 권한이 거부되었습니다. 위치 정보를 읽을 수 없습니다.";
      // 필요에 따라 에러 상태로 변경하거나 스낵바를 띄울 수 있도록 처리
      // notifyListeners();
    }
  }

  // 데이터 준비 (파싱 + 압축)
  Future<bool> prepareUploadData({required String caption}) async {
    if (_pickedImageFile == null) {
      _errorMessage = "이미지가 선택되지 않았습니다.";
      return false;
    }

    setState(ViewState.Loading);

    try {
      final bytes = await _pickedImageFile!.readAsBytes();
      final exifRawData = await readExifFromBytes(bytes);

      // 포맷팅된 EXIF 데이터 추출
      Map<String, dynamic> exifMetadata = _parseExifMetadata(exifRawData);
      GeoPoint? location = _convertGpsToGeoPoint(exifRawData);
      File compressedFile = await _compressImage(_pickedImageFile!);

      _preparedData = UploadData(
        compressedFile: compressedFile,
        caption: caption,
        exifData: exifMetadata,
        location: location,
        originalFileForPreview: _pickedImageFile!,
      );

      setState(ViewState.Idle);
      return true;

    } catch (e) {
      _errorMessage = e.toString();
      setState(ViewState.Error);
      return false;
    }
  }

  // 수동으로 위치 업데이트
  void updateLocation(GeoPoint newLocation) {
    if (_preparedData != null) {
      _preparedData = _preparedData!.copyWith(location: newLocation);
      notifyListeners();
    }
  }

  // 실제 업로드 실행
  Future<bool> executeUpload() async {
    if (_preparedData == null) {
      _errorMessage = "업로드할 데이터가 준비되지 않았습니다.";
      return false;
    }

    setState(ViewState.Loading);

    try {
      String? downloadUrl = await _uploadToStorage(_preparedData!.compressedFile);
      if (downloadUrl == null) throw Exception("파일 업로드 실패");

      await _saveToFirestore(
        caption: _preparedData!.caption,
        imageUrl: downloadUrl,
        exifData: _preparedData!.exifData,
        location: _preparedData!.location,
      );

      setState(ViewState.Idle);
      return true;

    } catch (e) {
      _errorMessage = e.toString();
      setState(ViewState.Error);
      return false;
    } finally {
      _pickedImageFile = null;
      _preparedData = null;
    }
  }

  // --- Helper Methods ---

  // EXIF 파싱 및 포맷팅
  Map<String, dynamic> _parseExifMetadata(Map<String, IfdTag> data) {
    if (data.isEmpty) return {};

    // 원본 값 추출
    String apertureRaw = data['EXIF FNumber']?.toString() ?? 'N/A';
    String shutterRaw = data['EXIF ExposureTime']?.toString() ?? 'N/A';
    String isoRaw = data['EXIF ISOSpeedRatings']?.toString() ?? 'N/A';

    // 포맷팅
    int? isoNumber = int.tryParse(isoRaw);
    String shutterFormatted = _formatShutterSpeed(shutterRaw);
    String apertureFormatted = _formatAperture(apertureRaw);

    return {
      'Make': data['Image Make']?.toString(),
      'Model': data['Image Model']?.toString(),
      'Aperture': (apertureFormatted == 'N/A') ? null : apertureFormatted,
      'ShutterSpeed': (shutterFormatted == 'N/A') ? null : shutterFormatted,
      'ISO': isoNumber, // 정수형 저장
      'FocalLength': _formatFocalLength(data['EXIF FocalLength']?.toString() ?? 'N/A'),
    };
  }

  // GPS -> GeoPoint 변환
  GeoPoint? _convertGpsToGeoPoint(Map<String, IfdTag> data) {
    final latTag = data['GPS GPSLatitude'];
    final lonTag = data['GPS GPSLongitude'];
    final latRef = data['GPS GPSLatitudeRef']?.printable;
    final lonRef = data['GPS GPSLongitudeRef']?.printable;

    if (latTag == null || lonTag == null || latRef == null || lonRef == null) {
      return null;
    }

    try {
      List<Ratio> latRatios = latTag.values.toList().cast<Ratio>();
      double lat = latRatios[0].toDouble() + (latRatios[1].toDouble() / 60) + (latRatios[2].toDouble() / 3600);
      if (latRef == 'S') lat = -lat;

      List<Ratio> lonRatios = lonTag.values.toList().cast<Ratio>();
      double lon = lonRatios[0].toDouble() + (lonRatios[1].toDouble() / 60) + (lonRatios[2].toDouble() / 3600);
      if (lonRef == 'W') lon = -lon;

      if (lat == 0.0 && lon == 0.0) return null;

      return GeoPoint(lat, lon);
    } catch (e) {
      return null;
    }
  }

  // 이미지 압축
  Future<File> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(dir.absolute.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 1080,
      minHeight: 1080,
    );

    if (result == null) return file;
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

  // 해시태그 추출
  List<String> _extractHashtags(String caption) {
    RegExp exp = RegExp(r"\#\S+");
    Iterable<RegExpMatch> matches = exp.allMatches(caption);
    return matches.map((m) => m.group(0)!).toList();
  }

  // Firestore 저장
  Future<void> _saveToFirestore({
    required String caption,
    required String imageUrl,
    required Map<String, dynamic> exifData,
    required GeoPoint? location,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final List<String> tags = _extractHashtags(caption);

    await _firestore.collection('posts').add({
      'userId': user.uid,
      'imageUrl': imageUrl,
      'caption': caption,
      'exifData': exifData,
      'location': location,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
      'tags': tags,
    });
  }

  // --- 포맷팅 헬퍼 함수들 ---

  String _formatFocalLength(String text) {
    if (text == 'N/A' || text.isEmpty) return 'N/A';
    if (text.endsWith('mm')) return text;
    try {
      double value;
      if (text.contains('/')) {
        final parts = text.split('/');
        value = double.parse(parts[0]) / double.parse(parts[1]);
      } else {
        value = double.parse(text);
      }
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}mm';
    } catch (e) {
      return text;
    }
  }

  String _formatAperture(String text) {
    if (text == 'N/A' || text.isEmpty) return 'N/A';
    if (text.startsWith('f/')) return text;
    try {
      double value;
      if (text.contains('/')) {
        final parts = text.split('/');
        value = double.parse(parts[0]) / double.parse(parts[1]);
      } else {
        value = double.parse(text);
      }
      return 'f/${value.toStringAsFixed(1)}';
    } catch (e) {
      return text;
    }
  }

  String _formatShutterSpeed(String text) {
    if (text == 'N/A' || text.isEmpty) return 'N/A';
    if (text.endsWith('s')) return text;
    try {
      if (text.contains('/')) {
        final parts = text.split('/');
        double value = double.parse(parts[0]) / double.parse(parts[1]);
        if (value < 1.0) {
          return '1/${(1 / value).round()}s';
        } else {
          return '${value.toStringAsFixed(1)}s';
        }
      } else {
        double value = double.parse(text);
        return '${value.toStringAsFixed(1)}s';
      }
    } catch (e) {
      return '${text}s';
    }
  }
}