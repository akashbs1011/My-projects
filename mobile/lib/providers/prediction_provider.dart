import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/disease.dart';
import '../models/prediction.dart';
import '../services/prediction_service.dart';

/// How the candidate list is ordered on the results screen.
///
/// The two orderings can disagree, and that disagreement is the point: a
/// condition the classifier ranks first may account for fewer of the reported
/// symptoms than one it ranks second. Letting the person switch makes the
/// difference visible rather than leaving it implied.
enum ResultSort { confidence, symptomMatch }

/// Runs the analysis and holds the most recent result.
class PredictionProvider extends ChangeNotifier {
  PredictionProvider(this._service);

  final PredictionService _service;

  AnalysisResult? _result;
  bool _analyzing = false;
  String? _error;
  ResultSort _sort = ResultSort.confidence;

  ResultSort get sort => _sort;

  AnalysisResult? get result => _result;

  /// Candidates in the currently selected order.
  ///
  /// Sorting happens here rather than on the server: both scores are already
  /// present in the response, so switching order needs no network call and is
  /// instant.
  List<PredictionResult> get orderedResults {
    final items = List<PredictionResult>.from(_result?.results ?? const []);
    switch (_sort) {
      case ResultSort.confidence:
        items.sort((a, b) => b.modelConfidence.compareTo(a.modelConfidence));
        break;
      case ResultSort.symptomMatch:
        // Ties broken by confidence so the order is deterministic.
        items.sort((a, b) {
          final c = b.symptomMatch.compareTo(a.symptomMatch);
          return c != 0 ? c : b.modelConfidence.compareTo(a.modelConfidence);
        });
        break;
    }
    return items;
  }

  void setSort(ResultSort value) {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
  }
  bool get isAnalyzing => _analyzing;
  String? get error => _error;
  bool get hasResult => _result != null;

  Future<bool> analyze(List<String> symptoms, String language) async {
    _analyzing = true;
    _error = null;
    notifyListeners();
    try {
      _result = await _service.analyze(symptoms: symptoms, language: language);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _analyzing = false;
      notifyListeners();
    }
  }

  /// Used by History so a saved analysis opens in the same results view.
  void showSaved(AnalysisResult result) {
    _result = result;
    _error = null;
    notifyListeners();
  }

  void clear() {
    _result = null;
    _error = null;
    notifyListeners();
  }

  Future<Disease> loadDisease(String slug, String language) =>
      _service.getDisease(slug, language: language);

  Future<({List<String> symptoms, List<String> suggestions})> extractSymptoms(
    String text,
    String language,
  ) =>
      _service.extractSymptoms(text, language: language);
}
