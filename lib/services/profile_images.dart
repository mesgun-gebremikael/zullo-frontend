import 'package:flutter/painting.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// The same cache key is used for prefetch, loading checks and display.
/// Decode previews at a bounded size instead of keeping full camera images.
class ProfileImages {
  static ImageProvider card(String url) =>
      ResizeImage(CachedNetworkImageProvider(url), width: 1080);
  static ImageProvider thumbnail(String url) =>
      ResizeImage(CachedNetworkImageProvider(url), width: 400);
  static ImageProvider avatar(String url) =>
      ResizeImage(CachedNetworkImageProvider(url), width: 160);
}
