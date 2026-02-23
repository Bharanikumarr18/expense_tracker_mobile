import 'package:flutter/material.dart';

import '../data/tracker_repository.dart';
import 'pages/add_expense_page.dart';
import 'pages/appliances_page.dart';
import 'pages/assets_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/events_page.dart';
import 'pages/export_page.dart';
import 'pages/import_page.dart';
import 'pages/income_page.dart';
import 'pages/longevity_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repo});

  final TrackerRepository repo;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<_NavItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      _NavItem(
        'Dashboard',
        Icons.dashboard_outlined,
        DashboardPage(repo: widget.repo),
      ),
      _NavItem(
        'Add Expense',
        Icons.add_circle_outline,
        AddExpensePage(repo: widget.repo),
      ),
      _NavItem(
        'Import',
        Icons.file_upload_outlined,
        ImportPage(repo: widget.repo),
      ),
      _NavItem(
        'Events',
        Icons.event_note_outlined,
        EventsPage(repo: widget.repo),
      ),
      _NavItem(
        'Export',
        Icons.picture_as_pdf_outlined,
        ExportPage(repo: widget.repo),
      ),
      _NavItem(
        'Appliances',
        Icons.kitchen_outlined,
        AppliancesPage(repo: widget.repo),
      ),
      _NavItem(
        'Income',
        Icons.payments_outlined,
        IncomePage(repo: widget.repo),
      ),
      _NavItem(
        'Assets',
        Icons.account_balance_outlined,
        AssetsPage(repo: widget.repo),
      ),
      _NavItem(
        'Longevity',
        Icons.shield_outlined,
        LongevityPage(repo: widget.repo),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;

        if (!wide) {
          return Scaffold(
            appBar: AppBar(title: Text(item.title)),
            drawer: Drawer(
              child: ListView(
                children: [
                  const DrawerHeader(child: Text('Finance Tracker Mobile')),
                  ...List.generate(_items.length, (i) {
                    final n = _items[i];
                    return ListTile(
                      leading: Icon(n.icon),
                      title: Text(n.title),
                      selected: i == _index,
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.of(context).pop();
                      },
                    );
                  }),
                ],
              ),
            ),
            body: item.page,
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Finance Tracker Mobile')),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (v) => setState(() => _index = v),
                labelType: NavigationRailLabelType.all,
                destinations: _items
                    .map(
                      (n) => NavigationRailDestination(
                        icon: Icon(n.icon),
                        label: Text(n.title),
                      ),
                    )
                    .toList(growable: false),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: item.page),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final Widget page;

  _NavItem(this.title, this.icon, this.page);
}
