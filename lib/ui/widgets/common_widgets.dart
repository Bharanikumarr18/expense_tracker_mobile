import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../utils/formatters.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
  });

  final String title;
  final double value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14),
                  const SizedBox(width: 6),
                ],
                Text(title, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatCurrency(value),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class TotalsPieChart extends StatefulWidget {
  const TotalsPieChart({super.key, required this.title, required this.rows});

  final String title;
  final List<TotalsRow> rows;

  @override
  State<TotalsPieChart> createState() => _TotalsPieChartState();
}

class _TotalsPieChartState extends State<TotalsPieChart> {
  int touched = -1;

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    if (rows.isEmpty) {
      return Card(
        child: SizedBox(
          height: 260,
          child: Center(child: Text('${widget.title}: no data')),
        ),
      );
    }

    final total = rows.fold<double>(0, (a, b) => a + b.amount);
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF06B6D4),
      const Color(0xFF22C55E),
      const Color(0xFFEAB308),
      const Color(0xFFF97316),
      const Color(0xFFEF4444),
      const Color(0xFFA855F7),
      const Color(0xFF14B8A6),
      const Color(0xFF8B5CF6),
      const Color(0xFF64748B),
      const Color(0xFFF43F5E),
      const Color(0xFF10B981),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          touched = -1;
                          return;
                        }
                        touched = response!.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  centerSpaceRadius: 45,
                  sectionsSpace: 2,
                  sections: List.generate(rows.length, (index) {
                    final row = rows[index];
                    final pct = total == 0 ? 0 : (row.amount / total) * 100;
                    final isTouched = index == touched;
                    return PieChartSectionData(
                      value: row.amount,
                      color: colors[index % colors.length],
                      radius: isTouched ? 90 : 78,
                      title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                      titleStyle: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      badgeWidget: isTouched
                          ? _TooltipBadge(
                              text:
                                  '${row.label}\n${formatCurrency(row.amount)} (${pct.toStringAsFixed(1)}%)',
                            )
                          : null,
                      badgePositionPercentageOffset: 1.4,
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(rows.length, (i) {
                final row = rows[i];
                final color = colors[i % colors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      row.label,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _TooltipBadge extends StatelessWidget {
  const _TooltipBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.85),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

Color randomPastelFrom(String text) {
  final seed = text.codeUnits.fold<int>(0, (a, b) => a + b);
  final rnd = Random(seed);
  return Color.fromARGB(
    255,
    120 + rnd.nextInt(120),
    120 + rnd.nextInt(120),
    120 + rnd.nextInt(120),
  );
}
