import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  final _amountCtrl = TextEditingController(text: '0');
  final _newCatCtrl = TextEditingController();
  final _newSubCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Category> _categories = const [];
  List<IncomeEntry> _entries = const [];

  int? _categoryId;
  int? _subId;
  DateTime _date = DateTime.now();
  DateTime _filterMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  List<TotalsRow> _catTotals = const [];
  List<TotalsRow> _subTotals = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _newCatCtrl.dispose();
    _newSubCtrl.dispose();
    super.dispose();
  }

  Category? get _selectedCategory {
    if (_categoryId == null) return null;
    for (final c in _categories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  Subcategory? get _selectedSub {
    final c = _selectedCategory;
    if (c == null || _subId == null) return null;
    for (final s in c.subcategories) {
      if (s.id == _subId) return s;
    }
    return null;
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.repo.getIncomeCategories();
      final entries = await widget.repo.getIncomes(
        from: monthStart(_filterMonth),
        to: monthEnd(_filterMonth),
      );
      final catTotals = await widget.repo.incomeTotalsByCategory(
        from: monthStart(_filterMonth),
        to: monthEnd(_filterMonth),
      );
      final subTotals = await widget.repo.incomeTotalsBySubcategory(
        from: monthStart(_filterMonth),
        to: monthEnd(_filterMonth),
      );

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryId ??= categories.isNotEmpty ? categories.first.id : null;
        _subId ??= _selectedCategory?.subcategories.isNotEmpty == true
            ? _selectedCategory!.subcategories.first.id
            : null;
        _entries = entries;
        _catTotals = catTotals;
        _subTotals = subTotals;
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

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onChanged,
  }) async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (d != null) onChanged(d);
  }

  Future<void> _addIncome() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (_selectedCategory == null ||
        _selectedSub == null ||
        amount == null ||
        amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all fields with valid values')),
      );
      return;
    }

    await widget.repo.addIncome(
      date: _date,
      categoryId: _selectedCategory!.id,
      subcategoryId: _selectedSub!.id,
      amount: amount,
    );
    _amountCtrl.text = '0';
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Income saved')));
  }

  Future<void> _editIncome(IncomeEntry e) async {
    final amountCtrl = TextEditingController(text: e.amount.toStringAsFixed(2));
    DateTime date = e.date;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Income'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) {
                  date = d;
                }
              },
              child: Text(formatIsoDate(date)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    await widget.repo.updateIncome(e.id, date: date, amount: amount);
    await _refresh();
  }

  Future<void> _addCategory() async {
    final name = _newCatCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await widget.repo.addIncomeCategory(name);
      _newCatCtrl.clear();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _addSubcategory() async {
    final name = _newSubCtrl.text.trim();
    if (name.isEmpty || _selectedCategory == null) return;
    try {
      await widget.repo.addIncomeSubcategory(_selectedCategory!.id, name);
      _newSubCtrl.clear();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
              const Text('Income page failed to load'),
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

    final subs = _selectedCategory?.subcategories ?? const <Subcategory>[];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Income',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 620;
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _categoryId,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                              items: _categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (v) {
                                setState(() {
                                  _categoryId = v;
                                  _subId =
                                      _selectedCategory
                                              ?.subcategories
                                              .isNotEmpty ==
                                          true
                                      ? _selectedCategory!
                                            .subcategories
                                            .first
                                            .id
                                      : null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _subId,
                              decoration: const InputDecoration(
                                labelText: 'Subcategory',
                              ),
                              items: subs
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (v) => setState(() => _subId = v),
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _categoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: _categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) {
                            setState(() {
                              _categoryId = v;
                              _subId =
                                  _selectedCategory?.subcategories.isNotEmpty ==
                                      true
                                  ? _selectedCategory!.subcategories.first.id
                                  : null;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _subId,
                          decoration: const InputDecoration(
                            labelText: 'Subcategory',
                          ),
                          items: subs
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) => setState(() => _subId = v),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _pickDate(
                        initial: _date,
                        onChanged: (d) => setState(() => _date = d),
                      ),
                      child: Text('Date: ${formatIsoDate(_date)}'),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Amount'),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _addIncome,
                      child: const Text('Add Income'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: const Text('Advanced (Income Category Management)'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCatCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New Category',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCategory,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSubCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New Subcategory',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addSubcategory,
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
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
                  children: [
                    DropdownButton<DateTime>(
                      value: _filterMonth,
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
                      onChanged: (v) async {
                        setState(() => _filterMonth = v ?? _filterMonth);
                        await _refresh();
                      },
                    ),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 430,
                      child: TotalsPieChart(
                        title: 'Income by Category',
                        rows: _catTotals,
                      ),
                    ),
                    SizedBox(
                      width: 430,
                      child: TotalsPieChart(
                        title: 'Income by Subcategory',
                        rows: _subTotals,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                if (_entries.isEmpty)
                  const EmptyState(
                    message: 'No income entries for selected month.',
                  )
                else ...[
                  for (final e in _entries)
                    Card(
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '${formatIsoDate(e.date)} • ${e.category} / ${e.subcategory}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            Text(
                              formatCurrency(e.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _editIncome(e),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () async {
                                await widget.repo.deleteIncome(e.id);
                                await _refresh();
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Month Total: ${formatCurrency(_entries.fold<double>(0, (a, b) => a + b.amount))}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
