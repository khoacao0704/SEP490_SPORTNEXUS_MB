import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/strings/facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/facility.dart';
import '../../models/geo_point.dart';
import '../../theme/app_colors.dart';

// Toàn bộ phần phụ thuộc flutter_map nằm trong file này.
// Muốn đổi sang Google Maps chỉ cần viết lại các widget ở đây.

const String _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String _userAgentPackage = 'com.example.test1';

LatLng _toLatLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

TileLayer _osmTileLayer() => TileLayer(urlTemplate: _osmTileUrl, userAgentPackageName: _userAgentPackage);

/// Ghi công OpenStreetMap (bắt buộc theo giấy phép OSM).
/// Tự viết thay cho SimpleAttributionWidget vì widget đó bị tràn khi bản đồ hẹp hoặc cỡ chữ lớn.
Widget _osmAttribution() => Align(
      alignment: Alignment.bottomRight,
      child: Container(
        color: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: const Text(
          '© OpenStreetMap contributors',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: Colors.black87),
        ),
      ),
    );

/// Bản đồ các cơ sở: mỗi cơ sở là một nhãn giá; nhãn đang chọn đổi màu.
class FacilityMap extends StatefulWidget {
  final List<Facility> facilities;

  /// Giá hiển thị trên nhãn (theo môn đang lọc nếu có).
  final int Function(Facility facility) priceOf;
  final GeoPoint initialCenter;
  final GeoPoint? userLocation;
  final String? selectedFacilityId;
  final ValueChanged<Facility> onFacilityTap;
  final VoidCallback? onMapTap;

  const FacilityMap({
    super.key,
    required this.facilities,
    required this.priceOf,
    required this.initialCenter,
    required this.onFacilityTap,
    this.userLocation,
    this.selectedFacilityId,
    this.onMapTap,
  });

  @override
  State<FacilityMap> createState() => _FacilityMapState();
}

class _FacilityMapState extends State<FacilityMap> {
  final MapController _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recenterOnUser() {
    final user = widget.userLocation;
    if (user != null) _controller.move(_toLatLng(user), 14);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _toLatLng(widget.initialCenter),
            initialZoom: 12.5,
            onTap: (_, _) => widget.onMapTap?.call(),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            _osmTileLayer(),
            MarkerLayer(
              markers: [
                if (widget.userLocation != null)
                  Marker(
                    point: _toLatLng(widget.userLocation!),
                    width: 22,
                    height: 22,
                    child: const _UserLocationDot(),
                  ),
                ...widget.facilities.map((f) {
                  final selected = f.id == widget.selectedFacilityId;
                  return Marker(
                    point: _toLatLng(f.location),
                    width: 96,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => widget.onFacilityTap(f),
                      child: _PriceMarker(price: widget.priceOf(f), selected: selected),
                    ),
                  );
                }),
              ],
            ),
            _osmAttribution(),
          ],
        ),
        if (widget.userLocation != null)
          Positioned(
            right: 12,
            top: 12,
            child: FloatingActionButton.small(
              heroTag: 'facility-map-my-location',
              tooltip: FacilityStrings.myLocation,
              backgroundColor: AppColors.white,
              onPressed: _recenterOnUser,
              child: const Icon(Icons.my_location, color: AppColors.primaryGreen),
            ),
          ),
      ],
    );
  }
}

/// Bản đồ nhỏ, không tương tác, hiển thị vị trí một cơ sở (trong màn chi tiết).
class FacilityLocationPreview extends StatelessWidget {
  final GeoPoint location;
  final double height;

  const FacilityLocationPreview({super.key, required this.location, this.height = 160});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _toLatLng(location),
            initialZoom: 15,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            _osmTileLayer(),
            MarkerLayer(markers: [
              Marker(
                point: _toLatLng(location),
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, color: AppColors.primaryGreen, size: 40),
              ),
            ]),
            _osmAttribution(),
          ],
        ),
      ),
    );
  }
}

class _PriceMarker extends StatelessWidget {
  final int price;
  final bool selected;

  const _PriceMarker({required this.price, required this.selected});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.authPrimary : AppColors.white;
    final fg = selected ? Colors.white : AppColors.primaryGreen;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGreen, width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Text(
            '${Formatters.currency(price ~/ 1000)}k',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
          ),
        ),
        Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen, size: 16),
      ],
    );
  }
}

class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
    );
  }
}

/// Bản đồ để Chủ sân ghim vị trí cơ sở: chạm để đặt ghim, [moveTo] đổi thì bản đồ dời tới đó.
class LocationPickerMap extends StatefulWidget {
  final GeoPoint initialCenter;
  final GeoPoint? picked;
  final GeoPoint? moveTo;
  final ValueChanged<GeoPoint> onPicked;

  const LocationPickerMap({
    super.key,
    required this.initialCenter,
    required this.onPicked,
    this.picked,
    this.moveTo,
  });

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final MapController _controller = MapController();

  @override
  void didUpdateWidget(LocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.moveTo;
    if (target != null && target != oldWidget.moveTo) _controller.move(_toLatLng(target), 16);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picked = widget.picked;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _toLatLng(picked ?? widget.initialCenter),
        initialZoom: picked == null ? 13 : 16,
        onTap: (_, latLng) => widget.onPicked(GeoPoint(latLng.latitude, latLng.longitude)),
      ),
      children: [
        _osmTileLayer(),
        if (picked != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _toLatLng(picked),
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, size: 44, color: AppColors.primaryGreen),
              ),
            ],
          ),
        _osmAttribution(),
      ],
    );
  }
}
