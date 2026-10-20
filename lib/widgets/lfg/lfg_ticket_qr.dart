import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/strings/lfg_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/lfg_match.dart';
import '../../theme/app_colors.dart';

/// Mã QR vé của [userId] trong kèo [match]. Vé của host là vé đơn đặt sân (đổi mã định kỳ) nên tự tải lại
/// theo chu kỳ vé đặt sân; lỗi khi tải lại thì giữ mã đang hiện.
class LfgTicketQr extends StatefulWidget {
  final LfgMatch match;
  final String userId;

  const LfgTicketQr({super.key, required this.match, required this.userId});

  @override
  State<LfgTicketQr> createState() => _LfgTicketQrState();
}

class _LfgTicketQrState extends State<LfgTicketQr> {
  String? _code;
  bool _failed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    final interval = AppRepositories.booking.ticketRefreshInterval;
    if (interval != null && widget.match.isHostedBy(widget.userId)) {
      _timer = Timer.periodic(interval, (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final code = await AppRepositories.lfg.getTicketCode(widget.match, widget.userId);
      if (mounted) {
        setState(() {
          _code = code;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && _code == null) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    if (code == null) {
      return SizedBox(
        height: 180,
        child: Center(
          child: _failed
              ? TextButton(
                  onPressed: () {
                    setState(() => _failed = false);
                    _load();
                  },
                  child: const Text(LfgStrings.retry),
                )
              : const CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }
    return Column(
      children: [
        Center(child: QrImageView(data: code, size: 180, backgroundColor: Colors.white)),
        const SizedBox(height: 6),
        SelectableText(code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
      ],
    );
  }
}
