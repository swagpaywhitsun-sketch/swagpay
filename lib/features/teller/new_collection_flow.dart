import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/customer.dart';
import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_thin_footer.dart';
import '../../core/widgets/thermal_receipt_card.dart';

class NewCollectionScreen extends ConsumerStatefulWidget {
  const NewCollectionScreen({super.key});

  @override
  ConsumerState<NewCollectionScreen> createState() => _NewCollectionScreenState();
}

class _NewCollectionScreenState extends ConsumerState<NewCollectionScreen> {
  // Screen States:
  // 1 = Enter Number & Amount
  // 2 = Awaiting Customer PIN
  // 3 = Payment Success
  // 4 = Payment Failed
  int _currentStep = 1;

  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  Customer? _lookupCustomer;
  bool _isLookingUp = false;
  String? _detectedNetwork;

  String? _activeReference;
  PaymentTransaction? _completedTransaction;
  String? _errorMessage;

  Timer? _pollingTimer;
  int _pollingElapsedSeconds = 0;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String val) async {
    final clean = val.replaceAll(RegExp(r'\D'), '');
    String? net;
    String prefix = '';
    if (clean.startsWith('233') && clean.length >= 5) {
      prefix = '0${clean.substring(3, 5)}';
    } else if (clean.startsWith('0') && clean.length >= 3) {
      prefix = clean.substring(0, 3);
    }

    if (['024', '025', '053', '054', '055', '059'].contains(prefix)) {
      net = 'MTN MoMo';
    } else if (['020', '050'].contains(prefix)) {
      net = 'Telecel Cash';
    } else if (['026', '056', '027', '057'].contains(prefix)) {
      net = 'AT Money';
    }

    setState(() => _detectedNetwork = net);

    if (clean.length >= 10) {
      setState(() => _isLookingUp = true);
      final cust = await ref.read(paymentRepositoryProvider).lookupCustomer(clean);
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          _lookupCustomer = cust;
        });
      }
    }
  }

  double get _currentAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  void _startMoMoCollection() async {
    final auth = ref.read(authProvider);
    final user = auth.currentUser;
    final repo = ref.read(paymentRepositoryProvider);

    setState(() {
      _currentStep = 2; // Awaiting Customer PIN
      _pollingElapsedSeconds = 0;
      _errorMessage = null;
    });

    try {
      final initRes = await repo.initiateMoMoPayment(
        momoNumber: _phoneController.text.trim(),
        amount: _currentAmount,
        customerName: _lookupCustomer?.name,
        tellerId: user?.id ?? 'usr_teller1',
        posId: user?.assignedPos.firstOrNull ?? 'pos_01',
      );

      _activeReference = initRes['reference'] as String;

      // Start status polling every 2.5 seconds
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
        _pollingElapsedSeconds += 2;
        if (!mounted) {
          timer.cancel();
          return;
        }

        try {
          final txn = await repo.checkPaymentStatus(_activeReference!);
          if (txn.status == TransactionStatus.success) {
            timer.cancel();
            setState(() {
              _completedTransaction = txn;
              _currentStep = 3; // Success
            });
          } else if (txn.status == TransactionStatus.failed) {
            timer.cancel();
            setState(() {
              _completedTransaction = txn;
              _errorMessage = txn.failureReason ?? 'Payment declined by customer';
              _currentStep = 4; // Failed
            });
          }
        } catch (_) {}

        // Timeout after 90 seconds
        if (_pollingElapsedSeconds >= 90) {
          timer.cancel();
          setState(() {
            _errorMessage = 'Customer PIN authorization timed out (90s)';
            _currentStep = 4;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
        _currentStep = 4;
      });
    }
  }

  void _resetFlow() {
    _pollingTimer?.cancel();
    setState(() {
      _currentStep = 1;
      _phoneController.clear();
      _amountController.clear();
      _lookupCustomer = null;
      _detectedNetwork = null;
      _activeReference = null;
      _completedTransaction = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF6F6F8);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF303030),
        automaticallyImplyLeading: false,
        title: Text(
          _currentStep == 1
              ? 'Collect Payment'
              : _currentStep == 2
                  ? 'Awaiting Authorization'
                  : _currentStep == 3
                      ? 'Collection Complete'
                      : 'Collection Failed',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => context.go('/teller/dashboard'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: _buildCurrentContent(context),
        ),
      ),
      bottomNavigationBar: const AppThinFooter(),
    );
  }

  Widget _buildCurrentContent(BuildContext context) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Entry();
      case 2:
        return _buildStep2AwaitingPin();
      case 3:
        return _buildStep3Success();
      case 4:
        return _buildStep4Failed();
      default:
        return const SizedBox();
    }
  }

  // --- STEP 1: PHONE NUMBER & AMOUNT ENTRY ---
  Widget _buildStep1Entry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF707579);
    final heading = isDark ? Colors.white : const Color(0xFF303030);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Customer card ──────────────────────────────────────────
        _card(
          cardBg: cardBg,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel('CUSTOMER NUMBER', muted),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: _onPhoneChanged,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: heading),
                decoration: InputDecoration(
                  hintText: 'e.g. 0550402859',
                  counterText: '',
                  hintStyle: TextStyle(color: muted.withValues(alpha: 0.6), fontSize: 15),
                  prefixIcon: Icon(Icons.phone_android_rounded, size: 20, color: muted),
                  suffixIcon: _isLookingUp
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : (_detectedNetwork != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF229ED9).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _detectedNetwork!,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF229ED9)),
                              ),
                            )
                          : null),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF7F8F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF229ED9), width: 1.5),
                  ),
                ),
              ),
              if (_lookupCustomer != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lookupCustomer!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: isDark ? AppColors.success : AppColors.successDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Amount card ────────────────────────────────────────────
        _card(
          cardBg: cardBg,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel('AMOUNT TO COLLECT (GHS)', muted),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF229ED9)),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: muted.withValues(alpha: 0.4)),
                  prefixText: 'GH₵ ',
                  prefixStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF229ED9)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF7F8F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF229ED9), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Primary action ─────────────────────────────────────────
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: (_currentAmount <= 0 || _phoneController.text.trim().length < 9)
                ? null
                : _startMoMoCollection,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text(
              'Send MoMo Prompt to Customer',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF229ED9),
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE1E3E5),
              disabledForegroundColor: muted,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 2: AWAITING CUSTOMER PIN ---
  Widget _buildStep2AwaitingPin() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF707579);
    final heading = isDark ? Colors.white : const Color(0xFF303030);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 32),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: CircularProgressIndicator(
                strokeWidth: 7,
                backgroundColor: borderColor,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF229ED9)),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_rounded, size: 34, color: Color(0xFF229ED9)),
                const SizedBox(height: 4),
                Text(
                  '${_pollingElapsedSeconds}s',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF229ED9)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Awaiting Customer MoMo PIN',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: heading),
        ),
        const SizedBox(height: 8),
        Text(
          'USSD debit prompt of GH₵ ${_currentAmount.toStringAsFixed(2)} was sent to ${_phoneController.text}.\nCustomer is entering their PIN on their phone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            'Ref: ${_activeReference ?? ''}',
            style: TextStyle(fontSize: 12, fontFamily: 'Courier', fontWeight: FontWeight.w700, color: heading),
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: _resetFlow,
          style: OutlinedButton.styleFrom(
            foregroundColor: muted,
            side: BorderSide(color: borderColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          child: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }

  // --- STEP 3: PAYMENT SUCCESS ---
  Widget _buildStep3Success() {
    if (_completedTransaction == null) return const SizedBox();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF707579);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: isDark ? 0.15 : 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, size: 56, color: AppColors.success),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Payment Successful',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF303030),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ref: ${_completedTransaction!.reference}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: muted, fontFamily: 'Courier'),
        ),
        const SizedBox(height: 20),

        ThermalReceiptCard(transaction: _completedTransaction!),
        const SizedBox(height: 20),

        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _resetFlow,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Collection', style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF229ED9),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => context.go('/teller/dashboard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : const Color(0xFF303030),
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ),
      ],
    );
  }

  // --- STEP 4: PAYMENT FAILED ---
  Widget _buildStep4Failed() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF707579);
    final heading = isDark ? Colors.white : const Color(0xFF303030);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: isDark ? 0.15 : 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, size: 52, color: AppColors.error),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Payment Failed',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.error),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Customer declined authorization or transaction timed out.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: muted),
        ),
        const SizedBox(height: 24),

        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _currentStep = 1),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF303030),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              final auth = ref.read(authProvider);
              final user = auth.currentUser;
              final repo = ref.read(paymentRepositoryProvider);
              final txn = repo.recordOfflineTransaction(
                momoNumber: _phoneController.text.trim(),
                amount: _currentAmount,
                customerName: _lookupCustomer?.name,
                tellerId: user?.id ?? 'usr_teller',
                posId: user?.assignedPos.firstOrNull ?? 'pos_01',
              );
              _pollingTimer?.cancel();
              setState(() {
                _completedTransaction = txn;
                _currentStep = 3; // Success (Receipt)
              });
            },
            icon: const Icon(Icons.cloud_off_rounded, size: 18),
            label: const Text(
              'Complete via Offline Counter Queue',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: heading,
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({
    required Color cardBg,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String label, Color color) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: color),
    ),
  );
}
