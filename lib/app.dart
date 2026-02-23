import 'package:flutter/material.dart';

import 'data/tracker_repository.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

class TrackerMobileApp extends StatelessWidget {
  const TrackerMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = TrackerRepository();
    return MaterialApp(
      title: 'Finance Tracker Mobile',
      debugShowCheckedModeBanner: false,
      theme: TrackerTheme.dark(),
      home: HomeShell(repo: repo),
    );
  }
}
