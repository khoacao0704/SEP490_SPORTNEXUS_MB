import 'package:flutter/material.dart';

/// Icon của tiện ích theo iconCode của BE; mã lạ / không có thì dùng dấu tích chung.
IconData amenityIcon(String? iconCode) => switch (iconCode) {
      'parking' => Icons.local_parking,
      'equipment' => Icons.sports_tennis,
      'canteen' => Icons.restaurant,
      'air_conditioner' => Icons.ac_unit,
      'water' => Icons.water_drop_outlined,
      'shower' => Icons.shower_outlined,
      'wifi' => Icons.wifi,
      'light' => Icons.lightbulb_outline,
      _ => Icons.check_circle,
    };
