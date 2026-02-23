import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _amountCtrl = TextEditingController(text: '0');
  final _newCatCtrl = TextEditingController();
  final _newSubCtrl = TextEditingController();
  final _newEventNameCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Category> _categories = const [];
  List<ExpenseEntry> _entries = const [];
  List<EventSummary> _events = const [];

  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  DateTime _date = DateTime.now();

  bool _isEvent = false;
  bool _useExistingEvent = true;
  EventSummary? _selectedEvent;
  bool _singleDayEvent = true;
  DateTime _eventStart = DateTime.now();
  DateTime _eventEnd = DateTime.now();

  DateTime _filterMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _newCatCtrl.dispose();
    _newSubCtrl.dispose();
    _newEventNameCtrl.dispose();
    super.dispose();
  }

  Category? get _selectedCategory {
    if (_selectedCategoryId == null) return null;
    for (final c in _categories) {
      if (c.id == _selectedCategoryId) {
        return c;
      }
    }
    return null;
  }

  Subcategory? get _selectedSub {
    final cat = _selectedCategory;
    if (cat == null || _selectedSubcategoryId == null) return null;
    for (final s in cat.subcategories) {
      if (s.id == _selectedSubcategoryId) {
        return s;
      }
    }
    return null;
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.repo.getExpenseCategories();
      final entries = await widget.repo.getExpenses(
        from: monthStart(_filterMonth),
        to: monthEnd(_filterMonth),
      );
      final events = await widget.repo.getEvents();

      if (!mounted) return;

      setState(() {
        _categories = categories;
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          _selectedCategoryId = categories.first.id;
        }
        if (_selectedSubcategoryId == null &&
            _selectedCategory != null &&
            _selectedCategory!.subcategories.isNotEmpty) {
          _selectedSubcategoryId = _selectedCategory!.subcategories.first.id;
        }
        _entries = entries;
        _events = events;
        if (_selectedEvent == null && events.isNotEmpty) {
          _selectedEvent = events.first;
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
    if (d != null) {
      onChanged(d);
    }
  }

  Future<void> _addExpense() async {
    if (_selectedCategory == null || _selectedSub == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select category and subcategory')),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter valid amount')));
      return;
    }

    try {
      if (_isEvent) {
        if (_useExistingEvent) {
          final event = _selectedEvent;
          if (event == null) {
            throw Exception('Select event');
          }
          await widget.repo.addExpense(
            date: _date,
            categoryId: _selectedCategory!.id,
            subcategoryId: _selectedSub!.id,
            amount: amount,
            isEvent: true,
            eventName: event.name,
            eventStart: event.start,
            eventEnd: event.end,
          );
        } else {
          final name = _newEventNameCtrl.text.trim();
          if (name.isEmpty) {
            throw Exception('Enter event name');
          }
          final start = _singleDayEvent ? _date : _eventStart;
          final end = _singleDayEvent ? _date : _eventEnd;
          await widget.repo.addExpense(
            date: _date,
            categoryId: _selectedCategory!.id,
            subcategoryId: _selectedSub!.id,
            amount: amount,
            isEvent: true,
            eventName: name,
            eventStart: start,
            eventEnd: end,
          );
        }
      } else {
        await widget.repo.addExpense(
          date: _date,
          categoryId: _selectedCategory!.id,
          subcategoryId: _selectedSub!.id,
          amount: amount,
          isEvent: false,
        );
      }

      _amountCtrl.text = '0';
      _newEventNameCtrl.clear();
      await _refreshAll();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _editEntry(ExpenseEntry e) async {
    final amountCtrl = TextEditingController(text: e.amount.toStringAsFixed(2));
    DateTime selectedDate = e.date;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Expense'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        setState(() => selectedDate = d);
                      }
                    },
                    child: Text(formatIsoDate(selectedDate)),
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
              );
            },
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
        );
      },
    );

    if (ok != true) return;

    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    await widget.repo.updateExpense(e.id, date: selectedDate, amount: amount);
    await _refreshAll();
  }

  Future<void> _addCategory() async {
    final name = _newCatCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await widget.repo.addExpenseCategory(name);
      _newCatCtrl.clear();
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Category add failed: $e')));
    }
  }

  Future<void> _addSubcategory() async {
    final name = _newSubCtrl.text.trim();
    final catId = _selectedCategory?.id;
    if (name.isEmpty || catId == null) return;

    try {
      await widget.repo.addExpenseSubcategory(catId, name);
      _newSubCtrl.clear();
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subcategory added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Subcategory add failed: $e')));
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
              const Text('Add Expense page failed to load'),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _refreshAll,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final cat = _selectedCategory;
    final subs = cat?.subcategories ?? const <Subcategory>[];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Add Expense',
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
                              value: _selectedCategoryId,
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
                                  _selectedCategoryId = v;
                                  final next = _selectedCategory;
                                  _selectedSubcategoryId =
                                      next?.subcategories.isNotEmpty == true
                                      ? next!.subcategories.first.id
                                      : null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _selectedSubcategoryId,
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
                              onChanged: (v) =>
                                  setState(() => _selectedSubcategoryId = v),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _selectedCategoryId,
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
                              _selectedCategoryId = v;
                              final next = _selectedCategory;
                              _selectedSubcategoryId =
                                  next?.subcategories.isNotEmpty == true
                                  ? next!.subcategories.first.id
                                  : null;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedSubcategoryId,
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
                          onChanged: (v) =>
                              setState(() => _selectedSubcategoryId = v),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _isEvent,
                  onChanged: (v) => setState(() => _isEvent = v),
                  title: const Text('Events'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_isEvent) ...[
                  const SizedBox(height: 4),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Use Existing'),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Create New'),
                      ),
                    ],
                    selected: {_useExistingEvent},
                    onSelectionChanged: (s) =>
                        setState(() => _useExistingEvent = s.first),
                  ),
                  const SizedBox(height: 8),
                  if (_useExistingEvent)
                    DropdownButtonFormField<EventSummary>(
                      value: _selectedEvent,
                      decoration: const InputDecoration(
                        labelText: 'Select Event',
                      ),
                      items: _events
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                '${e.name} | ${formatIsoDate(e.start)}${e.start == e.end ? '' : ' → ${formatIsoDate(e.end)}'}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) => setState(() => _selectedEvent = v),
                    )
                  else ...[
                    TextField(
                      controller: _newEventNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Event Name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      value: _singleDayEvent,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Single Day'),
                      onChanged: (v) => setState(() => _singleDayEvent = v),
                    ),
                    if (!_singleDayEvent)
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _pickDate(
                              initial: _eventStart,
                              onChanged: (d) => setState(() => _eventStart = d),
                            ),
                            child: Text('Start: ${formatIsoDate(_eventStart)}'),
                          ),
                          OutlinedButton(
                            onPressed: () => _pickDate(
                              initial: _eventEnd,
                              onChanged: (d) => setState(() => _eventEnd = d),
                            ),
                            child: Text('End: ${formatIsoDate(_eventEnd)}'),
                          ),
                        ],
                      ),
                  ],
                ],
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _addExpense,
                  child: const Text('Add Expense'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: const Text('Advanced (Expense Category Management)'),
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
                      labelText: 'New Subcategory (for selected category)',
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
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Filter Month',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
                        await _refreshAll();
                      },
                    ),
                    OutlinedButton(
                      onPressed: _refreshAll,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
                const Divider(),
                if (_entries.isEmpty)
                  const EmptyState(
                    message: 'No expense entries for selected month.',
                  )
                else ...[
                  for (final e in _entries)
                    Card(
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '${formatIsoDate(e.date)} • ${e.category} / ${e.subcategory}',
                        ),
                        subtitle: e.isEvent
                            ? Text(
                                '${e.eventName ?? ''} | ${formatIsoDate(e.eventStart ?? e.date)}${(e.eventStart == e.eventEnd) ? '' : ' → ${formatIsoDate(e.eventEnd ?? e.date)}'}',
                              )
                            : null,
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
                              onPressed: () => _editEntry(e),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () async {
                                await widget.repo.deleteExpense(e.id);
                                await _refreshAll();
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
