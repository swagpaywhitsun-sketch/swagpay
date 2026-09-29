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
    String label;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Polaris badges: soft tint fill, dark text, no heavy border
    switch (status) {
      case TransactionStatus.success:
        bg = isDark ? const Color(0xFF0D3320) : AppColors.badgeSuccessBg;
        fg = isDark ? const Color(0xFF6FD5A4) : AppColors.badgeSuccessFg;
        label = 'Success';
        break;
      case TransactionStatus.pending:
        bg = isDark ? const Color(0xFF3B2500) : AppColors.badgePendingBg;
        fg = isDark ? const Color(0xFFFBBF24) : AppColors.badgePendingFg;
        label = 'Pending';
        break;
      case TransactionStatus.failed:
        bg = isDark ? const Color(0xFF381010) : AppColors.badgeFailedBg;
        fg = isDark ? const Color(0xFFFCA5A5) : AppColors.badgeFailedFg;
        label = 'Failed';
        break;
      case TransactionStatus.refunded:
        bg = isDark ? const Color(0xFF102A45) : AppColors.badgeRefundedBg;
        fg = isDark ? const Color(0xFF93C5FD) : AppColors.badgeRefundedFg;
        label = 'Refunded';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : 9,
        vertical: isLarge ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isLarge ? 7 : 6,
            height: isLarge ? 7 : 6,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 12 : 11,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
