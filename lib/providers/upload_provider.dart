
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

  Future<void> pickImageForPreview() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _pickedImageFile = File(pickedFile.path);
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
  
  Map<String, dynamic> _parseExifMetadata(Map<String, IfdTag> data) {
    if (data.isEmpty) return {};
    return {
      'Make': data['Image Make']?.toString(),
      'Model': data['Image Model']?.toString(),
      'Aperture': data['EXIF FNumber']?.toString(),
      'ShutterSpeed': data['EXIF ExposureTime']?.toString(),
      'ISO': data['EXIF ISOSpeedRatings']?.toString(),
      'FocalLength': data['EXIF FocalLength']?.toString(),
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
  
  Future<void> _saveToFirestore({
    required String caption,
    required String imageUrl,
    required Map<String, dynamic> exifData,
    required GeoPoint? location,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('posts').add({
      'userId': user.uid,
      'imageUrl': imageUrl,
      'caption': caption,
      'exifData': exifData,
      'timestamp': FieldValue.serverTimestamp(),
      'location': location,
    });
  }
}