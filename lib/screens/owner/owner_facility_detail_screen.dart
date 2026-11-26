import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/strings/owner_facility_strings.dart';
import '../../core/strings/owner_slot_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/owner_facility.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/closure_sheet.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart';
import '../../widgets/owner/photo_picker.dart';
import '../../widgets/owner/slot_pickers.dart';
import 'facility_form_screen.dart';
import 'owner_courts_screen.dart';
import 'owner_slots_screen.dart';

/// Chi tiết một cơ sở (FacilityDetail của Web): trạng thái duyệt / khóa, thông tin (Sửa thông tin),
/// Sân & giá, Ca sân, ảnh (thêm / ảnh đại diện / xóa), tiện ích, đóng cơ sở.
/// Mobile giữ thêm: banner tạm ngưng do khiếu nại và lịch tạm đóng (ngày nghỉ).
/// Pop trả về `true` nếu đã có thay đổi.
class OwnerFacilityDetailScreen extends StatefulWidget {
  final OwnerFacility facility;

  const OwnerFacilityDetailScreen({super.key, required this.facility});

  @override
  State<OwnerFacilityDetailScreen> createState() => _OwnerFacilityDetailScreenState();
}

class _OwnerFacilityDetailScreenState extends State<OwnerFacilityDetailScreen> {
  late OwnerFacility _f = widget.facility;
  bool _changed = false;
  String _busy = '';
  List<FacilityAmenity> _catalog = const [];
  bool _catalogFailed = false;

  /// Tiện ích đang chỉnh (null = chưa sửa, theo dữ liệu cơ sở).
  Set<String>? _amenityDraft;

  @override
  void initState() {
    super.initState();
    AppRepositories.owner.getAmenities().then((a) {
      if (mounted) setState(() => _catalog = a);
    }).catchError((_) {
      if (mounted) setState(() => _catalogFailed = true);
    });
  }

  Future<T?> _push<T>(Widget screen) => Navigator.push<T>(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _reload() async {
    try {
      final f = await AppRepositories.owner.getOwnerFacility(_f.id);
      if (mounted) setState(() => _f = f);
    } catch (_) {}
  }

  void _apply(OwnerFacility? updated) {
    if (updated == null || !mounted) return;
    setState(() {
      _f = updated;
      _changed = true;
    });
  }

  /// Chạy thao tác, báo kết quả, tải lại cơ sở (run của Web).
  Future<bool> _run(String key, Future<void> Function() action, String? message) async {
    setState(() => _busy = key);
    try {
      await action();
      _changed = true;
      if (mounted && message != null) showOwnerSnack(context, message);
      await _reload();
      return true;
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Set<String> get _currentAmenities {
    final draft = _amenityDraft;
    if (draft != null) return draft;
    final ids = {for (final a in _f.amenityItems) if (a.id.isNotEmpty) a.id};
    if (ids.isNotEmpty) return ids;
    // Dữ liệu chỉ có tên tiện ích: đối chiếu theo tên với danh mục.
    final names = _f.operations.amenities.toSet();
    return {for (final a in _catalog) if (names.contains(a.name)) a.id};
  }

  List<FacilityPhoto> get _photos => _f.photos.isNotEmpty
      ? _f.photos
      : [
          for (var i = 0; i < _f.operations.images.length; i++)
            FacilityPhoto(id: '', url: _f.operations.images[i], isThumbnail: i == 0),
        ];

  Future<void> _addPhotos() async {
    final left = OwnerFacilityStrings.maxPhotos - _photos.length;
    if (left <= 0) {
      showOwnerSnack(context, OwnerFacilityStrings.tooManyPhotos(OwnerFacilityStrings.maxPhotos), error: true);
      return;
    }
    final paths = (await pickPhotoPaths(context)).take(left).toList();
    if (paths.isEmpty || !mounted) return;
    final tooBig = paths.any((p) {
      final file = File(p);
      return file.existsSync() && file.lengthSync() > OwnerFacilityStrings.maxPhotoBytes;
    });
    if (tooBig) {
      showOwnerSnack(context, OwnerFacilityStrings.photoTooBig, error: true);
      return;
    }
    await _run('upload', () => AppRepositories.owner.uploadFacilityPhotos(_f.id, paths), OwnerFacilityStrings.uploaded(paths.length));
  }

  Future<void> _deletePhoto(FacilityPhoto p) async {
    if (!await confirmOwner(context, OwnerFacilityStrings.deletePhotoConfirm)) return;
    await _run('del-${p.id}', () => AppRepositories.owner.deleteFacilityPhoto(_f.id, p.id), OwnerFacilityStrings.photoDeleted);
  }

  Future<void> _saveAmenities() async {
    final ids = _currentAmenities.toList();
    if (await _run('amenities', () => AppRepositories.owner.updateFacilityAmenities(_f.id, ids), OwnerFacilityStrings.amenitiesSaved)) {
      if (mounted) setState(() => _amenityDraft = null);
    }
  }

  Future<void> _close() async {
    if (!await confirmOwner(context, OwnerFacilityStrings.closeConfirm(_f.profile.name))) return;
    setState(() => _busy = 'delete');
    try {
      await AppRepositories.owner.deleteFacility(_f.id);
      if (!mounted) return;
      showOwnerSnack(context, OwnerFacilityStrings.closed);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showOwnerSnack(context, ownerErrorMessage(e), error: true);
        setState(() => _busy = '');
      }
    }
  }

  Future<void> _removeClosure(FacilityClosure c) async {
    try {
      _apply(await AppRepositories.owner.removeClosure(_f.id, c.id));
      if (mounted) showOwnerSnack(context, OwnerFacilityStrings.closureRemoved);
    } catch (e) {
      if (mounted) showOwnerSnack(context, ownerErrorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: Text(f.profile.name,
              style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        body: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (f.isApproved && f.isSuspended) _banner(OwnerFacilityStrings.suspendedBanner),
              _infoCard(f),
              _courtsAndSlots(f),
              _photosCard(),
              _amenitiesCard(),
              if (f.isApproved) _closuresSection(f),
              _closeCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.red.shade700))),
          ],
        ),
      );

  Widget _card({required List<Widget> children, Color? border}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border ?? AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _infoCard(OwnerFacility f) {
    final approval = switch (f.status) {
      ApprovalStatus.approved => (OwnerFacilityStrings.badgeApproved, BadgeTone.green),
      ApprovalStatus.pending => (OwnerFacilityStrings.badgePending, BadgeTone.amber),
      ApprovalStatus.rejected => (OwnerFacilityStrings.badgeRejected, BadgeTone.red),
    };
    final o = f.operations;
    final courts = f.courtCount ?? f.courts.fold<int>(0, (s, c) => s + c.courtCount);
    return _card(children: [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OwnerBadge(approval.$1, tone: approval.$2),
          if (f.isLocked) const OwnerBadge(OwnerFacilityStrings.badgeLocked, tone: BadgeTone.red),
        ],
      ),
      const SizedBox(height: 6),
      Text(f.profile.address, style: const TextStyle(color: AppColors.textSecondary)),
      if (f.status == ApprovalStatus.rejected && (f.rejectReason ?? '').isNotEmpty) ...[
        const SizedBox(height: 8),
        _alert(OwnerFacilityStrings.rejectReason(f.rejectReason!)),
      ],
      if (f.isLocked && (f.lockedReason ?? '').isNotEmpty) ...[
        const SizedBox(height: 8),
        _alert(OwnerFacilityStrings.lockReason(f.lockedReason!)),
      ],
      const SizedBox(height: 10),
      _row(OwnerFacilityStrings.infoHours, '${formatMinutes(o.openMinutes)} – ${formatMinutes(o.closeMinutes)}'),
      _row(OwnerFacilityStrings.infoPhone, o.phone.isEmpty ? '—' : o.phone),
      _row(OwnerFacilityStrings.infoArea, [f.profile.ward, f.profile.city].where((s) => s.isNotEmpty && s != '—').join(', ')),
      _row(
        OwnerFacilityStrings.infoRating,
        f.rating > 0 ? OwnerFacilityStrings.ratingValue(f.rating, f.reviewCount) : OwnerFacilityStrings.noRating,
      ),
      _row(OwnerFacilityStrings.infoCourts, OwnerFacilityStrings.courtsValue(courts)),
      _row(OwnerFacilityStrings.infoAutoSlots, f.autoGenerateSlots ? OwnerFacilityStrings.on : OwnerFacilityStrings.off),
      _row(
        OwnerFacilityStrings.infoDiscount,
        f.recurringDiscountPercent > 0 ? '${f.recurringDiscountPercent}%' : OwnerFacilityStrings.noDiscount,
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () async {
            final updated = await _push<OwnerFacility>(FacilityFormScreen(facility: _f));
            _apply(updated);
          },
          icon: const Icon(Icons.edit, size: 18),
          label: const Text(OwnerFacilityStrings.editTitle),
        ),
      ),
    ]);
  }

  Widget _alert(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: BadgeTone.red.background, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: BadgeTone.red.foreground, fontSize: 13)),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            Flexible(
              child: Text(value.isEmpty ? '—' : value,
                  textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  /// "Sân & giá" và "Ca sân" như menu Cơ sở & sân của Web.
  Widget _courtsAndSlots(OwnerFacility f) => _card(children: [
        _entry(Icons.sports_tennis, OwnerSlotStrings.courtsEntry, OwnerSlotStrings.courtsEntryHint, () async {
          await _push<void>(OwnerCourtsScreen(facility: f));
          await _reload();
        }),
        const Divider(height: 1),
        _entry(Icons.event_repeat, OwnerSlotStrings.slotsEntry, OwnerSlotStrings.slotsEntryHint,
            () => _push<void>(OwnerSlotsScreen(facilityId: f.id, facilityName: f.profile.name))),
      ]);

  Widget _entry(IconData icon, String title, String hint, VoidCallback onTap) => Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.primaryGreen),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(hint, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: onTap,
        ),
      );

  Widget _photosCard() {
    final photos = _photos;
    return _card(children: [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text('${OwnerFacilityStrings.photosTitle} ${OwnerFacilityStrings.photosCount(photos.length)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          OutlinedButton.icon(
            onPressed: _busy.isEmpty && photos.length < OwnerFacilityStrings.maxPhotos ? _addPhotos : null,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(_busy == 'upload' ? OwnerFacilityStrings.uploading : OwnerFacilityStrings.addPhotos),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (photos.isEmpty)
        const Text(OwnerFacilityStrings.noPhotos, style: TextStyle(color: AppColors.textSecondary))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in photos)
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: OwnerImage(p.url, width: 140, height: 90)),
                    if (p.isThumbnail) const OwnerBadge(OwnerFacilityStrings.thumbnail, tone: BadgeTone.green),
                    if (p.id.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: [
                          if (!p.isThumbnail)
                            TextButton(
                              onPressed: _busy.isEmpty
                                  ? () => _run('thumb-${p.id}', () => AppRepositories.owner.setFacilityThumbnail(_f.id, p.id),
                                      OwnerFacilityStrings.thumbnailSet)
                                  : null,
                              child: const Text(OwnerFacilityStrings.setThumbnail),
                            ),
                          IconButton(
                            tooltip: OwnerFacilityStrings.deletePhotoConfirm,
                            onPressed: _busy.isEmpty ? () => _deletePhoto(p) : null,
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
    ]);
  }

  Widget _amenitiesCard() {
    final current = _currentAmenities;
    return _card(children: [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          const Text(OwnerFacilityStrings.amenitiesTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Wrap(
            spacing: 6,
            children: [
              if (_amenityDraft != null)
                TextButton(onPressed: () => setState(() => _amenityDraft = null), child: const Text(OwnerFacilityStrings.undo)),
              ElevatedButton(
                onPressed: _amenityDraft == null || _busy == 'amenities' ? null : _saveAmenities,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                child: const Text(OwnerFacilityStrings.saveAmenities),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_catalog.isEmpty)
        Text(
          _catalogFailed ? OwnerFacilityStrings.amenitiesLoadError : OwnerFacilityStrings.uploading,
          style: const TextStyle(color: AppColors.textSecondary),
        )
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final a in _catalog)
              FilterChip(
                label: Text(a.name),
                selected: current.contains(a.id),
                onSelected: (on) => setState(() {
                  final next = {...current};
                  on ? next.add(a.id) : next.remove(a.id);
                  _amenityDraft = next;
                }),
              ),
          ],
        ),
    ]);
  }

  Widget _closuresSection(OwnerFacility f) {
    final active = f.activeClosures(DateTime.now());
    return _card(children: [
      Wrap(
        spacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(OwnerFacilityStrings.sectionClosures, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          TextButton.icon(
            onPressed: () async {
              final updated = await showClosureSheet(context, f);
              _apply(updated);
              if (updated != null && mounted) showOwnerSnack(context, OwnerFacilityStrings.closureAdded);
            },
            icon: const Icon(Icons.block, size: 18),
            label: const Text(OwnerFacilityStrings.addClosure),
          ),
        ],
      ),
      if (active.isEmpty)
        const Text(OwnerFacilityStrings.noClosures, style: TextStyle(color: AppColors.textSecondary))
      else
        for (final c in active)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.block, size: 18, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.isWholeFacility ? OwnerFacilityStrings.wholeFacility : f.courtFor(c.sport!, c.courtType!)?.label ?? ''}'
                        ' • ${OwnerFacilityStrings.closureRange(Formatters.dayMonth(c.from), Formatters.dayMonth(c.to))}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(c.reason, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => _removeClosure(c), child: const Text(OwnerFacilityStrings.reopen)),
              ],
            ),
          ),
    ]);
  }

  Widget _closeCard() => _card(
        border: const Color(0xFFFECACA),
        children: [
          const Text(OwnerFacilityStrings.closeTitle,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFB91C1C))),
          const Text(OwnerFacilityStrings.closeHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _busy == 'delete' ? null : _close,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text(OwnerFacilityStrings.closeButton),
            ),
          ),
        ],
      );
}
