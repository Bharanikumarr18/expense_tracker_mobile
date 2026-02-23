import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

enum DashboardMode { monthly, yearly, custom }

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

  DashboardMode _mode = DashboardMode.monthly;
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  int _selectedYear = DateTime.now().year;
  DateTime _customFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _customTo = DateTime.now();
  DateTime _dailyDate = DateTime.now();

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
      final sub = await widget.repo.expenseTotalsBySubcategory(
        from: from,
        to: to,
      );
      final daily = await widget.repo.dailyBuy(_dailyDate);

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _catRows = cat;
        _subRows = sub;
        _daily = daily;
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 240,
                child: SummaryCard(
                  title: 'Total Income',
                  value: _summary.monthIncome,
                ),
              ),
              SizedBox(
                width: 240,
                child: SummaryCard(
                  title: 'Total Expense',
                  value: _summary.monthExpense,
                ),
              ),
              SizedBox(
                width: 240,
                child: SummaryCard(title: 'Net Balance', value: _summary.net),
              ),
              SizedBox(
                width: 240,
                child: SummaryCard(title: 'Last 7 Days', value: _summary.last7),
              ),
              SizedBox(
                width: 240,
                child: SummaryCard(
                  title: 'Year So Far',
                  value: _summary.yearToDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<DashboardMode>(
                        value: _mode,
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
                        onChanged: (v) =>
                            setState(() => _mode = v ?? DashboardMode.monthly),
                      ),
                      if (_mode == DashboardMode.monthly)
                        DropdownButton<DateTime>(
                          value: _selectedMonth,
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
                      if (_mode == DashboardMode.yearly)
                        DropdownButton<int>(
                          value: _selectedYear,
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
                      if (_mode == DashboardMode.custom)
                        OutlinedButton(
                          onPressed: () => _pickDate(from: true),
                          child: Text('From: ${formatIsoDate(_customFrom)}'),
                        ),
                      if (_mode == DashboardMode.custom)
                        OutlinedButton(
                          onPressed: () => _pickDate(from: false),
                          child: Text('To: ${formatIsoDate(_customTo)}'),
                        ),
                      ElevatedButton(
                        onPressed: _refresh,
                        child: const Text('Refresh Charts'),
                      ),
                    ],
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
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TotalsPieChart(
                        title: 'By Category',
                        rows: _catRows,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TotalsPieChart(
                        title: 'By Subcategory',
                        rows: _subRows,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  TotalsPieChart(title: 'By Category', rows: _catRows),
                  const SizedBox(height: 8),
                  TotalsPieChart(title: 'By Subcategory', rows: _subRows),
                ],
              );
            },
          ),
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
