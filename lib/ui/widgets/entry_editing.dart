import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class RowEditSession {
  int? _editingId;
  EntryEditController? _controller;
  final Map<int, ValueNotifier<bool>> _flags = {};

  int? get editingId => _editingId;
  EntryEditController? get controller => _controller;

  ValueListenable<bool> flagFor(int id) {
    return _flags.putIfAbsent(id, () => ValueNotifier(false));
  }

  void begin(int id, EntryEditController controller) {
    if (_editingId == id) return;
    _setFlag(_editingId, false);
    _controller?.dispose();
    _controller = controller;
    _editingId = id;
    _setFlag(id, true);
  }

  void cancel() {
    _setFlag(_editingId, false);
    _editingId = null;
    _controller?.dispose();
    _controller = null;
  }

  void dispose() {
    cancel();
    for (final flag in _flags.values) {
      flag.dispose();
    }
    _flags.clear();
  }

  void _setFlag(int? id, bool value) {
    if (id == null) return;
    final flag = _flags[id];
    if (flag != null) {
      flag.value = value;
    }
  }
}

class EntryEditController {
  EntryEditController({required this.amountCtrl});

  final TextEditingController amountCtrl;

  factory EntryEditController.fromAmount(double amount) {
    return EntryEditController(
      amountCtrl: TextEditingController(text: amount.toStringAsFixed(2)),
    );
  }

  void dispose() {
    amountCtrl.dispose();
  }
}
