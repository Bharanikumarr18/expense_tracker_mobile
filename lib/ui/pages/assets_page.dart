import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> with TickerProviderStateMixin {
  final _goldCtrl = TextEditingController();
  final _silverCtrl = TextEditingController();

  final _metalWeightCtrl = TextEditingController(text: '0');
  String _metalType = 'Gold';
  DateTime _metalDate = DateTime.now();

  final _landLocCtrl = TextEditingController();
  final _landAreaCtrl = TextEditingController(text: '0');
  final _landRateCtrl = TextEditingController(text: '0');
  DateTime _landDate = DateTime.now();

  final _fdNameCtrl = TextEditingController();
  final _fdPrincipalCtrl = TextEditingController(text: '0');
  final _fdRateCtrl = TextEditingController(text: '0');
  final _fdTenureCtrl = TextEditingController(text: '365');
  DateTime _fdDate = DateTime.now();

  final _licNameCtrl = TextEditingController();
  final _licPremiumCtrl = TextEditingController(text: '0');
  final _licFreqCtrl = TextEditingController(text: 'Monthly');
  final _licMaturityAmountCtrl = TextEditingController(text: '0');
  DateTime? _licLastPremium;
  DateTime _licMaturityDate = DateTime.now().add(const Duration(days: 365));

  bool _loading = true;
  String? _error;
  Map<String, double> _totals = const {
    'metal': 0,
    'land': 0,
    'fd': 0,
    'lic': 0,
    'total': 0,
  };
  Map<String, double> _prices = const {
    'gold_price': 14400,
    'silver_price': 345,
  };

  List<MetalAssetEntry> _metalEntries = const [];
  List<LandAssetEntry> _landEntries = const [];
  List<FixedDepositEntry> _fdEntries = const [];
  List<LicPolicyEntry> _licEntries = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _goldCtrl.dispose();
    _silverCtrl.dispose();
    _metalWeightCtrl.dispose();
    _landLocCtrl.dispose();
    _landAreaCtrl.dispose();
    _landRateCtrl.dispose();
    _fdNameCtrl.dispose();
    _fdPrincipalCtrl.dispose();
    _fdRateCtrl.dispose();
    _fdTenureCtrl.dispose();
    _licNameCtrl.dispose();
    _licPremiumCtrl.dispose();
    _licFreqCtrl.dispose();
    _licMaturityAmountCtrl.dispose();
    super.dispose();
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

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prices = await widget.repo.getAssetPrices();
      final totals = await widget.repo.getAssetTotals();
      final metal = await widget.repo.getMetalAssets();
      final land = await widget.repo.getLandAssets();
      final fds = await widget.repo.getFixedDeposits();
      final lic = await widget.repo.getLicPolicies();

      if (!mounted) return;

      setState(() {
        _prices = prices;
        _goldCtrl.text = (_prices['gold_price'] ?? 0).toStringAsFixed(2);
        _silverCtrl.text = (_prices['silver_price'] ?? 0).toStringAsFixed(2);
        _totals = totals;
        _metalEntries = metal;
        _landEntries = land;
        _fdEntries = fds;
        _licEntries = lic;
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

  Future<void> _savePrices() async {
    final gold = double.tryParse(_goldCtrl.text.trim()) ?? 0;
    final silver = double.tryParse(_silverCtrl.text.trim()) ?? 0;
    await widget.repo.saveAssetPrice('gold_price', gold);
    await widget.repo.saveAssetPrice('silver_price', silver);
    await _refresh();
  }

  Future<void> _addMetal() async {
    final weight = double.tryParse(_metalWeightCtrl.text.trim());
    if (weight == null || weight <= 0) return;
    await widget.repo.addMetalAsset(_metalType, weight, _metalDate);
    _metalWeightCtrl.text = '0';
    await _refresh();
  }

  Future<void> _addLand() async {
    final loc = _landLocCtrl.text.trim();
    final area = double.tryParse(_landAreaCtrl.text.trim());
    final rate = double.tryParse(_landRateCtrl.text.trim());
    if (loc.isEmpty || area == null || area <= 0 || rate == null || rate <= 0)
      return;
    await widget.repo.addLandAsset(loc, area, rate, _landDate);
    _landLocCtrl.clear();
    _landAreaCtrl.text = '0';
    _landRateCtrl.text = '0';
    await _refresh();
  }

  Future<void> _addFd() async {
    final name = _fdNameCtrl.text.trim();
    final principal = double.tryParse(_fdPrincipalCtrl.text.trim());
    final rate = double.tryParse(_fdRateCtrl.text.trim());
    final days = int.tryParse(_fdTenureCtrl.text.trim());
    if (name.isEmpty ||
        principal == null ||
        principal <= 0 ||
        rate == null ||
        rate < 0 ||
        days == null ||
        days <= 0)
      return;
    await widget.repo.addFixedDeposit(
      name: name,
      principal: principal,
      rate: rate,
      tenureDays: days,
      depositDate: _fdDate,
    );
    _fdNameCtrl.clear();
    _fdPrincipalCtrl.text = '0';
    _fdRateCtrl.text = '0';
    _fdTenureCtrl.text = '365';
    await _refresh();
  }

  Future<void> _addLic() async {
    final name = _licNameCtrl.text.trim();
    final premium = double.tryParse(_licPremiumCtrl.text.trim());
    final maturity = double.tryParse(_licMaturityAmountCtrl.text.trim());
    final freq = _licFreqCtrl.text.trim().isEmpty
        ? 'Monthly'
        : _licFreqCtrl.text.trim();
    if (name.isEmpty ||
        premium == null ||
        premium <= 0 ||
        maturity == null ||
        maturity <= 0)
      return;

    await widget.repo.addLicPolicy(
      policyName: name,
      premiumAmount: premium,
      premiumFrequency: freq,
      lastPremiumDate: _licLastPremium,
      maturityDate: _licMaturityDate,
      maturityAmount: maturity,
    );

    _licNameCtrl.clear();
    _licPremiumCtrl.text = '0';
    _licMaturityAmountCtrl.text = '0';
    _licLastPremium = null;
    await _refresh();
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
              const Text('Assets page failed to load'),
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

    return DefaultTabController(
      length: 4,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Assets',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _goldCtrl,
                  decoration: const InputDecoration(labelText: 'Gold Price /g'),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _silverCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Silver Price /g',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _savePrices,
                child: const Text('Save Gold/Silver Price'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 250,
                child: SummaryCard(
                  title: 'Metal Value',
                  value: _totals['metal'] ?? 0,
                ),
              ),
              SizedBox(
                width: 250,
                child: SummaryCard(
                  title: 'Land Value',
                  value: _totals['land'] ?? 0,
                ),
              ),
              SizedBox(
                width: 250,
                child: SummaryCard(
                  title: 'FD Principal',
                  value: _totals['fd'] ?? 0,
                ),
              ),
              SizedBox(
                width: 250,
                child: SummaryCard(
                  title: 'LIC Maturity',
                  value: _totals['lic'] ?? 0,
                ),
              ),
              SizedBox(
                width: 260,
                child: SummaryCard(
                  title: 'Total Asset Value',
                  value: _totals['total'] ?? 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Metal'),
              Tab(text: 'Land'),
              Tab(text: 'Fixed Deposit'),
              Tab(text: 'LIC'),
            ],
          ),
          SizedBox(
            height: 620,
            child: TabBarView(
              children: [
                _buildMetalTab(),
                _buildLandTab(),
                _buildFdTab(),
                _buildLicTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetalTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      children: [
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('Add Metal Asset'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            DropdownButtonFormField<String>(
              value: _metalType,
              decoration: const InputDecoration(
                labelText: 'Metal Type',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              items: const [
                DropdownMenuItem(value: 'Gold', child: Text('Gold')),
                DropdownMenuItem(value: 'Silver', child: Text('Silver')),
              ],
              onChanged: (v) => setState(() => _metalType = v ?? 'Gold'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _metalWeightCtrl,
              decoration: const InputDecoration(
                labelText: 'Weight (grams)',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _pickDate(
                    initial: _metalDate,
                    onChanged: (d) => setState(() => _metalDate = d),
                  ),
                  child: Text('Date: ${formatIsoDate(_metalDate)}'),
                ),
                ElevatedButton(
                  onPressed: _addMetal,
                  child: const Text('Add Metal Asset'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('Metal Entries'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            if (_metalEntries.isEmpty)
              const EmptyState(message: 'No metal entries yet.')
            else
              ..._metalEntries.map(
                (e) => ListTile(
                  title: Text(
                    '${e.metalType} • ${e.weightGrams.toStringAsFixed(2)} g',
                  ),
                  subtitle: Text(formatIsoDate(e.entryDate)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.repo.deleteMetalAsset(e.id);
                      await _refresh();
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLandTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('Add Land Asset'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            TextField(
              controller: _landLocCtrl,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _landAreaCtrl,
              decoration: const InputDecoration(labelText: 'Area (sqft)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _landRateCtrl,
              decoration: const InputDecoration(labelText: 'Price / sqft'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _pickDate(
                    initial: _landDate,
                    onChanged: (d) => setState(() => _landDate = d),
                  ),
                  child: Text('Date: ${formatIsoDate(_landDate)}'),
                ),
                ElevatedButton(
                  onPressed: _addLand,
                  child: const Text('Add Land Asset'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('Land Entries'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            if (_landEntries.isEmpty)
              const EmptyState(message: 'No land entries yet.')
            else
              ..._landEntries.map(
                (e) => ListTile(
                  title: Text(e.location),
                  subtitle: Text(
                    '${e.areaSize.toStringAsFixed(2)} sqft × ${formatCurrency(e.pricePerUnit)}\n${formatIsoDate(e.entryDate)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.repo.deleteLandAsset(e.id);
                      await _refresh();
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFdTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('Add Fixed Deposit'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            TextField(
              controller: _fdNameCtrl,
              decoration: const InputDecoration(labelText: 'FD Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fdPrincipalCtrl,
              decoration: const InputDecoration(labelText: 'Principal'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fdRateCtrl,
              decoration: const InputDecoration(labelText: 'Rate (%)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fdTenureCtrl,
              decoration: const InputDecoration(labelText: 'Tenure (days)'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _pickDate(
                    initial: _fdDate,
                    onChanged: (d) => setState(() => _fdDate = d),
                  ),
                  child: Text('Deposit Date: ${formatIsoDate(_fdDate)}'),
                ),
                ElevatedButton(onPressed: _addFd, child: const Text('Add FD')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('FD Entries'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            if (_fdEntries.isEmpty)
              const EmptyState(message: 'No fixed deposits yet.')
            else
              ..._fdEntries.map(
                (e) => ListTile(
                  title: Text('${e.name} • ${formatCurrency(e.principal)}'),
                  subtitle: Text(
                    'Rate ${e.rate.toStringAsFixed(2)}% • ${e.tenureDays} days\n${formatIsoDate(e.depositDate)} → ${formatIsoDate(e.maturityDate)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.repo.deleteFixedDeposit(e.id);
                      await _refresh();
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLicTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('Add LIC'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            TextField(
              controller: _licNameCtrl,
              decoration: const InputDecoration(labelText: 'Policy Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _licPremiumCtrl,
              decoration: const InputDecoration(labelText: 'Premium Amount'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _licFreqCtrl,
              decoration: const InputDecoration(labelText: 'Premium Frequency'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _licMaturityAmountCtrl,
              decoration: const InputDecoration(labelText: 'Maturity Amount'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _pickDate(
                    initial: _licLastPremium ?? DateTime.now(),
                    onChanged: (d) => setState(() => _licLastPremium = d),
                  ),
                  child: Text(
                    _licLastPremium == null
                        ? 'Last Premium Date (optional)'
                        : 'Last Premium: ${formatIsoDate(_licLastPremium!)}',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _pickDate(
                    initial: _licMaturityDate,
                    onChanged: (d) => setState(() => _licMaturityDate = d),
                  ),
                  child: Text('Maturity: ${formatIsoDate(_licMaturityDate)}'),
                ),
                ElevatedButton(
                  onPressed: _addLic,
                  child: const Text('Add LIC'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('LIC Entries'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            if (_licEntries.isEmpty)
              const EmptyState(message: 'No LIC policies yet.')
            else
              ..._licEntries.map(
                (e) => ListTile(
                  title: Text(e.policyName),
                  subtitle: Text(
                    'Premium ${formatCurrency(e.premiumAmount)} (${e.premiumFrequency})\nMaturity ${formatCurrency(e.maturityAmount)} on ${formatIsoDate(e.maturityDate)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.repo.deleteLicPolicy(e.id);
                      await _refresh();
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
