import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String imageUrl;
  final String caption;
  final GeoPoint location; // 기존 GeoPoint 유지
  final Timestamp timestamp;
  final List<String> likes;
  final List<String> tags;
  final Map<String, dynamic> exifData; // 문자열 데이터 (예: "1/125s", "f/2.8")

  Post({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.caption,
    required this.location,
    required this.timestamp,
    required this.exifData,
    required this.likes,
    required this.tags,
  });

  // [신규] exifData의 문자열 값을 파싱하여 숫자형으로 반환하는 Getter들

  // 1. 셔터스피드 (예: "1/125s" -> 0.008)
  double? get shutterSpeedValue {
    final text = exifData['ShutterSpeed']?.toString();
    if (text == null || text == 'N/A') return null;
    try {
      // "1/125s"에서 's' 제거
      String cleanText = text.replaceAll('s', '');

      // "2269383/1000000000" 형태 처리 (분수 계산)
      if (cleanText.contains('/')) {
        final parts = cleanText.split('/');
        return double.parse(parts[0]) / double.parse(parts[1]);
      }
      // 그냥 실수 형태 처리
      return double.tryParse(cleanText);
    } catch (e) {
      return null;
    }
  }

  // [화면 표시용] 깔끔하게 포맷팅된 셔터스피드 Getter
  // 예: "2269383/1000000000" -> "1/440s"
  // 예: "0.008" -> "1/125s"
  String get formattedShutterSpeed {
    final val = shutterSpeedValue; // 위에서 계산한 숫자 값 활용
    if (val == null) return 'N/A';

    if (val < 1.0) {
      // 1초 미만인 경우 역수를 취해서 분모를 구함 (예: 0.008 -> 125)
      final denominator = (1 / val).round();
      return '1/${denominator}s';
    } else {
      // 1초 이상인 경우 소수점 1자리까지 표시
      return '${val.toStringAsFixed(1)}s';
    }
  }

  // 2. 조리개 (예: "f/2.8" -> 2.8)
  double? get apertureValue {
    final text = exifData['Aperture']?.toString();
    if (text == null || text == 'N/A') return null;
    try {
      // "f/2.8"에서 숫자만 추출
      return double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (e) {
      return null;
    }
  }

  // 3. ISO (예: 100 -> 100)
  int? get isoValue {
    final val = exifData['ISO'];
    if (val is int) return val;
    if (val is String) return int.tryParse(val);
    return null;
  }

  // 4. 초점거리 (예: "24mm" -> 24.0)
  double? get focalLengthValue {
    final text = exifData['FocalLength']?.toString();
    if (text == null || text == 'N/A') return null;
    try {
      return double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (e) {
      return null;
    }
  }

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      caption: data['caption'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      timestamp: data['timestamp'] ?? Timestamp.now(),
      exifData: Map<String, dynamic>.from(data['exifData'] ?? {}),
      likes: List<String>.from(data['likes'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  // 불변 객체인 Post를 수정하기 위한 copyWith 메서드 추가 (좋아요 업데이트용)
  Post copyWith({
    String? id,
    String? userId,
    String? imageUrl,
    String? caption,
    GeoPoint? location,
    Timestamp? timestamp,
    List<String>? likes,
    List<String>? tags,
    Map<String, dynamic>? exifData,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      exifData: exifData ?? this.exifData,
      likes: likes ?? this.likes,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'caption': caption,
      'location': location,
      'timestamp': timestamp,
      'exifData': exifData,
      'likes': likes,
      'tags': tags,
    };
  }
}