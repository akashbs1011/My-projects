import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../models/symptom.dart';
import '../providers/language_provider.dart';
import '../providers/prediction_provider.dart';
import '../providers/symptom_provider.dart';
import '../utils/constants.dart';
import '../utils/transliteration.dart';
import '../widgets/disclaimer_banner.dart';
import '../widgets/error_view.dart';
import '../widgets/language_selector.dart';
import '../widgets/loading_view.dart';
import '../widgets/speak_button.dart';
import '../widgets/symptom_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSymptoms());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSymptoms({bool force = false}) async {
    final language = context.read<LanguageProvider>();
    await context.read<SymptomProvider>().load(
          language.code,
          romanise: language.romanise,
          force: force,
        );
  }

  Future<void> _analyze() async {
    final symptoms = context.read<SymptomProvider>();
    final prediction = context.read<PredictionProvider>();
    final language = context.read<LanguageProvider>().code;
    final router = GoRouter.of(context);

    final ok = await prediction.analyze(
      symptoms.selected.map((s) => s.name).toList(),
      language,
    );
    if (ok && mounted) router.push(AppConstants.routeResults);
  }

  /// Turns a spoken phrase into canonical dataset symptoms through the
  /// backend's entity extractor, then reports exactly what was added.
  Future<void> _handleTranscript(String text) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final symptoms = context.read<SymptomProvider>();
    final language = context.read<LanguageProvider>().code;

    try {
      final extracted = await context
          .read<PredictionProvider>()
          .extractSymptoms(text, language);

      if (extracted.symptoms.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.t('voiceNoMatch'))),
        );
        return;
      }

      final added = symptoms.addByNames(extracted.symptoms);
      await symptoms.refreshSuggestions(language,
          romanise: context.read<LanguageProvider>().romanise);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.tf('voiceAdded', {'n': '$added'}))),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('somethingWentWrong'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final symptoms = context.watch<SymptomProvider>();
    final prediction = context.watch<PredictionProvider>();
    final language = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('appName')),
        actions: [
          LanguageSelector(onChanged: (_) => _loadSymptoms(force: true)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSymptoms(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(l10n.t('heroTitle'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l10n.t('heroSubtitle'),
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),

            DisclaimerBanner(message: l10n.t('disclaimer')),
            const SizedBox(height: 18),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.t('selectSymptoms'),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.t('searchHint'),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: symptoms.isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 19),
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _searchController.clear();
                                      symptoms.clearSearch();
                                      setState(() {});
                                    },
                                  ),
                      ),
                      onChanged: (value) {
                        symptoms.search(value, language.code);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 14),

                    SpeakButton(onTranscript: _handleTranscript),

                    if (language.supportsTransliteration) ...[
                      const SizedBox(height: 4),
                      SwitchListTile.adaptive(
                        value: language.romanise,
                        onChanged: (value) async {
                          await context
                              .read<LanguageProvider>()
                              .setRomanise(value);
                          await _loadSymptoms(force: true);
                        },
                        title: Text(l10n.t('romanise'),
                            style: Theme.of(context).textTheme.bodyMedium),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],

                    if (symptoms.selected.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${l10n.t('selected')} · ${symptoms.selectedCount}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          TextButton(
                            onPressed: symptoms.clearSelection,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                            ),
                            child: Text(l10n.t('clearAll')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final symptom in symptoms.selected)
                            SymptomChip(
                              label: symptom.label,
                              roman: _romanFor(symptom, language),
                              onRemove: () {
                                symptoms.remove(symptom);
                                symptoms.refreshSuggestions(language.code,
                                    romanise: language.romanise);
                              },
                            ),
                        ],
                      ),
                      if (symptoms.suggestions.isNotEmpty &&
                          !symptoms.atLimit) ...[
                        const SizedBox(height: 14),
                        Text(l10n.t('suggestedSymptoms').toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 2),
                        Text(l10n.t('suggestedCaption'),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final s in symptoms.suggestions.take(6))
                              ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 15),
                                label: Text(s.label,
                                    style: const TextStyle(fontSize: 13)),
                                onPressed: () {
                                  symptoms.toggle(s);
                                  symptoms.refreshSuggestions(language.code,
                                      romanise: language.romanise);
                                },
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: AppTheme.line),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],

                      if (symptoms.atLimit) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.tf('symptomLimitReached',
                              {'n': '${AppConstants.maxSelectedSymptoms}'}),
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.cautionText),
                        ),
                      ],
                    ],

                    const SizedBox(height: 16),
                    Text(
                      '${l10n.t('available')} · ${symptoms.visible.length}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 6),
                    _SymptomList(
                      symptoms: symptoms,
                      language: language,
                      onRetry: () => _loadSymptoms(force: true),
                    ),

                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: symptoms.canAnalyze && !prediction.isAnalyzing
                          ? _analyze
                          : null,
                      child: prediction.isAnalyzing
                          ? const ButtonSpinner()
                          : Text(l10n.t('analyze')),
                    ),
                    if (!symptoms.canAnalyze) ...[
                      const SizedBox(height: 8),
                      Text(
                        symptoms.selectedCount == 0
                            ? l10n.tf('symptomRange', {
                                'min': '${AppConstants.minSelectedSymptoms}',
                                'max': '${AppConstants.maxSelectedSymptoms}',
                              })
                            : l10n.tf('selectAtLeast', {
                                'n': '${AppConstants.minSelectedSymptoms}',
                                'r': '${symptoms.remainingToMinimum}',
                              }),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (prediction.error != null) ...[
                      const SizedBox(height: 14),
                      ErrorView(
                        message: prediction.error!,
                        onRetry: _analyze,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _romanFor(Symptom symptom, LanguageProvider language) {
    if (!language.romanise) return null;
    return symptom.roman ?? Transliteration.toRoman(symptom.label);
  }
}

class _SymptomList extends StatelessWidget {
  const _SymptomList({
    required this.symptoms,
    required this.language,
    required this.onRetry,
  });

  final SymptomProvider symptoms;
  final LanguageProvider language;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (symptoms.isLoading) return const LoadingView(rows: 2);

    if (symptoms.error != null) {
      return ErrorView(message: symptoms.error!, onRetry: onRetry);
    }

    if (symptoms.visible.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.line, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(l10n.t('noMatches'),
              style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: symptoms.visible.length,
        itemBuilder: (context, index) {
          final symptom = symptoms.visible[index];
          final selected = symptoms.isSelected(symptom);
          return SymptomTile(
            label: symptom.label,
            roman: language.romanise
                ? (symptom.roman ?? Transliteration.toRoman(symptom.label))
                : null,
            selected: selected,
            disabled: symptoms.atLimit,
            onTap: () {
              symptoms.toggle(symptom);
              symptoms.refreshSuggestions(language.code,
                  romanise: language.romanise);
            },
          );
        },
      ),
    );
  }
}
