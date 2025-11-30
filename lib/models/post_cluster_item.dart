import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart';
import 'package:geofeed/models/post.dart';



// cluster 하나에 들어갈 녀석들
class PostClusterItem with ClusterItem {
  final Post post;

  PostClusterItem(this.post);

  @override
  LatLng get location =>
      LatLng(post.location!.latitude, post.location!.longitude);
}
