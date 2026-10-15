import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/strings/common_strings.dart';
import '../../core/strings/owner_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/owner_repository.dart';
import '../../models/court_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_actions.dart';
import 'owner_session_detail_screen.dart';

/// Quét mã QR người chơi (camera) hoặc nhập mã vé để check-in.
/// Pop trả về `true` nếu đã check-in được ít nhất một người.
class OwnerScanScreen extends StatefulWidget {
  /// Tắt camera (dùng trong test, nơi không có plugin camera).
  final bool enableCamera;

  const OwnerScanScreen({super.key, this.enableCamera = true});

  @override
  State<OwnerScanScreen> createState() => _OwnerScanScreenState();
}

class _OwnerScanScreenState extends State<OwnerScanScreen> {
  /// Cùng một mã vừa xử lý xong thì bỏ qua trong khoảng này (mã vẫn còn trước camera).
  static const Duration _sameCodeCooldown = Duration(seconds: 3);

  // Không dùng noDuplicates: chủ sân đóng sheet rồi quét lại đúng mã đó vẫn phải nhận.
  late final MobileScannerController? _camera = widget.enableCamera ? MobileScannerController() : null;
  final _codeController = TextEditingController();
  bool _busy = false;

  /// Đang tra mã (hiện vòng xoay); tắt khi mở sheet check-in để không quay nền.
  bool _looking = false;
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

  Future<void> _handle(String code) async {
    if (_busy || code.trim().isEmpty) return;
    setState(() => _busy = _looking = true);
    _lastCode = code;
    FocusScope.of(context).unfocus();
    try {
      final found = await AppRepositories.owner.lookupTicket(code);
      if (!mounted) return;
      setState(() => _looking = false);
      final block = found.session.checkInBlock(found.player, DateTime.now());
      if (block == null) {
        final updated = await checkInPlayer(context, found.session, found.player);
        if (updated != null) {
          _changed = true;
          _codeController.clear();
        }
      } else {
        await _showBlocked(found, OwnerStrings.checkInBlocked(found.session, block));
      }
    } catch (e) {
      if (mounted) {
        final message = e is OwnerException ? e.message : CommonStrings.genericError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } finally {
      _lastHandledAt = DateTime.now();
      if (mounted) setState(() => _busy = _looking = false);
    }
  }

  Future<void> _showBlocked(TicketLookup found, String reason) async {
    final s = found.session;
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(found.player.name),
        content: Text('${s.facilityName}\n${s.sportLabel} • ${Formatters.slotLabel(s.start, s.end)}\n\n$reason'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(OwnerStrings.cancel)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text(OwnerStrings.viewSession)),
        ],
      ),
    );
    if (open == true && mounted) {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => OwnerSessionDetailScreen(session: s)),
      );
      if (changed == true) _changed = true;
    }
  }

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
                    child: Text(OwnerStrings.scanHint, style: TextStyle(color: Colors.white70)),
                  ),
                  if (_looking) const CircularProgressIndicator(color: AppColors.primaryGreen),
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
                          textCapitalization: TextCapitalization.characters,
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
                        onPressed: _busy ? null : () => _handle(_codeController.text),
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
                ],
              ),
            ),
          ],
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
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70),
      ),
    ),
  );
}
