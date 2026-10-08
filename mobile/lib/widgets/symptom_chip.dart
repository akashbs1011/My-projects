import 'package:flutter/material.dart';

import '../app/theme.dart';

/// A selected symptom, with the control to remove it.
class SymptomChip extends StatelessWidget {
  const SymptomChip({
    super.key,
    required this.label,
    required this.onRemove,
    this.roman,
  });

  final String label;
  final String? roman;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          if (roman != null && roman!.isNotEmpty)
            Text(
              roman!,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.inkMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      deleteIconColor: AppTheme.clinicalDark,
      deleteButtonTooltipMessage: 'Remove $label',
      backgroundColor: AppTheme.clinicalLight,
      side: const BorderSide(color: AppTheme.clinicalBorder),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// A row in the available-symptoms list.
class SymptomTile extends StatelessWidget {
  const SymptomTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.roman,
    this.disabled = false,
  });

  final String label;
  final String? roman;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: disabled && !selected ? null : onTap,
        borderRadius: BorderRadius.circular(9),
        child: Opacity(
          opacity: disabled && !selected ? 0.4 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.clinical : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppTheme.clinical : AppTheme.line,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: selected ? AppTheme.clinicalDark : AppTheme.ink,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (roman != null && roman!.isNotEmpty)
                        Text(
                          roman!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.inkMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
