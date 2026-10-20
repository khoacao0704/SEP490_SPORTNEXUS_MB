import 'package:flutter/material.dart';
import '../../core/strings/facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo_utils.dart';
import '../../models/facility.dart';
import '../../models/facility_search.dart';
import '../../models/sport.dart';
import '../../theme/app_colors.dart';
import 'sport_icon.dart';

/// "Cầu Lông • 3 sân"; chưa biết số sân của môn (kết quả tìm kiếm của BE chỉ có tổng số sân) thì chỉ ghi tên môn.
String _sportTooltip(Facility facility, Sport sport) {
  final courts = facility.offeringsFor(sport).fold(0, (n, o) => n + o.courtCount);
  return courts == 0 ? sport.label : '${sport.label} • ${FacilityStrings.courtCount(courts)}';
}

/// Ảnh mạng có nền và icon dự phòng khi tải lỗi / không có mạng.
class FacilityImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;

  const FacilityImage({super.key, required this.url, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.lightGreen,
      alignment: Alignment.center,
      child: const Icon(Icons.sports, color: AppColors.primaryGreen, size: 32),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
    );
  }
}

class FacilityCard extends StatelessWidget {
  final FacilitySearchResult result;

  /// Môn đang lọc: hiển thị giá và số sân của môn đó thay vì giá thấp nhất toàn cơ sở.
  final Sport? sport;
  final VoidCallback onTap;

  const FacilityCard({super.key, required this.result, required this.onTap, this.sport});

  @override
  Widget build(BuildContext context) {
    final facility = result.facility;
    final offering = sport == null ? null : facility.offeringFor(sport!);
    final price = offering?.priceFrom ?? facility.priceFrom;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FacilityImage(
                  url: facility.imageUrls.isEmpty ? null : facility.imageUrls.first,
                  width: 96,
                  height: 96,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            facility.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                          ),
                        ),
                        if (facility.isPromoted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tagOrangeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              FacilityStrings.promoted,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${facility.rating} (${facility.reviewCount})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain),
                        ),
                        if (result.distanceKm != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.near_me, size: 13, color: AppColors.primaryGreen),
                          const SizedBox(width: 2),
                          Text(
                            GeoUtils.formatDistance(result.distanceKm!),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      facility.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...facility.sports.map((s) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Tooltip(
                                message: _sportTooltip(facility, s),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: s == sport ? AppColors.primaryGreen : AppColors.lightGreen,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    sportIcon(s),
                                    size: 14,
                                    color: s == sport ? Colors.white : AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            )),
                        const Spacer(),
                        Text(
                          FacilityStrings.priceFrom(Formatters.vnd(price)),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
