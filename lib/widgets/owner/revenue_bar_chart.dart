import 'package:flutter/material.dart';

import '../../core/strings/owner_finance_strings.dart';
import '../../core/utils/formatters.dart';
import '../../theme/app_colors.dart';

/// Biểu đồ cột doanh thu theo ngày trong tháng (một dãy số liệu nên không cần chú thích).
/// Chạm vào cột để xem số tiền của ngày đó.
class RevenueBarChart extends StatefulWidget {
  /// Doanh thu từng ngày, chỉ số 0 = ngày 1.
  final List<int> daily;
  final DateTime month;

  const RevenueBarChart({super.key, required this.daily, required this.month});

  @override
  State<RevenueBarChart> createState() => _RevenueBarChartState();
}

class _RevenueBarChartState extends State<RevenueBarChart> {
  int? _selected;

  @override
  void didUpdateWidget(RevenueBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month) _selected = null;
  }

  /// Làm tròn mốc trục lên số "đẹp" (1, 2, 5 x 10^n).
  static int _niceMax(int v) {
    if (v <= 0) return 1;
    var step = 1;
    while (step * 10 <= v) {
      step *= 10;
    }
    for (final m in [1, 2, 5, 10]) {
      if (m * step >= v) return m * step;
    }
    return 10 * step;
  }

  @override
  Widget build(BuildContext context) {
    final daily = widget.daily;
    final maxValue = _niceMax(daily.fold(0, (a, b) => a > b ? a : b));
    final sel = _selected;
    const chartHeight = 140.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 20,
          child: Text(
            sel == null
                ? OwnerFinanceStrings.chartHint
                : OwnerFinanceStrings.chartTooltip(sel + 1, widget.month.month, daily[sel]),
            style: TextStyle(
              fontSize: 12,
              color: sel == null ? AppColors.textSecondary : AppColors.textMain,
              fontWeight: sel == null ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(Formatters.currency(maxValue), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              // Lưới nhạt: mốc giữa và đỉnh.
              for (final f in [0.0, 0.5])
                Positioned(
                  top: chartHeight * f,
                  left: 0,
                  right: 0,
                  child: Container(height: 1, color: AppColors.divider),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < daily.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selected = _selected == i ? null : i),
                        child: Padding(
                          // Khe 2px giữa các cột.
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: daily[i] == 0 ? 0 : (chartHeight * daily[i] / maxValue).clamp(2.0, chartHeight),
                              decoration: BoxDecoration(
                                color: sel == null || sel == i
                                    ? AppColors.primaryGreen
                                    : AppColors.primaryGreen.withValues(alpha: 0.35),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Container(height: 1, color: AppColors.cardBorder),
        const SizedBox(height: 4),
        SizedBox(
          height: 14,
          child: Row(
            children: [
              for (var i = 0; i < daily.length; i++)
                Expanded(
                  child: (i == 0 || (i + 1) % 5 == 0)
                      ? OverflowBox(
                          maxWidth: 24,
                          maxHeight: 14,
                          child: Text(
                            '${i + 1}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
