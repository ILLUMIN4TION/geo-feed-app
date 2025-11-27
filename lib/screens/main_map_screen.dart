import 'package:flutter/material.dart';
import 'package:geofeed/models/post.dart';
import 'package:geofeed/providers/post_provider.dart';
import 'package:geofeed/screens/post_detail_screen.dart';
import 'package:geofeed/utils/view_state.dart';
import 'package:geofeed/widgets/map_post_preview.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 12.0,
  );

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateMarkers();
  }

  void _updateMarkers() {
    final posts = context.read<PostProvider>().posts;
    setState(() {
      _markers = _createMarkers(context, posts);
    });
  }

  Set<Marker> _createMarkers(BuildContext context, List<Post> posts) {
    return posts.where((post) => post.location != null).map((post) {
      return Marker(
        markerId: MarkerId(post.id),
        position: LatLng(
          post.location!.latitude,
          post.location!.longitude,
        ),

        onTap: () async {
          final selectedPost = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => MapPostPreview(post: post),
          );

          if (!context.mounted) return;

          if (selectedPost != null && selectedPost is Post) {
            // 변경점: push를 await하여 결과를 받아옴
            final detailResult = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(post: selectedPost),
              ),
            );

            // 상세 화면에서 돌아왔을 때 바텀시트를 다시 열어준다
            if (detailResult != null &&
                detailResult is Map &&
                detailResult["reopenSheet"] == true) {
              // 바텀시트 다시 열기
              Future.delayed(Duration(milliseconds: 100), () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => MapPostPreview(post: post),

                );
              });
            }
          }
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final postProvider = context.watch<PostProvider>();

    if (postProvider.state == ViewState.Loading &&
        postProvider.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    _markers = _createMarkers(context, postProvider.posts);

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("포토스팟 지도"),
      // ),
      body: GoogleMap(
        initialCameraPosition: _initialCameraPosition,
        onMapCreated: _onMapCreated,
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
      ),
    );
  }
}