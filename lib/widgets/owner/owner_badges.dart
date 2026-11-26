import 'package:flutter/material.dart';

import '../../core/strings/owner_strings.dart';
import '../../models/owner_booking.dart';

/// Màu badge như Web (snx-badge--amber / blue / green / red / gray).
enum BadgeTone { amber, blue, green, red, gray, purple }

extension BadgeToneColors on BadgeTone {
  Color get background => switch (this) {
        BadgeTone.amber => const Color(0xFFFEF3C7),
        BadgeTone.blue => const Color(0xFFDBEAFE),
        BadgeTone.green => const Color(0xFFDCFCE7),
        BadgeTone.red => const Color(0xFFFEE2E2),
        BadgeTone.gray => const Color(0xFFF1F5F9),
        BadgeTone.purple => const Color(0xFFF5F3FF),
      };

  Color get foreground => switch (this) {
        BadgeTone.amber => const Color(0xFFB45309),
        BadgeTone.blue => const Color(0xFF1D4ED8),
        BadgeTone.green => const Color(0xFF15803D),
        BadgeTone.red => const Color(0xFFB91C1C),
        BadgeTone.gray => const Color(0xFF475569),
        BadgeTone.purple => const Color(0xFF6D28D9),
      };
}

/// Màu badge theo trạng thái (src/CourtOwner/shared.js).
BadgeTone toneForStatus(String status) => switch (status) {
      'PENDING' || 'PENDING_PAYMENT' => BadgeTone.amber,
      'CONFIRMED' || 'PAID' => BadgeTone.blue,
      'CHECKED_IN' || 'COMPLETED' => BadgeTone.green,
      'CANCELLED' || 'NO_SHOW' => BadgeTone.red,
      _ => BadgeTone.gray,
    };

/// Màu ô lưới lịch (CELL_STYLES của Web).
({Color bg, Color chip}) cellColors(SlotCellState s) => switch (s) {
      SlotCellState.checkedIn => (bg: const Color(0xFFECFDF5), chip: const Color(0xFF10B981)),
      SlotCellState.paid => (bg: const Color(0xFFFEF3C7), chip: const Color(0xFFF59E0B)),
      SlotCellState.pending => (bg: const Color(0xFFEFF6FF), chip: const Color(0xFF3B82F6)),
      SlotCellState.reserved => (bg: const Color(0xFFF5F3FF), chip: const Color(0xFF8B5CF6)),
      SlotCellState.maintenance => (bg: const Color(0xFFF1F5F9), chip: const Color(0xFF94A3B8)),
      SlotCellState.past => (bg: const Color(0xFFFAFAFA), chip: const Color(0xFFCBD5E1)),
      SlotCellState.available => (bg: Colors.white, chip: const Color(0xFF10B981)),
    };

class OwnerBadge extends StatelessWidget {
  final String text;
  final BadgeTone tone;

  const OwnerBadge(this.text, {super.key, required this.tone});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(6)),
        child: Text(
          text,
          style: TextStyle(color: tone.foreground, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}

/// Badge trạng thái đơn / thanh toán.
class BookingStatusBadge extends StatelessWidget {
  final String status;

  const BookingStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) => OwnerBadge(OwnerStrings.bookingBadge(status), tone: toneForStatus(status));
}

/// Màu badge trạng thái ca sân (shared.js của Web).
BadgeTone toneForSlotStatus(String status) => switch (status) {
      'AVAILABLE' => BadgeTone.green,
      'LOCKING' || 'RESERVED' => BadgeTone.amber,
      'BOOKED' => BadgeTone.blue,
      _ => BadgeTone.gray,
    };
