import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

enum DashboardMode { monthly, yearly, custom }

enum SubChartView { pie, bar }

enum DetailFilterMode { monthly, last7, custom }

class _MonthlySnapshot {
  final DateTime month;
  final double total;
  final double avgDay;
  final int txCount;
  final DateTime? peakDay;
  final double peakAmount;
  final String topCategory;
  final String topSubcategory;

  const _MonthlySnapshot({
    required this.month,
    required this.total,
    required this.avgDay,
    required this.txCount,
    required this.peakDay,
    required this.peakAmount,
    required this.topCategory,
    required this.topSubcategory,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  DashboardSummary _summary = const DashboardSummary(
    monthIncome: 0,
    monthExpense: 0,
    net: 0,
    last7: 0,
    yearToDate: 0,
  );
  List<TotalsRow> _catRows = const [];
  List<TotalsRow> _subRows = const [];
  List<ExpenseEntry> _daily = const [];
  List<ExpenseEntry> _periodEntries = const [];
  List<ExpenseEntry> _allEntries = const [];
  List<_MonthlySnapshot> _snapshots = const [];

  DashboardMode _mode = DashboardMode.monthly;
  SubChartView _subChartView = SubChartView.pie;
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  int _selectedYear = DateTime.now().year;
  DateTime _customFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _customTo = DateTime.now();
  DateTime _dailyDate = DateTime.now();
  String _subCategoryFilter = 'All';
  List<String> _subCategoryFilterOptions = const ['All'];
  String? _barSubcategory;

  String? _detailCategory;
  String? _detailSubcategory;
  DetailFilterMode _detailMode = DetailFilterMode.monthly;
  DateTime _detailMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _detailFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _detailTo = DateTime.now();
  bool _cumulativeMonthly = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  (DateTime, DateTime) _range() {
    switch (_mode) {
      case DashboardMode.monthly:
        return (monthStart(_selectedMonth), monthEnd(_selectedMonth));
      case DashboardMode.yearly:
        final d = DateTime(_selectedYear, 1, 1);
        return (yearStart(d), yearEnd(d));
      case DashboardMode.custom:
        return (_customFrom, _customTo);
    }
  }

  List<_MonthlySnapshot> _buildSnapshots(List<ExpenseEntry> rows) {
    if (rows.isEmpty) return const [];
    final byMonth = <DateTime, List<ExpenseEntry>>{};
    for (final e in rows) {
      final key = DateTime(e.date.year, e.date.month, 1);
      byMonth.putIfAbsent(key, () => []).add(e);
    }
    final snapshots = <_MonthlySnapshot>[];
    for (final entry in byMonth.entries) {
      final month = entry.key;
      final data = entry.value;
      final total = data.fold<double>(0, (a, b) => a + b.amount);
      final daySet = data
          .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
          .toSet();
      final days = daySet.length == 0 ? 1 : daySet.length;
      final avgDay = total / days;
      final txCount = data.length;
      final byDay = <DateTime, double>{};
      for (final e in data) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        byDay[d] = (byDay[d] ?? 0) + e.amount;
      }
      DateTime? peakDay;
      double peakAmount = 0;
      for (final d in byDay.entries) {
        if (d.value > peakAmount) {
          peakAmount = d.value;
          peakDay = d.key;
        }
      }
      final byCat = <String, double>{};
      final bySub = <String, double>{};
      for (final e in data) {
        byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
        bySub[e.subcategory] = (bySub[e.subcategory] ?? 0) + e.amount;
      }
      final topCategory = byCat.entries.isEmpty
          ? '-'
          : (byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                .first
                .key;
      final topSub = bySub.entries.isEmpty
          ? '-'
          : (bySub.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                .first
                .key;

      snapshots.add(
        _MonthlySnapshot(
          month: month,
          total: total,
          avgDay: avgDay,
          txCount: txCount,
          peakDay: peakDay,
          peakAmount: peakAmount,
          topCategory: topCategory,
          topSubcategory: topSub,
        ),
      );
    }
    snapshots.sort((a, b) => b.month.compareTo(a.month));
    return snapshots;
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final summary = await widget.repo.getDashboardSummary(now);
      final (from, to) = _range();
      final cat = await widget.repo.expenseTotalsByCategory(from: from, to: to);
      final filterOptions = <String>[
        'All',
        ...cat.map((e) => e.label).where((e) => e.trim().isNotEmpty),
      ];
      final selectedFilter = filterOptions.contains(_subCategoryFilter)
          ? _subCategoryFilter
          : 'All';
      final sub = await widget.repo.expenseTotalsBySubcategory(
        from: from,
        to: to,
        category: selectedFilter == 'All' ? null : selectedFilter,
      );
      final daily = await widget.repo.dailyBuy(_dailyDate);
      final periodEntries = await widget.repo.getExpenses(from: from, to: to);

      List<ExpenseEntry> allEntries = _allEntries;
      if (allEntries.isEmpty) {
        allEntries = await widget.repo.getExpenses(
          from: DateTime(2000, 1, 1),
          to: DateTime.now(),
        );
      }
      final snapshots = _buildSnapshots(allEntries);

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _catRows = cat;
        _subRows = sub;
        _subCategoryFilterOptions = filterOptions;
        _subCategoryFilter = selectedFilter;
        _daily = daily;
        _periodEntries = periodEntries;
        _allEntries = allEntries;
        _snapshots = snapshots;
        if (_barSubcategory == null && sub.isNotEmpty) {
          _barSubcategory = sub.first.label;
        }
        if (_detailCategory == null && periodEntries.isNotEmpty) {
          _detailCategory = periodEntries.first.category;
        }
        if (_detailCategory != null) {
          final options =
              periodEntries
                  .where((e) => e.category == _detailCategory)
                  .map((e) => e.subcategory)
                  .toSet()
                  .toList()
                ..sort();
          _detailSubcategory ??= options.isNotEmpty ? options.first : null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from ? _customFrom : _customTo;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _customFrom = picked;
        if (_customTo.isBefore(_customFrom)) {
          _customTo = _customFrom;
        }
      } else {
        _customTo = picked;
        if (_customTo.isBefore(_customFrom)) {
          _customFrom = _customTo;
        }
      }
    });
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
              const Text('Dashboard failed to load'),
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

    final (from, to) = _range();
    final detailCategories = _allEntries.map((e) => e.category).toSet().toList()
      ..sort();
    final detailSubcategories =
        _allEntries
            .where((e) => e.category == _detailCategory)
            .map((e) => e.subcategory)
            .toSet()
            .toList()
          ..sort();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Text(
                'Expense Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: _refresh, child: const Text('Refresh')),
            ],
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Monthly Snapshot Cards'),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              if (_snapshots.isEmpty)
                const Text('No snapshot data yet.')
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _snapshots
                      .map((s) => _SnapshotCard(snapshot: s))
                      .toList(growable: false),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 980 ? 3 : 2;
              final ratio = width < 420
                  ? 1.55
                  : (crossAxisCount == 3 ? 2.6 : 1.85);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: ratio,
                children: [
                  SummaryCard(
                    title: 'Total Income',
                    value: _summary.monthIncome,
                  ),
                  SummaryCard(
                    title: 'Total Expense',
                    value: _summary.monthExpense,
                  ),
                  SummaryCard(title: 'Net Balance', value: _summary.net),
                  SummaryCard(title: 'Last 7 Days', value: _summary.last7),
                  SummaryCard(title: 'Year So Far', value: _summary.yearToDate),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final isNarrow = width < 420;
                      final half = ((width - 8) / 2).clamp(120.0, width);
                      final modeWidth = isNarrow ? half : 130.0;
                      final monthWidth = isNarrow ? half : 150.0;
                      final yearWidth = isNarrow ? half : 110.0;
                      final subWidth = isNarrow ? width : 200.0;
                      final chartWidth = isNarrow ? half : 140.0;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: modeWidth,
                            child: DropdownButtonFormField<DashboardMode>(
                              value: _mode,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Mode',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: DashboardMode.monthly,
                                  child: Text('Monthly'),
                                ),
                                DropdownMenuItem(
                                  value: DashboardMode.yearly,
                                  child: Text('Yearly'),
                                ),
                                DropdownMenuItem(
                                  value: DashboardMode.custom,
                                  child: Text('Custom'),
                                ),
                              ],
                              onChanged: (v) => setState(
                                () => _mode = v ?? DashboardMode.monthly,
                              ),
                            ),
                          ),
                          if (_mode == DashboardMode.monthly)
                            SizedBox(
                              width: monthWidth,
                              child: DropdownButtonFormField<DateTime>(
                                value: _selectedMonth,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Month',
                                ),
                                items: List.generate(24, (i) {
                                  final d = DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month - i,
                                    1,
                                  );
                                  return DropdownMenuItem(
                                    value: d,
                                    child: Text(
                                      '${d.year}-${d.month.toString().padLeft(2, '0')}',
                                    ),
                                  );
                                }),
                                onChanged: (v) => setState(
                                  () => _selectedMonth = v ?? _selectedMonth,
                                ),
                              ),
                            ),
                          if (_mode == DashboardMode.yearly)
                            SizedBox(
                              width: yearWidth,
                              child: DropdownButtonFormField<int>(
                                value: _selectedYear,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Year',
                                ),
                                items: List.generate(10, (i) {
                                  final y = DateTime.now().year - i;
                                  return DropdownMenuItem(
                                    value: y,
                                    child: Text(y.toString()),
                                  );
                                }),
                                onChanged: (v) => setState(
                                  () => _selectedYear = v ?? _selectedYear,
                                ),
                              ),
                            ),
                          if (_mode == DashboardMode.custom)
                            SizedBox(
                              width: half,
                              child: OutlinedButton(
                                onPressed: () => _pickDate(from: true),
                                child: Text(
                                  'From: ${formatIsoDate(_customFrom)}',
                                ),
                              ),
                            ),
                          if (_mode == DashboardMode.custom)
                            SizedBox(
                              width: half,
                              child: OutlinedButton(
                                onPressed: () => _pickDate(from: false),
                                child: Text('To: ${formatIsoDate(_customTo)}'),
                              ),
                            ),
                          SizedBox(
                            width: subWidth,
                            child: DropdownButtonFormField<String>(
                              value: _subCategoryFilter,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Subcategory',
                              ),
                              items: _subCategoryFilterOptions
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (v) async {
                                if (v == null) return;
                                setState(() => _subCategoryFilter = v);
                                await _refresh();
                              },
                            ),
                          ),
                          SizedBox(
                            width: chartWidth,
                            child: DropdownButtonFormField<SubChartView>(
                              value: _subChartView,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Chart',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: SubChartView.pie,
                                  child: Text('Pie'),
                                ),
                                DropdownMenuItem(
                                  value: SubChartView.bar,
                                  child: Text('Bar'),
                                ),
                              ],
                              onChanged: (v) => setState(
                                () => _subChartView = v ?? SubChartView.pie,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _refresh,
                            child: const Text('Refresh Charts'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total for selected period: ${formatCurrency(_catRows.fold(0, (a, b) => a + b.amount))}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Spending Distribution',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final charts = [
                TotalsPieChart(title: 'By Category', rows: _catRows),
                _subChartView == SubChartView.pie
                    ? TotalsPieChart(
                        title: _subCategoryFilter == 'All'
                            ? 'By Subcategory'
                            : 'By Subcategory ($_subCategoryFilter)',
                        rows: _subRows,
                      )
                    : TotalsBarChart(
                        title: _subCategoryFilter == 'All'
                            ? 'By Subcategory'
                            : 'By Subcategory ($_subCategoryFilter)',
                        rows: _subRows,
                      ),
              ];
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: charts[0]),
                    const SizedBox(width: 8),
                    Expanded(child: charts[1]),
                  ],
                );
              }
              return Column(
                children: [charts[0], const SizedBox(height: 8), charts[1]],
              );
            },
          ),
          if (_subChartView == SubChartView.bar && _subRows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transactions for Subcategory',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth < 420
                            ? constraints.maxWidth
                            : 320.0;
                        return SizedBox(
                          width: width,
                          child: DropdownButtonFormField<String>(
                            value: _barSubcategory,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Subcategory',
                            ),
                            items: _subRows
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.label,
                                    child: Text(
                                      e.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (v) =>
                                setState(() => _barSubcategory = v),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    ..._periodEntries
                        .where((e) => e.subcategory == _barSubcategory)
                        .toList()
                        .take(20)
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${formatIsoDate(e.date)} • ${e.subcategory} • ${formatCurrency(e.amount)}',
                            ),
                          ),
                        ),
                    if (_periodEntries
                        .where((e) => e.subcategory == _barSubcategory)
                        .isEmpty)
                      const Text('No transactions found for this subcategory.'),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Daily Buy Date',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDate: _dailyDate,
                          );
                          if (picked != null) {
                            setState(() => _dailyDate = picked);
                            await _refresh();
                          }
                        },
                        child: Text(formatIsoDate(_dailyDate)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_daily.isEmpty)
                    const Text('No entries for selected date.')
                  else ...[
                    for (final e in _daily)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${e.subcategory} — ${formatCurrency(e.amount)}',
                        ),
                      ),
                    const Divider(),
                    Text(
                      'Total — ${formatCurrency(_daily.fold<double>(0, (a, b) => a + b.amount))}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Cumulative Spending Curve'),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              SwitchListTile.adaptive(
                value: _cumulativeMonthly,
                onChanged: (v) => setState(() => _cumulativeMonthly = v),
                title: Text(_cumulativeMonthly ? 'Monthly' : 'Daily'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              _CumulativeChart(
                entries: _periodEntries,
                monthly: _cumulativeMonthly,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('View Subcategory Details Table'),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final narrow = width < 420;
                  final categoryWidth = narrow ? width : 230.0;
                  final subcategoryWidth = narrow ? width : 230.0;
                  final modeWidth = narrow ? width : 170.0;
                  final monthWidth = narrow ? width : 150.0;
                  final dateWidth = narrow ? width : 180.0;

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: categoryWidth,
                        child: DropdownButtonFormField<String>(
                          value: _detailCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: detailCategories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) => setState(() {
                            _detailCategory = v;
                            final subs =
                                _allEntries
                                    .where((e) => e.category == v)
                                    .map((e) => e.subcategory)
                                    .toSet()
                                    .toList()
                                  ..sort();
                            _detailSubcategory = subs.isNotEmpty
                                ? subs.first
                                : null;
                          }),
                        ),
                      ),
                      SizedBox(
                        width: subcategoryWidth,
                        child: DropdownButtonFormField<String>(
                          value: _detailSubcategory,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Subcategory',
                          ),
                          items: detailSubcategories
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) =>
                              setState(() => _detailSubcategory = v),
                        ),
                      ),
                      SizedBox(
                        width: modeWidth,
                        child: DropdownButtonFormField<DetailFilterMode>(
                          value: _detailMode,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Mode'),
                          items: const [
                            DropdownMenuItem(
                              value: DetailFilterMode.monthly,
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: DetailFilterMode.last7,
                              child: Text('Last 7 Days'),
                            ),
                            DropdownMenuItem(
                              value: DetailFilterMode.custom,
                              child: Text('Custom'),
                            ),
                          ],
                          onChanged: (v) => setState(
                            () => _detailMode = v ?? DetailFilterMode.monthly,
                          ),
                        ),
                      ),
                      if (_detailMode == DetailFilterMode.monthly)
                        SizedBox(
                          width: monthWidth,
                          child: DropdownButtonFormField<DateTime>(
                            value: _detailMonth,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Month',
                            ),
                            items: List.generate(24, (i) {
                              final d = DateTime(
                                DateTime.now().year,
                                DateTime.now().month - i,
                                1,
                              );
                              return DropdownMenuItem(
                                value: d,
                                child: Text(
                                  '${d.year}-${d.month.toString().padLeft(2, '0')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                            onChanged: (v) => setState(
                              () => _detailMonth = v ?? _detailMonth,
                            ),
                          ),
                        ),
                      if (_detailMode == DetailFilterMode.custom)
                        SizedBox(
                          width: dateWidth,
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                initialDate: _detailFrom,
                              );
                              if (picked != null) {
                                setState(() => _detailFrom = picked);
                              }
                            },
                            child: Text(
                              'From ${formatIsoDate(_detailFrom)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      if (_detailMode == DetailFilterMode.custom)
                        SizedBox(
                          width: dateWidth,
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                initialDate: _detailTo,
                              );
                              if (picked != null) {
                                setState(() => _detailTo = picked);
                              }
                            },
                            child: Text(
                              'To ${formatIsoDate(_detailTo)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  if (_detailCategory == null || _detailSubcategory == null) {
                    return const Text('Select category and subcategory.');
                  }
                  DateTime start;
                  DateTime end;
                  switch (_detailMode) {
                    case DetailFilterMode.monthly:
                      start = monthStart(_detailMonth);
                      end = monthEnd(_detailMonth);
                      break;
                    case DetailFilterMode.last7:
                      end = DateTime.now();
                      start = end.subtract(const Duration(days: 6));
                      break;
                    case DetailFilterMode.custom:
                      start = _detailFrom;
                      end = _detailTo;
                      break;
                  }
                  final rows =
                      _allEntries
                          .where(
                            (e) =>
                                e.category == _detailCategory &&
                                e.subcategory == _detailSubcategory &&
                                !e.date.isBefore(start) &&
                                !e.date.isAfter(end),
                          )
                          .toList()
                        ..sort((a, b) => b.date.compareTo(a.date));

                  if (rows.isEmpty) {
                    return const Text('No records for this selection.');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...rows
                          .take(40)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${formatIsoDate(e.date)} • ${e.subcategory} • ${formatCurrency(e.amount)}',
                              ),
                            ),
                          ),
                      const Divider(),
                      Text(
                        'Total: ${formatCurrency(rows.fold<double>(0, (a, b) => a + b.amount))}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Range: ${formatIsoDate(from)} to ${formatIsoDate(to)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot});

  final _MonthlySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${snapshot.month.year}-${snapshot.month.month.toString().padLeft(2, '0')}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text('Total: ${formatCurrency(snapshot.total)}'),
              Text('Avg/day: ${formatCurrency(snapshot.avgDay)}'),
              Text('Transactions: ${snapshot.txCount}'),
              Text(
                'Peak day: ${snapshot.peakDay == null ? '-' : formatPrettyDate(snapshot.peakDay!)} (${formatCurrency(snapshot.peakAmount)})',
              ),
              Text('Top category: ${snapshot.topCategory}'),
              Text('Top subcategory: ${snapshot.topSubcategory}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CumulativeChart extends StatelessWidget {
  const _CumulativeChart({required this.entries, required this.monthly});

  final List<ExpenseEntry> entries;
  final bool monthly;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('No data for selected period.');
    }

    final map = <DateTime, double>{};
    for (final e in entries) {
      final key = monthly
          ? DateTime(e.date.year, e.date.month, 1)
          : DateTime(e.date.year, e.date.month, e.date.day);
      map[key] = (map[key] ?? 0) + e.amount;
    }
    final points = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    double running = 0;
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      running += points[i].value;
      spots.add(FlSpot(i.toDouble(), running));
    }

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
