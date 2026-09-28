import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/pos_device.dart';
import '../../core/models/transaction.dart';
import '../../core/models/user.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_badge.dart';

// --- TELLERS MANAGEMENT SCREEN ---
class AdminTellersScreen extends ConsumerWidget {
  const AdminTellersScreen({super.key});

  void _showAddTellerDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '500000');
    final branchCtrl = TextEditingController(text: 'Victoria Island Branch');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Teller / Cashier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address *')),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
              const SizedBox(height: 12),
              TextField(controller: branchCtrl, decoration: const InputDecoration(labelText: 'Branch')),
              const SizedBox(height: 12),
              TextField(controller: limitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Single Txn Limit (₦)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
              final newTeller = AppUser(
                id: 'TEL-00${DateTime.now().millisecond}',
                fullName: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                role: UserRole.teller,
                branch: branchCtrl.text.trim(),
                assignedPos: ['POS-IKOYI-01'],
                singleTxnLimit: double.tryParse(limitCtrl.text) ?? 500000.0,
              );
              await ref.read(paymentRepositoryProvider).addTeller(newTeller);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Teller successfully created!'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Create Teller'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final tellers = repo.getTellers();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Teller & Staff Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Assign POS terminals, adjust limits, and manage counter staff access', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddTellerDialog(context, ref),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Add Teller'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9)),
                columns: const [
                  DataColumn(label: Text('TELLER ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('BRANCH', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ASSIGNED POS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('LIMIT', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: tellers.map((t) {
                  return DataRow(
                    cells: [
                      DataCell(Text(t.id, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text('${t.fullName}\n${t.email}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(t.branch ?? 'Main')),
                      DataCell(Text(t.assignedPos.join(', '))),
                      DataCell(Text('GH₵ ${NumberFormat('#,##0').format(t.singleTxnLimit)}')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.isActive ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t.isActive ? 'ACTIVE' : 'SUSPENDED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: t.isActive ? AppColors.successDark : AppColors.error,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Editing limits for ${t.fullName}')),
                            );
                          },
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

// --- POS TERMINALS MANAGEMENT SCREEN ---
class AdminPosScreen extends ConsumerWidget {
  const AdminPosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(paymentRepositoryProvider);
    final posDevices = repo.getPosDevices();
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('POS Hardware & Terminals', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Hardware whitelisting, serial verification, and remote lock', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scanning local network for new PAX/Newland terminals...')),
                  );
                },
                icon: const Icon(Icons.radar_rounded, size: 18),
                label: const Text('Scan & Register POS'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9)),
                columns: const [
                  DataColumn(label: Text('TERMINAL ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DEVICE / SERIAL', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('BRANCH / LOCATION', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('IP ADDRESS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('LAST SEEN', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('WHITELIST', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: posDevices.map((p) {
                  return DataRow(
                    cells: [
                      DataCell(Text(p.id, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text('${p.name}\n${p.serialNumber}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${p.branch}\n${p.location}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(p.ipAddress ?? '192.168.1.100', style: const TextStyle(fontFamily: 'Courier'))),
                      DataCell(Text(dateFormat.format(p.lastSeen))),
                      DataCell(
                        Switch(
                          value: p.isWhitelisted,
                          onChanged: (val) {
                            repo.updatePosDevice(p.copyWith(isWhitelisted: val));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${p.id} whitelist status updated to $val')),
                            );
                          },
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.status == PosStatus.online ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            p.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: p.status == PosStatus.online ? AppColors.successDark : AppColors.error,
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

// --- TRANSACTIONS MANAGEMENT SCREEN ---
class AdminTransactionsScreen extends ConsumerStatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  ConsumerState<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends ConsumerState<AdminTransactionsScreen> {
  final _searchCtrl = TextEditingController();
  TransactionStatus? _filterStatus;
  MoMoNetwork? _filterNetwork;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(paymentRepositoryProvider);
    final txns = repo.getTransactions(
      searchQuery: _searchCtrl.text.trim(),
      statusFilter: _filterStatus,
      networkFilter: _filterNetwork,
    );
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All Transactions & Collections', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Real-time ledger connected to WhitsunPay MoMo gateway & Supabase', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transactions exported to CSV successfully!')),
                  );
                },
                icon: const Icon(Icons.table_view_rounded, size: 18),
                label: const Text('Export CSV'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search by Ref, customer phone, teller...',
                        prefixIcon: Icon(Icons.search_rounded),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<TransactionStatus?>(
                    value: _filterStatus,
                    hint: const Text('All Statuses'),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Statuses')),
                      DropdownMenuItem(value: TransactionStatus.success, child: Text('Success')),
                      DropdownMenuItem(value: TransactionStatus.pending, child: Text('Pending')),
                      DropdownMenuItem(value: TransactionStatus.failed, child: Text('Failed')),
                      DropdownMenuItem(value: TransactionStatus.refunded, child: Text('Refunded')),
                    ],
                    onChanged: (val) => setState(() => _filterStatus = val),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<MoMoNetwork?>(
                    value: _filterNetwork,
                    hint: const Text('All Networks'),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Networks')),
                      DropdownMenuItem(value: MoMoNetwork.mtn, child: Text('MTN MoMo')),
                      DropdownMenuItem(value: MoMoNetwork.vodafone, child: Text('Telecel Cash')),
                      DropdownMenuItem(value: MoMoNetwork.airtel, child: Text('AT Money')),
                    ],
                    onChanged: (val) => setState(() => _filterNetwork = val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Data Table
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9)),
                columns: const [
                  DataColumn(label: Text('REFERENCE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DATE & TIME', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('CUSTOMER', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('NETWORK', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TELLER / POS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: txns.map((t) {
                  return DataRow(
                    cells: [
                      DataCell(Text(t.reference, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(dateFormat.format(t.timestamp), style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${t.customerName}\n${t.customerNumber}', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('GH₵ ${NumberFormat('#,##0.00').format(t.amount)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text(t.networkDisplay)),
                      DataCell(Text('${t.tellerName}\n${t.posId}', style: const TextStyle(fontSize: 12))),
                      DataCell(StatusBadge(status: t.status)),
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
