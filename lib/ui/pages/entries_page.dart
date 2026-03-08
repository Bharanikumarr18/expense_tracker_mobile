import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

enum EntriesType { expense, income }

enum EntriesRangeMode { monthly, custom }

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  bool _loading = true;
  bool _loadingRows = false;
  String? _error;

  EntriesType _type = EntriesType.expense;
  EntriesRangeMode _rangeMode = EntriesRangeMode.monthly;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  List<DateTime> _expenseMonths = const [];
  List<DateTime> _incomeMonths = const [];
  List<Category> _expenseCategories = const [];
  List<Category> _incomeCategories = const [];

  int? _categoryId;
  int? _subcategoryId;

  List<_EntriesRow> _rows = const [];
  double _filteredTotal = 0;
  int _rowsPerPage = PaginatedDataTable.defaultRowsPerPage;

  late final _EntriesDataSource _tableSource;

  @override
  void initState() {
    super.initState();
    _tableSource = _EntriesDataSource(const []);
    _bootstrap();
  }

  @override
  void dispose() {
    _tableSource.dispose();
    super.dispose();
  }

  DateTime _monthOnly(DateTime d) => DateTime(d.year, d.month, 1);

  String _monthLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  bool _containsMonth(List<DateTime> months, DateTime target) {
    return months.any((m) => m.year == target.year && m.month == target.month);
  }

  List<DateTime> get _activeMonths {
    if (_type == EntriesType.expense) {
      return _expenseMonths;
    }
    return _incomeMonths;
  }

  List<Category> get _activeCategories {
    if (_type == EntriesType.expense) {
      return _expenseCategories;
    }
    return _incomeCategories;
  }

  void _normalizeFilterSelections() {
    final months = _activeMonths;
    if (!_containsMonth(months, _selectedMonth)) {
      _selectedMonth = months.first;
    }

    if (_categoryId != null &&
        !_activeCategories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    final validSubIds = _subcategoryOptions.map((e) => e.id).toSet();
    if (_subcategoryId != null && !validSubIds.contains(_subcategoryId)) {
      _subcategoryId = null;
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final expenseCategories = await widget.repo.getExpenseCategories();
      final incomeCategories = await widget.repo.getIncomeCategories();
      final expenseMonthsRaw = await widget.repo.getExpenseMonths();
      final incomeMonthsRaw = await widget.repo.getIncomeMonths();

      final fallbackMonth = _monthOnly(DateTime.now());
      final expenseMonths = expenseMonthsRaw.isEmpty
          ? <DateTime>[fallbackMonth]
          : expenseMonthsRaw.map(_monthOnly).toList(growable: false);
      final incomeMonths = incomeMonthsRaw.isEmpty
          ? <DateTime>[fallbackMonth]
          : incomeMonthsRaw.map(_monthOnly).toList(growable: false);

      if (!mounted) return;
      setState(() {
        _expenseCategories = expenseCategories;
        _incomeCategories = incomeCategories;
        _expenseMonths = expenseMonths;
        _incomeMonths = incomeMonths;
        _normalizeFilterSelections();
        _loading = false;
      });

      await _loadEntries();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onChanged,
  }) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  List<_SubFilterItem> get _subcategoryOptions {
    final categories = _activeCategories;
    if (categories.isEmpty) {
      return const [];
    }

    if (_categoryId != null) {
      final category = categories
          .where((c) => c.id == _categoryId)
          .cast<Category?>()
          .firstWhere((c) => c != null, orElse: () => null);
      if (category == null) {
        return const [];
      }
      final items =
          category.subcategories
              .map((s) => _SubFilterItem(id: s.id, label: s.name))
              .toList(growable: false)
            ..sort(
              (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
            );
      return items;
    }

    final all = <_SubFilterItem>[];
    for (final category in categories) {
      for (final sub in category.subcategories) {
        all.add(
          _SubFilterItem(id: sub.id, label: '${sub.name} (${category.name})'),
        );
      }
    }
    all.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return all;
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loadingRows = true;
      _error = null;
    });

    try {
      late final DateTime from;
      late final DateTime to;
      if (_rangeMode == EntriesRangeMode.monthly) {
        from = monthStart(_selectedMonth);
        to = monthEnd(_selectedMonth);
      } else {
        var customFrom = _from;
        var customTo = _to;
        if (customTo.isBefore(customFrom)) {
          customTo = customFrom;
        }
        from = customFrom;
        to = customTo;
      }

      final rows = <_EntriesRow>[];
      if (_type == EntriesType.expense) {
        final data = await widget.repo.getExpenses(
          from: from,
          to: to,
          categoryId: _categoryId,
          subcategoryId: _subcategoryId,
        );
        for (final entry in data) {
          rows.add(
            _EntriesRow(
              date: entry.date,
              typeLabel: 'Expense',
              category: entry.category,
              subcategory: entry.subcategory,
              amount: entry.amount,
            ),
          );
        }
      } else {
        final data = await widget.repo.getIncomes(
          from: from,
          to: to,
          categoryId: _categoryId,
          subcategoryId: _subcategoryId,
        );
        for (final entry in data) {
          rows.add(
            _EntriesRow(
              date: entry.date,
              typeLabel: 'Income',
              category: entry.category,
              subcategory: entry.subcategory,
              amount: entry.amount,
            ),
          );
        }
      }

      final total = rows.fold<double>(0, (a, b) => a + b.amount);

      if (!mounted) return;
      _tableSource.setRows(rows);
      setState(() {
        _rows = rows;
        _filteredTotal = total;
        _loadingRows = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRows = false;
        _error = e.toString();
      });
    }
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
              const Text('Entries page failed to load'),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _bootstrap, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final monthOptions = _activeMonths;
    final categories = _activeCategories;
    final subcategoryOptions = _subcategoryOptions;

    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Entries',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final narrow = width < 460;
                  final full = width;
                  final typeWidth = narrow ? full : 150.0;
                  final modeWidth = narrow ? full : 140.0;
                  final monthWidth = narrow ? full : 160.0;
                  final categoryWidth = narrow ? full : 250.0;
                  final subWidth = narrow ? full : 280.0;
                  final dateWidth = narrow ? full : 180.0;
                  final buttonWidth = narrow ? full : 150.0;

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: typeWidth,
                        child: DropdownButtonFormField<EntriesType>(
                          value: _type,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(
                              value: EntriesType.expense,
                              child: Text('Expense'),
                            ),
                            DropdownMenuItem(
                              value: EntriesType.income,
                              child: Text('Income'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _type = v;
                              _categoryId = null;
                              _subcategoryId = null;
                              _normalizeFilterSelections();
                            });
                            _loadEntries();
                          },
                        ),
                      ),
                      SizedBox(
                        width: modeWidth,
                        child: DropdownButtonFormField<EntriesRangeMode>(
                          value: _rangeMode,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Range'),
                          items: const [
                            DropdownMenuItem(
                              value: EntriesRangeMode.monthly,
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: EntriesRangeMode.custom,
                              child: Text('Date Wise'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _rangeMode = v);
                            _loadEntries();
                          },
                        ),
                      ),
                      if (_rangeMode == EntriesRangeMode.monthly)
                        SizedBox(
                          width: monthWidth,
                          child: DropdownButtonFormField<DateTime>(
                            value: _selectedMonth,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Month',
                            ),
                            items: monthOptions
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(
                                      _monthLabel(d),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _selectedMonth = v);
                              _loadEntries();
                            },
                          ),
                        ),
                      if (_rangeMode == EntriesRangeMode.custom)
                        SizedBox(
                          width: dateWidth,
                          child: OutlinedButton(
                            onPressed: () => _pickDate(
                              initial: _from,
                              onChanged: (v) => setState(() {
                                _from = v;
                                if (_to.isBefore(_from)) {
                                  _to = _from;
                                }
                              }),
                            ),
                            child: Text(
                              'From ${formatIsoDate(_from)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      if (_rangeMode == EntriesRangeMode.custom)
                        SizedBox(
                          width: dateWidth,
                          child: OutlinedButton(
                            onPressed: () => _pickDate(
                              initial: _to,
                              onChanged: (v) => setState(() {
                                _to = v;
                                if (_to.isBefore(_from)) {
                                  _from = _to;
                                }
                              }),
                            ),
                            child: Text(
                              'To ${formatIsoDate(_to)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: categoryWidth,
                        child: DropdownButtonFormField<int?>(
                          value: _categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All categories'),
                            ),
                            ...categories.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(
                                  c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _categoryId = v;
                              _subcategoryId = null;
                              _normalizeFilterSelections();
                            });
                            _loadEntries();
                          },
                        ),
                      ),
                      SizedBox(
                        width: subWidth,
                        child: DropdownButtonFormField<int?>(
                          value: _subcategoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Subcategory',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All subcategories'),
                            ),
                            ...subcategoryOptions.map(
                              (s) => DropdownMenuItem<int?>(
                                value: s.id,
                                child: Text(
                                  s.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => _subcategoryId = v);
                            _loadEntries();
                          },
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        child: ElevatedButton.icon(
                          onPressed: _loadingRows ? null : _loadEntries,
                          icon: const Icon(Icons.search),
                          label: const Text('Load Entries'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingRows)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_rows.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: EmptyState(
                  message: 'No entries found for current filters.',
                ),
              ),
            )
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 760),
                  child: PaginatedDataTable(
                    header: const Text('Filtered Entries Table'),
                    showFirstLastButtons: true,
                    rowsPerPage: _rowsPerPage,
                    availableRowsPerPage: const [5, 10, 20, 50],
                    onRowsPerPageChanged: (v) {
                      if (v == null) return;
                      setState(() => _rowsPerPage = v);
                    },
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Subcategory')),
                      DataColumn(label: Text('Amount'), numeric: true),
                    ],
                    source: _tableSource,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(
                'Total (${_rows.length} rows)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              trailing: Text(
                formatCurrency(_filteredTotal),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntriesRow {
  const _EntriesRow({
    required this.date,
    required this.typeLabel,
    required this.category,
    required this.subcategory,
    required this.amount,
  });

  final DateTime date;
  final String typeLabel;
  final String category;
  final String subcategory;
  final double amount;
}

class _SubFilterItem {
  const _SubFilterItem({required this.id, required this.label});

  final int id;
  final String label;
}

class _EntriesDataSource extends DataTableSource {
  _EntriesDataSource(List<_EntriesRow> rows) : _rows = rows;

  List<_EntriesRow> _rows;

  void setRows(List<_EntriesRow> rows) {
    _rows = rows;
    notifyListeners();
  }

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= _rows.length) return null;
    final row = _rows[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(formatIsoDate(row.date))),
        DataCell(Text(row.typeLabel)),
        DataCell(
          Text(row.category, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DataCell(
          Text(row.subcategory, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        DataCell(
          Align(
            alignment: Alignment.centerRight,
            child: Text(formatCurrency(row.amount)),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _rows.length;

  @override
  int get selectedRowCount => 0;
}
