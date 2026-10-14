import '../../models/geo_point.dart';

class City {
  final String name;

  /// Tâm thành phố: dùng để căn bản đồ và chọn thành phố gần GPS nhất.
  final GeoPoint center;

  const City(this.name, this.center);
}

class VietnamCities {
  VietnamCities._();

  static const City hoChiMinh = City('Hồ Chí Minh', GeoPoint(10.7769, 106.7009));

  static const List<City> all = [
    hoChiMinh,
    City('Hà Nội', GeoPoint(21.0285, 105.8542)),
    City('Đà Nẵng', GeoPoint(16.0544, 108.2022)),
    City('Hải Phòng', GeoPoint(20.8449, 106.6881)),
    City('Cần Thơ', GeoPoint(10.0452, 105.7469)),
    City('Bình Dương', GeoPoint(10.9804, 106.6519)),
    City('Đồng Nai', GeoPoint(10.9574, 106.8429)),
    City('Bà Rịa - Vũng Tàu', GeoPoint(10.3460, 107.0843)),
    City('An Giang', GeoPoint(10.3759, 105.4185)),
    City('Bắc Ninh', GeoPoint(21.1861, 106.0763)),
  ];

  static City byName(String name) =>
      all.firstWhere((c) => c.name == name, orElse: () => hoChiMinh);
}
