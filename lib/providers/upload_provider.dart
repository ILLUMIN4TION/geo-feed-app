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

  // 1. 앱이 죽었을 때를 대비한 보험 (그대로 유지)
  Future<void> checkLostData() async {
    if (Platform.isAndroid) {
      try {
        final LostDataResponse response = await _picker.retrieveLostData();
        if (response.isEmpty) return;
        if (response.file != null) {
          _pickedImageFile = File(response.file!.path);
          notifyListeners();
        } 
      } catch (e) {
        print("Lost data retrieval failed: $e");
      }
    }
  }

  // 2. 이미지 선택 (옵션 모두 제거하여 예전처럼 가볍게)
  Future<void> pickImageForPreview({required ImageSource source}) async {
    try {
      var locationStatus = await Permission.location.request();
      
      if (source == ImageSource.gallery && Platform.isAndroid) {
         await Permission.accessMediaLocation.request();
      }

      if (locationStatus.isGranted) {
        // ★★★ [수정됨] 모든 옵션 제거 (예전 코드로 회귀) ★★★
        // requestFullMetadata: true <-- 이거 때문에 S24에서 메모리 터짐
        // maxWidth/Height <-- 이것도 제거 (가져오는 건 원본 그대로)
        final XFile? pickedFile = await _picker.pickImage(
            source: source
        );

        if (pickedFile != null) {
          _pickedImageFile = File(pickedFile.path);
          notifyListeners();
        }
      } else {
        _errorMessage = "위치 권한이 거부되었습니다.";
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = "이미지 선택 중 오류: $e";
      notifyListeners();
    }
  }

  Future<bool> prepareUploadData({required String caption}) async {
    if (_pickedImageFile == null) {
      _errorMessage = "이미지가 선택되지 않았습니다.";
      return false;
    }

    setState(ViewState.Loading);

    try {
      final bytes = await _pickedImageFile!.readAsBytes();
      final exifRawData = await readExifFromBytes(bytes);

      Map<String, dynamic> exifMetadata = _parseExifMetadata(exifRawData);
      GeoPoint? location = _convertGpsToGeoPoint(exifRawData);
      
      // 압축 수행
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
      _errorMessage = "데이터 준비 실패: $e";
      setState(ViewState.Error);
      return false;
    }
  }

  void updateLocation(GeoPoint newLocation) {
    if (_preparedData != null) {
      _preparedData = _preparedData!.copyWith(location: newLocation);
      notifyListeners();
    }
  }

  Future<bool> executeUpload() async {
    if (_preparedData == null) {
      _errorMessage = "업로드할 데이터가 준비되지 않았습니다.";
      return false;
    }

    setState(ViewState.Loading);

    try {
      final uploadResults = await _uploadBothVersions(_preparedData!.compressedFile);
      
      if (uploadResults['original'] == null) {
        throw Exception("파일 업로드 실패");
      }

      await _saveToFirestore(
        caption: _preparedData!.caption,
        imageUrl: uploadResults['original']!,
        thumbnailUrl: uploadResults['thumbnail'],
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

  // ★ [최적화 1] 원본 업로드용 압축 (WebP 적용)
  Future<File> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    // 확장자를 .webp로 변경
    final targetPath = p.join(dir.absolute.path, "${DateTime.now().millisecondsSinceEpoch}.webp");

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,      // 원본은 화질 유지
      minWidth: 1080,   
      minHeight: 1080,
      format: CompressFormat.webp, // ★ 포맷 변경 (JPG -> WebP)
    );

    if (result == null) return file;
    return File(result.path);
  }

  // ★ [최적화 2] 썸네일 생성 (WebP + 과감한 리사이징)
  Future<File> _createThumbnail(File file) async {
    final dir = await getTemporaryDirectory();
    // 확장자를 .webp로 변경
    final targetPath = p.join(
      dir.absolute.path,
      "thumb_${DateTime.now().millisecondsSinceEpoch}.webp",
    );

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 50,      // ★ 품질을 70 -> 50으로 낮춤 (작은 이미지라 티 안남)
      minWidth: 300,    // ★ 크기를 800 -> 300으로 대폭 축소 (갤러리/마커용으로 충분)
      minHeight: 300,
      format: CompressFormat.webp, // ★ 포맷 변경
    );

    if (result == null) return file;
    return File(result.path);
  }

  // ★ [최적화 3] 업로드 시 확장자 및 메타데이터 설정
  Future<Map<String, String?>> _uploadBothVersions(File file) async {
    final user = _auth.currentUser;
    if (user == null) return {'original': null, 'thumbnail': null};

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final thumbnailFile = await _createThumbnail(file);
    
    // 파일명 뒤에 .webp 붙이기
    final results = await Future.wait([
      _uploadSingleFile(file, 'uploads/${user.uid}/${timestamp}_original.webp'),
      _uploadSingleFile(thumbnailFile, 'uploads/${user.uid}/${timestamp}_thumb.webp'),
    ]);

    try {
      await thumbnailFile.delete();
    } catch (e) {
      // 무시
    }

    return {
      'original': results[0],
      'thumbnail': results[1],
    };
  }

  

  Future<String?> _uploadSingleFile(File file, String path) async {
    try {
      final ref = _storage.ref(path);
      UploadTask task = ref.putFile(file);
      TaskSnapshot snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Upload error for $path: $e");
      return null;
    }
  }

  Map<String, dynamic> _parseExifMetadata(Map<String, IfdTag> data) {
    if (data.isEmpty) return {};

    String apertureRaw = data['EXIF FNumber']?.toString() ?? 'N/A';
    String shutterRaw = data['EXIF ExposureTime']?.toString() ?? 'N/A';
    String isoRaw = data['EXIF ISOSpeedRatings']?.toString() ?? 'N/A';

    int? isoNumber = int.tryParse(isoRaw);
    String shutterFormatted = _formatShutterSpeed(shutterRaw);
    String apertureFormatted = _formatAperture(apertureRaw);

    return {
      'Make': data['Image Make']?.toString(),
      'Model': data['Image Model']?.toString(),
      'Aperture': (apertureFormatted == 'N/A') ? null : apertureFormatted,
      'ShutterSpeed': (shutterFormatted == 'N/A') ? null : shutterFormatted,
      'ISO': isoNumber,
      'FocalLength': _formatFocalLength(data['EXIF FocalLength']?.toString() ?? 'N/A'),
    };
  }

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
      double lat = 0.0;
      if (latRatios.length == 3) {
         lat = latRatios[0].toDouble() + (latRatios[1].toDouble() / 60) + (latRatios[2].toDouble() / 3600);
      } else if (latRatios.isNotEmpty) {
         lat = latRatios[0].toDouble();
      }
      if (latRef == 'S') lat = -lat;

      List<Ratio> lonRatios = lonTag.values.toList().cast<Ratio>();
      double lon = 0.0;
      if (lonRatios.length == 3) {
         lon = lonRatios[0].toDouble() + (lonRatios[1].toDouble() / 60) + (lonRatios[2].toDouble() / 3600);
      } else if (lonRatios.isNotEmpty) {
         lon = lonRatios[0].toDouble();
      }
      if (lonRef == 'W') lon = -lon;

      if (lat == 0.0 && lon == 0.0) return null;

      return GeoPoint(lat, lon);
    } catch (e) {
      return null;
    }
  }

  

  List<String> _extractHashtags(String caption) {
    RegExp exp = RegExp(r"\#\S+");
    Iterable<RegExpMatch> matches = exp.allMatches(caption);
    return matches.map((m) => m.group(0)!).toList();
  }

  Future<void> _saveToFirestore({
    required String caption,
    required String imageUrl,
    String? thumbnailUrl,
    required Map<String, dynamic> exifData,
    required GeoPoint? location,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final List<String> tags = _extractHashtags(caption);

    await _firestore.collection('posts').add({
      'userId': user.uid,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'exifData': exifData,
      'location': location,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
      'tags': tags,
    });
  }

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