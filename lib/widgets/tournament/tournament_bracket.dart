import 'package:flutter/material.dart';
import '../../core/strings/tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/tournament.dart';
import '../../theme/app_colors.dart';

/// Tên hiển thị của một bên trong trận: vòng đầu để trống là miễn thi đấu, vòng sau là chờ xác định.
String tournamentSideName(Tournament t, String? entryId, int round) {
  final entry = t.entryById(entryId);
  if (entry == null) return round == 1 ? TournamentStrings.bye : TournamentStrings.tbd;
  return entry.withdrawn ? '${entry.name} (${TournamentStrings.withdrawnTag})' : entry.name;
}

/// Một trận trong danh sách lịch thi đấu.
class TournamentMatchTile extends StatelessWidget {
  final Tournament tournament;
  final TournamentMatch match;

  /// Đơn của người dùng để tô nổi bật.
  final String? myEntryId;

  const TournamentMatchTile({super.key, required this.tournament, required this.match, this.myEntryId});

  @override
  Widget build(BuildContext context) {
    final m = match;
    final mine = myEntryId != null && m.involves(myEntryId!);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mine ? AppColors.lightGreen : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mine ? AppColors.primaryGreen : AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [
                    m.scheduledAt == null
                        ? TournamentStrings.timeTbd
                        : '${Formatters.weekdayDayMonth(m.scheduledAt!)} • ${Formatters.time(m.scheduledAt!)}',
                    if (m.court.isNotEmpty) m.court,
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _side(m.entryAId),
          const SizedBox(height: 4),
          _side(m.entryBId),
          if (m.score != null) ...[
            const SizedBox(height: 6),
            Text(
              m.score!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
            ),
          ],
        ],
      ),
    );
  }

  Widget _side(String? entryId) {
    final won = entryId != null && match.winnerId == entryId;
    final lost = match.isFinished && !won;
    return Row(
      children: [
        Icon(
          won ? Icons.emoji_events : Icons.circle,
          size: won ? 16 : 8,
          color: won ? AppColors.primaryGreen : (lost ? AppColors.cardBorder : AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tournamentSideName(tournament, entryId, match.round) + (entryId != null && entryId == myEntryId ? ' ${TournamentStrings.you}' : ''),
            style: TextStyle(
              fontWeight: won ? FontWeight.bold : FontWeight.w500,
              color: lost ? AppColors.textSecondary : AppColors.textMain,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sơ đồ nhánh loại trực tiếp: mỗi vòng một cột, cuộn ngang.
class TournamentBracket extends StatelessWidget {
  final Tournament tournament;
  final String? myEntryId;

  const TournamentBracket({super.key, required this.tournament, this.myEntryId});

  static const double _boxWidth = 168;
  static const double _boxHeight = 60;
  static const double _gap = 14;
  static const double _connectorWidth = 28;
  static const double _headerHeight = 32;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final rounds = t.roundCount;
    final firstRoundCount = t.matchesInRound(1).length;
    if (firstRoundCount == 0) return const SizedBox.shrink();
    final bodyHeight = (_boxHeight + _gap) * firstRoundCount;

    final columns = <Widget>[];
    for (var round = 1; round <= rounds; round++) {
      final count = (firstRoundCount >> (round - 1)).clamp(1, firstRoundCount);
      final slot = bodyHeight / count;
      final byIndex = {for (final m in t.matchesInRound(round)) m.index: m};
      if (round > 1) {
        columns.add(Column(
          children: [
            const SizedBox(height: _headerHeight),
            CustomPaint(
              size: Size(_connectorWidth, bodyHeight),
              painter: _ConnectorPainter(count: count, slot: slot),
            ),
          ],
        ));
      }
      columns.add(SizedBox(
        width: _boxWidth,
        child: Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: Text(
                TournamentStrings.roundName(round, rounds),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
            ),
            for (var i = 0; i < count; i++)
              SizedBox(height: slot, child: Center(child: _box(byIndex[i], round))),
          ],
        ),
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: columns),
    );
  }

  Widget _box(TournamentMatch? m, int round) {
    final mine = m != null && myEntryId != null && m.involves(myEntryId!);
    return Container(
      width: _boxWidth,
      height: _boxHeight,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: mine ? AppColors.primaryGreen : AppColors.cardBorder, width: mine ? 2 : 1),
      ),
      child: Column(
        children: [
          Expanded(child: _row(m, m?.entryAId, round)),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(child: _row(m, m?.entryBId, round)),
        ],
      ),
    );
  }

  Widget _row(TournamentMatch? m, String? entryId, int round) {
    final won = m != null && entryId != null && m.winnerId == entryId;
    final lost = m != null && m.isFinished && !won;
    final isMine = entryId != null && entryId == myEntryId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: won ? AppColors.lightGreen : null,
      alignment: Alignment.centerLeft,
      child: Text(
        tournamentSideName(tournament, entryId, round),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: won || isMine ? FontWeight.bold : FontWeight.normal,
          color: lost ? AppColors.textSecondary : (isMine ? AppColors.primaryGreen : AppColors.textMain),
        ),
      ),
    );
  }
}

/// Nối mỗi cặp trận ở vòng trước vào trận tương ứng ở vòng sau.
class _ConnectorPainter extends CustomPainter {
  final int count;
  final double slot;

  _ConnectorPainter({required this.count, required this.slot});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cardBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final prevSlot = slot / 2;
    final midX = size.width / 2;
    for (var i = 0; i < count; i++) {
      final y1 = prevSlot * (2 * i + 0.5);
      final y2 = prevSlot * (2 * i + 1.5);
      final yMid = slot * (i + 0.5);
      final path = Path()
        ..moveTo(0, y1)
        ..lineTo(midX, y1)
        ..lineTo(midX, y2)
        ..lineTo(0, y2)
        ..moveTo(midX, yMid)
        ..lineTo(size.width, yMid);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) => oldDelegate.count != count || oldDelegate.slot != slot;
}
