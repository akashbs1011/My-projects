/// A symptom recorded for a condition in Training.csv, with the measured
/// fraction of that condition's records in which it appears.
class DiseaseSymptom {
  const DiseaseSymptom({required this.name, required this.support});

  final String name;
  final double support;

  factory DiseaseSymptom.fromJson(Map<String, dynamic> json) => DiseaseSymptom(
        name: json['name'] as String? ?? '',
        support: (json['support'] as num?)?.toDouble() ?? 0,
      );
}

class DiseaseSeverity {
  const DiseaseSeverity({
    required this.meanWeight,
    required this.maxWeight,
    required this.scale,
  });

  final double meanWeight;
  final int maxWeight;
  final String scale;

  static DiseaseSeverity? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['mean_symptom_weight'] == null) return null;
    return DiseaseSeverity(
      meanWeight: (json['mean_symptom_weight'] as num).toDouble(),
      maxWeight: (json['max_symptom_weight'] as num?)?.toInt() ?? 0,
      scale: json['scale'] as String? ?? '',
    );
  }
}

/// Disease detail. Every text field can be absent, in which case the API
/// supplies the "not in the knowledge base" message instead of content the
/// application invented.
class Disease {
  const Disease({
    required this.name,
    required this.slug,
    required this.overview,
    required this.precautions,
    required this.commonSymptoms,
    required this.whenToSeekCare,
    required this.symptomSource,
    required this.disclaimer,
    this.severity,
    this.nameTranslated,
    this.overviewTranslated,
    this.whenToSeekCareTranslated,
    this.precautionsMessage,
  });

  final String name;
  final String slug;
  final String overview;
  final List<String> precautions;
  final List<DiseaseSymptom> commonSymptoms;
  final String whenToSeekCare;
  final String symptomSource;
  final String disclaimer;
  final DiseaseSeverity? severity;
  final String? nameTranslated;
  final String? overviewTranslated;
  final String? whenToSeekCareTranslated;
  final String? precautionsMessage;

  String get displayName => nameTranslated ?? name;
  String get displayOverview => overviewTranslated ?? overview;
  String get displayWhenToSeekCare =>
      whenToSeekCareTranslated ?? whenToSeekCare;

  factory Disease.fromJson(Map<String, dynamic> json) => Disease(
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        overview: json['overview'] as String? ?? '',
        precautions: (json['precautions'] as List?)?.cast<String>() ?? const [],
        commonSymptoms: (json['common_symptoms'] as List? ?? [])
            .map((e) => DiseaseSymptom.fromJson(e as Map<String, dynamic>))
            .toList(),
        whenToSeekCare: json['when_to_seek_care'] as String? ?? '',
        symptomSource: json['symptom_source'] as String? ?? '',
        disclaimer: json['disclaimer'] as String? ?? '',
        severity:
            DiseaseSeverity.fromJson(json['severity'] as Map<String, dynamic>?),
        nameTranslated: json['name_translated'] as String?,
        overviewTranslated: json['overview_translated'] as String?,
        whenToSeekCareTranslated: json['when_to_seek_care_translated'] as String?,
        precautionsMessage: json['precautions_message'] as String?,
      );
}
