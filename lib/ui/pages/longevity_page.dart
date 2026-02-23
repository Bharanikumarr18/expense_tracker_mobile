import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';

class LongevityPage extends StatefulWidget {
  const LongevityPage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<LongevityPage> createState() => _LongevityPageState();
}

class _LongevityPageState extends State<LongevityPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _status = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  String _humanSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffix = ['B', 'KB', 'MB', 'GB'];
    final i = min((log(bytes) / log(1024)).floor(), suffix.length - 1);
    final value = bytes / pow(1024, i);
    return '${value.toStringAsFixed(i == 0 ? 0 : 2)} ${suffix[i]}';
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final st = await widget.repo.getLongevityStatus();
      if (!mounted) return;
      setState(() {
        _status = st;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Longevity page failed to load'),
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
          'Longevity',
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
                  'System Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Expense entries: ${_status['expense_count'] ?? 0}'),
                Text('Income entries: ${_status['income_count'] ?? 0}'),
                Text('Events: ${_status['event_count'] ?? 0}'),
                Text(
                  'DB size: ${_humanSize((_status['db_size_bytes'] ?? 0) as int)}',
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Status'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
