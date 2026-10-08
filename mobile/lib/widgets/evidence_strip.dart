import 'package:flutter/material.dart';

import '../app/theme.dart';

/// One segment per selected symptom: filled when the dataset associates that
/// symptom with this condition, hollow when it does not.
///
/// A result that accounts for every symptom looks visibly different from one
/// that accounts for two out of six, which is the point — the gaps are shown
/// as plainly as the matches.
class EvidenceStrip extends StatelessWidget {
  const EvidenceStrip({
    super.key,
    required this.matchedCount,
    required this.unmatchedCount,
  });

  final int matchedCount;
  final int unmatchedCount;

  @override
  Widget build(BuildContext context) {
    final total = matchedCount + unmatchedCount;
    if (total == 0) return const SizedBox.shrink();

    return Semantics(
      label: '$matchedCount of $total selected symptoms are associated '
          'with this condition in the dataset.',
      excludeSemantics: true,
      child: Row(
        children: List.generate(total, (index) {
          final matched = index < matchedCount;
          return Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: index == total - 1 ? 0 : 3),
              decoration: BoxDecoration(
                color: matched ? AppTheme.clinical : Colors.transparent,
                border: matched ? null : Border.all(color: AppTheme.line, width: 1.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}
