import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  bool _loading = true;
  String? _error;
  List<EventSummary> _events = const [];
  EventSummary? _selected;
  List<ExpenseEntry> _entries = const [];
  List<Category> _categories = const [];
  bool _entriesLoaded = false;
  bool _entriesLoading = false;
  DateTime? _filterFrom;
  DateTime? _filterTo;
  int? _filterCategoryId;
  int? _filterSubcategoryId;

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
      final events = await widget.repo.getEvents();
      final categories = await widget.repo.getExpenseCategories();
      EventSummary? selected = _selected;
      if (selected != null) {
        selected = events
            .where((e) => e.key == selected!.key)
            .cast<EventSummary?>()
            .firstWhere((e) => e != null, orElse: () => null);
      }
      selected ??= events.isNotEmpty ? events.first : null;

      if (!mounted) return;
      setState(() {
        _events = events;
        _selected = selected;
        _categories = categories;
        _filterFrom ??= selected?.start;
        _filterTo ??= selected?.end;
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
    final event = _selected;
    if (event == null) return;
    setState(() {
      _entriesLoading = true;
      _entriesLoaded = true;
    });
    try {
      final rows = await widget.repo.getEventEntriesFiltered(
        event,
        from: _filterFrom,
        to: _filterTo,
        categoryId: _filterCategoryId,
        subcategoryId: _filterSubcategoryId,
      );
      if (!mounted) return;
      setState(() {
        _entries = rows;
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

  Future<void> _editEvent(EventSummary event) async {
    final nameCtrl = TextEditingController(text: event.name);
    DateTime start = event.start;
    DateTime end = event.end;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Event'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Event Name'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: start,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        setDialogState(() => start = d);
                      }
                    },
                    child: Text('Start: ${formatIsoDate(start)}'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: end,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        setDialogState(() => end = d);
                      }
                    },
                    child: Text('End: ${formatIsoDate(end)}'),
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
    await widget.repo.updateEventMetadata(
      oldEvent: event,
      newName: nameCtrl.text.trim(),
      newStart: start,
      newEnd: end,
    );
    await _refresh();
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
              const Text('Events page failed to load'),
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

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Events',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_events.isEmpty)
          const EmptyState(
            message: 'No events found yet. Add expense with Events enabled.',
          )
        else ...[
          DropdownButtonFormField<EventSummary>(
            value: _selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Select Event'),
            items: _events
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      '${e.name} | ${formatIsoDate(e.start)}${e.start == e.end ? '' : ' → ${formatIsoDate(e.end)}'} | ${formatCurrency(e.total)}',
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (v) async {
              setState(() {
                _selected = v;
                _filterFrom = v?.start;
                _filterTo = v?.end;
                _filterCategoryId = null;
                _filterSubcategoryId = null;
                _entriesLoaded = false;
                _entries = const [];
              });
              await _refresh();
            },
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _selected == null
                        ? null
                        : () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _filterFrom ?? _selected!.start,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) {
                              setState(() {
                                _filterFrom = d;
                                _entriesLoaded = false;
                              });
                            }
                          },
                    child: Text(
                      _filterFrom == null
                          ? 'From'
                          : 'From: ${formatIsoDate(_filterFrom!)}',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _selected == null
                        ? null
                        : () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _filterTo ?? _selected!.end,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) {
                              setState(() {
                                _filterTo = d;
                                _entriesLoaded = false;
                              });
                            }
                          },
                    child: Text(
                      _filterTo == null
                          ? 'To'
                          : 'To: ${formatIsoDate(_filterTo!)}',
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<int?>(
                      value: _filterCategoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
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
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Delete'),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _selected == null
                        ? null
                        : () async {
                            await widget.repo.unlinkEvent(_selected!);
                            await _refresh();
                          },
                    icon: const Icon(Icons.link_off),
                    label: const Text('Delete Event Only'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selected == null
                        ? null
                        : () async {
                            await widget.repo.deleteEventWithEntries(
                              _selected!,
                            );
                            await _refresh();
                          },
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Delete Event + Entries'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selected == null
                        ? null
                        : () => _editEvent(_selected!),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Name/Dates'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: !_entriesLoaded
                  ? const EmptyState(
                      message: 'Choose filters and tap Load Entries.',
                    )
                  : _entriesLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                  ? const EmptyState(
                      message: 'No entries under selected filters.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Entries (${_entries.length})'),
                        const Divider(),
                        ..._entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${formatIsoDate(e.date)} • ${e.category} / ${e.subcategory} • ${formatCurrency(e.amount)}',
                            ),
                          ),
                        ),
                        const Divider(),
                        Text(
                          'Total: ${formatCurrency(_entries.fold<double>(0, (a, b) => a + b.amount))}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }
}
