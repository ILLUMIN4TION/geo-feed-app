
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
import 'package:permission_handler/permission_handler.dart'; // 1. permission_handler 임포트

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

  // (수정) 작업 1-A: UploadScreen에서 이미지 선택
  Future<void> pickImageForPreview() async {
    // 1. (수정) '위치'와 '미디어 위치' 권한을 모두 요청
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.accessMediaLocation, // 필수
    ].request();

    // 2. 두 권한이 모두 승인되었는지 확인 (특히 accessMediaLocation)<- 없으면 사진에서 GPS 데이터를 가져올 수가 없음!!!!
    if (statuses[Permission.location] == PermissionStatus.granted &&
        statuses[Permission.accessMediaLocation] == PermissionStatus.granted) {
      
      // 3. 권한이 승인되었을 때만 이미지 선택 진행
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        _pickedImageFile = File(pickedFile.path);
        notifyListeners(); 
      }
    } else {
      // 4. (신규) 권한이 하나라도 거부되었을 때
      _errorMessage = "사진의 위치(GPS) 정보를 읽어오기 위한 권한이 필요합니다.";
      // TODO: 사용자에게 "권한이 거부되었습니다. 설정에서 허용해주세요." 알림 띄우기
      // openAppSettings(); // (선택) 앱 설정 화면으로 바로 보내기
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

  // --- Helper Methods (에러 해결 부분) ---

  // --- (수정) Helper 1: 촬영 설정(EXIF) 파싱 및 포맷팅 ---
  Map<String, dynamic> _parseExifMetadata(Map<String, IfdTag> data) {
    if (data.isEmpty) return {};

    // 1. 원본 String 값 추출
    String apertureRaw = data['EXIF FNumber']?.toString() ?? 'N/A';
    String shutterRaw = data['EXIF ExposureTime']?.toString() ?? 'N/A';
    String isoRaw = data['EXIF ISOSpeedRatings']?.toString() ?? 'N/A';

    // 2. (신규) Firestore에 저장할 값으로 포맷팅
    int? isoNumber = int.tryParse(isoRaw); // "50" -> 50
    String shutterFormatted = _formatShutterSpeed(shutterRaw);
    String apertureFormatted = _formatAperture(apertureRaw);

    return {
      'Make': data['Image Make']?.toString(),
      'Model': data['Image Model']?.toString(),

      // (수정) 포맷팅된 값 저장
      'Aperture': (apertureFormatted == 'N/A') ? null : apertureFormatted,
      'ShutterSpeed': (shutterFormatted == 'N/A') ? null : shutterFormatted,

      // (수정) ISO를 String이 아닌 Number(int)로 저장
      'ISO': isoNumber, // "250"이 아닌 250으로 저장됨 (null일 수도 있음)

      // (수정) FocalLength도 "mm"를 붙여서 저장
      'FocalLength': _formatFocalLength(data['EXIF FocalLength']?.toString() ?? 'N/A'),
    };
  }

  // 포매팅을 위한 헬퍼 함수들 위의 _parseExifdata에 사용함

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
    if (text.startsWith('f/')) return text; //f/처럼 처음부터 명확한 조리개 값이 들어올 경우에는 바로 return합니다

    try {
      double value;
      if (text.contains('/')) { //text에 값에 /가 포함되어있으면
        final parts = text.split('/'); // '/'를 기준으로 나누고 parts에 저장합니다.
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
  
  Future<String?> _uploadToStorage(File file) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final ref = _storage.ref('uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    UploadTask task = ref.putFile(file);
    TaskSnapshot snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  // 11. 해시태그 추출 헬퍼 함수
  List<String> _extractHashtags(String caption) {
    // 정규식: # 뒤에 공백이 아닌 문자가 1개 이상 오는 것들 찾기
    RegExp exp = RegExp(r"\#\S+");
    Iterable<RegExpMatch> matches = exp.allMatches(caption);

    // '#태그' -> '태그' (샵 제거 후 저장하려면 substring(1) 사용, 여기선 # 포함해서 저장)
    return matches.map((m) => m.group(0)!).toList();
  }

  // 12. Firestore 저장
  Future<void> _saveToFirestore({
    required String caption,
    required String imageUrl,
    required Map<String, dynamic> exifData,
    required GeoPoint? location,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 2. 캡션에서 태그 추출
    final List<String> tags = _extractHashtags(caption);

    await _firestore.collection('posts').add({
      'userId': user.uid,
      'imageUrl': imageUrl,
      'caption': caption,
      'exifData': exifData,
      'location': location,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
      'tags': tags, // 3. 태그 리스트 저장
    });
  }




}