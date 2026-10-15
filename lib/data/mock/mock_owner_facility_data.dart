import '../../models/court_type.dart';
import '../../models/facility.dart';
import '../../models/geo_point.dart';
import '../../models/owner_facility.dart';
import '../../models/sport.dart';
import 'mock_facility_data.dart';

/// Cơ sở mẫu của Chủ sân demo: 2 cơ sở đã duyệt (có giá), 1 hồ sơ chờ duyệt, 1 hồ sơ bị từ chối.
class MockOwnerFacilityData {
  MockOwnerFacilityData._();

  static const String _licenseImage =
      'https://images.unsplash.com/photo-1586281380349-632531db7ed4?auto=format&fit=crop&q=80&w=800';

  static CourtPricing _pricing(int weekday, int peak, {int slot = 60, int weekendExtra = 20000}) => CourtPricing(
        slotMinutes: slot,
        peakStart: 17 * 60,
        peakEnd: 21 * 60,
        weekdayPrice: weekday,
        weekdayPeakPrice: peak,
        weekendPrice: weekday + weekendExtra,
        weekendPeakPrice: peak + weekendExtra,
      );

  static OwnerFacility _approved(
    Facility f,
    String license,
    Map<CourtType, CourtPricing> standardOrTyped, {
    Map<Sport, CourtPricing> bySport = const {},
    List<FacilityClosure> closures = const [],
    required DateTime submittedAt,
  }) =>
      OwnerFacility(
        id: f.id,
        status: ApprovalStatus.approved,
        profile: FacilityProfile(
          name: f.name,
          city: f.city,
          ward: f.district,
          address: f.address,
          location: f.location,
          licenseNumber: license,
          licenseImages: const [_licenseImage],
        ),
        operations: FacilityOperations(
          phone: f.phone,
          openMinutes: parseMinutes(f.openTime),
          closeMinutes: parseMinutes(f.closeTime),
          description: f.description,
          amenities: f.amenities,
          rules: f.rules,
          images: f.imageUrls,
        ),
        courts: [
          for (final o in f.offerings)
            CourtConfig(
              sport: o.sport,
              courtType: o.courtType,
              courtCount: o.courtCount,
              pricing: o.courtType.isStandard ? bySport[o.sport] : standardOrTyped[o.courtType],
            ),
        ],
        closures: closures,
        submittedAt: submittedAt,
        rating: f.rating,
        reviewCount: f.reviewCount,
      );

  static List<OwnerFacility> seed(DateTime now) {
    Facility byId(String id) => MockFacilityData.facilities.firstWhere((f) => f.id == id);
    final today = DateTime(now.year, now.month, now.day);

    return [
      _approved(
        byId('f-hcm-thientrieu'),
        '0312345678',
        const {},
        bySport: {
          Sport.badminton: _pricing(120000, 160000),
          Sport.pickleball: _pricing(150000, 200000),
        },
        submittedAt: today.subtract(const Duration(days: 120)),
      ),
      _approved(
        byId('f-hcm-hoalu'),
        '0319876543',
        {
          CourtType.football5: _pricing(500000, 700000, slot: 90, weekendExtra: 100000),
          CourtType.football7: _pricing(800000, 1100000, slot: 90, weekendExtra: 100000),
          CourtType.football11: _pricing(1800000, 2400000, slot: 120, weekendExtra: 200000),
          CourtType.basketballFull: _pricing(250000, 320000),
          // Nửa sân 3x3 vừa thêm, chưa cài giá.
        },
        closures: [
          FacilityClosure(
            id: 'cl-hoalu-1',
            sport: Sport.football,
            courtType: CourtType.football11,
            from: today.add(const Duration(days: 7)),
            to: today.add(const Duration(days: 9)),
            reason: 'Thay mặt cỏ sân 11 người',
          ),
        ],
        submittedAt: today.subtract(const Duration(days: 90)),
      ),
      OwnerFacility(
        id: 'f-own-pending',
        status: ApprovalStatus.pending,
        profile: const FacilityProfile(
          name: 'Pickleball Bình Thạnh',
          city: 'Hồ Chí Minh',
          ward: 'Phường Thạnh Mỹ Tây',
          address: '120 Xô Viết Nghệ Tĩnh',
          location: GeoPoint(10.8040, 106.7120),
          licenseNumber: '0315556677',
          licenseImages: [_licenseImage],
        ),
        operations: const FacilityOperations(
          phone: '0909 555 666',
          openMinutes: 6 * 60,
          closeMinutes: 22 * 60,
          description: 'Cụm 4 sân pickleball có mái che.',
          images: [
            'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?auto=format&fit=crop&q=80&w=1000',
          ],
        ),
        courts: const [CourtConfig(sport: Sport.pickleball, courtCount: 4)],
        submittedAt: today.subtract(const Duration(days: 1)),
      ),
      OwnerFacility(
        id: 'f-own-rejected',
        status: ApprovalStatus.rejected,
        profile: const FacilityProfile(
          name: 'Sân Cầu Lông Tân Bình',
          city: 'Hồ Chí Minh',
          ward: 'Phường Tân Sơn Hòa',
          address: '45 Hoàng Văn Thụ',
          location: GeoPoint(10.8000, 106.6650),
          licenseNumber: '03199',
          licenseImages: [_licenseImage],
        ),
        operations: const FacilityOperations(
          phone: '0909 777 888',
          openMinutes: 5 * 60,
          closeMinutes: 22 * 60,
          images: [
            'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&q=80&w=1000',
          ],
        ),
        courts: const [CourtConfig(sport: Sport.badminton, courtCount: 5)],
        submittedAt: today.subtract(const Duration(days: 5)),
        rejectReason: 'Ảnh giấy phép bị mờ và số giấy phép không khớp với ảnh. Vui lòng chụp lại rõ nét.',
      ),
    ];
  }
}
