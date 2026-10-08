import 'package:clinical_ai/models/history_entry.dart';
import 'package:clinical_ai/models/prediction.dart';
import 'package:clinical_ai/models/symptom.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PredictionResult', () {
    final json = {
      'disease': 'Influenza',
      'slug': 'influenza',
      'model_confidence': 0.82,
      'symptom_match': 0.6667,
      'matched_symptoms': ['fever', 'cough', 'fatigue'],
      'unmatched_symptoms': ['itching'],
      'explanation': '3 of your 4 selected symptoms match...',
      'rank': 1,
    };

    test('parses both scores separately', () {
      final result = PredictionResult.fromJson(json);
      expect(result.modelConfidence, 0.82);
      expect(result.symptomMatch, 0.6667);
      // The two must never be conflated - they measure different things.
      expect(result.modelConfidence, isNot(result.symptomMatch));
    });

    test('counts every selected symptom, matched or not', () {
      expect(PredictionResult.fromJson(json).totalSelected, 4);
    });

    test('prefers a translated name when the backend supplies one', () {
      final translated = PredictionResult.fromJson({
        ...json,
        'disease_translated': 'ಇನ್ಫ್ಲುಯೆನ್ಸ',
      });
      expect(translated.displayName, 'ಇನ್ಫ್ಲುಯೆನ್ಸ');
      expect(PredictionResult.fromJson(json).displayName, 'Influenza');
    });

    test('tolerates missing optional fields without throwing', () {
      final sparse = PredictionResult.fromJson({'disease': 'Unknown'});
      expect(sparse.matchedSymptoms, isEmpty);
      expect(sparse.modelConfidence, 0);
    });
  });

  group('AnalysisResult', () {
    test('surfaces unrecognised symptoms rather than dropping them', () {
      final result = AnalysisResult.fromJson({
        'results': [],
        'recognised_symptoms': ['fever'],
        'unrecognised_symptoms': ['sparkly toes'],
        'urgency': {'urgent': false, 'triggered_symptoms': []},
        'disclaimer': 'This tool provides general information...',
        'language': 'en',
      });
      expect(result.unrecognisedSymptoms, ['sparkly toes']);
      expect(result.isEmpty, isTrue);
    });

    test('parses the urgency notice', () {
      final result = AnalysisResult.fromJson({
        'results': [],
        'urgency': {
          'urgent': true,
          'triggered_symptoms': ['chest pain'],
          'notice': 'Some selected symptoms may require prompt medical attention.',
        },
        'disclaimer': '',
        'language': 'en',
      });
      expect(result.urgency.urgent, isTrue);
      expect(result.urgency.displayNotice, contains('prompt medical attention'));
    });

    test('handles a null urgency block', () {
      final result = AnalysisResult.fromJson({
        'results': [], 'disclaimer': '', 'language': 'en',
      });
      expect(result.urgency.urgent, isFalse);
    });
  });

  group('Symptom', () {
    test('compares by canonical dataset name, not display label', () {
      const a = Symptom(name: 'high fever', label: 'High fever');
      const b = Symptom(name: 'high fever', label: 'ಅಧಿಕ ಜ್ವರ');
      // Same dataset symptom shown in two languages is still one selection.
      expect(a, equals(b));
      expect({a, b}.length, 1);
    });
  });

  group('HistoryEntry', () {
    test('parses a saved analysis', () {
      final entry = HistoryEntry.fromJson({
        'id': '507f1f77bcf86cd799439011',
        'symptoms': ['fever', 'cough'],
        'predictions': [],
        'selected_language': 'kn',
        'top_prediction': {
          'disease': 'Influenza',
          'slug': 'influenza',
          'model_confidence': 0.82,
          'symptom_match': 0.67,
        },
        'created_at': '2026-01-15T10:30:00Z',
      });
      expect(entry.topPrediction?.disease, 'Influenza');
      expect(entry.selectedLanguage, 'kn');
      expect(entry.createdAt, isNotNull);
    });
  });
}
