import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/constants/vietnam_cities.dart';
import '../../core/services/location_service.dart';
import '../../core/strings/facility_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/facility_repository.dart';
import '../../models/facility.dart';
import '../../models/facility_search.dart';
import '../../models/geo_point.dart';
import '../../models/sport.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/amenity_icon.dart';
import '../../widgets/facility/facility_card.dart';
import '../../widgets/facility/facility_map.dart';
import '../../widgets/facility/sport_icon.dart';
import 'facility_detail_screen.dart';

enum _ViewMode { list, map }

class FacilitySearchScreen extends StatefulWidget {
  final Sport? initialSport;
  final LocationService locationService;

  const FacilitySearchScreen({
    super.key,
    this.initialSport,
    this.locationService = const LocationService(),
  });

  @override
  State<FacilitySearchScreen> createState() => _FacilitySearchScreenState();
}

class _FacilitySearchScreenState extends State<FacilitySearchScreen> {
  LocationService get _locationService => widget.locationService;
  final TextEditingController _keywordController = TextEditingController();
  Timer? _keywordDebounce;

  City _city = VietnamCities.hoChiMinh;
  String? _district;
  Sport? _sport;
  FacilitySort _sort = FacilitySort.distance;
  _ViewMode _viewMode = _ViewMode.list;

  /// Khoảng giá đang lọc ([_priceRanges]); `null` = mọi mức giá.
  (int?, int?)? _priceRange;
  double? _minRating;
  Set<String> _amenityIds = {};

  /// Danh mục tiện ích cho bảng lọc, tải lần đầu mở bảng.
  Future<List<Amenity>>? _amenitiesFuture;

  /// Các mức giá để chọn nhanh (đ/giờ): (từ, đến), `null` = không giới hạn.
  static const List<(int?, int?)> _priceRanges = [
    (null, 100000),
    (100000, 200000),
    (200000, 300000),
    (300000, null),
  ];
  static const List<double> _ratingOptions = [3, 4, 4.5];

  LocationResult? _location;
  bool _isLocating = true;

  List<FacilitySearchResult> _results = [];
  List<String> _districts = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedMapFacilityId;

  /// Mỗi lần tìm tăng số này; kết quả của lần tìm cũ về muộn sẽ bị bỏ qua.
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _sport = widget.initialSport;
    _init();
  }

  @override
  void dispose() {
    _keywordDebounce?.cancel();
    _keywordController.dispose();
    super.dispose();
  }

  /// BE chưa lọc được theo tỉnh/quận: ẩn chọn thành phố và bộ lọc quận.
  bool get _hasAreaFilter => AppRepositories.facility.supportsAreaFilter;

  Future<void> _init() async {
    await _locate(pickNearestCity: true);
    if (_hasAreaFilter) await _loadDistricts();
    await _search();
  }

  Future<void> _locate({bool pickNearestCity = false}) async {
    setState(() => _isLocating = true);
    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _location = result;
      _isLocating = false;
      if (pickNearestCity && result.point != null) {
        _city = _nearestCity(result.point!);
      }
    });
  }

  City _nearestCity(GeoPoint point) {
    return VietnamCities.all.reduce((a, b) =>
        GeoUtils.distanceKm(point, a.center) <= GeoUtils.distanceKm(point, b.center) ? a : b);
  }

  Future<void> _loadDistricts() async {
    final districts = await AppRepositories.facility.getDistricts(_city.name);
    if (mounted) setState(() => _districts = districts);
  }

  Future<void> _search() async {
    final generation = ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await AppRepositories.facility.searchFacilities(FacilitySearchQuery(
        city: _city.name,
        district: _district,
        sport: _sport,
        keyword: _keywordController.text,
        sort: _sort,
        userLocation: _location?.point,
        minPrice: _priceRange?.$1,
        maxPrice: _priceRange?.$2,
        minRating: _minRating,
        amenityIds: _amenityIds,
      ));
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = results;
        _isLoading = false;
        if (!_results.any((r) => r.facility.id == _selectedMapFacilityId)) _selectedMapFacilityId = null;
      });
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _isLoading = false;
        // Lỗi từ BE / mạng đã có câu tiếng Việt cụ thể; lỗi khác dùng câu chung.
        _error = e is FacilityException ? e.message : FacilityStrings.loadError;
      });
    }
  }

  void _onKeywordChanged(String _) {
    setState(() {}); // cập nhật nút xóa (x) trong ô tìm kiếm
    _keywordDebounce?.cancel();
    _keywordDebounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _onLocationAction() async {
    final status = _location?.status;
    if (status == LocationStatus.deniedForever || status == LocationStatus.serviceDisabled) {
      await _locationService.openSettings(status!);
      return;
    }
    await _locate();
    await _search();
  }

  void _openDetail(FacilitySearchResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FacilityDetailScreen(
          facility: result.facility,
          distanceKm: result.distanceKm,
          initialSport: _sport,
        ),
      ),
    );
  }

  int _priceOf(Facility f) => (_sport == null ? null : f.offeringFor(_sport!)?.priceFrom) ?? f.priceFrom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          FacilityStrings.searchTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _viewMode == _ViewMode.list ? FacilityStrings.mapView : FacilityStrings.listView,
            icon: Icon(
              _viewMode == _ViewMode.list ? Icons.map_outlined : Icons.view_list_outlined,
              color: AppColors.primaryGreen,
            ),
            onPressed: () => setState(() {
              _viewMode = _viewMode == _ViewMode.list ? _ViewMode.map : _ViewMode.list;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          _buildLocationBanner(),
          Expanded(child: _viewMode == _ViewMode.list ? _buildListView() : _buildMapView()),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    final hasActiveFilter = _district != null ||
        _sort != FacilitySort.distance ||
        _priceRange != null ||
        _minRating != null ||
        _amenityIds.isNotEmpty;

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _keywordController,
            onChanged: _onKeywordChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: FacilityStrings.searchHint,
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _keywordController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _keywordController.clear();
                        _search();
                      },
                    ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_hasAreaFilter) ...[
                Expanded(
                  child: _HeaderButton(
                    icon: Icons.location_on_outlined,
                    label: _district == null ? _city.name : '$_district, ${_city.name}',
                    showChevron: true,
                    onTap: _showCityPicker,
                  ),
                ),
                const SizedBox(width: 8),
              ] else
                const Spacer(),
              _HeaderButton(
                icon: Icons.tune,
                label: FacilityStrings.filterTitle,
                highlighted: hasActiveFilter,
                onTap: _showFilterSheet,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSportChips(),
        ],
      ),
    );
  }

  Widget _buildSportChips() {
    Widget chip({required String label, IconData? icon, required bool selected, required VoidCallback onTap}) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primaryGreen),
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: AppColors.primaryGreen,
          backgroundColor: AppColors.white,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppColors.textMain,
          ),
          side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(
            label: FacilityStrings.allSports,
            selected: _sport == null,
            onTap: () {
              setState(() => _sport = null);
              _search();
            },
          ),
          ...Sport.values.map((s) => chip(
                label: s.label,
                icon: sportIcon(s),
                selected: _sport == s,
                onTap: () {
                  setState(() => _sport = s);
                  _search();
                },
              )),
        ],
      ),
    );
  }

  Widget _buildLocationBanner() {
    if (_isLocating) {
      return Container(
        width: double.infinity,
        color: AppColors.lightGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Expanded(
              child: Text(FacilityStrings.locating, style: TextStyle(fontSize: 12, color: AppColors.darkGreen)),
            ),
          ],
        ),
      );
    }

    final status = _location?.status;
    if (status == null || status == LocationStatus.granted) return const SizedBox.shrink();

    final message = switch (status) {
      LocationStatus.serviceDisabled => FacilityStrings.locationServiceOff,
      LocationStatus.unavailable => FacilityStrings.locationUnavailable,
      _ => FacilityStrings.locationDenied,
    };
    final action = status == LocationStatus.deniedForever || status == LocationStatus.serviceDisabled
        ? FacilityStrings.openSettings
        : status == LocationStatus.unavailable
            ? FacilityStrings.retry
            : FacilityStrings.enableLocation;

    return Container(
      width: double.infinity,
      color: AppColors.tagOrangeBg,
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: [
          const Icon(Icons.location_off_outlined, size: 18, color: AppColors.tagOrangeText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.tagOrangeText)),
          ),
          TextButton(
            onPressed: _onLocationAction,
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.tagOrangeText)),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) return _buildErrorState();
    if (_results.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _search,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _results.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              children: [
                Text(
                  FacilityStrings.resultCount(_results.length),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                if (_isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            );
          }
          final result = _results[index - 1];
          return FacilityCard(result: result, sport: _sport, onTap: () => _openDetail(result));
        },
      ),
    );
  }

  Widget _buildMapView() {
    final selected = _results.where((r) => r.facility.id == _selectedMapFacilityId).firstOrNull;

    return Stack(
      children: [
        FacilityMap(
          // Đổi thành phố thì dựng lại bản đồ để căn về tâm thành phố mới.
          key: ValueKey(_city.name),
          facilities: _results.map((r) => r.facility).toList(),
          priceOf: _priceOf,
          initialCenter: _location?.point != null && _nearestCity(_location!.point!) == _city
              ? _location!.point!
              : _city.center,
          userLocation: _location?.point,
          selectedFacilityId: _selectedMapFacilityId,
          onFacilityTap: (f) => setState(() => _selectedMapFacilityId = f.id),
          onMapTap: () => setState(() => _selectedMapFacilityId = null),
        ),
        if (_isLoading)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
          ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              child: FacilityCard(result: selected, sport: _sport, onTap: () => _openDetail(selected)),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      // ListView để vẫn kéo-làm-mới được khi rỗng.
      children: const [
        SizedBox(height: 80),
        Icon(Icons.search_off, size: 64, color: AppColors.cardBorder),
        SizedBox(height: 12),
        Text(
          FacilityStrings.noResults,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        SizedBox(height: 4),
        Text(
          FacilityStrings.noResultsHint,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 56, color: AppColors.cardBorder),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
          TextButton(onPressed: _search, child: const Text(FacilityStrings.retry)),
        ],
      ),
    );
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                FacilityStrings.chooseCity,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: VietnamCities.all.map((city) {
                  final selected = city.name == _city.name;
                  return ListTile(
                    leading: Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: AppColors.primaryGreen,
                    ),
                    title: Text(
                      city.name,
                      style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      if (selected) return;
                      setState(() {
                        _city = city;
                        _district = null;
                        _selectedMapFacilityId = null;
                      });
                      await _loadDistricts();
                      await _search();
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priceRangeLabel((int?, int?) range) => switch (range) {
        (null, final max?) => FacilityStrings.priceBelow(Formatters.vnd(max)),
        (final min?, null) => FacilityStrings.priceAbove(Formatters.vnd(min)),
        (final min, final max) => FacilityStrings.priceBetween(Formatters.currency(min ?? 0), Formatters.vnd(max ?? 0)),
      };

  /// 4.5 → "4,5", 4 → "4".
  static String _stars(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString().replaceAll('.', ',');

  void _showFilterSheet() {
    var sort = _sort;
    String? district = _district;
    var priceRange = _priceRange;
    var minRating = _minRating;
    final amenityIds = {..._amenityIds};
    final hasLocation = _location?.point != null;
    final amenitiesFuture = _amenitiesFuture ??= AppRepositories.facility.getAmenities();
    // Lỗi tải danh mục tiện ích: lần mở sau thử lại.
    amenitiesFuture.catchError((_) {
      _amenitiesFuture = null;
      return <Amenity>[];
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Widget optionChip(String label, bool selected, VoidCallback? onTap) => ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: onTap == null ? null : (_) => onTap(),
                showCheckmark: false,
                selectedColor: AppColors.primaryGreen,
                backgroundColor: AppColors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textMain,
                ),
                side: BorderSide(color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
              );

          Widget heading(String text) => Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
              );

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Text(
                          FacilityStrings.filterTitle,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setSheetState(() {
                            sort = FacilitySort.distance;
                            district = null;
                            priceRange = null;
                            minRating = null;
                            amenityIds.clear();
                          }),
                          child: const Text(FacilityStrings.resetFilter),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text(FacilityStrings.sortBy, style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              optionChip(
                                FacilityStrings.sortDistance,
                                sort == FacilitySort.distance,
                                hasLocation ? () => setSheetState(() => sort = FacilitySort.distance) : null,
                              ),
                              optionChip(FacilityStrings.sortPrice, sort == FacilitySort.priceLowToHigh,
                                  () => setSheetState(() => sort = FacilitySort.priceLowToHigh)),
                              optionChip(FacilityStrings.sortPriceDesc, sort == FacilitySort.priceHighToLow,
                                  () => setSheetState(() => sort = FacilitySort.priceHighToLow)),
                              optionChip(FacilityStrings.sortRating, sort == FacilitySort.rating,
                                  () => setSheetState(() => sort = FacilitySort.rating)),
                              optionChip(FacilityStrings.sortNewest, sort == FacilitySort.newest,
                                  () => setSheetState(() => sort = FacilitySort.newest)),
                            ],
                          ),
                          heading(FacilityStrings.priceRange),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              optionChip(FacilityStrings.any, priceRange == null,
                                  () => setSheetState(() => priceRange = null)),
                              ..._priceRanges.map((r) => optionChip(
                                  _priceRangeLabel(r), priceRange == r, () => setSheetState(() => priceRange = r))),
                            ],
                          ),
                          heading(FacilityStrings.minRating),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              optionChip(FacilityStrings.any, minRating == null,
                                  () => setSheetState(() => minRating = null)),
                              ..._ratingOptions.map((r) => optionChip(FacilityStrings.ratingAtLeast(_stars(r)),
                                  minRating == r, () => setSheetState(() => minRating = r))),
                            ],
                          ),
                          FutureBuilder<List<Amenity>>(
                            future: amenitiesFuture,
                            builder: (context, snapshot) {
                              final amenities = snapshot.data ?? const <Amenity>[];
                              if (snapshot.connectionState != ConnectionState.done) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: LinearProgressIndicator(minHeight: 2),
                                );
                              }
                              if (amenities.isEmpty) return const SizedBox.shrink();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  heading(FacilityStrings.amenities),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: amenities.map((a) {
                                      final selected = amenityIds.contains(a.id);
                                      return FilterChip(
                                        avatar: Icon(amenityIcon(a.iconCode), size: 16,
                                            color: selected ? Colors.white : AppColors.primaryGreen),
                                        label: Text(a.name),
                                        selected: selected,
                                        showCheckmark: false,
                                        selectedColor: AppColors.primaryGreen,
                                        backgroundColor: AppColors.white,
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? Colors.white : AppColors.textMain,
                                        ),
                                        side: BorderSide(
                                            color: selected ? AppColors.primaryGreen : AppColors.cardBorder),
                                        onSelected: (on) => setSheetState(
                                            () => on ? amenityIds.add(a.id) : amenityIds.remove(a.id)),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    FacilityStrings.amenitiesHint,
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (_hasAreaFilter) ...[
                            heading(FacilityStrings.district),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                optionChip(FacilityStrings.allDistricts, district == null,
                                    () => setSheetState(() => district = null)),
                                ..._districts
                                    .map((d) => optionChip(d, district == d, () => setSheetState(() => district = d))),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          setState(() {
                            _sort = sort;
                            _district = district;
                            _priceRange = priceRange;
                            _minRating = minRating;
                            _amenityIds = amenityIds;
                          });
                          _search();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.authPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(FacilityStrings.applyFilter, style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final bool showChevron;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.lightGreen : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: highlighted ? AppColors.primaryGreen : AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain),
              ),
            ),
            if (showChevron)
              const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
