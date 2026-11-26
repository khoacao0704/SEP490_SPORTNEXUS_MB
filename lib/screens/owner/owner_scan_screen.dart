import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/owner_booking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart';

/// Một lượt quét trong phiên (Nhật ký quét trong phiên của Web).
class _ScanLogEntry {
  final bool ok;
  final String code;
  final String message;
  final DateTime time;

  const _ScanLogEntry({required this.ok, required this.code, required this.message, required this.time});
}

/// Quét QR check-in (CheckQR của Web): camera hoặc nhập mã / máy quét cầm tay → "Đã đọc được mã vé"
/// → Xác nhận check-in → kết quả. Kèm danh sách đơn hôm nay để check-in thủ công và nhật ký quét.
/// Pop trả về `true` nếu đã check-in được ít nhất một lượt.
class OwnerScanScreen extends StatefulWidget {
  /// Tắt camera (dùng trong test, nơi không có plugin camera).
  final bool enableCamera;
  final String facilityId;
  final String facilityName;

  const OwnerScanScreen({
    super.key,
    this.enableCamera = true,
    required this.facilityId,
    this.facilityName = '',
  });

  @override
  State<OwnerScanScreen> createState() => _OwnerScanScreenState();
}

class _OwnerScanScreenState extends State<OwnerScanScreen> {
  /// Cùng một mã vừa xử lý xong thì bỏ qua trong khoảng này (mã vẫn còn trước camera).
  static const Duration _sameCodeCooldown = Duration(seconds: 3);
  static const int _logLimit = 20;

  late final MobileScannerController? _camera = widget.enableCamera ? MobileScannerController() : null;
  final _codeController = TextEditingController();
  final List<_ScanLogEntry> _log = [];
  bool _busy = false;
  bool _changed = false;
  String? _lastCode;
  DateTime? _lastHandledAt;

  @override
  void dispose() {
    _camera?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null) return;
    final last = _lastHandledAt;
    if (code == _lastCode && last != null && DateTime.now().difference(last) < _sameCodeCooldown) return;
    _handle(code);
  }

  Future<void> _handle(String raw) async {
    final code = raw.trim();
    if (_busy || code.isEmpty) return;
    _busy = true;
    _lastCode = code;
    FocusScope.of(context).unfocus();
    try {
      final confirmed = await _confirm(code);
      if (confirmed != true || !mounted) return;
      ScanResult? result;
      String message;
      try {
        result = await AppRepositories.owner.scanQr(facilityId: widget.facilityId, qrCode: code);
        message = result.message;
        _changed = true;
        _codeController.clear();
      } catch (e) {
        message = ownerErrorMessage(e);
      }
      if (!mounted) return;
      setState(() {
        _log.insert(0, _ScanLogEntry(ok: result != null, code: code, message: message, time: DateTime.now()));
        if (_log.length > _logLimit) _log.removeLast();
      });
      await _showResult(code, result, message);
    } finally {
      _lastHandledAt = DateTime.now();
      _busy = false;
    }
  }

  Future<bool?> _confirm(String code) => showModalBottomSheet<bool>(
        context: context,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  OwnerStrings.scannedTitle,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                ),
                const SizedBox(height: 6),
                Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Text(OwnerStrings.scannedBody(widget.facilityName), style: const TextStyle(height: 1.4)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text(OwnerStrings.cancelEdit),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                        child: const Text(OwnerStrings.confirmCheckIn),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _showResult(String code, ScanResult? r, String message) => showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final ok = r != null;
          final rows = <(String, String)>[
            if (r?.ticketType != null) (OwnerStrings.rowTicketType, OwnerStrings.ticketTypes[r!.ticketType] ?? r.ticketType!),
            if (r?.customerName != null) (OwnerStrings.rowCustomer, r!.customerName!),
            if (r?.courtName != null) (OwnerStrings.rowCourt, r!.courtName!),
            if (r?.start != null)
              (OwnerStrings.rowPlayTime, '${Formatters.time(r!.start!)}${r.end == null ? '' : ' - ${Formatters.time(r.end!)}'}'),
            if (r?.amount != null) (OwnerStrings.rowAmount, Formatters.vnd(r!.amount!)),
          ];
          return AlertDialog(
            icon: Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? AppColors.primaryGreen : Colors.red, size: 48),
            title: Text(ok ? OwnerStrings.scanSuccess : OwnerStrings.scanFailed, textAlign: TextAlign.center),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (r?.avatarUrl != null) ...[
                    CircleAvatar(radius: 40, backgroundImage: NetworkImage(r!.avatarUrl!)),
                    const SizedBox(height: 6),
                    const Text(OwnerStrings.compareFace, style: TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                    const SizedBox(height: 8),
                  ],
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  for (final (label, value) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
                          Flexible(
                            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(OwnerStrings.scanCode(code),
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary)),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                child: const Text(OwnerStrings.scanNext),
              ),
            ],
          );
        },
      );

  Future<void> _openToday() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: TodayCheckInSheet(facilityId: widget.facilityId)),
    );
    if (changed == true) _changed = true;
  }

  void _openLog() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(OwnerStrings.scanLog, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_log.isEmpty)
                  const Text(OwnerStrings.scanLogEmpty, style: TextStyle(color: AppColors.textSecondary))
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final e in _log)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(e.ok ? Icons.check_circle : Icons.cancel, color: e.ok ? AppColors.primaryGreen : Colors.red),
                            title: Text(e.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${Formatters.time(e.time)} • ${e.code}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text(OwnerStrings.scanTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          actions: [
            IconButton(tooltip: OwnerStrings.scanLog, icon: const Icon(Icons.history), onPressed: _openLog),
            if (_camera != null) IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _camera.toggleTorch()),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_camera != null)
                    MobileScanner(
                      controller: _camera,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) => const _CameraMessage(OwnerStrings.cameraError),
                    )
                  else
                    const _CameraMessage(OwnerStrings.cameraError),
                  IgnorePointer(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryGreen, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: Text(OwnerStrings.scanHint, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
            Container(
              color: AppColors.white,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    OwnerStrings.manualTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _handle,
                          decoration: InputDecoration(
                            hintText: OwnerStrings.manualHint,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _handle(_codeController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(OwnerStrings.lookup),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openToday,
                      icon: const Icon(Icons.list_alt),
                      label: const Text(OwnerStrings.todayBookings),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Đơn đặt sân hôm nay: tab Chờ check-in (PAID) / Đã check-in (CHECKED_IN), check-in thủ công từng đơn.
/// Pop trả về `true` nếu đã check-in thủ công.
class TodayCheckInSheet extends StatefulWidget {
  final String facilityId;

  const TodayCheckInSheet({super.key, required this.facilityId});

  @override
  State<TodayCheckInSheet> createState() => _TodayCheckInSheetState();
}

class _TodayCheckInSheetState extends State<TodayCheckInSheet> {
  List<OwnerBooking>? _waiting;
  List<OwnerBooking>? _checked;
  bool _showChecked = false;
  String? _busyId;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = DateTime.now();
    Future<List<OwnerBooking>> load(String status) async => (await AppRepositories.owner.getBookings(
          facilityId: widget.facilityId,
          date: today,
          status: status,
          pageSize: 100,
        ))
            .items;
    try {
      final results = await Future.wait([load(OwnerBookingStatus.paid), load(OwnerBookingStatus.checkedIn)]);
      if (mounted) {
        setState(() {
          _waiting = results[0];
          _checked = results[1];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _waiting ??= const [];
          _checked ??= const [];
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ownerErrorMessage(e)), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _checkIn(OwnerBooking b) async {
    setState(() => _busyId = b.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppRepositories.owner.checkInBooking(b.id);
      _changed = true;
      messenger.showSnackBar(SnackBar(content: Text(OwnerStrings.todayCheckedIn(b.customerName ?? '—', b.courtName))));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ownerErrorMessage(e)), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _busyId = null);
  }

  @override
  Widget build(BuildContext context) {
    final list = _showChecked ? _checked : _waiting;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(OwnerStrings.todayBookings, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                  IconButton(onPressed: () => Navigator.pop(context, _changed), icon: const Icon(Icons.close)),
                ],
              ),
              const Text(OwnerStrings.todayHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(OwnerStrings.tabWaiting(_waiting?.length ?? 0))),
                  ButtonSegment(value: true, label: Text(OwnerStrings.tabChecked(_checked?.length ?? 0))),
                ],
                selected: {_showChecked},
                onSelectionChanged: (s) => setState(() => _showChecked = s.first),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: list == null
                    ? const Center(child: Text(OwnerStrings.todayLoading))
                    : list.isEmpty
                        ? Center(
                            child: Text(
                              _showChecked ? OwnerStrings.todayNoChecked : OwnerStrings.todayNoWaiting,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView(
                            children: [
                              for (final b in list)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${b.customerName ?? '—'}${b.isWalkIn ? OwnerStrings.walkInShort : ''}',
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(b.customerPhone ?? '—', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      const SizedBox(height: 4),
                                      Text('${b.courtName}${b.sportName.isEmpty ? '' : ' • ${b.sportName}'} • '
                                          '${Formatters.timeRange(b.start, b.end)}'),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              OwnerStrings.todayInCourt(b.checkedInCount, b.participantCount < 1 ? 1 : b.participantCount),
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                          ),
                                          Text(Formatters.vnd(b.totalAmount), style: const TextStyle(fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: _showChecked
                                            ? const OwnerBadge(OwnerStrings.inCourt, tone: BadgeTone.green)
                                            : ElevatedButton(
                                                onPressed: _busyId == null ? () => _checkIn(b) : null,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primaryGreen,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: Text(_busyId == b.id ? OwnerStrings.checkingIn : OwnerStrings.manualCheckIn),
                                              ),
                                      ),
                                    ],
                                  ),
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

class _CameraMessage extends StatelessWidget {
  final String text;

  const _CameraMessage(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        ),
      );
}
