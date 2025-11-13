// lib/widgets/location_text.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

class LocationText extends StatefulWidget {
  final GeoPoint location;
  const LocationText({super.key, required this.location});

  @override
  State<LocationText> createState() => _LocationTextState();
}

class _LocationTextState extends State<LocationText> {
  late Future<String> _addressFuture;

  @override
  void initState() {
    super.initState();
    _addressFuture = _getAddressFromGeoPoint(widget.location);
  }

  // (수정) v2 문법 사용
  Future<String> _getAddressFromGeoPoint(GeoPoint geoPoint) async {
    try {
      // 1. (신규) 앱 전역 로케일을 먼저 설정
      await setLocaleIdentifier("ko_KR"); 

      // 2. (수정) localeIdentifier 파라미터 없이 호출
      List<Placemark> placemarks = await placemarkFromCoordinates(
        geoPoint.latitude,
        geoPoint.longitude,
        // localeIdentifier: "ko_KR", // <- 이 줄 삭제
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // ... (나머지 주소 조합 로직은 동일)
        if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) {
          return [p.locality, p.subLocality, p.thoroughfare, p.subThoroughfare]
              .where((s) => s != null && s.isNotEmpty).join(' ');
        }
        return [p.locality, p.subLocality]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
      }
      return "알 수 없는 위치";
    } catch (e) {
      print("Geocoding Error: $e");
      return "주소 변환 실패";
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _addressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("위치 확인 중...", style: TextStyle(fontSize: 12, color: Colors.grey));
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("위치 정보 없음", style: TextStyle(fontSize: 12, color: Colors.grey));
        }

        // 4. 성공: 변환된 한글 주소 표시
        return Text(
          snapshot.data!,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}