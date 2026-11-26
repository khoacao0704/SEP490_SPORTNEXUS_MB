import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/strings/owner_facility_strings.dart';
import '../../theme/app_colors.dart';

/// Ảnh từ URL (BE trả) hoặc đường dẫn trong máy (vừa chụp / chọn, chưa tải lên).
class OwnerImage extends StatelessWidget {
  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;

  const OwnerImage(this.source, {super.key, this.width, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext _, Object _, StackTrace? _) => Container(
      width: width,
      height: height,
      color: AppColors.lightGreen,
      child: const Icon(Icons.image_outlined, color: AppColors.primaryGreen),
    );
    return source.startsWith('http')
        ? Image.network(source, width: width, height: height, fit: fit, errorBuilder: fallback)
        : Image.file(File(source), width: width, height: height, fit: fit, errorBuilder: fallback);
  }
}

/// Chọn ảnh từ camera hoặc thư viện; trả về đường dẫn trong máy (rỗng nếu hủy / bị từ chối quyền).
Future<List<String>> pickPhotoPaths(BuildContext context, {bool multiple = true}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text(OwnerFacilityStrings.takePhoto),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text(OwnerFacilityStrings.fromGallery),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return const [];
  final picker = ImagePicker();
  try {
    final picked = source == ImageSource.camera || !multiple
        ? [?await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600)]
        : await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    return [for (final x in picked) x.path];
  } catch (_) {
    // Bị từ chối quyền camera / thư viện ảnh hoặc thiết bị không hỗ trợ.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(OwnerFacilityStrings.pickPhotoError), backgroundColor: Colors.red),
      );
    }
    return const [];
  }
}

