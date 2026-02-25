import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

enum IncomeFilterMode { monthly, yearly, custom }

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
  final _renameCatCtrl = TextEditingController();
  final _renameSubCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Category> _categories = const [];
  List<IncomeEntry> _entries = const [];
  bool _entriesLoaded = false;
  bool _entriesLoading = false;
  int? _filterCategoryId;
  int? _filterSubcategoryId;

  int? _categoryId;
  int? _subId;
  DateTime _date = DateTime.now();
  DateTime _filterMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  IncomeFilterMode _filterMode = IncomeFilterMode.monthly;
  int _filterYear = DateTime.now().year;
  DateTime _filterCustomFrom = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _filterCustomTo = DateTime.now();

  int? _advRenameCatId;
  int? _advRenameSubId;
  int? _advDeleteCatId;
  int? _advDeleteSubId;

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
    _renameCatCtrl.dispose();
    _renameSubCtrl.dispose();
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

  (DateTime, DateTime) _incomeRange() {
    switch (_filterMode) {
      case IncomeFilterMode.monthly:
        return (monthStart(_filterMonth), monthEnd(_filterMonth));
      case IncomeFilterMode.yearly:
        final d = DateTime(_filterYear, 1, 1);
        return (yearStart(d), yearEnd(d));
      case IncomeFilterMode.custom:
        return (_filterCustomFrom, _filterCustomTo);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.repo.getIncomeCategories();
      final (from, to) = _incomeRange();
      final catTotals = await widget.repo.incomeTotalsByCategory(
        from: from,
        to: to,
      );
      final subTotals = await widget.repo.incomeTotalsBySubcategory(
        from: from,
        to: to,
      );

      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (_categoryId != null &&
            !categories.any((c) => c.id == _categoryId)) {
          _categoryId = null;
        }
        _categoryId ??= categories.isNotEmpty ? categories.first.id : null;
        if (_subId != null &&
            (_selectedCategory == null ||
                !_selectedCategory!.subcategories.any((s) => s.id == _subId))) {
          _subId = null;
        }
        _subId ??= _selectedCategory?.subcategories.isNotEmpty == true
            ? _selectedCategory!.subcategories.first.id
            : null;

        _advRenameCatId ??= categories.isNotEmpty ? categories.first.id : null;
        _advDeleteCatId ??= categories.isNotEmpty ? categories.first.id : null;

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
        _catTotals = catTotals;
        _subTotals = subTotals;
        _filterCategoryId ??= null;
        _filterSubcategoryId ??= null;
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
    setState(() {
      _entriesLoading = true;
      _entriesLoaded = true;
    });
    try {
      final (from, to) = _incomeRange();
      final entries = await widget.repo.getIncomes(
        from: from,
        to: to,
        categoryId: _filterCategoryId,
        subcategoryId: _filterSubcategoryId,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
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
    if (_entriesLoaded) {
      await _loadEntries();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Income saved')));
  }

  Future<void> _editIncome(IncomeEntry e) async {
    final amountCtrl = TextEditingController(text: e.amount.toStringAsFixed(2));
    DateTime date = e.date;
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
      builder: (context) => AlertDialog(
        title: const Text('Edit Income'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
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
                      setState(() => date = d);
                    }
                  },
                  child: Text(formatIsoDate(date)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedCatId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    setState(() {
                      selectedCatId = v;
                      final nextCat = _categories
                          .where((c) => c.id == v)
                          .cast<Category?>()
                          .firstWhere((c) => c != null, orElse: () => null);
                      selectedSubId = nextCat?.subcategories.isNotEmpty == true
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
                  items:
                      (_categories
                              .firstWhere(
                                (c) => c.id == selectedCatId,
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
      ),
    );

    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    await widget.repo.updateIncome(
      e.id,
      date: date,
      amount: amount,
      categoryId: selectedCatId,
      subcategoryId: selectedSubId,
    );
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
      await widget.repo.renameIncomeCategory(id, name);
      _renameCatCtrl.clear();
      await _refresh();
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
      await widget.repo.renameIncomeSubcategory(id, name);
      _renameSubCtrl.clear();
      await _refresh();
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
      'This removes all income entries under this subcategory.',
    );
    if (!ok) return;
    try {
      await widget.repo.deleteIncomeSubcategory(id);
      await _refresh();
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
      'This removes all income entries and subcategories under this category.',
    );
    if (!ok) return;
    try {
      await widget.repo.deleteIncomeCategory(id);
      await _refresh();
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
        if (_categories.isEmpty) ...[
          const EmptyState(
            message: 'No income categories yet. Add them below.',
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
                              value: _categoryId,
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
                                  : (v) => setState(() => _subId = v),
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _categoryId,
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
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _subId,
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
                              : (v) => setState(() => _subId = v),
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _renameCatCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New category name',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _renameCategory,
                  child: const Text('Rename'),
                ),
              ],
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _renameSubCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New subcategory name',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _renameSubcategory,
                  child: const Text('Rename'),
                ),
              ],
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
                  children: [
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<IncomeFilterMode>(
                        value: _filterMode,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Mode'),
                        items: const [
                          DropdownMenuItem(
                            value: IncomeFilterMode.monthly,
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: IncomeFilterMode.yearly,
                            child: Text('Yearly'),
                          ),
                          DropdownMenuItem(
                            value: IncomeFilterMode.custom,
                            child: Text('Custom'),
                          ),
                        ],
                        onChanged: (v) async {
                          setState(() {
                            _filterMode = v ?? IncomeFilterMode.monthly;
                            _entriesLoaded = false;
                            _entries = const [];
                          });
                          await _refresh();
                        },
                      ),
                    ),
                    if (_filterMode == IncomeFilterMode.monthly)
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
                          onChanged: (v) async {
                            setState(() {
                              _filterMonth = v ?? _filterMonth;
                              _entriesLoaded = false;
                              _entries = const [];
                            });
                            await _refresh();
                          },
                        ),
                      ),
                    if (_filterMode == IncomeFilterMode.yearly)
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<int>(
                          value: _filterYear,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Year'),
                          items: List.generate(10, (i) {
                            final y = DateTime.now().year - i;
                            return DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            );
                          }),
                          onChanged: (v) async {
                            setState(() {
                              _filterYear = v ?? _filterYear;
                              _entriesLoaded = false;
                              _entries = const [];
                            });
                            await _refresh();
                          },
                        ),
                      ),
                    if (_filterMode == IncomeFilterMode.custom)
                      OutlinedButton(
                        onPressed: () => _pickDate(
                          initial: _filterCustomFrom,
                          onChanged: (d) => setState(() {
                            _filterCustomFrom = d;
                            if (_filterCustomTo.isBefore(d)) {
                              _filterCustomTo = d;
                            }
                            _entriesLoaded = false;
                            _entries = const [];
                          }),
                        ),
                        child: Text(
                          'From: ${formatIsoDate(_filterCustomFrom)}',
                        ),
                      ),
                    if (_filterMode == IncomeFilterMode.custom)
                      OutlinedButton(
                        onPressed: () => _pickDate(
                          initial: _filterCustomTo,
                          onChanged: (d) => setState(() {
                            _filterCustomTo = d;
                            if (_filterCustomTo.isBefore(_filterCustomFrom)) {
                              _filterCustomFrom = d;
                            }
                            _entriesLoaded = false;
                            _entries = const [];
                          }),
                        ),
                        child: Text('To: ${formatIsoDate(_filterCustomTo)}'),
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
                const SizedBox(height: 8),
                Text(
                  'Selected period income: ${formatCurrency(_catTotals.fold<double>(0, (a, b) => a + b.amount))}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final left = TotalsPieChart(
                      title: 'Income by Category',
                      rows: _catTotals,
                    );
                    final right = TotalsPieChart(
                      title: 'Income by Subcategory',
                      rows: _subTotals,
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 8),
                          Expanded(child: right),
                        ],
                      );
                    }
                    return Column(
                      children: [left, const SizedBox(height: 8), right],
                    );
                  },
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
                    message: 'No income entries for selected filters.',
                  )
                else ...[
                  for (final e in _entries)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${formatIsoDate(e.date)} • ${e.category} / ${e.subcategory}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatCurrency(e.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _editIncome(e),
                                      icon: const Icon(Icons.edit_outlined),
                                      iconSize: 18,
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 30,
                                            height: 30,
                                          ),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await widget.repo.deleteIncome(e.id);
                                        await _loadEntries();
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                      iconSize: 18,
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
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
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${formatCurrency(_entries.fold<double>(0, (a, b) => a + b.amount))}',
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
