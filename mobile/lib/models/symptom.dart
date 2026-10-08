/// A symptom from the vocabulary the backend derived from Training.csv.
///
/// [name] is the canonical dataset name and is what gets sent back for
/// analysis. [label] is what the person reads, and may be translated.
class Symptom {
  const Symptom({required this.name, required this.label, this.roman});

  final String name;
  final String label;

  /// Roman transliteration of a translated label, when one applies.
  final String? roman;

  factory Symptom.fromJson(Map<String, dynamic> json) => Symptom(
        name: json['name'] as String? ?? json['id'] as String? ?? '',
        label: json['label'] as String? ?? json['name'] as String? ?? '',
        roman: json['roman'] as String?,
      );

  Symptom copyWith({String? roman}) =>
      Symptom(name: name, label: label, roman: roman ?? this.roman);

  @override
  bool operator ==(Object other) => other is Symptom && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
