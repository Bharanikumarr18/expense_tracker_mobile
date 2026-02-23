import 'package:flutter/material.dart';

import 'app.dart';
import 'data/db_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDatabaseRuntime();
  runApp(const TrackerMobileApp());
}
