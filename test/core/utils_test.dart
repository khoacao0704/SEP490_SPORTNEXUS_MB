import 'package:flutter_test/flutter_test.dart';
import 'package:test1/core/utils/formatters.dart';
import 'package:test1/core/utils/geo_utils.dart';
import 'package:test1/core/utils/text_utils.dart';
import 'package:test1/models/geo_point.dart';

void main() {
  group('GeoUtils', () {
    test('khoảng cách Q1 -> Q7 khoảng 3-4 km', () {
      const q1 = GeoPoint(10.7769, 106.7009);
      const q7 = GeoPoint(10.7530, 106.7290);
      final d = GeoUtils.distanceKm(q1, q7);
      expect(d, greaterThan(3));
      expect(d, lessThan(4.5));
    });

    test('cùng một điểm thì bằng 0', () {
      const p = GeoPoint(21.0285, 105.8542);
      expect(GeoUtils.distanceKm(p, p), 0);
    });

    test('định dạng khoảng cách', () {
      expect(GeoUtils.formatDistance(0.35), '350 m');
      expect(GeoUtils.formatDistance(2.345), '2,3 km');
      expect(GeoUtils.formatDistance(12.7), '13 km');
    });
  });

  group('TextUtils', () {
    test('bỏ dấu tiếng Việt và chữ hoa', () {
      expect(TextUtils.normalize('Thủ Đức'), 'thu duc');
      expect(TextUtils.normalize('ĐƯỜNG Nguyễn Thị Thập'), 'duong nguyen thi thap');
      expect(TextUtils.normalize('Sân Cầu Lông Kỳ Hòa'), 'san cau long ky hoa');
    });

    test('tìm kiếm không phân biệt dấu', () {
      expect(TextUtils.containsIgnoringDiacritics('Pickleball Thảo Điền', 'thao dien'), isTrue);
      expect(TextUtils.containsIgnoringDiacritics('Sân Chu Văn An', 'CHU VĂN'), isTrue);
      expect(TextUtils.containsIgnoringDiacritics('Sân Chu Văn An', 'ky hoa'), isFalse);
      expect(TextUtils.containsIgnoringDiacritics('Bất kỳ', '  '), isTrue);
    });
  });

  group('Formatters', () {
    test('tiền tệ', () {
      expect(Formatters.currency(1500000), '1.500.000');
      expect(Formatters.currency(900), '900');
      expect(Formatters.vnd(120000), '120.000 đ');
    });

    test('ngày giờ', () {
      final dt = DateTime(2026, 10, 14, 18, 5); // Thứ 4
      expect(Formatters.time(dt), '18:05');
      expect(Formatters.timeRange(dt, dt.add(const Duration(minutes: 90))), '18:05 - 19:35');
      expect(Formatters.weekdayDayMonth(dt), 'Thứ 4, 14/10');
      expect(Formatters.weekday(DateTime(2026, 10, 18)), 'CN');
    });
  });
}
