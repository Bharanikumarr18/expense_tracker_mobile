import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

enum AvgMode { weekly, monthly, yearly }

enum AnomalyGranularity { daily, weekly, monthly }

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool _loading = true;
  String? _error;
  List<ExpenseEntry> _entries = const [];

  AvgMode _avgMode = AvgMode.monthly;
  DateTime? _selectedMonth;
  String? _trendCategory;
  String? _trendSubcategory;
  AnomalyGranularity _granularity = AnomalyGranularity.daily;
  int _window = 14;
  double _threshold = 3.5;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repo.getExpenses(
        from: DateTime(2000, 1, 1),
        to: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _entries = data;
        _loading = false;
        if (_selectedMonth == null && data.isNotEmpty) {
          final months = _monthList(data);
          _selectedMonth = months.isNotEmpty ? months.first : null;
        }
        if (_trendCategory == null && data.isNotEmpty) {
          _trendCategory = data.first.category;
        }
        if (_trendCategory != null) {
          final subs =
              _entries
                  .where((e) => e.category == _trendCategory)
                  .map((e) => e.subcategory)
                  .toSet()
                  .toList()
                ..sort();
          _trendSubcategory ??= subs.isNotEmpty ? subs.first : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<DateTime> _monthList(List<ExpenseEntry> rows) {
    final set = <String, DateTime>{};
    for (final e in rows) {
      final m = DateTime(e.date.year, e.date.month, 1);
      set['${m.year}-${m.month}'] = m;
    }
    final months = set.values.toList()..sort((a, b) => b.compareTo(a));
    return months;
  }

  Map<DateTime, double> _groupByPeriod(
    List<ExpenseEntry> rows,
    AnomalyGranularity granularity,
  ) {
    final map = <DateTime, double>{};
    for (final e in rows) {
      DateTime key;
      switch (granularity) {
        case AnomalyGranularity.weekly:
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          key = d.subtract(Duration(days: d.weekday - 1));
          break;
        case AnomalyGranularity.monthly:
          key = DateTime(e.date.year, e.date.month, 1);
          break;
        case AnomalyGranularity.daily:
          key = DateTime(e.date.year, e.date.month, e.date.day);
          break;
      }
      map[key] = (map[key] ?? 0) + e.amount;
    }
    return map;
  }

  double _averageSpend(List<ExpenseEntry> rows, AvgMode mode) {
    if (rows.isEmpty) return 0;
    final map = <String, double>{};
    for (final e in rows) {
      String key;
      switch (mode) {
        case AvgMode.weekly:
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          final week = d.subtract(Duration(days: d.weekday - 1));
          key = '${week.year}-${week.month}-${week.day}';
          break;
        case AvgMode.monthly:
          key = '${e.date.year}-${e.date.month}';
          break;
        case AvgMode.yearly:
          key = '${e.date.year}';
          break;
      }
      map[key] = (map[key] ?? 0) + e.amount;
    }
    if (map.isEmpty) return 0;
    final sum = map.values.fold<double>(0, (a, b) => a + b);
    return sum / map.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Insights failed to load'),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return const EmptyState(message: 'No expenses available yet.');
    }

    final avg = _averageSpend(_entries, _avgMode);
    final months = _monthList(_entries);
    final monthlyTotals = <DateTime, double>{};
    for (final e in _entries) {
      final key = DateTime(e.date.year, e.date.month, 1);
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + e.amount;
    }
    final topMonth = monthlyTotals.entries.isNotEmpty
        ? (monthlyTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
        : null;

    final selectedMonth =
        _selectedMonth ?? (months.isNotEmpty ? months.first : null);
    final monthRows = selectedMonth == null
        ? <ExpenseEntry>[]
        : _entries
              .where(
                (e) =>
                    e.date.year == selectedMonth.year &&
                    e.date.month == selectedMonth.month,
              )
              .toList();

    final topCats = <String, double>{};
    final topSubs = <String, double>{};
    for (final e in monthRows) {
      topCats[e.category] = (topCats[e.category] ?? 0) + e.amount;
      topSubs[e.subcategory] = (topSubs[e.subcategory] ?? 0) + e.amount;
    }
    final topCatList = topCats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSubList = topSubs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final categories = _entries.map((e) => e.category).toSet().toList()..sort();
    final selectedCategory =
        _trendCategory ?? (categories.isNotEmpty ? categories.first : null);
    final subcats =
        _entries
            .where((e) => e.category == selectedCategory)
            .map((e) => e.subcategory)
            .toSet()
            .toList()
          ..sort();
    final selectedSub =
        _trendSubcategory ?? (subcats.isNotEmpty ? subcats.first : null);

    final trendMap = <DateTime, double>{};
    if (selectedCategory != null && selectedSub != null) {
      for (final e in _entries) {
        if (e.category != selectedCategory || e.subcategory != selectedSub)
          continue;
        final key = DateTime(e.date.year, e.date.month, 1);
        trendMap[key] = (trendMap[key] ?? 0) + e.amount;
      }
    }
    final trendList = trendMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    double? trendDiff;
    double? trendPct;
    if (trendList.length >= 2) {
      final last = trendList[trendList.length - 1].value;
      final prev = trendList[trendList.length - 2].value;
      trendDiff = last - prev;
      trendPct = prev == 0 ? 100.0 : (trendDiff / prev) * 100.0;
    }

    final series = _groupByPeriod(_entries, _granularity);
    final seriesList = series.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final anomalies = <_AnomalyPoint>[];
    if (seriesList.length >= 4) {
      final values = seriesList.map((e) => e.value).toList();
      for (var i = 0; i < seriesList.length; i++) {
        final start = max(0, i - _window ~/ 2);
        final end = min(seriesList.length, i + _window ~/ 2 + 1);
        final windowValues = values.sublist(start, end)..sort();
        final median = windowValues[windowValues.length ~/ 2];
        final deviations = windowValues.map((v) => (v - median).abs()).toList()
          ..sort();
        final mad = deviations[deviations.length ~/ 2];
        final z = mad == 0 ? 0.0 : 0.6745 * (values[i] - median) / mad;
        if (z.abs() > _threshold) {
          anomalies.add(
            _AnomalyPoint(date: seriesList[i].key, value: values[i], z: z),
          );
        }
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Insights',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Average Spend',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<AvgMode>(
                        value: _avgMode,
                        items: const [
                          DropdownMenuItem(
                            value: AvgMode.weekly,
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem(
                            value: AvgMode.monthly,
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: AvgMode.yearly,
                            child: Text('Yearly'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _avgMode = v ?? AvgMode.monthly),
                      ),
                      Text('Average: ${formatCurrency(avg)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (topMonth != null)
                    Text(
                      'Highest Month: ${formatPrettyDate(topMonth.key)} — ${formatCurrency(topMonth.value)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top 5 (Selected Month)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<DateTime>(
                    value: selectedMonth,
                    items: months
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              '${m.year}-${m.month.toString().padLeft(2, '0')}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _selectedMonth = v),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 720;
                      final left = _TopList(
                        title: 'Categories',
                        items: topCatList.take(5).toList(),
                      );
                      final right = _TopList(
                        title: 'Subcategories',
                        items: topSubList.take(5).toList(),
                      );
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: 12),
                            Expanded(child: right),
                          ],
                        );
                      }
                      return Column(
                        children: [left, const SizedBox(height: 8), right],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category Trend Comparison',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: selectedCategory,
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _trendCategory = v),
                  ),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: selectedSub,
                    items: subcats
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _trendSubcategory = v),
                  ),
                  const SizedBox(height: 8),
                  if (trendDiff == null)
                    const Text('Not enough data for comparison')
                  else
                    Builder(
                      builder: (context) {
                        final diff = trendDiff ?? 0;
                        final pct = trendPct ?? 0;
                        return Text(
                          'Change vs previous month: ${diff >= 0 ? '+' : '-'}${formatCurrency(diff.abs())} (${pct.abs().toStringAsFixed(1)}%)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopList extends StatelessWidget {
  const _TopList({required this.title, required this.items});
  final String title;
  final List<MapEntry<String, double>> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (items.isEmpty)
              const Text('No data')
            else
              ...items.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${e.key} — ${formatCurrency(e.value)}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnomalyPoint {
  final DateTime date;
  final double value;
  final double z;

  _AnomalyPoint({required this.date, required this.value, required this.z});
}
