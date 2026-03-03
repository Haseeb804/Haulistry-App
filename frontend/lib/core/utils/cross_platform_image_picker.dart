import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Cross-platform image data that works on Web, iOS, and Android
class CrossPlatformImage {
  final Uint8List bytes;
  final String? path;
  final String name;

  CrossPlatformImage({
    required this.bytes,
    this.path,
    required this.name,
  });
}

/// Cross-platform image picker utility
class CrossPlatformImagePicker {
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery
  static Future<CrossPlatformImage?> pickFromGallery({
    int maxWidth = 1920,
    int maxHeight = 1080,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        return CrossPlatformImage(
          bytes: bytes,
          path: kIsWeb ? null : image.path,
          name: image.name,
        );
      }
    } catch (e) {
    }
    return null;
  }

  /// Take a photo with camera
  static Future<CrossPlatformImage?> takePhoto({
    int maxWidth = 1920,
    int maxHeight = 1080,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        return CrossPlatformImage(
          bytes: bytes,
          path: kIsWeb ? null : image.path,
          name: image.name,
        );
      }
    } catch (e) {
    }
    return null;
  }

  /// Show image source dialog and pick image
  static Future<CrossPlatformImage?> showPickerDialog(BuildContext context) async {
    CrossPlatformImage? result;
    
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.blue),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  result = await pickFromGallery();
                },
              ),
              if (!kIsWeb) // Camera not fully supported on Web
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.green),
                  ),
                  title: const Text('Take a Photo'),
                  subtitle: const Text('Use your camera'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    result = await takePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );

    // Wait a bit for the modal to close and pick action to complete
    await Future.delayed(const Duration(milliseconds: 100));
    return result;
  }
}

/// Widget to display CrossPlatformImage
class CrossPlatformImageWidget extends StatelessWidget {
  final CrossPlatformImage image;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const CrossPlatformImageWidget({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.memory(
      image.bytes,
      fit: fit,
      width: width,
      height: height,
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Widget for displaying profile image with fallback
class CrossPlatformProfileImage extends StatelessWidget {
  final CrossPlatformImage? localImage;
  final String? networkUrl;
  final String fallbackText;
  final double radius;
  final Color backgroundColor;
  final TextStyle? fallbackTextStyle;

  const CrossPlatformProfileImage({
    super.key,
    this.localImage,
    this.networkUrl,
    required this.fallbackText,
    this.radius = 60,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.fallbackTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    
    if (localImage != null) {
      imageProvider = MemoryImage(localImage!.bytes);
    } else if (networkUrl != null && networkUrl!.isNotEmpty) {
      imageProvider = NetworkImage(networkUrl!);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
              style: fallbackTextStyle ??
                  TextStyle(
                    fontSize: radius * 0.8,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
            )
          : null,
    );
  }
}
