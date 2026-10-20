import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/strings/booking_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/booking.dart';
import '../../theme/app_colors.dart';

/// Mã QR vé của [booking]: tải từ repository, mã đổi theo chu kỳ thì tự tải lại khi đang mở.
class BookingTicketQr extends StatefulWidget {
  final Booking booking;
  final double size;

  const BookingTicketQr({super.key, required this.booking, this.size = 200});

  @override
  State<BookingTicketQr> createState() => _BookingTicketQrState();
}

class _BookingTicketQrState extends State<BookingTicketQr> {
  String? _code;
  bool _failed = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    final interval = AppRepositories.booking.ticketRefreshInterval;
    if (interval != null) _refreshTimer = Timer.periodic(interval, (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final code = await AppRepositories.booking.getTicketCode(widget.booking);
      if (mounted) {
        setState(() {
          _code = code;
          _failed = false;
        });
      }
    } catch (_) {
      // Lỗi khi làm mới: giữ mã đang hiện (mã cũ vẫn dùng được); chưa có mã thì báo lỗi.
      if (mounted && _code == null) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    if (code == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: _failed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      BookingStrings.ticketLoadError,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _failed = false);
                        _load();
                      },
                      child: const Text(BookingStrings.retry),
                    ),
                  ],
                )
              : const CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QrImageView(data: code, size: widget.size, backgroundColor: Colors.white),
        const SizedBox(height: 4),
        SelectableText(
          code,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
        ),
        if (AppRepositories.booking.ticketRefreshInterval != null) ...[
          const SizedBox(height: 4),
          const Text(
            BookingStrings.ticketRefreshNote,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
