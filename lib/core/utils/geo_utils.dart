import 'dart:math';

import '../../models/geo_point.dart';

class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusKm = 6371;

  /// Khoảng cách đường chim bay giữa 2 điểm (công thức Haversine), đơn vị km.
  static double distanceKm(GeoPoint a, GeoPoint b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = pow(sin(dLat / 2), 2) +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * pow(sin(dLng / 2), 2);
    return 2 * _earthRadiusKm * asin(sqrt(h));
  }

  /// 0.35 -> "350 m", 2.345 -> "2,3 km", 12.7 -> "13 km"
  static String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    return '${km.round()} km';
  }

  static double _rad(double deg) => deg * pi / 180;
}
