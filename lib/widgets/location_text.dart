import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geofeed/utils/theme.dart';

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
    _loadAddress();
  }

  // 데이터 로드 로직 분리
  void _loadAddress() {
    _addressFuture = _getAddressFromGeoPoint(widget.location);
  }

  // (핵심) 좌표가 바뀌면 주소 다시 변환
  @override
  void didUpdateWidget(covariant LocationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.latitude != widget.location.latitude ||
        oldWidget.location.longitude != widget.location.longitude) {
      _loadAddress();
    }
  }

  Future<String> _getAddressFromGeoPoint(GeoPoint geoPoint) async {
    try {
      // v2 방식: 전역 로케일 설정 (한글 주소 강제)
      await setLocaleIdentifier("ko_KR");

      List<Placemark> placemarks = await placemarkFromCoordinates(
        geoPoint.latitude,
        geoPoint.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        // 도로명 주소 우선 표시
        if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) {
          return [
            p.locality,
            p.subLocality,
            p.thoroughfare,
            p.subThoroughfare
          ].where((s) => s != null && s.isNotEmpty).join(' ');
        }

        // 없으면 시/구 표시
        return [p.locality, p.subLocality]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
      }
      return "알 수 없는 위치";
    } catch (e) {
      return "주소 변환 실패";
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _addressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 8, height: 8,
                child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textHint)),
              ),
              const SizedBox(width: 4),
              Text("위치 확인 중...", style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
            ],
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Text("위치 정보 없음", style: TextStyle(fontSize: 12, color: AppTheme.textHint));
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded, size: 12, color: AppTheme.primaryColor),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                snapshot.data!,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.85)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}