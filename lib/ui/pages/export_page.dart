import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../../utils/file_saver.dart';

enum ExportMode { monthly, yearly, custom }

class ExportPage extends StatefulWidget {
  const ExportPage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  ExportMode _expenseMode = ExportMode.monthly;
  ExportMode _incomeMode = ExportMode.monthly;

  DateTime _expenseMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _incomeMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  int _expenseYear = DateTime.now().year;
  int _incomeYear = DateTime.now().year;
  DateTime _expenseFrom = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _expenseTo = DateTime.now();
  DateTime _incomeFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _incomeTo = DateTime.now();

  List<Category> _expenseCategories = const [];
  List<Category> _incomeCategories = const [];
  List<EventSummary> _events = const [];
  Set<String> _summaryCategories = <String>{};
  bool _selectAllSummarySub = true;
  Set<String> _summarySubcategories = <String>{};

  String _expenseCategoryFilter = 'All';
  String _expenseSubFilter = 'All';
  String _incomeCategoryFilter = 'All';
  String _incomeSubFilter = 'All';

  EventSummary? _selectedEvent;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRef();
  }

  Future<void> _loadRef() async {
    final expCats = await widget.repo.getExpenseCategories();
    final incCats = await widget.repo.getIncomeCategories();
    final events = await widget.repo.getEvents();
    if (!mounted) return;
    setState(() {
      _expenseCategories = expCats;
      _incomeCategories = incCats;
      _events = events;
      _selectedEvent = events.isEmpty ? null : events.first;
      _summaryCategories = expCats.map((e) => e.name).toSet();
      _summarySubcategories = expCats
          .expand((e) => e.subcategories.map((s) => s.name))
          .toSet();
    });
  }

  (DateTime, DateTime) _range(
    ExportMode mode,
    DateTime month,
    int year,
    DateTime from,
    DateTime to,
  ) {
    switch (mode) {
      case ExportMode.monthly:
        return (monthStart(month), monthEnd(month));
      case ExportMode.yearly:
        final y = DateTime(year, 1, 1);
        return (yearStart(y), yearEnd(y));
      case ExportMode.custom:
        return (from, to);
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

  Future<Uint8List> _buildExpensePdf(
    List<ExpenseEntry> rows,
    DateTime from,
    DateTime to,
  ) async {
    final doc = pw.Document();
    final total = rows.fold<double>(0, (a, b) => a + b.amount);

    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.all(28),
          pageFormat: PdfPageFormat.a4,
        ),
        build: (context) => [
          pw.Text(
            'Expense Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Period: ${formatIsoDate(from)} → ${formatIsoDate(to)}'),
          pw.SizedBox(height: 4),
          pw.Text('Total: ${formatCurrency(total)}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Category', 'Subcategory', 'Amount'],
            data: rows
                .map(
                  (e) => [
                    formatIsoDate(e.date),
                    e.category,
                    e.subcategory,
                    e.amount.toStringAsFixed(2),
                  ],
                )
                .toList(growable: false),
            border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.4),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _buildIncomePdf(
    List<IncomeEntry> rows,
    DateTime from,
    DateTime to,
  ) async {
    final doc = pw.Document();
    final total = rows.fold<double>(0, (a, b) => a + b.amount);

    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.all(28),
          pageFormat: PdfPageFormat.a4,
        ),
        build: (context) => [
          pw.Text(
            'Income Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Period: ${formatIsoDate(from)} → ${formatIsoDate(to)}'),
          pw.SizedBox(height: 4),
          pw.Text('Total: ${formatCurrency(total)}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Category', 'Subcategory', 'Amount'],
            data: rows
                .map(
                  (e) => [
                    formatIsoDate(e.date),
                    e.category,
                    e.subcategory,
                    e.amount.toStringAsFixed(2),
                  ],
                )
                .toList(growable: false),
            border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.4),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _buildEventPdf(
    EventSummary event,
    List<ExpenseEntry> rows,
  ) async {
    final doc = pw.Document();
    final total = rows.fold<double>(0, (a, b) => a + b.amount);

    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.all(28),
          pageFormat: PdfPageFormat.a4,
        ),
        build: (context) => [
          pw.Text(
            'Event Report — ${event.name}',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Date range: ${formatPrettyDate(event.start)}${event.start == event.end ? '' : ' → ${formatPrettyDate(event.end)}'}',
          ),
          pw.SizedBox(height: 4),
          pw.Text('Total spend: ${formatCurrency(total)}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Category', 'Subcategory', 'Amount'],
            data: rows
                .map(
                  (e) => [
                    formatIsoDate(e.date),
                    e.category,
                    e.subcategory,
                    e.amount.toStringAsFixed(2),
                  ],
                )
                .toList(growable: false),
            border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.4),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _buildSummaryPdf(
    List<TotalsRow> catRows,
    List<TotalsRow> subRows,
    DateTime from,
    DateTime to,
  ) async {
    final doc = pw.Document();
    final total = catRows.fold<double>(0, (a, b) => a + b.amount);

    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.all(28),
          pageFormat: PdfPageFormat.a4,
        ),
        build: (context) => [
          pw.Text(
            'Summary / Totals Export',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Period: ${formatIsoDate(from)} → ${formatIsoDate(to)}'),
          pw.SizedBox(height: 4),
          pw.Text('Grand Total: ${formatCurrency(total)}'),
          pw.SizedBox(height: 14),
          pw.Text(
            'By Category',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Category', 'Amount'],
            data: catRows
                .map((e) => [e.label, e.amount.toStringAsFixed(2)])
                .toList(growable: false),
            border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.4),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'By Subcategory',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Subcategory', 'Amount'],
            data: subRows
                .map((e) => [e.label, e.amount.toStringAsFixed(2)])
                .toList(growable: false),
            border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.4),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _shareBytes(Uint8List bytes, String fileName) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<void> _saveExportCopy(Uint8List bytes, String fileName) async {
    try {
      final custom = await widget.repo.getAppSetting('export_directory');
      final dir = custom != null && custom.trim().isNotEmpty
          ? custom.trim()
          : null;
      final savedPath = await saveBytesToDirectory(
        bytes: bytes,
        fileName: fileName,
        directoryPath: dir,
      );
      if (savedPath == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to $savedPath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _exportExpense() async {
    setState(() => _busy = true);
    final (from, to) = _range(
      _expenseMode,
      _expenseMonth,
      _expenseYear,
      _expenseFrom,
      _expenseTo,
    );
    final all = await widget.repo.getExpenses(from: from, to: to);
    final rows = all
        .where((e) {
          if (_expenseCategoryFilter != 'All' &&
              e.category != _expenseCategoryFilter)
            return false;
          if (_expenseSubFilter != 'All' && e.subcategory != _expenseSubFilter)
            return false;
          return true;
        })
        .toList(growable: false);
    final bytes = await _buildExpensePdf(rows, from, to);
    await _saveExportCopy(
      bytes,
      'expense_${formatIsoDate(from)}_${formatIsoDate(to)}.pdf',
    );
    await _shareBytes(
      bytes,
      'expense_${formatIsoDate(from)}_${formatIsoDate(to)}.pdf',
    );
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _exportIncome() async {
    setState(() => _busy = true);
    final (from, to) = _range(
      _incomeMode,
      _incomeMonth,
      _incomeYear,
      _incomeFrom,
      _incomeTo,
    );
    final all = await widget.repo.getIncomes(from: from, to: to);
    final rows = all
        .where((e) {
          if (_incomeCategoryFilter != 'All' &&
              e.category != _incomeCategoryFilter)
            return false;
          if (_incomeSubFilter != 'All' && e.subcategory != _incomeSubFilter)
            return false;
          return true;
        })
        .toList(growable: false);
    final bytes = await _buildIncomePdf(rows, from, to);
    await _saveExportCopy(
      bytes,
      'income_${formatIsoDate(from)}_${formatIsoDate(to)}.pdf',
    );
    await _shareBytes(
      bytes,
      'income_${formatIsoDate(from)}_${formatIsoDate(to)}.pdf',
    );
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _exportEvent() async {
    final event = _selectedEvent;
    if (event == null) return;
    setState(() => _busy = true);
    final rows = await widget.repo.getEventEntries(event);
    final bytes = await _buildEventPdf(event, rows);
    await _saveExportCopy(
      bytes,
      'event_${event.name}_${formatIsoDate(event.start)}.pdf',
    );
    await _shareBytes(
      bytes,
      'event_${event.name}_${formatIsoDate(event.start)}.pdf',
    );
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _exportSummaryTotals() async {
    setState(() => _busy = true);
    final (from, to) = _range(
      _expenseMode,
      _expenseMonth,
      _expenseYear,
      _expenseFrom,
      _expenseTo,
    );
    var catRows = await widget.repo.expenseTotalsByCategory(from: from, to: to);
    var subRows = await widget.repo.expenseTotalsBySubcategory(
      from: from,
      to: to,
    );

    if (_summaryCategories.isNotEmpty) {
      catRows = catRows
          .where((r) => _summaryCategories.contains(r.label))
          .toList(growable: false);
      if (!_selectAllSummarySub) {
        subRows = subRows
            .where((r) => _summarySubcategories.contains(r.label))
            .toList(growable: false);
      }
    }

    final bytes = await _buildSummaryPdf(catRows, subRows, from, to);
    await _saveExportCopy(
      bytes,
      'expense_summary_${formatIsoDate(from)}_${formatIsoDate(to)}.pdf',
    );
    await _shareBytes(
      bytes,
      'expense_summary_${formatIsoDate(from)}_${formatIsoDate(to)}.pdf',
    );
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Widget _buildModeFilter({
    required ExportMode mode,
    required ValueChanged<ExportMode> onMode,
    required DateTime month,
    required ValueChanged<DateTime> onMonth,
    required int year,
    required ValueChanged<int> onYear,
    required DateTime from,
    required ValueChanged<DateTime> onFrom,
    required DateTime to,
    required ValueChanged<DateTime> onTo,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<ExportMode>(
          value: mode,
          items: const [
            DropdownMenuItem(value: ExportMode.monthly, child: Text('Monthly')),
            DropdownMenuItem(value: ExportMode.yearly, child: Text('Yearly')),
            DropdownMenuItem(value: ExportMode.custom, child: Text('Custom')),
          ],
          onChanged: (v) => onMode(v ?? ExportMode.monthly),
        ),
        if (mode == ExportMode.monthly)
          DropdownButton<DateTime>(
            value: month,
            items: List.generate(24, (i) {
              final d = DateTime(
                DateTime.now().year,
                DateTime.now().month - i,
                1,
              );
              return DropdownMenuItem(
                value: d,
                child: Text('${d.year}-${d.month.toString().padLeft(2, '0')}'),
              );
            }),
            onChanged: (v) => onMonth(v ?? month),
          ),
        if (mode == ExportMode.yearly)
          DropdownButton<int>(
            value: year,
            items: List.generate(10, (i) {
              final y = DateTime.now().year - i;
              return DropdownMenuItem(value: y, child: Text('$y'));
            }),
            onChanged: (v) => onYear(v ?? year),
          ),
        if (mode == ExportMode.custom)
          OutlinedButton(
            onPressed: () => _pickDate(initial: from, onChanged: onFrom),
            child: Text('From ${formatIsoDate(from)}'),
          ),
        if (mode == ExportMode.custom)
          OutlinedButton(
            onPressed: () => _pickDate(initial: to, onChanged: onTo),
            child: Text('To ${formatIsoDate(to)}'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategoryOptions = [
      'All',
      ..._expenseCategories.map((e) => e.name),
    ];
    final expenseSubOptions = [
      'All',
      ..._expenseCategories
          .expand((e) => e.subcategories.map((s) => s.name))
          .toSet()
          .toList()
        ..sort(),
    ];
    final incomeCategoryOptions = [
      'All',
      ..._incomeCategories.map((e) => e.name),
    ];
    final incomeSubOptions = [
      'All',
      ..._incomeCategories
          .expand((e) => e.subcategories.map((s) => s.name))
          .toSet()
          .toList()
        ..sort(),
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Export',
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
                  'Export Expenses',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _buildModeFilter(
                  mode: _expenseMode,
                  onMode: (v) => setState(() => _expenseMode = v),
                  month: _expenseMonth,
                  onMonth: (v) => setState(() => _expenseMonth = v),
                  year: _expenseYear,
                  onYear: (v) => setState(() => _expenseYear = v),
                  from: _expenseFrom,
                  onFrom: (v) => setState(() => _expenseFrom = v),
                  to: _expenseTo,
                  onTo: (v) => setState(() => _expenseTo = v),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    DropdownButton<String>(
                      value: _expenseCategoryFilter,
                      items: expenseCategoryOptions
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text('Category: $v'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) =>
                          setState(() => _expenseCategoryFilter = v ?? 'All'),
                    ),
                    DropdownButton<String>(
                      value: _expenseSubFilter,
                      items: expenseSubOptions
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text('Subcategory: $v'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) =>
                          setState(() => _expenseSubFilter = v ?? 'All'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _exportExpense,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export Expense PDF'),
                    ),
                  ],
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
                  'Summary / Totals Export',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._expenseCategories.map(
                      (c) => FilterChip(
                        selected: _summaryCategories.contains(c.name),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _summaryCategories.add(c.name);
                            } else {
                              _summaryCategories.remove(c.name);
                            }
                          });
                        },
                        label: Text(c.name),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _selectAllSummarySub,
                  onChanged: (v) => setState(() => _selectAllSummarySub = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All Subcategories'),
                ),
                if (!_selectAllSummarySub)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._expenseCategories
                          .expand((e) => e.subcategories)
                          .map(
                            (s) => FilterChip(
                              selected: _summarySubcategories.contains(s.name),
                              onSelected: (sel) {
                                setState(() {
                                  if (sel) {
                                    _summarySubcategories.add(s.name);
                                  } else {
                                    _summarySubcategories.remove(s.name);
                                  }
                                });
                              },
                              label: Text(s.name),
                            ),
                          ),
                    ],
                  ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _busy ? null : _exportSummaryTotals,
                  child: const Text('Generate Summary PDF'),
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
                  'Export Income',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _buildModeFilter(
                  mode: _incomeMode,
                  onMode: (v) => setState(() => _incomeMode = v),
                  month: _incomeMonth,
                  onMonth: (v) => setState(() => _incomeMonth = v),
                  year: _incomeYear,
                  onYear: (v) => setState(() => _incomeYear = v),
                  from: _incomeFrom,
                  onFrom: (v) => setState(() => _incomeFrom = v),
                  to: _incomeTo,
                  onTo: (v) => setState(() => _incomeTo = v),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    DropdownButton<String>(
                      value: _incomeCategoryFilter,
                      items: incomeCategoryOptions
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text('Category: $v'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) =>
                          setState(() => _incomeCategoryFilter = v ?? 'All'),
                    ),
                    DropdownButton<String>(
                      value: _incomeSubFilter,
                      items: incomeSubOptions
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text('Subcategory: $v'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) =>
                          setState(() => _incomeSubFilter = v ?? 'All'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _exportIncome,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export Income PDF'),
                    ),
                  ],
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
                  'Event Export',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_events.isEmpty)
                  const Text('No events available')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      DropdownButton<EventSummary>(
                        value: _selectedEvent,
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
                      ),
                      ElevatedButton.icon(
                        onPressed: _busy || _selectedEvent == null
                            ? null
                            : _exportEvent,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Export Event PDF'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
