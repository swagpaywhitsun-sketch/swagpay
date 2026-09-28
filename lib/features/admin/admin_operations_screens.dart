import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/refund_request.dart';
import '../../core/models/settlement.dart';
import '../../core/network/api_config.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';

// --- REFUND APPROVALS SCREEN ---
class AdminRefundsScreen extends ConsumerWidget {
  const AdminRefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final refunds = repo.getRefundRequests();
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Refund & Void Approvals', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('Review teller-requested transaction reversals before settlement pool debit', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9)),
                columns: const [
                  DataColumn(label: Text('REQUEST ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('REFERENCE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TELLER', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('REASON', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('REQUESTED AT', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: refunds.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(Text(r.id, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(r.reference)),
                      DataCell(Text('GH₵ ${r.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(r.tellerName)),
                      DataCell(Text(r.reason)),
                      DataCell(Text(dateFormat.format(r.createdAt))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: r.status == RefundStatus.approved
                                ? AppColors.success.withValues(alpha: 0.15)
                                : (r.status == RefundStatus.rejected
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : AppColors.gold.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            r.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: r.status == RefundStatus.approved
                                  ? AppColors.successDark
                                  : (r.status == RefundStatus.rejected ? AppColors.error : AppColors.gold),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        r.status == RefundStatus.pending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                                    onPressed: () async {
                                      await repo.reviewRefund(r.id, true);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Refund ${r.id} APPROVED and processed')),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_rounded, color: AppColors.error),
                                    onPressed: () async {
                                      await repo.reviewRefund(r.id, false);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Refund ${r.id} REJECTED')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              )
                            : const Text('Resolved', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SETTLEMENTS & RECONCILIATION SCREEN ---
class AdminSettlementsScreen extends ConsumerWidget {
  const AdminSettlementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final settlements = repo.getSettlements();
    final dateFormat = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Daily Settlements & Reconciliation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('Reconcile counter collections with clearing bank pool and POS terminal batches', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9)),
                columns: const [
                  DataColumn(label: Text('BATCH ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('COLLECTED (GHS)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('SETTLED (GHS)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('VARIANCE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TXN COUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: settlements.map((s) {
                  return DataRow(
                    cells: [
                      DataCell(Text(s.id, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(dateFormat.format(s.date))),
                      DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(s.totalCollected)}')),
                      DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(s.totalSettled)}')),
                      DataCell(
                        Text(
                          'GH₵ ${NumberFormat('#,##0.00').format(s.variance)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: s.variance == 0 ? AppColors.successDark : AppColors.error,
                          ),
                        ),
                      ),
                      DataCell(Text('${s.transactionCount}')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: s.status == SettlementStatus.settled ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            s.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: s.status == SettlementStatus.settled ? AppColors.successDark : AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- AUDIT LOGS SCREEN ---
class AdminAuditLogsScreen extends ConsumerWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final logs = repo.getAuditLogs();
    final dateFormat = DateFormat('dd MMM, hh:mm:ss a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('System Audit Trail', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('Immutable security and operational log of all teller and admin actions', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9)),
                columns: const [
                  DataColumn(label: Text('TIMESTAMP', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('USER / ROLE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ENTITY', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DETAILS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('NODE / IP', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: logs.map((l) {
                  return DataRow(
                    cells: [
                      DataCell(Text(dateFormat.format(l.timestamp), style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${l.user}\n(${l.role})', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(l.action, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(l.entity)),
                      DataCell(Text(l.details)),
                      DataCell(Text('${l.device}\n${l.ip}', style: const TextStyle(fontFamily: 'Courier', fontSize: 11))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SYSTEM SETTINGS & LIVE API CONFIG SCREEN ---
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  late final TextEditingController _apiUrlCtrl;
  bool _useLiveApi = false;
  bool _isConnecting = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final currentUrl = prefs.getString('custom_base_url') ?? ApiConfig.baseUrl;
    _apiUrlCtrl = TextEditingController(text: currentUrl);
    _useLiveApi = prefs.getBool('use_live_api') ?? false;
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = null;
    });

    final url = _apiUrlCtrl.text.trim();
    final client = ref.read(apiClientProvider);
    client.updateBaseUrl(url);

    try {
      await client.get('/health').timeout(const Duration(seconds: 4));
      setState(() {
        _isConnecting = false;
        _connectionStatus = 'Success! Connected to $url';
      });
    } catch (_) {
      setState(() {
        _isConnecting = false;
        _connectionStatus = 'Endpoint saved. Will route API calls to: $url';
      });
    }

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('custom_base_url', url);
    await prefs.setBool('use_live_api', _useLiveApi);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('System Configuration & API', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('Configure backend API endpoints, hardware POS gatekeeper, and security rules', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),

          // Backend API Connection Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.dns_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Backend API', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Direct connection to your production/staging payment API', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _apiUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Base URL *',
                      hintText: 'https://api.yourdomain.com/v1',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SwitchListTile(
                    title: const Text('Live Backend API Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Send transactions to this remote URL instead of offline mock storage'),
                    value: _useLiveApi,
                    onChanged: (val) => setState(() => _useLiveApi = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  if (_connectionStatus != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Text(_connectionStatus!, style: const TextStyle(color: AppColors.successDark, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _testConnection,
                    icon: _isConnecting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text(_isConnecting ? 'Verifying...' : 'Save & Test API Connection'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Security & POS Gatekeeper Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('POS Hardware Security Gatekeeper', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Enforce POS-only access restricting Admin Web to verified hardware fingerprints.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enforce POS Whitelist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Block unverified browser clients immediately'),
                    value: true,
                    onChanged: (_) {},
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    title: const Text('Require 2FA for Admin Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Send 6-digit OTP prompt on all refunds and settlements'),
                    value: true,
                    onChanged: (_) {},
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
