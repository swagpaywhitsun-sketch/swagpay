import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyPress;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  const NumericKeypad({
    super.key,
    required this.onKeyPress,
    required this.onDelete,
    required this.onClear,
  });

  Widget _buildKey(BuildContext context, String label, {Widget? customChild, VoidCallback? customTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 2.5),
        child: Material(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          elevation: 0,
          child: InkWell(
            onTap: customTap ?? () => onKeyPress(label),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: customChild ??
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1
        Row(
          children: [
            _buildKey(context, '1'),
            _buildKey(context, '2'),
            _buildKey(context, '3'),
          ],
        ),
        // Row 2
        Row(
          children: [
            _buildKey(context, '4'),
            _buildKey(context, '5'),
            _buildKey(context, '6'),
          ],
        ),
        // Row 3
        Row(
          children: [
            _buildKey(context, '7'),
            _buildKey(context, '8'),
            _buildKey(context, '9'),
          ],
        ),
        // Row 4
        Row(
          children: [
            _buildKey(
              context,
              'C',
              customTap: onClear,
              customChild: const Text(
                'CLR',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.error),
              ),
            ),
            _buildKey(context, '0'),
            _buildKey(
              context,
              'DEL',
              customTap: onDelete,
              customChild: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
