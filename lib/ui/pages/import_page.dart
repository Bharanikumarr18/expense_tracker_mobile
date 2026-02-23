import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  bool _parsing = false;
  bool _importing = false;
  bool _autoCreateMissing = true;

  String? _fileName;
  List<_ImportRow> _rows = const [];

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }
    if (!mounted) return;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file bytes')),
      );
      return;
    }

    setState(() {
      _parsing = true;
      _fileName = file.name;
      _rows = const [];
    });

    try {
      final ext = file.extension?.toLowerCase() ?? '';
      final table = ext == 'xlsx' ? _parseXlsx(bytes) : _parseCsv(bytes);
      final rows = await _validateRows(table);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _parsing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _parsing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Parse failed: $e')));
    }
  }

  List<Map<String, String>> _parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final rows = const CsvDecoder(
      dynamicTyping: false,
      skipEmptyLines: true,
    ).convert(text);
    if (rows.isEmpty) {
      return const [];
    }

    final headers = rows.first
        .map((e) => e.toString().trim().toLowerCase())
        .toList(growable: false);
    return rows.skip(1).map((r) {
      final out = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        out[headers[i]] = i < r.length ? r[i].toString().trim() : '';
      }
      return out;
    }).toList();
  }

  List<Map<String, String>> _parseXlsx(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return const [];
    }
    final table = excel.tables.values.first;
    if (table.maxRows == 0) {
      return const [];
    }

    final headerCells = table.row(0);
    final headers = headerCells
        .map((c) => (c?.value ?? '').toString().trim().toLowerCase())
        .toList(growable: false);

    final out = <Map<String, String>>[];
    for (var r = 1; r < table.maxRows; r++) {
      final row = table.row(r);
      final data = <String, String>{};
      var nonEmpty = false;
      for (var c = 0; c < headers.length; c++) {
        final key = headers[c];
        if (key.isEmpty) continue;
        final raw = c < row.length
            ? (row[c]?.value ?? '').toString().trim()
            : '';
        if (raw.isNotEmpty) nonEmpty = true;
        data[key] = raw;
      }
      if (nonEmpty) {
        out.add(data);
      }
    }
    return out;
  }

  Future<List<_ImportRow>> _validateRows(
    List<Map<String, String>> rawRows,
  ) async {
    final events = await widget.repo.getEvents();
    final eventByName = <String, EventSummary>{
      for (final e in events) e.name.trim().toLowerCase(): e,
    };

    final validated = <_ImportRow>[];

    for (var i = 0; i < rawRows.length; i++) {
      final rowNo = i + 2;
      final row = rawRows[i];

      final dateRaw = row['date'] ?? '';
      final category = (row['category'] ?? '').trim();
      final subcategory = (row['subcategory'] ?? '').trim();
      final priceRaw = (row['price'] ?? row['amount'] ?? '').trim();

      final issues = <String>[];
      DateTime? date;
      double? amount;

      if (dateRaw.isEmpty) {
        issues.add('Date missing');
      } else {
        try {
          date = parseDateFlexible(dateRaw);
        } catch (_) {
          issues.add('Invalid date');
        }
      }

      if (category.isEmpty) {
        issues.add('Category missing');
      }
      if (subcategory.isEmpty) {
        issues.add('Subcategory missing');
      }

      amount = double.tryParse(priceRaw);
      if (amount == null || amount <= 0) {
        issues.add('Invalid price');
      }

      var isEvent = false;
      String? eventName;
      DateTime? eventStart;
      DateTime? eventEnd;

      final eventMode = (row['event_mode'] ?? '').trim().toLowerCase();
      final eventExisting = (row['event'] ?? '').trim();
      final eventNew = (row['new_event_name'] ?? '').trim();
      final eventStartRaw = (row['event_start'] ?? '').trim();
      final eventEndRaw = (row['event_end'] ?? '').trim();

      if (eventMode.isNotEmpty) {
        isEvent = true;
        if (eventMode == 'use existing') {
          if (eventExisting.isEmpty) {
            issues.add('Existing event missing');
          } else {
            final found = eventByName[eventExisting.toLowerCase()];
            if (found == null) {
              issues.add('Existing event not found');
            } else {
              eventName = found.name;
              eventStart = found.start;
              eventEnd = found.end;
            }
          }
        } else if (eventMode == 'create new') {
          eventName = eventNew.isNotEmpty ? eventNew : eventExisting;
          if (eventName.trim().isEmpty) {
            issues.add('New event name missing');
          }

          if (eventStartRaw.isNotEmpty) {
            try {
              eventStart = parseDateFlexible(eventStartRaw);
            } catch (_) {
              issues.add('Invalid event_start');
            }
          }

          if (eventEndRaw.isNotEmpty) {
            try {
              eventEnd = parseDateFlexible(eventEndRaw);
            } catch (_) {
              issues.add('Invalid event_end');
            }
          }

          eventStart ??= date;
          eventEnd ??= eventStart;
        } else {
          issues.add('event_mode must be Use Existing or Create New');
        }
      }

      validated.add(
        _ImportRow(
          rowNo: rowNo,
          date: date,
          category: category,
          subcategory: subcategory,
          amount: amount,
          isEvent: isEvent,
          eventName: eventName,
          eventStart: eventStart,
          eventEnd: eventEnd,
          issues: issues,
        ),
      );
    }

    return validated;
  }

  Future<void> _importValidRows() async {
    final valid = _rows.where((r) => r.isValid).toList(growable: false);
    if (valid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No valid rows to import')));
      return;
    }

    setState(() => _importing = true);
    var success = 0;
    var fail = 0;

    for (final row in valid) {
      try {
        await widget.repo.addExpenseByNames(
          date: row.date!,
          category: row.category,
          subcategory: row.subcategory,
          amount: row.amount!,
          autoCreateMissing: _autoCreateMissing,
          isEvent: row.isEvent,
          eventName: row.eventName,
          eventStart: row.eventStart,
          eventEnd: row.eventEnd,
        );
        success++;
      } catch (_) {
        fail++;
      }
    }

    if (!mounted) return;
    setState(() => _importing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported: $success, Failed: $fail')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _rows.where((r) => r.isValid).length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Import Expenses',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Supported columns: date, category, subcategory, price(amount), optional event_mode/event/new_event_name/event_start/event_end.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _parsing ? null : _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick .csv/.xlsx'),
            ),
            FilterChip(
              selected: _autoCreateMissing,
              onSelected: (v) => setState(() => _autoCreateMissing = v),
              label: const Text('Auto-create missing category/subcategory'),
            ),
            if (_fileName != null) Chip(label: Text(_fileName!)),
          ],
        ),
        if (_parsing)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 10),
        if (_rows.isEmpty)
          const EmptyState(message: 'No import rows loaded yet.')
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preview (${_rows.length} rows, $validCount valid)'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 420,
                    child: ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, i) {
                        final r = _rows[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            child: Text(
                              r.rowNo.toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          title: Text(
                            '${r.date == null ? '-' : formatIsoDate(r.date!)} | ${r.category} | ${r.subcategory} | ${r.amount?.toStringAsFixed(2) ?? '-'}',
                          ),
                          subtitle: r.issues.isEmpty
                              ? (r.isEvent
                                    ? Text(
                                        'Event: ${r.eventName} | ${formatIsoDate(r.eventStart ?? r.date!)}${r.eventStart == r.eventEnd ? '' : ' → ${formatIsoDate(r.eventEnd ?? r.date!)}'}',
                                      )
                                    : const Text('Ready'))
                              : Text(r.issues.join(' | ')),
                          trailing: Icon(
                            r.isValid
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: r.isValid ? Colors.green : Colors.orange,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: (_importing || validCount == 0)
                        ? null
                        : _importValidRows,
                    icon: const Icon(Icons.save),
                    label: Text(
                      _importing ? 'Importing...' : 'Save Import to Expenses',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ImportRow {
  final int rowNo;
  final DateTime? date;
  final String category;
  final String subcategory;
  final double? amount;
  final bool isEvent;
  final String? eventName;
  final DateTime? eventStart;
  final DateTime? eventEnd;
  final List<String> issues;

  const _ImportRow({
    required this.rowNo,
    required this.date,
    required this.category,
    required this.subcategory,
    required this.amount,
    required this.isEvent,
    required this.eventName,
    required this.eventStart,
    required this.eventEnd,
    required this.issues,
  });

  bool get isValid => issues.isEmpty && date != null && amount != null;
}
