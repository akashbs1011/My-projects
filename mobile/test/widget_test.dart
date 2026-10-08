import 'package:clinical_ai/app/theme.dart';
import 'package:clinical_ai/localization/app_localizations.dart';
import 'package:clinical_ai/models/prediction.dart';
import 'package:clinical_ai/widgets/confidence_bar.dart';
import 'package:clinical_ai/widgets/disclaimer_banner.dart';
import 'package:clinical_ai/widgets/evidence_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a widget with the localisation delegates it needs.
Widget harness(Widget child, {String language = 'en'}) => MaterialApp(
      theme: AppTheme.light(),
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('DisclaimerBanner renders the message', (tester) async {
    await tester.pumpWidget(harness(
      const DisclaimerBanner(message: 'This tool does not provide a diagnosis.'),
    ));
    expect(find.text('This tool does not provide a diagnosis.'), findsOneWidget);
  });

  testWidgets('urgent banner uses the alert treatment', (tester) async {
    await tester.pumpWidget(harness(
      const DisclaimerBanner(message: 'Seek care promptly.', urgent: true),
    ));
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('ConfidenceBar always shows its caption alongside the number',
      (tester) async {
    await tester.pumpWidget(harness(
      const ConfidenceBar(
        value: 0.82,
        label: 'Model confidence',
        caption: 'Not a medically validated probability.',
      ),
    ));
    // A bare percentage must never appear without the wording that qualifies it.
    expect(find.text('82%'), findsOneWidget);
    expect(find.text('Not a medically validated probability.'), findsOneWidget);
  });

  testWidgets('EvidenceStrip draws one segment per selected symptom',
      (tester) async {
    await tester.pumpWidget(harness(
      const EvidenceStrip(matchedCount: 3, unmatchedCount: 2),
    ));
    expect(find.byType(Expanded), findsNWidgets(5));
  });

  testWidgets('EvidenceStrip renders nothing when no symptoms were selected',
      (tester) async {
    await tester.pumpWidget(harness(
      const EvidenceStrip(matchedCount: 0, unmatchedCount: 0),
    ));
    expect(find.byType(Expanded), findsNothing);
  });

  testWidgets('a result parsed from the API keeps its scores distinct',
      (tester) async {
    final result = PredictionResult.fromJson(const {
      'disease': 'Influenza',
      'slug': 'influenza',
      'model_confidence': 0.9,
      'symptom_match': 0.4,
      'matched_symptoms': ['fever'],
      'unmatched_symptoms': ['itching', 'rash'],
      'explanation': 'Explanation text.',
      'rank': 1,
    });

    await tester.pumpWidget(harness(
      EvidenceStrip(
        matchedCount: result.matchedSymptoms.length,
        unmatchedCount: result.unmatchedSymptoms.length,
      ),
    ));

    // High confidence with weak overlap is exactly the case the two-score
    // display exists to make visible.
    expect(result.modelConfidence, 0.9);
    expect(result.symptomMatch, 0.4);
    expect(find.byType(Expanded), findsNWidgets(3));
  });
}
