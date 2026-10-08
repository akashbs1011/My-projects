import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The medical disclaimer, and the urgency notice when a red-flag symptom is
/// selected. Both are rendered by the same widget so their styling can never
/// drift apart.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({
    super.key,
    required this.message,
    this.urgent = false,
  });

  final String message;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final bg = urgent ? AppTheme.alertBg : AppTheme.clinicalLight;
    final border = urgent ? AppTheme.alertBorder : AppTheme.clinicalBorder;
    final fg = urgent ? AppTheme.alertText : AppTheme.clinicalDark;

    return Semantics(
      liveRegion: urgent,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              urgent ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
              size: 19,
              color: fg,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: urgent ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
