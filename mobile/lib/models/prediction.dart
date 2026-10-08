/// One candidate condition returned by the Random Forest classifier.
///
/// The two scores mean different things and are deliberately kept apart:
///
///   [symptomMatch]     share of the symptoms recorded for this condition in
///                      Training.csv that the person actually selected.
///   [modelConfidence]  the classifier's raw probability for this class.
///
/// Neither is a medically validated probability, and the UI says so wherever
/// either one is shown.
class PredictionResult {
  const PredictionResult({
    required this.disease,
    required this.slug,
    required this.modelConfidence,
    required this.symptomMatch,
    required this.matchedSymptoms,
    required this.unmatchedSymptoms,
    required this.explanation,
    required this.rank,
    this.diseaseTranslated,
    this.explanationTranslated,
  });

  final String disease;
  final String slug;
  final double modelConfidence;
  final double symptomMatch;
  final List<String> matchedSymptoms;
  final List<String> unmatchedSymptoms;
  final String explanation;
  final int rank;
  final String? diseaseTranslated;
  final String? explanationTranslated;

  /// Prefers the translated text when the backend supplied one.
  String get displayName => diseaseTranslated ?? disease;
  String get displayExplanation => explanationTranslated ?? explanation;

  int get totalSelected => matchedSymptoms.length + unmatchedSymptoms.length;

  factory PredictionResult.fromJson(Map<String, dynamic> json) =>
      PredictionResult(
        disease: json['disease'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        modelConfidence: (json['model_confidence'] as num?)?.toDouble() ?? 0,
        symptomMatch: (json['symptom_match'] as num?)?.toDouble() ?? 0,
        matchedSymptoms:
            (json['matched_symptoms'] as List?)?.cast<String>() ?? const [],
        unmatchedSymptoms:
            (json['unmatched_symptoms'] as List?)?.cast<String>() ?? const [],
        explanation: json['explanation'] as String? ?? '',
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        diseaseTranslated: json['disease_translated'] as String?,
        explanationTranslated: json['explanation_translated'] as String?,
      );
}

/// Whether any selected symptom is on the backend's red-flag list.
class UrgencyNotice {
  const UrgencyNotice({
    required this.urgent,
    required this.triggeredSymptoms,
    this.notice,
    this.noticeTranslated,
  });

  final bool urgent;
  final List<String> triggeredSymptoms;
  final String? notice;
  final String? noticeTranslated;

  String? get displayNotice => noticeTranslated ?? notice;

  factory UrgencyNotice.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UrgencyNotice(urgent: false, triggeredSymptoms: []);
    }
    return UrgencyNotice(
      urgent: json['urgent'] as bool? ?? false,
      triggeredSymptoms:
          (json['triggered_symptoms'] as List?)?.cast<String>() ?? const [],
      notice: json['notice'] as String?,
      noticeTranslated: json['notice_translated'] as String?,
    );
  }
}

/// The full response from POST /api/predictions/analyze.
class AnalysisResult {
  const AnalysisResult({
    required this.results,
    required this.recognisedSymptoms,
    required this.unrecognisedSymptoms,
    required this.urgency,
    required this.disclaimer,
    required this.language,
    this.message,
    this.historyId,
    this.translationNote,
  });

  final List<PredictionResult> results;
  final List<String> recognisedSymptoms;

  /// Symptoms the dataset has no column for. Reported rather than dropped
  /// silently, so the person knows what was left out of the analysis.
  final List<String> unrecognisedSymptoms;
  final UrgencyNotice urgency;
  final String disclaimer;
  final String language;
  final String? message;
  final String? historyId;
  final String? translationNote;

  bool get isEmpty => results.isEmpty;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
        results: (json['results'] as List? ?? [])
            .map((e) => PredictionResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        recognisedSymptoms:
            (json['recognised_symptoms'] as List?)?.cast<String>() ?? const [],
        unrecognisedSymptoms:
            (json['unrecognised_symptoms'] as List?)?.cast<String>() ?? const [],
        urgency: UrgencyNotice.fromJson(
            json['urgency'] as Map<String, dynamic>?),
        disclaimer: json['disclaimer'] as String? ?? '',
        language: json['language'] as String? ?? 'en',
        message: json['message'] as String?,
        historyId: json['history_id'] as String?,
        translationNote: json['translation_note'] as String?,
      );
}
