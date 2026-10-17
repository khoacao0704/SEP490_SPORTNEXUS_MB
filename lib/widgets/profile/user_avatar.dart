import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../theme/app_colors.dart';

/// Ảnh đại diện tròn: ảnh trên mạng (Cloudinary) hoặc ảnh trong máy (bản giả lập);
/// chưa có ảnh hoặc ảnh lỗi thì hiện chữ cái đầu của tên.
class UserAvatar extends StatelessWidget {
  final AppUser user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 36});

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    final initial = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryGreen,
      child: Text(
        user.initial,
        style: TextStyle(color: Colors.white, fontSize: radius * 0.9, fontWeight: FontWeight.bold),
      ),
    );
    if (url == null) return initial;

    final size = radius * 2;
    Widget fallback(BuildContext _, Object _, StackTrace? _) => initial;
    return ClipOval(
      child: url.startsWith('http')
          ? Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: fallback)
          : Image.file(File(url), width: size, height: size, fit: BoxFit.cover, errorBuilder: fallback),
    );
  }
}
