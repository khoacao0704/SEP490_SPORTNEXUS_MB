import 'package:flutter/material.dart';

/// Nhãn hạng mức Elo (Đồng / Bạc / Vàng / Bạch kim / Kim cương).
class RankBadge extends StatelessWidget {
  final String rank;

  const RankBadge({super.key, required this.rank});

  static Color colorOf(String rank) {
    final r = rank.toLowerCase();
    if (r.contains('kim cương')) return const Color(0xFF1E88E5);
    if (r.contains('bạch kim')) return const Color(0xFF00897B);
    if (r.contains('vàng')) return const Color(0xFFF9A825);
    if (r.contains('bạc')) return const Color(0xFF78909C);
    return const Color(0xFF8D6E63);
  }

  @override
  Widget build(BuildContext context) {
    if (rank.isEmpty) return const SizedBox.shrink();
    final color = colorOf(rank);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(rank, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
