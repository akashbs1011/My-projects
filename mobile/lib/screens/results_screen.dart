import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../models/prediction.dart';
import '../providers/prediction_provider.dart';
import '../widgets/disclaimer_banner.dart';
import '../widgets/error_view.dart';
import '../widgets/listen_button.dart';
import '../widgets/result_card.dart';
import '../utils/constants.dart';

/// Ranked candidate conditions.
///
/// The urgency notice is placed above the results deliberately: if a red-flag
/// symptom was selected, that is the first thing on screen, before any ranking.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prediction = context.watch<PredictionProvider>();
    final result = prediction.result;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('results'))),
      body: result == null
          ? EmptyView(
              icon: Icons.query_stats_outlined,
              title: l10n.t('noResults'),
              actionLabel: l10n.t('back'),
              onAction: () => Navigator.of(context).maybePop(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              children: [
                if (result.urgency.urgent &&
                    result.urgency.displayNotice != null) ...[
                  DisclaimerBanner(
                    message: result.urgency.displayNotice!,
                    urgent: true,
                  ),
                  const SizedBox(height: 14),
                ],

                // Thin input is the most common reason scores look low, so it
                // is explained here rather than leaving the person to conclude
                // the app is simply unsure of everything.
                if (result.recognisedSymptoms.length < 3) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cautionBg,
                      border: Border.all(color: AppTheme.cautionBorder),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.tips_and_updates_outlined,
                                size: 19, color: AppTheme.cautionText),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.t('thinInputTitle'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.cautionText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.tf('thinInputBody', {
                            'n': '${result.recognisedSymptoms.length}',
                          }),
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: AppTheme.cautionText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: Text(l10n.t('addMoreSymptoms')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cautionText,
                            side: const BorderSide(color: AppTheme.cautionBorder),
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (result.unrecognisedSymptoms.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.cautionBg,
                      border: Border.all(color: AppTheme.cautionBorder),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${l10n.t('excludedSymptoms')}: '
                      '${result.unrecognisedSymptoms.join(', ')}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.cautionText, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (result.message != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Text(result.message!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (result.isEmpty && result.message == null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Text(l10n.t('noResults'),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ),

                if (result.results.isNotEmpty) ...[
                  ListenButton(
                    textBuilder: () => _spokenSummary(context, result),
                  ),
                  const SizedBox(height: 14),
                ],

                // Sort control, shown only when there is more than one
                // candidate to reorder.
                if (result.results.length > 1) ...[
                  _SortToggle(
                    value: prediction.sort,
                    onChanged: (v) =>
                        context.read<PredictionProvider>().setSort(v),
                  ),
                  const SizedBox(height: 12),
                ],

                for (var i = 0;
                    i < prediction.orderedResults.length &&
                        i < AppConstants.maxResultsShown;
                    i++) ...[
                  ResultCard(result: prediction.orderedResults[i], rank: i + 1),
                  const SizedBox(height: 12),
                ],

                if (result.translationNote != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.translationNote!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                ],

                if (result.results.isNotEmpty &&
                    result.results.first.modelConfidence < 0.5) ...[
                  Text(
                    l10n.t('lowConfidenceNote'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ],

                DisclaimerBanner(
                  message: result.disclaimer.isEmpty
                      ? l10n.t('disclaimerShort')
                      : result.disclaimer,
                ),
              ],
            ),
    );
  }
}

/// Assembles the spoken version of the results.
///
/// It reads the same numbers shown on screen, in the same order, and ends with
/// the disclaimer — someone listening rather than reading must not receive a
/// more confident account than someone looking at it.
String _spokenSummary(BuildContext context, AnalysisResult result) {
  final l10n = AppLocalizations.of(context);
  final shown = context
      .read<PredictionProvider>()
      .orderedResults
      .take(AppConstants.maxResultsShown)
      .toList();
  final parts = <String>[];

  if (result.urgency.urgent && result.urgency.displayNotice != null) {
    // Urgency is spoken first, exactly as it is shown first.
    parts.add(result.urgency.displayNotice!);
  }

  parts.add(l10n.tf('spokenIntro', {'n': '${shown.length}'}));

  for (var i = 0; i < shown.length; i++) {
    final r = shown[i];
    parts.add(l10n.tf('spokenResult', {
      'n': '${i + 1}',
      'disease': r.displayName,
      'matched': '${r.matchedSymptoms.length}',
      'total': '${r.totalSelected}',
      'match': '${(r.symptomMatch * 100).round()}',
      'confidence': '${(r.modelConfidence * 100).round()}',
    }));
  }

  parts.add(l10n.t('spokenDisclaimer'));
  return parts.join(' ');
}


/// Switches the candidate ordering between the two scores.
///
/// The control exists because the orderings can disagree. Where they do, the
/// person can see that the highest-probability candidate is not necessarily
/// the one that accounts for most of what they reported.
class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.value, required this.onChanged});

  final ResultSort value;
  final ValueChanged<ResultSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('sortBy').toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        SegmentedButton<ResultSort>(
          segments: [
            ButtonSegment(
              value: ResultSort.confidence,
              label: Text(l10n.t('modelConfidence'),
                  style: const TextStyle(fontSize: 12.5)),
            ),
            ButtonSegment(
              value: ResultSort.symptomMatch,
              label: Text(l10n.t('symptomMatch'),
                  style: const TextStyle(fontSize: 12.5)),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12.5)),
          ),
        ),
      ],
    );
  }
}
