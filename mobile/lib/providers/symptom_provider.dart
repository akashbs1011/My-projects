import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/symptom.dart';
import '../services/prediction_service.dart';
import '../utils/constants.dart';

/// The symptom vocabulary and the person's current selection.
///
/// The vocabulary always comes from the backend, which builds it from
/// Training.csv. Nothing here contains a hard-coded symptom name.
class SymptomProvider extends ChangeNotifier {
  SymptomProvider(this._service);

  final PredictionService _service;

  List<Symptom> _all = [];
  List<Symptom> _visible = [];
  final List<Symptom> _selected = [];

  String _query = '';
  bool _loading = false;
  bool _searching = false;
  String? _error;
  Timer? _debounce;
  String _loadedLanguage = '';

  List<Symptom> get visible => List.unmodifiable(_visible);
  List<Symptom> get selected => List.unmodifiable(_selected);
  int get selectedCount => _selected.length;
  bool get isLoading => _loading;
  bool get isSearching => _searching;
  String? get error => _error;
  String get query => _query;
  bool get canAnalyze => _selected.length >= AppConstants.minSelectedSymptoms;
  int get remainingToMinimum =>
      (AppConstants.minSelectedSymptoms - _selected.length).clamp(0, 99);
  bool get atLimit => _selected.length >= AppConstants.maxSelectedSymptoms;

  bool isSelected(Symptom symptom) => _selected.contains(symptom);

  List<Symptom> _suggestions = [];
  bool _loadingSuggestions = false;

  List<Symptom> get suggestions => List.unmodifiable(_suggestions);
  bool get isLoadingSuggestions => _loadingSuggestions;

  /// Refreshes the co-occurrence prompts for the current selection.
  ///
  /// Silent on failure: a missing prompt is a lost convenience, not an error
  /// worth interrupting the person for.
  Future<void> refreshSuggestions(String language, {bool romanise = false}) async {
    if (_selected.isEmpty) {
      _suggestions = [];
      notifyListeners();
      return;
    }
    _loadingSuggestions = true;
    notifyListeners();
    try {
      final found = await _service.suggestSymptoms(
        _selected.map((s) => s.name).toList(),
        language: language,
        romanise: romanise,
      );
      _suggestions = found.where((s) => !_selected.contains(s)).toList();
    } catch (_) {
      _suggestions = [];
    } finally {
      _loadingSuggestions = false;
      notifyListeners();
    }
  }

  /// Loads the vocabulary, refetching when the language changes so labels
  /// arrive translated.
  Future<void> load(String language, {bool romanise = false, bool force = false}) async {
    if (!force && _loadedLanguage == language && _all.isNotEmpty) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _all = await _service.listSymptoms(language: language, romanise: romanise);
      _visible = _all;
      _loadedLanguage = language;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Debounced so typing does not fire a request per keystroke.
  void search(String query, String language) {
    _query = query;
    notifyListeners();

    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _visible = _all;
      _searching = false;
      notifyListeners();
      return;
    }

    _debounce = Timer(AppConstants.searchDebounce, () => _runSearch(query, language));
  }

  Future<void> _runSearch(String query, String language) async {
    _searching = true;
    notifyListeners();
    try {
      _visible = await _service.searchSymptoms(query, language: language);
    } on ApiException {
      // Falls back to filtering what is already loaded rather than emptying
      // the list because one request failed.
      final needle = query.toLowerCase();
      _visible = _all
          .where((s) =>
              s.label.toLowerCase().contains(needle) ||
              s.name.toLowerCase().contains(needle))
          .toList();
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _debounce?.cancel();
    _query = '';
    _visible = _all;
    notifyListeners();
  }

  void toggle(Symptom symptom) {
    if (_selected.contains(symptom)) {
      _selected.remove(symptom);
    } else {
      if (atLimit) return;
      _selected.add(symptom);
    }
    notifyListeners();
  }

  void remove(Symptom symptom) {
    _selected.remove(symptom);
    notifyListeners();
  }

  /// Adds symptoms by canonical name, used by voice input. Returns how many
  /// were genuinely new so the UI can report an accurate count.
  int addByNames(List<String> names) {
    var added = 0;
    for (final name in names) {
      if (atLimit) break;
      final match = _all.firstWhere(
        (s) => s.name == name,
        orElse: () => Symptom(name: name, label: name),
      );
      if (!_selected.contains(match)) {
        _selected.add(match);
        added++;
      }
    }
    if (added > 0) notifyListeners();
    return added;
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
