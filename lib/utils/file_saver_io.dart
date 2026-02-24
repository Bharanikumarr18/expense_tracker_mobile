import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> saveBytesToDirectory({
  required Uint8List bytes,
  required String fileName,
  String? directoryPath,
}) async {
  final dir = directoryPath ?? await _defaultExportDir();
  if (dir == null) return null;
  final directory = Directory(dir);
  await directory.create(recursive: true);
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String?> _defaultExportDir() async {
  final docs = await getApplicationDocumentsDirectory();
  return '${docs.path}/tracker_exports';
}
