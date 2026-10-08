import '../models/disease.dart';
import '../models/prediction.dart';
import '../models/symptom.dart';
import '../utils/constants.dart';

import 'api_client.dart';

/// Symptom vocabulary, analysis, and disease detail.
///
/// The symptom list is always fetched from the backend, which derives it from
/// Training.csv. No symptom or disease name is hard-coded in this app.
class PredictionService {
  const PredictionService(this._api);

  final ApiClient _api;

  Future<List<Symptom>> listSymptoms({
    String language = 'en',
    bool romanise = false,
  }) async {
    final data = await _api.get('/symptoms', query: {
      'language': language,
      'romanise': romanise,
    });
    return (data['symptoms'] as List)
        .map((e) => Symptom.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Symptom>> searchSymptoms(
    String query, {
    String language = 'en',
    int limit = AppConstants.symptomSearchLimit,
  }) async {
    final data = await _api.get('/symptoms/search', query: {
      'q': query,
      'language': language,
      'limit': limit,
    });
    return (data['symptoms'] as List)
        .map((e) => Symptom.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Symptoms commonly recorded alongside the current selection.
  ///
  /// Advisory only. Failures return an empty list rather than surfacing an
  /// error, because a missing prompt should never obstruct the main task.
  Future<List<Symptom>> suggestSymptoms(
    List<String> selected, {
    String language = 'en',
    bool romanise = false,
    int limit = 6,
  }) async {
    if (selected.isEmpty) return const [];
    try {
      final data = await _api.get('/symptoms/suggest', query: {
        'selected': selected.join(','),
        'language': language,
        'romanise': romanise,
        'limit': limit,
      });
      return (data['suggestions'] as List)
          .map((e) => Symptom.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<AnalysisResult> analyze({
    required List<String> symptoms,
    String language = 'en',
    bool saveToHistory = true,
  }) async {
    final data = await _api.post('/predictions/analyze', body: {
      'symptoms': symptoms,
      'language': language,
      'save_to_history': saveToHistory,
    });
    return AnalysisResult.fromJson(data as Map<String, dynamic>);
  }

  /// Turns dictated or typed free text into canonical dataset symptoms.
  ///
  /// Returns exact matches and lower-confidence suggestions separately so the
  /// UI can confirm the uncertain ones instead of assuming.
  Future<({List<String> symptoms, List<String> suggestions})>
      extractSymptoms(String text, {String? language}) async {
    final data = await _api.post('/predictions/extract-symptoms', body: {
      'text': text,
      if (language != null) 'language': language,
    });
    final map = data as Map<String, dynamic>;
    final suggestions = (map['suggestions'] as List? ?? [])
        .map((e) => (e as Map<String, dynamic>)['symptom'] as String)
        .toList();
    return (
      symptoms: (map['symptoms'] as List?)?.cast<String>() ?? <String>[],
      suggestions: suggestions,
    );
  }

  Future<Disease> getDisease(String slug, {String language = 'en'}) async {
    final data = await _api.get('/diseases/$slug', query: {'language': language});
    return Disease.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> health() async =>
      (await _api.get('/health') as Map).cast<String, dynamic>();
}
