import 'package:flutter/material.dart';

import '../data/tracker_repository.dart';
import 'app_controller.dart';
import 'pages/add_expense_page.dart';
import 'pages/appliances_page.dart';
import 'pages/assets_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/events_page.dart';
import 'pages/entries_page.dart';
import 'pages/export_page.dart';
import 'pages/import_page.dart';
import 'pages/income_page.dart';
import 'pages/insights_page.dart';
import 'pages/longevity_page.dart';
import 'pages/settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repo, required this.controller});

  final TrackerRepository repo;
  final AppController controller;

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
        'Entries',
        Icons.table_rows_outlined,
        EntriesPage(repo: widget.repo),
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
        'Insights',
        Icons.insights_outlined,
        InsightsPage(repo: widget.repo),
      ),
      _NavItem(
        'Longevity',
        Icons.shield_outlined,
        LongevityPage(repo: widget.repo),
      ),
      _NavItem(
        'Settings',
        Icons.settings_outlined,
        SettingsPage(controller: widget.controller),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];
    Widget navRail() {
      return SafeArea(
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Text(
                  'Finance Tracker Mobile',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Scrollbar(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final n = _items[i];
                      final selected = i == _index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          dense: true,
                          selected: selected,
                          leading: Icon(n.icon),
                          title: Text(n.title),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () => setState(() => _index = i),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget animatedPage(Widget child) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (widget, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: widget),
          );
        },
        child: KeyedSubtree(key: ValueKey(_index), child: child),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;

        if (!wide) {
          return Scaffold(
            appBar: AppBar(title: Text(item.title)),
            drawer: Drawer(
              child: SafeArea(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Finance Tracker Mobile',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Divider(height: 1),
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
            ),
            body: SafeArea(child: animatedPage(item.page)),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Finance Tracker Mobile')),
          body: Row(
            children: [
              navRail(),
              const VerticalDivider(width: 1),
              Expanded(child: SafeArea(child: animatedPage(item.page))),
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
