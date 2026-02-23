import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class AppliancesPage extends StatefulWidget {
  const AppliancesPage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<AppliancesPage> createState() => _AppliancesPageState();
}

class _AppliancesPageState extends State<AppliancesPage> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _deprCtrl = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  DateTime? _warrantyExpiry;
  bool _loading = true;
  List<ApplianceEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _deprCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final rows = await widget.repo.getAppliances();
    if (!mounted) return;
    setState(() {
      _entries = rows;
      _loading = false;
    });
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

  double _currentValue(ApplianceEntry e) {
    if (e.depreciationYears == null || e.depreciationYears! <= 0) {
      return e.price;
    }
    final days = DateTime.now()
        .difference(e.purchaseDate)
        .inDays
        .clamp(0, e.depreciationYears! * 365);
    final ratio = 1 - (days / (e.depreciationYears! * 365));
    return e.price * ratio;
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final years = int.tryParse(_deprCtrl.text.trim());

    if (name.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid appliance details')),
      );
      return;
    }

    await widget.repo.addAppliance(
      name: name,
      price: price,
      purchaseDate: _purchaseDate,
      warrantyExpiry: _warrantyExpiry,
      depreciationYears: years,
    );

    _nameCtrl.clear();
    _priceCtrl.text = '0';
    _deprCtrl.clear();
    _warrantyExpiry = null;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Appliances',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Appliance Name',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _deprCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Depreciation Years (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _pickDate(
                        initial: _purchaseDate,
                        onChanged: (d) => setState(() => _purchaseDate = d),
                      ),
                      child: Text('Purchase: ${formatIsoDate(_purchaseDate)}'),
                    ),
                    OutlinedButton(
                      onPressed: () => _pickDate(
                        initial: _warrantyExpiry ?? _purchaseDate,
                        onChanged: (d) => setState(() => _warrantyExpiry = d),
                      ),
                      child: Text(
                        _warrantyExpiry == null
                            ? 'Warranty Expiry (optional)'
                            : 'Warranty: ${formatIsoDate(_warrantyExpiry!)}',
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _add,
                      child: const Text('Add Appliance'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_entries.isEmpty)
          const EmptyState(message: 'No appliance entries yet.')
        else
          ..._entries.map((e) {
            final current = _currentValue(e);
            final warrantyDays = e.warrantyExpiry == null
                ? null
                : e.warrantyExpiry!.difference(DateTime.now()).inDays;
            return Card(
              child: ListTile(
                title: Text(e.name),
                subtitle: Text(
                  'Price: ${formatCurrency(e.price)}\nCurrent (depr.): ${formatCurrency(current)}\nPurchase: ${formatIsoDate(e.purchaseDate)}${warrantyDays == null ? '' : '\nWarranty left: ${warrantyDays >= 0 ? '$warrantyDays days' : 'Expired'}'}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await widget.repo.deleteAppliance(e.id);
                    await _refresh();
                  },
                ),
              ),
            );
          }),
      ],
    );
  }
}
