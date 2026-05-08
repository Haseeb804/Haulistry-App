import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Utility helpers for displaying user profile images that may be stored
/// either as HTTP URLs or base64 data URIs (data:image/jpeg;base64,...).
class ImageHelper {
  ImageHelper._();

  /// Returns the correct [ImageProvider] for a given image string.
  /// Handles both HTTP/HTTPS URLs and base64 data URIs.
  static ImageProvider? providerFor(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str = imageUrl.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(imageUrl);
  }

  /// Returns a [Widget] that renders a profile image (circular clip).
  /// Falls back to an initial letter [fallback] widget when no image is set.
  static Widget profileAvatar({
    required String? imageUrl,
    required double radius,
    required Widget fallback,
  }) {
    final provider = providerFor(imageUrl);
    if (provider != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: provider,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: fallback,
    );
  }

  /// Safely decode a base64 image string or data-URI to raw bytes.
  /// Returns null when the input is empty or cannot be decoded.
  static Uint8List? safeDecodeBytes(String? imageData) {
    if (imageData == null || imageData.isEmpty) return null;
    try {
      final b64 = imageData.contains(',') ? imageData.split(',').last : imageData;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// Builds an image widget from a URL or base64 string, sized to [width] x [height].
  static Widget imageWidget({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str = imageUrl.split(',').last;
        return Image.memory(
          base64Decode(base64Str),
          width: width,
          height: height,
          fit: fit,
        );
      } catch (_) {
        return SizedBox(width: width, height: height);
      }
    }
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
