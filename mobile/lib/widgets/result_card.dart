import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../models/prediction.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'confidence_bar.dart';
import 'evidence_strip.dart';

/// One candidate condition.
///
/// The two scores are laid out side by side and never combined, because a high
/// classifier probability with poor symptom overlap means something different
/// from the reverse, and collapsing them would hide that.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.result, required this.rank});

  final PredictionResult result;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tf('resultNumber', {'n': '$rank'}).toUpperCase(),
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(result.displayName, style: theme.textTheme.titleLarge),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => context.push(
                    '${AppConstants.routeDisease}/${result.slug}',
                    extra: result.matchedSymptoms,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(l10n.t('viewDetails')),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Text(l10n.t('possibleMatch'), style: theme.textTheme.bodyMedium),

            const SizedBox(height: 16),
            EvidenceStrip(
              matchedCount: result.matchedSymptoms.length,
              unmatchedCount: result.unmatchedSymptoms.length,
            ),

            const SizedBox(height: 16),
            // Stacked on narrow screens so neither caption gets truncated.
            LayoutBuilder(
              builder: (context, constraints) {
                final matchBar = ConfidenceBar(
                  value: result.symptomMatch,
                  label: l10n.t('symptomMatch'),
                  caption: l10n.t('symptomMatchCaption'),
                );
                final confidenceBar = ConfidenceBar(
                  value: result.modelConfidence,
                  label: l10n.t('modelConfidence'),
                  caption: l10n.t('modelConfidenceCaption'),
                  muted: true,
                );

                if (constraints.maxWidth < 380) {
                  return Column(
                    children: [
                      matchBar,
                      const SizedBox(height: 14),
                      confidenceBar,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: matchBar),
                    const SizedBox(width: 18),
                    Expanded(child: confidenceBar),
                  ],
                );
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),

            if (result.matchedSymptoms.isNotEmpty) ...[
              _SectionLabel(l10n.t('matchedSymptoms')),
              const SizedBox(height: 8),
              _SymptomWrap(
                symptoms: result.matchedSymptoms,
                matched: true,
              ),
              const SizedBox(height: 14),
            ],

            if (result.unmatchedSymptoms.isNotEmpty) ...[
              _SectionLabel(l10n.t('unmatchedSymptoms')),
              const SizedBox(height: 8),
              _SymptomWrap(
                symptoms: result.unmatchedSymptoms,
                matched: false,
              ),
              const SizedBox(height: 14),
            ],

            _SectionLabel(l10n.t('explanation')),
            const SizedBox(height: 6),
            Text(result.displayExplanation, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      );
}

class _SymptomWrap extends StatelessWidget {
  const _SymptomWrap({required this.symptoms, required this.matched});

  final List<String> symptoms;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final symptom in symptoms)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: matched ? AppTheme.clinicalLight : AppTheme.mist,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  matched ? Icons.check_rounded : Icons.remove_rounded,
                  size: 13,
                  color: matched ? AppTheme.clinicalDark : AppTheme.inkMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  Formatters.symptomLabel(symptom),
                  style: TextStyle(
                    fontSize: 13,
                    color: matched ? AppTheme.clinicalDark : AppTheme.inkMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
