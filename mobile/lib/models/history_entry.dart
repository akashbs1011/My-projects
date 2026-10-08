import 'prediction.dart';

class TopPrediction {
  const TopPrediction({
    required this.disease,
    required this.slug,
    required this.modelConfidence,
    required this.symptomMatch,
  });

  final String disease;
  final String slug;
  final double modelConfidence;
  final double symptomMatch;

  static TopPrediction? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return TopPrediction(
      disease: json['disease'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      modelConfidence: (json['model_confidence'] as num?)?.toDouble() ?? 0,
      symptomMatch: (json['symptom_match'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// One saved analysis from prediction_history in MongoDB.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.symptoms,
    required this.predictions,
    required this.selectedLanguage,
    this.topPrediction,
    this.createdAt,
  });

  final String id;
  final List<String> symptoms;
  final List<PredictionResult> predictions;
  final String selectedLanguage;
  final TopPrediction? topPrediction;
  final DateTime? createdAt;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String? ?? '',
        symptoms: (json['symptoms'] as List?)?.cast<String>() ?? const [],
        predictions: (json['predictions'] as List? ?? [])
            .map((e) => PredictionResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        selectedLanguage: json['selected_language'] as String? ?? 'en',
        topPrediction:
            TopPrediction.fromJson(json['top_prediction'] as Map<String, dynamic>?),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );
}
