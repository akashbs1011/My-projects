import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../models/api_exception.dart';
import '../models/disease.dart';
import '../providers/language_provider.dart';
import '../providers/prediction_provider.dart';
import '../utils/formatters.dart';
import '../widgets/disclaimer_banner.dart';
import '../widgets/error_view.dart';
import '../widgets/listen_button.dart';
import '../widgets/loading_view.dart';

/// Disease information.
///
/// Every section renders the knowledge-base message when the backend has no
/// entry. Nothing on this screen is written by the app itself.
class DiseaseDetailScreen extends StatefulWidget {
  const DiseaseDetailScreen({
    super.key,
    required this.slug,
    this.matchedSymptoms = const [],
  });

  final String slug;

  /// Symptoms the person selected, so they can be highlighted in the list of
  /// symptoms recorded for this condition.
  final List<String> matchedSymptoms;

  @override
  State<DiseaseDetailScreen> createState() => _DiseaseDetailScreenState();
}

class _DiseaseDetailScreenState extends State<DiseaseDetailScreen> {
  Disease? _disease;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final language = context.read<LanguageProvider>().code;
      final disease = await context
          .read<PredictionProvider>()
          .loadDisease(widget.slug, language);
      if (mounted) setState(() => _disease = disease);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this condition.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matched = widget.matchedSymptoms.toSet();

    return Scaffold(
      appBar: AppBar(title: Text(_disease?.displayName ?? l10n.t('loading'))),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingView(rows: 4),
            );
          }
          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorView(message: _error!, onRetry: _load),
            );
          }

          final disease = _disease!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(disease.displayName,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      if (disease.severity != null)
                        _SeverityBadge(severity: disease.severity!),
                      const SizedBox(height: 8),
                      Text(disease.symptomSource,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              ListenButton(
                textBuilder: () => _spokenDisease(context, disease),
              ),
              const SizedBox(height: 12),

              _Section(
                icon: Icons.article_outlined,
                title: l10n.t('overview'),
                child: _TextOrMissing(
                  text: disease.displayOverview,
                  missing: l10n.t('notInKnowledgeBase'),
                ),
              ),

              _Section(
                icon: Icons.coronavirus_outlined,
                title: l10n.t('commonSymptoms'),
                child: disease.commonSymptoms.isEmpty
                    ? _MissingText(l10n.t('notInKnowledgeBase'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final symptom in disease.commonSymptoms)
                                _SupportChip(
                                  symptom: symptom,
                                  highlighted: matched.contains(symptom.name),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(l10n.t('supportCaption'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
              ),

              _Section(
                icon: Icons.health_and_safety_outlined,
                title: l10n.t('precautions'),
                child: disease.precautions.isEmpty
                    ? _MissingText(disease.precautionsMessage ??
                        l10n.t('notInKnowledgeBase'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in disease.precautions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(top: 7, right: 10),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.clinical,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      Formatters.symptomLabel(item),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),

              _Section(
                icon: Icons.emergency_outlined,
                title: l10n.t('whenToSeekCare'),
                child: Text(disease.displayWhenToSeekCare,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),


              const SizedBox(height: 4),
              DisclaimerBanner(
                message: disease.disclaimer.isEmpty
                    ? l10n.t('disclaimerShort')
                    : disease.disclaimer,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppTheme.clinical),
                  const SizedBox(width: 9),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _TextOrMissing extends StatelessWidget {
  const _TextOrMissing({required this.text, required this.missing});

  final String text;
  final String missing;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty || text == missing) return _MissingText(missing);
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _MissingText extends StatelessWidget {
  const _MissingText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontStyle: FontStyle.italic, color: AppTheme.inkMuted),
      );
}

class _SupportChip extends StatelessWidget {
  const _SupportChip({required this.symptom, required this.highlighted});

  final DiseaseSymptom symptom;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? AppTheme.clinicalLight : AppTheme.mist,
        borderRadius: BorderRadius.circular(7),
        border: highlighted
            ? Border.all(color: AppTheme.clinicalBorder)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (highlighted) ...[
            const Icon(Icons.check_rounded, size: 13, color: AppTheme.clinicalDark),
            const SizedBox(width: 4),
          ],
          Text(
            Formatters.symptomLabel(symptom.name),
            style: TextStyle(
              fontSize: 13,
              color: highlighted ? AppTheme.clinicalDark : AppTheme.inkSoft,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            Formatters.percent(symptom.support),
            style: AppTheme.stat.copyWith(fontSize: 11, color: AppTheme.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final DiseaseSeverity severity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final weight = severity.meanWeight;

    final (bg, border, fg) = weight >= 5
        ? (AppTheme.alertBg, AppTheme.alertBorder, AppTheme.alertText)
        : weight >= 3
            ? (AppTheme.cautionBg, AppTheme.cautionBorder, AppTheme.cautionText)
            : (AppTheme.clinicalLight, AppTheme.clinicalBorder, AppTheme.clinicalDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${l10n.t('severity')} ${weight.toStringAsFixed(1)} / 7',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Assembles the spoken version of a disease page.
///
/// It reads the same sections in the same order as the screen and ends with
/// the disclaimer, so a listener receives no more certainty than a reader.
/// Sections absent from the dataset are skipped rather than narrated as empty.
String _spokenDisease(BuildContext context, Disease disease) {
  final l10n = AppLocalizations.of(context);
  final parts = <String>[disease.displayName];

  final severity = disease.severity;
  if (severity != null) {
    parts.add('${l10n.t('severity')} '
        '${severity.meanWeight.toStringAsFixed(1)} / 7.');
  }

  final overview = disease.displayOverview;
  if (overview.isNotEmpty && overview != l10n.t('notInKnowledgeBase')) {
    parts.add('${l10n.t('overview')}. $overview');
  }

  if (disease.commonSymptoms.isNotEmpty) {
    final names = disease.commonSymptoms
        .map((s) => Formatters.symptomLabel(s.name))
        .join(', ');
    parts.add('${l10n.t('commonSymptoms')}. $names.');
  }

  if (disease.precautions.isNotEmpty) {
    final items = disease.precautions
        .map(Formatters.symptomLabel)
        .join('. ');
    parts.add('${l10n.t('precautions')}. $items.');
  }

  if (disease.displayWhenToSeekCare.isNotEmpty) {
    parts.add('${l10n.t('whenToSeekCare')}. ${disease.displayWhenToSeekCare}');
  }

  parts.add(l10n.t('spokenDisclaimer'));
  return parts.join(' ');
}
