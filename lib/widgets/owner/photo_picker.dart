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

/// Lưới ảnh có nút thêm (chụp / thư viện) và xóa từng ảnh.
class PhotoPickerGrid extends StatelessWidget {
  final List<String> photos;
  final ValueChanged<List<String>> onChanged;
  final String? errorText;

  const PhotoPickerGrid({super.key, required this.photos, required this.onChanged, this.errorText});

  Future<void> _add(BuildContext context) async {
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
    if (source == null) return;
    final picker = ImagePicker();
    final List<XFile> picked;
    try {
      picked = source == ImageSource.camera
          ? [?await picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1600)]
          : await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    } catch (_) {
      // Bị từ chối quyền camera / thư viện ảnh hoặc thiết bị không hỗ trợ.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(OwnerFacilityStrings.pickPhotoError), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (picked.isNotEmpty) onChanged([...photos, ...picked.map((x) => x.path)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < photos.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: OwnerImage(photos[i], width: 88, height: 88),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () => onChanged([...photos]..removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _add(context),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: errorText != null ? Colors.red : AppColors.cardBorder),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: AppColors.primaryGreen),
                    SizedBox(height: 4),
                    Text(OwnerFacilityStrings.addPhoto, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}
