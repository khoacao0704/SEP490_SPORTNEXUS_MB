import 'package:flutter/material.dart';

import '../../core/services/location_service.dart';
import '../../core/strings/owner_facility_strings.dart';
import '../../models/geo_point.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/facility_map.dart';

/// Ghim vị trí cơ sở trên bản đồ. Pop trả về [GeoPoint] đã chọn.
class LocationPickerScreen extends StatefulWidget {
  final GeoPoint initialCenter;
  final GeoPoint? initial;

  const LocationPickerScreen({super.key, required this.initialCenter, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late GeoPoint? _picked = widget.initial;
  GeoPoint? _moveTo;
  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final result = await const LocationService().getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.point != null) {
        _picked = result.point;
        _moveTo = result.point;
      }
    });
    if (result.point == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(OwnerFacilityStrings.locationUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OwnerFacilityStrings.pickerTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          LocationPickerMap(
            initialCenter: widget.initialCenter,
            picked: _picked,
            moveTo: _moveTo,
            onPicked: (p) => setState(() => _picked = p),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: const Text(OwnerFacilityStrings.pickerHint, style: TextStyle(fontSize: 13)),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 96,
            child: FloatingActionButton.extended(
              heroTag: 'my-location',
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.primaryGreen,
              onPressed: _locating ? null : _useMyLocation,
              icon: _locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
              label: const Text(OwnerFacilityStrings.useMyLocation),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(OwnerFacilityStrings.confirmLocation, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
