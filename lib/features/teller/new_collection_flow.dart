import 'dart:async';
import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoMo Payment Collection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.go('/teller/dashboard'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Phone Number Input
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          onChanged: _onPhoneChanged,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Customer MoMo Number *',
            hintText: 'e.g. 0550402859',
            prefixIcon: const Icon(Icons.phone_android_rounded),
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
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _detectedNetwork!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.successDark),
                        ),
                      )
                    : null),
          ),
        ),
        const SizedBox(height: 12),

        // Verified Account Holder Banner
        if (_lookupCustomer != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verified Name: ${_lookupCustomer!.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.successDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Amount Input Field (Native Keyboard)
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
          decoration: InputDecoration(
            labelText: 'Amount to Collect (GHS) *',
            hintText: '0.00',
            prefixText: 'GH₵ ',
            prefixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
            prefixIcon: const Icon(Icons.payments_rounded),
          ),
        ),
        const SizedBox(height: 24),

        // Request Payment Button
        ElevatedButton.icon(
          onPressed: (_currentAmount <= 0 || _phoneController.text.trim().length < 9)
              ? null
              : _startMoMoCollection,
          icon: const Icon(Icons.send_rounded, size: 20),
          label: const Text('Send MoMo Prompt to Customer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  // --- STEP 2: AWAITING CUSTOMER PIN ---
  Widget _buildStep2AwaitingPin() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Stack(
          alignment: Alignment.center,
          children: [
            const SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                strokeWidth: 8,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_rounded, size: 40, color: AppColors.warning),
                const SizedBox(height: 4),
                Text(
                  '${_pollingElapsedSeconds}s',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.warning),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'Awaiting Customer MoMo PIN',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'USSD debit prompt of GH₵ ${_currentAmount.toStringAsFixed(2)} was sent to ${_phoneController.text}.\nCustomer is entering their PIN on their phone.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Ref: ${_activeReference ?? ''}',
            style: const TextStyle(fontSize: 12, fontFamily: 'Courier', fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 40),

        OutlinedButton(
          onPressed: _resetFlow,
          child: const Text('Cancel Request'),
        ),
      ],
    );
  }

  // --- STEP 3: PAYMENT SUCCESS ---
  Widget _buildStep3Success() {
    if (_completedTransaction == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment Successful!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.successDark),
        ),
        const SizedBox(height: 4),
        Text(
          'Ref: ${_completedTransaction!.reference}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Courier'),
        ),
        const SizedBox(height: 24),

        ThermalReceiptCard(transaction: _completedTransaction!),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: _resetFlow,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Collection'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go('/teller/dashboard'),
          child: const Text('Back to Dashboard'),
        ),
      ],
    );
  }

  // --- STEP 4: PAYMENT FAILED ---
  Widget _buildStep4Failed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFFFDE8E8),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, size: 64, color: AppColors.error),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment Failed',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.error),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Customer declined authorization or transaction timed out.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: () => setState(() => _currentStep = 1),
          child: const Text('Try Again'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
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
          icon: const Icon(Icons.cloud_off_rounded),
          label: const Text('Complete via Offline Counter Queue'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _resetFlow,
          child: const Text('Cancel & Start New'),
        ),
      ],
    );
  }
}
