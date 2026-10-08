import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Placeholder cards shown while content loads, so the layout does not jump
/// when the real data arrives.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.rows = 3, this.label});

  final int rows;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: Column(
        children: List.generate(
          rows,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i == rows - 1 ? 0 : 12),
            child: Container(
              height: 96,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.line),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: 140, color: AppTheme.line),
                  const SizedBox(height: 12),
                  _bar(width: 220, color: AppTheme.mist),
                  const SizedBox(height: 8),
                  _bar(width: 170, color: AppTheme.mist),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar({required double width, required Color color}) => Container(
        width: width,
        height: 11,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

/// Small inline spinner sized to sit inside a button.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 17,
        height: 17,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
      );
}
