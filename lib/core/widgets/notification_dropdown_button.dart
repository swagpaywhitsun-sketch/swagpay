import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/app_records.dart';
import '../state/providers.dart';

class NotificationDropdownButton extends ConsumerWidget {
  final bool isDark;

  const NotificationDropdownButton({
    super.key,
    required this.isDark,
  });

  String _formatCount(int count) {
    if (count > 99) return '99+';
    return count.toString();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.transaction:
        return Icons.receipt_long_rounded;
      case NotificationType.alert:
        return Icons.warning_amber_rounded;
      case NotificationType.refund:
        return Icons.replay_rounded;
      case NotificationType.system:
        return Icons.shield_rounded;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.transaction:
        return const Color(0xFF10B981);
      case NotificationType.alert:
        return const Color(0xFFF59E0B);
      case NotificationType.refund:
        return const Color(0xFF8B5CF6);
      case NotificationType.system:
        return const Color(0xFF229ED9);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final allNotifs = repo.getNotifications();
    final unreadCount = allNotifs.where((n) => !n.isRead).length;

    final cardBg = isDark ? const Color(0xFF1E2128) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3340) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return PopupMenuButton<String>(
      tooltip: 'Notifications (${unreadCount > 0 ? unreadCount : "None"})',
      offset: const Offset(0, 48),
      padding: EdgeInsets.zero,
      color: cardBg,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      onSelected: (val) {
        if (val == 'view_all') {
          context.push('/teller/notifications');
        } else if (val == 'mark_read') {
          repo.markAllNotificationsRead();
        } else if (val.startsWith('item_')) {
          final id = val.replaceFirst('item_', '');
          repo.markNotificationRead(id);
          final item = allNotifs.firstWhere(
            (n) => n.id == id,
            orElse: () => allNotifs.first,
          );
          if (item.targetRoute != null && item.targetRoute!.isNotEmpty) {
            context.push(item.targetRoute!);
          } else {
            context.push('/teller/notifications');
          }
        }
      },
      itemBuilder: (context) {
        final recentItems = allNotifs.take(4).toList();

        return <PopupMenuEntry<String>>[
          // ── Uber Eats Sleek Header ──────────────────────────
          PopupMenuItem<String>(
            enabled: false,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: SizedBox(
              width: 300,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: unreadCount > 0
                              ? const Color(0xFF229ED9).withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: unreadCount > 0
                                ? const Color(0xFF229ED9).withValues(alpha: 0.3)
                                : const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          unreadCount > 0 ? '${_formatCount(unreadCount)} new' : 'All caught up',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: unreadCount > 0 ? const Color(0xFF229ED9) : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (unreadCount > 0)
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        Navigator.pop(context);
                        repo.markAllNotificationsRead();
                        HapticFeedback.selectionClick();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF229ED9),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const PopupMenuDivider(height: 1),

          // ── Compact Item List ────────────────────────────────
          if (recentItems.isEmpty)
            PopupMenuItem<String>(
              enabled: false,
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 300,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 18, color: textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'No notifications right now',
                      style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recentItems.map((item) {
              final color = _colorForType(item.type);
              final icon = _iconForType(item.type);

              return PopupMenuItem<String>(
                value: 'item_${item.id}',
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SizedBox(
                  width: 300,
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, size: 15, color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _timeAgo(item.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              item.message,
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF229ED9),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

          const PopupMenuDivider(height: 1),

          // ── Uber Eats Style Footer ──────────────────────────
          PopupMenuItem<String>(
            value: 'view_all',
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              width: 300,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'View all notifications',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF229ED9),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: const Color(0xFF229ED9).withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2128) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _formatCount(unreadCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}
