import 'package:geolocator/geolocator.dart';

import '../../models/geo_point.dart';

enum LocationStatus {
  granted,

  /// Người dùng từ chối quyền (còn có thể hỏi lại).
  denied,

  /// Người dùng từ chối vĩnh viễn: phải mở Cài đặt để cấp quyền.
  deniedForever,

  /// GPS của thiết bị đang tắt.
  serviceDisabled,

  /// Không lấy được vị trí (hết thời gian chờ, lỗi thiết bị...).
  unavailable,
}

class LocationResult {
  final LocationStatus status;
  final GeoPoint? point;

  const LocationResult(this.status, [this.point]);

  bool get hasLocation => point != null;
}

/// Lấy vị trí GPS của người dùng, tự xin quyền nếu cần.
class LocationService {
  const LocationService();

  /// Giới hạn cho các bước hệ thống tự chạy, để màn hình không bị treo ở trạng thái "đang định vị".
  /// Bước hỏi quyền chờ người dùng trả lời nên không giới hạn.
  static const Duration _systemCallTimeout = Duration(seconds: 5);
  static const Duration _positionTimeout = Duration(seconds: 12);

  Future<LocationResult> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled().timeout(_systemCallTimeout)) {
        return const LocationResult(LocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission().timeout(_systemCallTimeout);
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationStatus.denied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(_positionTimeout);
      return LocationResult(LocationStatus.granted, GeoPoint(position.latitude, position.longitude));
    } catch (_) {
      return const LocationResult(LocationStatus.unavailable);
    }
  }

  /// Mở Cài đặt ứng dụng (khi quyền bị từ chối vĩnh viễn) hoặc Cài đặt vị trí (khi GPS tắt).
  Future<void> openSettings(LocationStatus status) async {
    if (status == LocationStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
