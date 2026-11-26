import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings/owner_dashboard_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/owner_dashboard.dart';
import '../../theme/app_colors.dart';

const Color _bar = Color(0xFF059669);
const Color _barActive = Color(0xFF047857);
const Color _grid = Color(0xFFE2E8F0);
const Color _axis = Color(0xFF64748B);

/// Rút gọn số cho trục: 500k / 1,2tr / 1,5 tỷ (như Web).
String compactAmount(num v) {
  String fmt(num n) => (n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1)).replaceAll('.', ',');
  if (v >= 1e9) return '${fmt(v / 1e9)} tỷ';
  if (v >= 1e6) return '${fmt(v / 1e6)}tr';
  if (v >= 1e3) return '${fmt(v / 1e3)}k';
  return '${v.round()}';
}

/// Mốc trục tròn: 1 / 2 / 2,5 / 5 × 10^n.
double niceMax(num v) {
  if (v <= 0) return 1;
  final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  return [1, 2, 2.5, 5, 10].map((m) => m * p).firstWhere((x) => x >= v);
}

String _dayLabel(DateTime d) => Formatters.dayMonth(d);

/// Biểu đồ cột doanh thu theo ngày. Chạm vào cột để xem ngày đó (thay cho tooltip khi rê chuột của Web).
class RevenueBarChart extends StatefulWidget {
  final List<DayStat> days;
  final double height;

  const RevenueBarChart({super.key, required this.days, this.height = 160});

  @override
  State<RevenueBarChart> createState() => _RevenueBarChartState();
}

class _RevenueBarChartState extends State<RevenueBarChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final max = niceMax(days.fold<int>(0, (m, d) => math.max(m, d.revenue)));
    final every = math.max(1, (days.length / 6).ceil());
    final sel = _selected != null && _selected! < days.length ? days[_selected!] : null;
    const axisStyle = TextStyle(fontSize: 11, color: _axis, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final t in [max, max / 2, 0]) Text(compactAmount(t), style: axisStyle),
                ],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CustomPaint(
                  painter: _GridPainter(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < days.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _selected = _selected == i ? null : i),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: (days[i].revenue / max).clamp(0, 1).toDouble(),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  constraints: const BoxConstraints(maxWidth: 28, minHeight: 0),
                                  decoration: BoxDecoration(
                                    color: _selected == i ? _barActive : _bar,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // Chừa đúng chỗ trục Y (đo bằng chữ dài nhất) để nhãn ngày thẳng cột.
            Opacity(opacity: 0, child: Text(compactAmount(max), style: axisStyle)),
            const SizedBox(width: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const SizedBox(height: 16, width: double.infinity),
                    for (var i = 0; i < days.length; i += every)
                      Positioned(
                        left: c.maxWidth * i / days.length,
                        child: Text(_dayLabel(days[i].date), style: axisStyle.copyWith(fontSize: 10)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          sel == null
              ? OwnerDashboardStrings.tapBarHint
              : OwnerDashboardStrings.dayDetail(_dayLabel(sel.date), Formatters.vnd(sel.revenue), sel.bookings),
          style: TextStyle(
            fontSize: 12,
            color: sel == null ? AppColors.textSecondary : AppColors.textMain,
            fontWeight: sel == null ? FontWeight.normal : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dashed = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (final y in [0.0, size.height / 2]) {
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), dashed);
      }
    }
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), Paint()..color = const Color(0xFF94A3B8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hai đường số đơn cộng dồn: kỳ trước (xám) và kỳ này (xanh).
class ComparisonLineChart extends StatelessWidget {
  final List<int> previous;
  final List<int> current;
  final int length;
  final String previousLabel;
  final String currentLabel;

  const ComparisonLineChart({
    super.key,
    required this.previous,
    required this.current,
    required this.length,
    required this.previousLabel,
    required this.currentLabel,
  });

  static const Color previousColor = Color(0xFF94A3B8);
  static const Color currentColor = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    final top = niceMax([...previous, ...current].fold<int>(0, math.max));
    const axisStyle = TextStyle(fontSize: 11, color: _axis, fontWeight: FontWeight.w600);
    Widget legend(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 3, color: c),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 12))),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [for (final t in [top, top / 2, 0]) Text(compactAmount(t), style: axisStyle)],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CustomPaint(
                  painter: _LinesPainter(previous: previous, current: current, length: length, top: top),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 4, children: [legend(previousColor, previousLabel), legend(currentColor, currentLabel)]),
      ],
    );
  }
}

class _LinesPainter extends CustomPainter {
  final List<int> previous;
  final List<int> current;
  final int length;
  final double top;

  _LinesPainter({required this.previous, required this.current, required this.length, required this.top});

  @override
  void paint(Canvas canvas, Size size) {
    _GridPainter().paint(canvas, size);
    void line(List<int> values, Color color) {
      if (values.isEmpty) return;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = length <= 1 ? 0.0 : size.width * i / (length - 1);
        final y = size.height - size.height * values[i] / top;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }

    line(previous, ComparisonLineChart.previousColor);
    line(current, ComparisonLineChart.currentColor);
  }

  @override
  bool shouldRepaint(covariant _LinesPainter old) =>
      old.previous != previous || old.current != current || old.length != length || old.top != top;
}

/// Thanh xếp hạng ngang (RankBarChart của Web): tên, giá trị, gợi ý.
class RankBars extends StatelessWidget {
  final List<({String name, int value, String hint})> items;

  const RankBars({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final max = items.fold<int>(0, (m, e) => math.max(m, e.value));
    return Column(
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Text(OwnerDashboardStrings.bookingsCount(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : e.value / max,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFEEF2F1),
                    color: _bar,
                  ),
                ),
                const SizedBox(height: 2),
                Text(e.hint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
      ],
    );
  }
}
