import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final TransactionStatus status;
  final bool isLarge;

  const StatusBadge({super.key, required this.status, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case TransactionStatus.success:
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.successDark;
        icon = Icons.check_circle_rounded;
        label = 'SUCCESS';
        break;
      case TransactionStatus.pending:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = const Color(0xFFB7791F);
        icon = Icons.hourglass_top_rounded;
        label = 'PENDING';
        break;
      case TransactionStatus.failed:
        bg = AppColors.error.withValues(alpha: 0.15);
        fg = AppColors.error;
        icon = Icons.cancel_rounded;
        label = 'FAILED';
        break;
      case TransactionStatus.refunded:
        bg = AppColors.primaryLight.withValues(alpha: 0.15);
        fg = AppColors.primaryLight;
        icon = Icons.replay_rounded;
        label = 'REFUNDED';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 14 : 10,
        vertical: isLarge ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isLarge ? 16 : 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 13 : 11,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
