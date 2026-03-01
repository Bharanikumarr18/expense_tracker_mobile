import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/entry_editing.dart';

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
  final _renameCatCtrl = TextEditingController();
  final _renameSubCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Category> _categories = const [];
  List<ExpenseEntry> _entries = const [];
  List<EventSummary> _events = const [];
  bool _entriesLoaded = false;
  bool _entriesLoading = false;
  double _entriesTotal = 0.0;
  final RowEditSession _editSession = RowEditSession();
  int? _filterCategoryId;
  int? _filterSubcategoryId;

  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  DateTime _date = DateTime.now();

  bool _isEvent = false;
  bool _useExistingEvent = true;
  EventSummary? _selectedEvent;
  bool _singleDayEvent = true;
  DateTime _eventStart = DateTime.now();
  DateTime _eventEnd = DateTime.now();

  int? _advRenameCatId;
  int? _advRenameSubId;
  int? _advDeleteCatId;
  int? _advDeleteSubId;

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
    _editSession.dispose();
    _amountCtrl.dispose();
    _newCatCtrl.dispose();
    _newSubCtrl.dispose();
    _newEventNameCtrl.dispose();
    _renameCatCtrl.dispose();
    _renameSubCtrl.dispose();
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
      final events = await widget.repo.getEvents();

      if (!mounted) return;

      setState(() {
        _categories = categories;
        if (_selectedCategoryId != null &&
            !categories.any((c) => c.id == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          _selectedCategoryId = categories.first.id;
        }
        if (_selectedSubcategoryId != null &&
            (_selectedCategory == null ||
                !_selectedCategory!.subcategories.any(
                  (s) => s.id == _selectedSubcategoryId,
                ))) {
          _selectedSubcategoryId = null;
        }
        if (_selectedSubcategoryId == null &&
            _selectedCategory != null &&
            _selectedCategory!.subcategories.isNotEmpty) {
          _selectedSubcategoryId = _selectedCategory!.subcategories.first.id;
        }
        _events = events;
        if (_selectedEvent == null && events.isNotEmpty) {
          _selectedEvent = events.first;
        }

        _advRenameCatId ??= categories.isNotEmpty ? categories.first.id : null;
        _advDeleteCatId ??= categories.isNotEmpty ? categories.first.id : null;

        _filterCategoryId ??= null;
        _filterSubcategoryId ??= null;

        final renameCat = categories
            .where((c) => c.id == _advRenameCatId)
            .cast<Category?>()
            .firstWhere((c) => c != null, orElse: () => null);
        if (renameCat != null) {
          _advRenameSubId ??= renameCat.subcategories.isNotEmpty
              ? renameCat.subcategories.first.id
              : null;
          if (_advRenameSubId != null &&
              !renameCat.subcategories.any((s) => s.id == _advRenameSubId)) {
            _advRenameSubId = renameCat.subcategories.isNotEmpty
                ? renameCat.subcategories.first.id
                : null;
          }
        }

        final deleteCat = categories
            .where((c) => c.id == _advDeleteCatId)
            .cast<Category?>()
            .firstWhere((c) => c != null, orElse: () => null);
        if (deleteCat != null) {
          _advDeleteSubId ??= deleteCat.subcategories.isNotEmpty
              ? deleteCat.subcategories.first.id
              : null;
          if (_advDeleteSubId != null &&
              !deleteCat.subcategories.any((s) => s.id == _advDeleteSubId)) {
            _advDeleteSubId = deleteCat.subcategories.isNotEmpty
                ? deleteCat.subcategories.first.id
                : null;
          }
        }
        _loading = false;
      });
      if (_entriesLoaded) {
        await _loadEntries();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadEntries() async {
    if (_editSession.editingId != null) {
      _editSession.cancel();
    }
    setState(() {
      _entriesLoading = true;
      _entriesLoaded = true;
    });
    try {
      final entries = await widget.repo.getExpenses(
        from: monthStart(_filterMonth),
        to: monthEnd(_filterMonth),
        categoryId: _filterCategoryId,
        subcategoryId: _filterSubcategoryId,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _entriesTotal = entries.fold<double>(0, (a, b) => a + b.amount);
        _entriesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _entriesLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveInlineEdit({
    required ExpenseEntry entry,
    required DateTime date,
    required int? categoryId,
    required int? subcategoryId,
    required double amount,
  }) async {
    await widget.repo.updateExpense(
      entry.id,
      date: date,
      amount: amount,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
    );
    _editSession.cancel();
    await _loadEntries();
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

  Widget _adaptiveFieldActionRow({
    required Widget field,
    required Widget action,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: action),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: field),
            const SizedBox(width: 8),
            action,
          ],
        );
      },
    );
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
      if (_entriesLoaded) {
        await _loadEntries();
      }

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
    int? selectedCatId = _categories
        .where((c) => c.name == e.category)
        .cast<Category?>()
        .firstWhere((c) => c != null, orElse: () => null)
        ?.id;
    int? selectedSubId;
    if (selectedCatId != null) {
      final cat = _categories.firstWhere(
        (c) => c.id == selectedCatId,
        orElse: () => const Category(id: -1, name: '', subcategories: []),
      );
      selectedSubId = cat.subcategories
          .where((s) => s.name == e.subcategory)
          .cast<Subcategory?>()
          .firstWhere((s) => s != null, orElse: () => null)
          ?.id;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Expense'),
          content: StatefulBuilder(
            builder: (context, setState) {
              final cat = _categories
                  .where((c) => c.id == selectedCatId)
                  .cast<Category?>()
                  .firstWhere((c) => c != null, orElse: () => null);
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
                  DropdownButtonFormField<int>(
                    value: selectedCatId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
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
                        selectedCatId = v;
                        final nextCat = _categories
                            .where((c) => c.id == v)
                            .cast<Category?>()
                            .firstWhere((c) => c != null, orElse: () => null);
                        selectedSubId =
                            nextCat?.subcategories.isNotEmpty == true
                            ? nextCat!.subcategories.first.id
                            : null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedSubId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Subcategory'),
                    items: (cat?.subcategories ?? const <Subcategory>[])
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (v) => setState(() => selectedSubId = v),
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

    await widget.repo.updateExpense(
      e.id,
      date: selectedDate,
      amount: amount,
      categoryId: selectedCatId,
      subcategoryId: selectedSubId,
    );
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

  Future<bool> _confirmDelete(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _renameCategory() async {
    final id = _advRenameCatId;
    final name = _renameCatCtrl.text.trim();
    if (id == null || name.isEmpty) return;
    try {
      await widget.repo.renameExpenseCategory(id, name);
      _renameCatCtrl.clear();
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category renamed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rename failed: $e')));
    }
  }

  Future<void> _renameSubcategory() async {
    final id = _advRenameSubId;
    final name = _renameSubCtrl.text.trim();
    if (id == null || name.isEmpty) return;
    try {
      await widget.repo.renameExpenseSubcategory(id, name);
      _renameSubCtrl.clear();
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subcategory renamed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rename failed: $e')));
    }
  }

  Future<void> _deleteSubcategory() async {
    final id = _advDeleteSubId;
    if (id == null) return;
    final ok = await _confirmDelete(
      'Delete Subcategory?',
      'This removes all expenses under this subcategory.',
    );
    if (!ok) return;
    try {
      await widget.repo.deleteExpenseSubcategory(id);
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subcategory deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _deleteCategory() async {
    final id = _advDeleteCatId;
    if (id == null) return;
    final ok = await _confirmDelete(
      'Delete Category?',
      'This removes all expenses and subcategories under this category.',
    );
    if (!ok) return;
    try {
      await widget.repo.deleteExpenseCategory(id);
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
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
        if (_categories.isEmpty) ...[
          const EmptyState(
            message: 'No categories yet. Add them in Advanced section below.',
          ),
          const SizedBox(height: 8),
        ],
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
                              isExpanded: true,
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
                              onChanged: _categories.isEmpty
                                  ? null
                                  : (v) {
                                      setState(() {
                                        _selectedCategoryId = v;
                                        final next = _selectedCategory;
                                        _selectedSubcategoryId =
                                            next?.subcategories.isNotEmpty ==
                                                true
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
                              isExpanded: true,
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
                              onChanged: subs.isEmpty
                                  ? null
                                  : (v) => setState(
                                      () => _selectedSubcategoryId = v,
                                    ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _selectedCategoryId,
                          isExpanded: true,
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
                          onChanged: _categories.isEmpty
                              ? null
                              : (v) {
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
                          isExpanded: true,
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
                          onChanged: subs.isEmpty
                              ? null
                              : (v) =>
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
                      isExpanded: true,
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
            _adaptiveFieldActionRow(
              field: TextField(
                controller: _newCatCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Category',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              action: ElevatedButton(
                onPressed: _addCategory,
                child: const Text('Add'),
              ),
            ),
            const SizedBox(height: 8),
            _adaptiveFieldActionRow(
              field: TextField(
                controller: _newSubCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Subcategory (for selected category)',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              action: ElevatedButton(
                onPressed: _addSubcategory,
                child: const Text('Add'),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Rename Category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _advRenameCatId,
              decoration: const InputDecoration(labelText: 'Select Category'),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(growable: false),
              onChanged: (v) => setState(() => _advRenameCatId = v),
            ),
            const SizedBox(height: 6),
            _adaptiveFieldActionRow(
              field: TextField(
                controller: _renameCatCtrl,
                decoration: const InputDecoration(
                  labelText: 'New category name',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              action: ElevatedButton(
                onPressed: _renameCategory,
                child: const Text('Rename'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rename Subcategory',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _advRenameCatId,
              decoration: const InputDecoration(labelText: 'Parent Category'),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(growable: false),
              onChanged: (v) {
                setState(() {
                  _advRenameCatId = v;
                  final cat = _categories
                      .where((c) => c.id == v)
                      .cast<Category?>()
                      .firstWhere((c) => c != null, orElse: () => null);
                  _advRenameSubId = cat?.subcategories.isNotEmpty == true
                      ? cat!.subcategories.first.id
                      : null;
                });
              },
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _advRenameSubId,
              decoration: const InputDecoration(
                labelText: 'Select Subcategory',
              ),
              items:
                  (_categories
                          .firstWhere(
                            (c) => c.id == _advRenameCatId,
                            orElse: () => const Category(
                              id: -1,
                              name: '',
                              subcategories: [],
                            ),
                          )
                          .subcategories)
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(growable: false),
              onChanged: (v) => setState(() => _advRenameSubId = v),
            ),
            const SizedBox(height: 6),
            _adaptiveFieldActionRow(
              field: TextField(
                controller: _renameSubCtrl,
                decoration: const InputDecoration(
                  labelText: 'New subcategory name',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              action: ElevatedButton(
                onPressed: _renameSubcategory,
                child: const Text('Rename'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Delete Subcategory',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _advDeleteCatId,
              decoration: const InputDecoration(labelText: 'Parent Category'),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(growable: false),
              onChanged: (v) {
                setState(() {
                  _advDeleteCatId = v;
                  final cat = _categories
                      .where((c) => c.id == v)
                      .cast<Category?>()
                      .firstWhere((c) => c != null, orElse: () => null);
                  _advDeleteSubId = cat?.subcategories.isNotEmpty == true
                      ? cat!.subcategories.first.id
                      : null;
                });
              },
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _advDeleteSubId,
              decoration: const InputDecoration(
                labelText: 'Select Subcategory',
              ),
              items:
                  (_categories
                          .firstWhere(
                            (c) => c.id == _advDeleteCatId,
                            orElse: () => const Category(
                              id: -1,
                              name: '',
                              subcategories: [],
                            ),
                          )
                          .subcategories)
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(growable: false),
              onChanged: (v) => setState(() => _advDeleteSubId = v),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _deleteSubcategory,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Subcategory'),
            ),
            const SizedBox(height: 12),
            Text(
              'Delete Category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _advDeleteCatId,
              decoration: const InputDecoration(labelText: 'Select Category'),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(growable: false),
              onChanged: (v) => setState(() => _advDeleteCatId = v),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _deleteCategory,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Delete Category'),
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
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<DateTime>(
                        value: _filterMonth,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Month'),
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
                        onChanged: (v) {
                          setState(() {
                            _filterMonth = v ?? _filterMonth;
                            _entriesLoaded = false;
                            _entries = const [];
                            _entriesTotal = 0;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<int?>(
                        value: _filterCategoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All categories'),
                          ),
                          ..._categories.map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _filterCategoryId = v;
                            _filterSubcategoryId = null;
                            _entriesLoaded = false;
                            _entries = const [];
                            _entriesTotal = 0;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<int?>(
                        value: _filterSubcategoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Subcategory',
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All subcategories'),
                          ),
                          ...(_categories
                                  .firstWhere(
                                    (c) => c.id == _filterCategoryId,
                                    orElse: () => const Category(
                                      id: -1,
                                      name: '',
                                      subcategories: [],
                                    ),
                                  )
                                  .subcategories)
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                              ),
                        ],
                        onChanged: _filterCategoryId == null
                            ? null
                            : (v) {
                                setState(() {
                                  _filterSubcategoryId = v;
                                  _entriesLoaded = false;
                                  _entries = const [];
                                  _entriesTotal = 0;
                                });
                              },
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _entriesLoading ? null : _loadEntries,
                      child: const Text('Load Entries'),
                    ),
                  ],
                ),
                const Divider(),
                if (!_entriesLoaded)
                  const EmptyState(
                    message: 'Choose filters and tap Load Entries.',
                  )
                else if (_entriesLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_entries.isEmpty)
                  const EmptyState(
                    message: 'No expense entries for selected filters.',
                  )
                else ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final h = (MediaQuery.of(context).size.height * 0.55)
                          .clamp(240.0, 520.0)
                          .toDouble();
                      return SizedBox(
                        height: h,
                        child: ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final e = _entries[index];
                            return ExpenseEntryRow(
                              key: ValueKey(e.id),
                              entry: e,
                              categories: _categories,
                              session: _editSession,
                              onSave: _saveInlineEdit,
                              onDelete: () async {
                                await widget.repo.deleteExpense(e.id);
                                await _loadEntries();
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Month Total: ${formatCurrency(_entriesTotal)}',
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

class ExpenseEntryRow extends StatelessWidget {
  const ExpenseEntryRow({
    super.key,
    required this.entry,
    required this.categories,
    required this.session,
    required this.onSave,
    required this.onDelete,
  });

  final ExpenseEntry entry;
  final List<Category> categories;
  final RowEditSession session;
  final Future<void> Function({
    required ExpenseEntry entry,
    required DateTime date,
    required int? categoryId,
    required int? subcategoryId,
    required double amount,
  })
  onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: session.flagFor(entry.id),
      builder: (context, isEditing, _) {
        if (!isEditing || session.editingId != entry.id) {
          return _ExpenseViewRow(
            entry: entry,
            onEdit: () => session.begin(
              entry.id,
              EntryEditController.fromAmount(entry.amount),
            ),
            onDelete: onDelete,
          );
        }
        final controller = session.controller;
        if (controller == null) {
          return _ExpenseViewRow(
            entry: entry,
            onEdit: () => session.begin(
              entry.id,
              EntryEditController.fromAmount(entry.amount),
            ),
            onDelete: onDelete,
          );
        }
        return _ExpenseEditRow(
          entry: entry,
          categories: categories,
          controller: controller,
          onCancel: session.cancel,
          onSave: onSave,
        );
      },
    );
  }
}

class _ExpenseViewRow extends StatelessWidget {
  const _ExpenseViewRow({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatIsoDate(entry.date)} • ${entry.category} / ${entry.subcategory}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.isEvent)
                    Text(
                      '${entry.eventName ?? ''} | ${formatIsoDate(entry.eventStart ?? entry.date)}${(entry.eventStart == entry.eventEnd) ? '' : ' → ${formatIsoDate(entry.eventEnd ?? entry.date)}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(entry.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseEditRow extends StatefulWidget {
  const _ExpenseEditRow({
    required this.entry,
    required this.categories,
    required this.controller,
    required this.onCancel,
    required this.onSave,
  });

  final ExpenseEntry entry;
  final List<Category> categories;
  final EntryEditController controller;
  final VoidCallback onCancel;
  final Future<void> Function({
    required ExpenseEntry entry,
    required DateTime date,
    required int? categoryId,
    required int? subcategoryId,
    required double amount,
  })
  onSave;

  @override
  State<_ExpenseEditRow> createState() => _ExpenseEditRowState();
}

class _ExpenseEditRowState extends State<_ExpenseEditRow> {
  late DateTime _date;
  int? _catId;
  int? _subId;

  @override
  void initState() {
    super.initState();
    _date = widget.entry.date;
    if (widget.categories.isEmpty) return;
    final cat = widget.categories.firstWhere(
      (c) => c.name == widget.entry.category,
      orElse: () => widget.categories.first,
    );
    _catId = cat.id;
    if (cat.subcategories.isEmpty) {
      _subId = null;
    } else {
      final sub = cat.subcategories.firstWhere(
        (s) => s.name == widget.entry.subcategory,
        orElse: () => cat.subcategories.first,
      );
      _subId = sub.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.categories
        .where((c) => c.id == _catId)
        .cast<Category?>()
        .firstWhere((c) => c != null, orElse: () => null);
    final subs = cat?.subcategories ?? const <Subcategory>[];
    return Card(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      setState(() => _date = d);
                    }
                  },
                  child: Text(formatIsoDate(_date)),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<int>(
                    value: _catId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: widget.categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.categories.isEmpty
                        ? null
                        : (v) {
                            setState(() {
                              _catId = v;
                              final next = widget.categories
                                  .where((c) => c.id == v)
                                  .cast<Category?>()
                                  .firstWhere(
                                    (c) => c != null,
                                    orElse: () => null,
                                  );
                              _subId = next?.subcategories.isNotEmpty == true
                                  ? next!.subcategories.first.id
                                  : null;
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<int>(
                    value: _subId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Subcategory'),
                    items: subs
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: subs.isEmpty
                        ? null
                        : (v) => setState(() => _subId = v),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: widget.controller.amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final amount = double.tryParse(
                      widget.controller.amountCtrl.text.trim(),
                    );
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount')),
                      );
                      return;
                    }
                    await widget.onSave(
                      entry: widget.entry,
                      date: _date,
                      categoryId: _catId,
                      subcategoryId: _subId,
                      amount: amount,
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
