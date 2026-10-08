import 'package:flutter/material.dart';
import '../models/transaction.dart';
import 'lively_widgets.dart';

class StatusBadge extends StatelessWidget {
  final TransactionStatus status;
  final bool isLarge;

  const StatusBadge({super.key, required this.status, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData? icon;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case TransactionStatus.success:
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
        fg = isDark ? const Color(0xFF34D399) : const Color(0xFF15803D);
        label = 'Success';
        icon = Icons.check_circle_rounded;
        break;
      case TransactionStatus.pending:
        bg = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        label = 'Pending';
        icon = null; // will use PulsingBeacon
        break;
      case TransactionStatus.failed:
        bg = isDark ? const Color(0xFF4C0519) : const Color(0xFFFEE2E2);
        fg = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        label = 'Failed';
        icon = Icons.cancel_rounded;
        break;
      case TransactionStatus.refunded:
        bg = isDark ? const Color(0xFF082F49) : const Color(0xFFE0F2FE);
        fg = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
        label = 'Refunded';
        icon = Icons.replay_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : 9,
        vertical: isLarge ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: fg.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == TransactionStatus.pending)
            PulsingBeacon(
              color: fg,
              size: isLarge ? 7 : 5.5,
              showRipple: true,
            )
          else if (icon != null)
            Icon(icon, size: isLarge ? 13 : 11, color: fg)
          else
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
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
