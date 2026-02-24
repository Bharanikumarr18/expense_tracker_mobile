import 'package:flutter/material.dart';

import 'data/tracker_repository.dart';
import 'ui/app_controller.dart';
import 'ui/home_shell.dart';

class TrackerMobileApp extends StatefulWidget {
  const TrackerMobileApp({super.key});

  @override
  State<TrackerMobileApp> createState() => _TrackerMobileAppState();
}

class _TrackerMobileAppState extends State<TrackerMobileApp> {
  late final TrackerRepository _repo;
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _repo = TrackerRepository();
    _controller = AppController(repo: _repo);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Finance Tracker Mobile',
          debugShowCheckedModeBanner: false,
          theme: _controller.themeData,
          home: HomeShell(repo: _repo, controller: _controller),
        );
      },
    );
  }
}
