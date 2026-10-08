import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../models/history_entry.dart';
import '../models/prediction.dart';
import '../providers/history_provider.dart';
import '../providers/language_provider.dart';
import '../providers/prediction_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/result_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<HistoryProvider>().load());
  }

  Future<void> _confirmDelete(HistoryEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(l10n.t('confirmDelete'), l10n.t('delete'));
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<HistoryProvider>().remove(entry.id);
    if (ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.t('deleted'))));
    }
  }

  Future<void> _confirmClear() async {
    final l10n = AppLocalizations.of(context);
    final confirmed =
        await _confirm(l10n.t('confirmClear'), l10n.t('clearHistory'));
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<HistoryProvider>().clear();
    if (ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.t('historyCleared'))));
    }
  }

  Future<bool> _confirm(String message, String confirmLabel) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.t('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.alertText),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Reopens a saved analysis in the same results view the live one uses.
  void _openSaved(HistoryEntry entry) {
    context.read<PredictionProvider>().showSaved(
          AnalysisResult(
            results: entry.predictions,
            recognisedSymptoms: entry.symptoms,
            unrecognisedSymptoms: const [],
            urgency: const UrgencyNotice(urgent: false, triggeredSymptoms: []),
            disclaimer: AppLocalizations.of(context).t('disclaimerShort'),
            language: entry.selectedLanguage,
          ),
        );
    context.push(AppConstants.routeResults);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final history = context.watch<HistoryProvider>();
    final localeCode = context.watch<LanguageProvider>().code;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('historyTitle')),
        actions: [
          if (history.items.isNotEmpty)
            TextButton(
              onPressed: _confirmClear,
              child: Text(l10n.t('clearHistory')),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<HistoryProvider>().load(),
        child: Builder(
          builder: (context) {
            if (history.isLoading && history.items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingView(rows: 3),
              );
            }

            if (history.error != null && history.items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ErrorView(
                    message: history.error!,
                    onRetry: () => context.read<HistoryProvider>().load(),
                  ),
                ],
              );
            }

            if (history.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyView(
                    icon: Icons.history_toggle_off_outlined,
                    title: l10n.t('historyEmpty'),
                    actionLabel: l10n.t('startAnalysis'),
                    onAction: () => context.go(AppConstants.routeHome),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              itemCount: history.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = history.items[index];
                final expanded = _expandedId == entry.id;

                return Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(
                                    () => _expandedId = expanded ? null : entry.id),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      Formatters.dateTime(
                                          entry.createdAt, localeCode),
                                      style: AppTheme.stat.copyWith(
                                          fontSize: 11.5,
                                          color: AppTheme.inkMuted),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      entry.topPrediction?.disease ?? '—',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 14,
                                      children: [
                                        Text(
                                          '${l10n.t('symptomMatch')} '
                                          '${Formatters.percent(entry.topPrediction?.symptomMatch)}',
                                          style: AppTheme.stat.copyWith(
                                              fontSize: 11.5,
                                              color: AppTheme.inkMuted),
                                        ),
                                        Text(
                                          '${l10n.t('modelConfidence')} '
                                          '${Formatters.percent(entry.topPrediction?.modelConfidence)}',
                                          style: AppTheme.stat.copyWith(
                                              fontSize: 11.5,
                                              color: AppTheme.inkMuted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      entry.symptoms.join(' · '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 20),
                                  tooltip: l10n.t('delete'),
                                  color: AppTheme.inkMuted,
                                  onPressed: () => _confirmDelete(entry),
                                ),
                                IconButton(
                                  icon: Icon(
                                    expanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 22,
                                  ),
                                  color: AppTheme.inkMuted,
                                  onPressed: () => setState(() =>
                                      _expandedId = expanded ? null : entry.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (expanded)
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: AppTheme.mist,
                            border: Border(
                                top: BorderSide(color: AppTheme.line)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              for (var i = 0;
                                  i < entry.predictions.length && i < 3;
                                  i++) ...[
                                ResultCard(
                                    result: entry.predictions[i], rank: i + 1),
                                const SizedBox(height: 10),
                              ],
                              OutlinedButton(
                                onPressed: () => _openSaved(entry),
                                child: Text(l10n.t('viewDetails')),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
