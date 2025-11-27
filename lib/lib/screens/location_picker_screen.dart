// lib/screens/location_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // 초기 위치 (서울 시청)
  LatLng _pickedLocation = const LatLng(37.5665, 126.9780);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("위치 선택"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // 선택한 위치를 되돌려줌
              Navigator.of(context).pop(_pickedLocation);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation,
              zoom: 15,
            ),
            // (핵심) 카메라가 움직일 때마다 중앙 좌표를 저장
            onCameraMove: (position) {
              _pickedLocation = position.target;
            },
            myLocationEnabled: true, // 내 위치 버튼
            myLocationButtonEnabled: true,
          ),

          // 화면 중앙에 고정된 핀 아이콘
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 30.0), // 핀의 끝이 중앙에 오도록 조정
              child: Icon(
                Icons.location_on,
                size: 50,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pop(_pickedLocation);
        },
        label: const Text("이 위치로 설정"),
        icon: const Icon(Icons.check),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}