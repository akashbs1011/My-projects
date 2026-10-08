import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/history_entry.dart';
import '../services/history_service.dart';

class HistoryProvider extends ChangeNotifier {
  HistoryProvider(this._service);

  final HistoryService _service;

  List<HistoryEntry> _items = [];
  bool _loading = false;
  String? _error;
  int _total = 0;

  List<HistoryEntry> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;
  String? get error => _error;
  int get total => _total;
  bool get isEmpty => _items.isEmpty && !_loading && _error == null;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _service.list();
      _items = page.items;
      _total = page.total;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> remove(String id) async {
    // Removed locally first so the list responds immediately, and restored if
    // the server rejects it.
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return false;
    final removed = _items.removeAt(index);
    _total = (_total - 1).clamp(0, 1 << 30);
    notifyListeners();

    try {
      await _service.remove(id);
      return true;
    } on ApiException catch (e) {
      _items.insert(index, removed);
      _total += 1;
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> clear() async {
    final backup = List<HistoryEntry>.from(_items);
    final backupTotal = _total;
    _items = [];
    _total = 0;
    notifyListeners();

    try {
      await _service.clear();
      return true;
    } on ApiException catch (e) {
      _items = backup;
      _total = backupTotal;
      _error = e.message;
      notifyListeners();
      return false;
    }
  }
}
