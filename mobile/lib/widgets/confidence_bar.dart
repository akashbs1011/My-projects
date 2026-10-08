import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../utils/formatters.dart';

/// A score with its label and the caption that says what it measures.
///
/// The caption is part of the widget on purpose: a bare percentage can never
/// reach the screen without the wording that qualifies it.
class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({
    super.key,
    required this.value,
    required this.label,
    required this.caption,
    this.muted = false,
  });

  final double value;
  final String label;
  final String caption;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final fraction = value.clamp(0.0, 1.0);
    final fill = muted ? AppTheme.inkMuted : AppTheme.clinical;

    return Semantics(
      label: '$label ${Formatters.percent(value)}. $caption',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(Formatters.percent(value), style: AppTheme.stat),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppTheme.line,
              valueColor: AlwaysStoppedAnimation(fill),
            ),
          ),
          const SizedBox(height: 6),
          Text(caption, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
