import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/transaction.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_thin_footer.dart';
import '../../core/widgets/carrier_brand_icon.dart';
import '../../core/widgets/thermal_receipt_card.dart';

class NewCollectionScreen extends ConsumerStatefulWidget {
  const NewCollectionScreen({super.key});

  @override
  ConsumerState<NewCollectionScreen> createState() => _NewCollectionScreenState();
}

class _NewCollectionScreenState extends ConsumerState<NewCollectionScreen> {
  // Screen Steps:
  // 1 = Enter Amount (Screen 1)
  // 2 = Enter MoMo Number, Select Network & Pay Button (Screen 2)
  // 3 = Awaiting Customer MoMo PIN (60s countdown & polling)
  // 4 = Payment Success (Authentic Thermal POS Receipt)
  // 5 = Payment Failed / Declined
  int _currentStep = 1;

  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  MoMoNetwork? _selectedNetwork;
  String? _selectedPosId;

  String? _activeReference;
  PaymentTransaction? _completedTransaction;
  String? _errorMessage;
  bool _isRechecking = false;
  bool _isInitiating = false;

  Timer? _pollingTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 60;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  double get _currentAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  void _onNumpadTap(String val) {
    String current = _amountController.text;
    if (val == 'C') {
      _amountController.clear();
    } else if (val == '⌫') {
      if (current.isNotEmpty) {
        _amountController.text = current.substring(0, current.length - 1);
      }
    } else if (val == '.') {
      if (!current.contains('.')) {
        if (current.isEmpty) {
          _amountController.text = '0.';
        } else {
          _amountController.text = '$current.';
        }
      }
    } else {
      // If there are already two decimal places, don't allow more
      if (current.contains('.')) {
        final parts = current.split('.');
        if (parts.length > 1 && parts[1].length >= 2) return;
      }
      if (current == '0') {
        _amountController.text = val;
      } else {
        _amountController.text = '$current$val';
      }
    }
    setState(() {});
  }

  void _setPresetAmount(double val) {
    setState(() {
      _amountController.text = val.toStringAsFixed(val == val.roundToDouble() ? 0 : 2);
    });
  }

  void _proceedToStep2() {
    if (_currentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than GH₵ 0.00'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() {
      _currentStep = 2;
    });
  }

  void _selectNetwork(MoMoNetwork network) {
    setState(() => _selectedNetwork = network);
  }

  void _startMoMoCollection() async {
    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit Ghana mobile money number.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedNetwork == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a carrier network (MTN, Vodafone, or Airtel).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = ref.read(authProvider).currentUser;
    final repo = ref.read(paymentRepositoryProvider);
    if (user == null) {
      setState(() => _errorMessage = 'This terminal has no active session. Sign in before collecting payment.');
      return;
    }

    setState(() {
      _isInitiating = true;
      _errorMessage = null;
    });

    try {
      final posDevices = repo.getPosDevices();
      final effectivePos = (_selectedPosId != null && _selectedPosId!.isNotEmpty)
          ? _selectedPosId!
          : (user.assignedPos.firstOrNull?.isNotEmpty == true
              ? user.assignedPos.first
              : (posDevices.isNotEmpty ? posDevices.first.id : 'POS-01'));

      // Fire prompt immediately without waiting for customer name lookup!
      final initRes = await repo.initiateMoMoPayment(
        momoNumber: cleanPhone,
        amount: _currentAmount,
        customerName: null, // Name is resolved from the API response JSON
        tellerId: user.id,
        posId: effectivePos,
        network: _selectedNetwork,
      );

      _activeReference = initRes['reference'] as String;

      setState(() {
        _isInitiating = false;
        _currentStep = 3; // Awaiting Customer PIN
        _remainingSeconds = 60;
      });

      // 60s active countdown
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _currentStep != 3) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            timer.cancel();
            _pollingTimer?.cancel();
            _errorMessage = 'Customer prompt timed out (60s). Customer did not authorize prompt on their phone.';
            _currentStep = 5; // Failed
          }
        });
      });

      // Rapid status polling every 1.5 seconds for instant decline/approval response
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
        if (!mounted || _currentStep != 3) {
          timer.cancel();
          return;
        }

        try {
          var txn = await repo.checkPaymentStatus(_activeReference!);
          if (_selectedNetwork != null && txn.network != _selectedNetwork) {
            txn = txn.copyWith(network: _selectedNetwork);
          }
          if (txn.status == TransactionStatus.success) {
            timer.cancel();
            _countdownTimer?.cancel();
            setState(() {
              _completedTransaction = txn;
              _currentStep = 4; // Success
            });
          } else if (txn.status == TransactionStatus.failed) {
            timer.cancel();
            _countdownTimer?.cancel();
            setState(() {
              _completedTransaction = txn;
              _errorMessage = txn.failureReason ?? 'Payment declined by customer on handset';
              _currentStep = 5; // Failed
            });
          }
        } catch (_) {
          // Ignore network glitch during polling
        }
      });
    } catch (e) {
      _countdownTimer?.cancel();
      _pollingTimer?.cancel();
      setState(() {
        _isInitiating = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
        _currentStep = 5;
      });
    }
  }

  Future<void> _checkManualStatus() async {
    if (_activeReference == null) return;
    setState(() => _isRechecking = true);
    final repo = ref.read(paymentRepositoryProvider);
    try {
      var txn = await repo.checkPaymentStatus(_activeReference!);
      if (_selectedNetwork != null && txn.network != _selectedNetwork) {
        txn = txn.copyWith(network: _selectedNetwork);
      }
      if (!mounted) return;
      setState(() {
        _isRechecking = false;
        _completedTransaction = txn;
      });
      if (txn.status == TransactionStatus.success) {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
        setState(() => _currentStep = 4);
      } else if (txn.status == TransactionStatus.failed) {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
        setState(() {
          _errorMessage = txn.failureReason ?? 'Payment declined by customer on handset';
          _currentStep = 5;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prompt is still pending on customer handset. Awaiting PIN authorization...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRechecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not verify status: ${e.toString().replaceAll('ApiException: ', '')}')),
      );
    }
  }

  void _resetFlow() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _currentStep = 1;
      _remainingSeconds = 60;
      _selectedNetwork = null;
      _amountController.clear();
      _phoneController.clear();
      _activeReference = null;
      _completedTransaction = null;
      _errorMessage = null;
      _isRechecking = false;
      _isInitiating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF4F5F7);

    String appTitle;
    switch (_currentStep) {
      case 1:
        appTitle = 'Enter Amount';
        break;
      case 2:
        appTitle = 'Payment Details';
        break;
      case 3:
        appTitle = 'Awaiting Authorization';
        break;
      case 4:
        appTitle = 'Payment Complete';
        break;
      case 5:
        appTitle = 'Payment Declined';
        break;
      default:
        appTitle = 'Collect Payment';
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E22) : const Color(0xFF1E293B),
        leading: _currentStep == 2
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Back to Amount',
                onPressed: () => setState(() => _currentStep = 1),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(
          appTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Dashboard',
            onPressed: () => context.go('/teller/dashboard'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: _buildCurrentContent(context),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppThinFooter(),
    );
  }

  Widget _buildCurrentContent(BuildContext context) {
    switch (_currentStep) {
      case 1:
        return _buildStep1EnterAmount();
      case 2:
        return _buildStep2PaymentDetails();
      case 3:
        return _buildStep3AwaitingPin();
      case 4:
        return _buildStep4Success();
      case 5:
        return _buildStep5Failed();
      default:
        return const SizedBox();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SCREEN 1: ENTER AMOUNT
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep1EnterAmount() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final heading = isDark ? Colors.white : const Color(0xFF1E293B);

    final hasValidAmount = _currentAmount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Amount Display Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'ENTER AMOUNT TO CHARGE',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: muted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    'GH₵ ',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1570A6),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _amountController.text.isEmpty ? '0.00' : _amountController.text,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        color: _amountController.text.isEmpty
                            ? muted.withValues(alpha: 0.4)
                            : const Color(0xFF1570A6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Preset Amount Quick Chips
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [10.0, 20.0, 50.0, 100.0, 200.0, 500.0].map((val) {
                  final isSelected = _currentAmount == val;
                  return InkWell(
                    onTap: () => _setPresetAmount(val),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1570A6)
                            : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1570A6) : borderColor,
                        ),
                      ),
                      child: Text(
                        'GH₵ ${val.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : heading,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // POS Virtual Touch Numpad
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              _buildNumpadRow(['1', '2', '3'], isDark, heading, cardBg, borderColor),
              const SizedBox(height: 8),
              _buildNumpadRow(['4', '5', '6'], isDark, heading, cardBg, borderColor),
              const SizedBox(height: 8),
              _buildNumpadRow(['7', '8', '9'], isDark, heading, cardBg, borderColor),
              const SizedBox(height: 8),
              _buildNumpadRow(['.', '0', '⌫'], isDark, heading, cardBg, borderColor),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Screen 1 Action Button: Continue to Screen 2
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: hasValidAmount ? _proceedToStep2 : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: Text(
              hasValidAmount
                  ? 'Continue to Payment (GH₵ ${_currentAmount.toStringAsFixed(2)})'
                  : 'Enter Amount to Continue',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1570A6),
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
              disabledForegroundColor: muted,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> keys, bool isDark, Color heading, Color cardBg, Color borderColor) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => _onNumpadTap(key),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: key == '⌫'
                      ? Icon(Icons.backspace_outlined, size: 20, color: heading)
                      : Text(
                          key,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: heading,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SCREEN 2: PAYMENT DETAILS (AMOUNT DUE, PHONE, NETWORK, PAY BUTTON)
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep2PaymentDetails() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final heading = isDark ? Colors.white : const Color(0xFF1E293B);

    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final hasValidPhone = cleanPhone.length >= 9;
    final hasCarrier = _selectedNetwork != null;
    final canPay = hasValidPhone && hasCarrier && !_isInitiating;

    final payButtonColor = _selectedNetwork != null ? _getNetworkBrandColor(_selectedNetwork!) : const Color(0xFF1570A6);
    final payButtonTextColor = _selectedNetwork == MoMoNetwork.mtn ? Colors.black : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Bold Amount Due Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2634) : const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1570A6).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AMOUNT DUE TO PAY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: const Color(0xFF1570A6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GH₵ ${_currentAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1570A6),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => setState(() => _currentStep = 1),
                icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF1570A6)),
                label: const Text(
                  'Edit',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1570A6)),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1570A6).withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 1. Enter Mobile Money Number
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '1. MOBILE MONEY NUMBER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: muted,
                    ),
                  ),
                  if (cleanPhone.length == 10)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 12),
                          SizedBox(width: 4),
                          Text(
                            '10 Digits',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: heading, letterSpacing: 1.0),
                decoration: InputDecoration(
                  hintText: 'e.g. 0244123456',
                  counterText: '',
                  hintStyle: TextStyle(color: muted.withValues(alpha: 0.5), fontSize: 16, letterSpacing: 0),
                  prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 22, color: Color(0xFF1570A6)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1570A6), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Select Carrier Network Provider
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '2. SELECT NETWORK PROVIDER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: muted,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildNetworkCard(
                      network: MoMoNetwork.mtn,
                      isDark: isDark,
                      defaultBorderColor: borderColor,
                      muted: muted,
                      heading: heading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildNetworkCard(
                      network: MoMoNetwork.vodafone,
                      isDark: isDark,
                      defaultBorderColor: borderColor,
                      muted: muted,
                      heading: heading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildNetworkCard(
                      network: MoMoNetwork.airtel,
                      isDark: isDark,
                      defaultBorderColor: borderColor,
                      muted: muted,
                      heading: heading,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Pay Button carrying the amount dynamically
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: canPay ? _startMoMoCollection : null,
            icon: _isInitiating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.payment_rounded, size: 22),
            label: Text(
              _isInitiating
                  ? 'Sending Prompt...'
                  : !hasValidPhone
                      ? 'Enter Customer MoMo Number'
                      : !hasCarrier
                          ? 'Select Carrier Network Above'
                          : 'Pay GH₵ ${_currentAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.3),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasCarrier ? payButtonColor : const Color(0xFF1570A6),
              foregroundColor: payButtonTextColor,
              disabledBackgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
              disabledForegroundColor: muted,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkCard({
    required MoMoNetwork network,
    required bool isDark,
    required Color defaultBorderColor,
    required Color muted,
    required Color heading,
  }) {
    final isSelected = _selectedNetwork == network;
    final brandColor = _getNetworkBrandColor(network);
    final selectedBg = _getNetworkSelectedBg(network, isDark);

    return InkWell(
      onTap: () => _selectNetwork(network),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedBg
              : (isDark ? const Color(0xFF27272A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? brandColor : defaultBorderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            CarrierBrandIcon(network: network, size: 28),
            const SizedBox(height: 8),
            Text(
              network.carrierName,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: heading,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              network.serviceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? brandColor : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SCREEN 3: AWAITING CUSTOMER AUTHORIZATION (60s COUNTDOWN & POLLING)
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep3AwaitingPin() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final heading = isDark ? Colors.white : const Color(0xFF1E293B);
    final brandColor = _selectedNetwork != null ? _getNetworkBrandColor(_selectedNetwork!) : const Color(0xFF1570A6);
    final isUrgent = _remainingSeconds <= 15;
    final countdownColor = isUrgent ? const Color(0xFFE65100) : brandColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        // Countdown Timer Ring
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: (_remainingSeconds.clamp(0, 60)) / 60.0,
                strokeWidth: 8,
                backgroundColor: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(countdownColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_remainingSeconds',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    color: countdownColor,
                  ),
                ),
                Text(
                  'SEC REMAINING',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: muted,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (_selectedNetwork != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: brandColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CarrierBrandIcon(network: _selectedNetwork!, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_selectedNetwork!.carrierName} (${_selectedNetwork!.serviceName})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: brandColor,
                  ),
                ),
              ],
            ),
          ),

        Text(
          'Awaiting Customer MoMo PIN',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: heading),
        ),
        const SizedBox(height: 8),
        Text(
          'MoMo prompt of GH₵ ${_currentAmount.toStringAsFixed(2)} was dispatched to ${_phoneController.text}.\nCustomer is approving the prompt on their phone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13.5, height: 1.4),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Gateway Listening (1.5s interval)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: muted),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        Text(
          'Ref: ${_activeReference ?? ''}',
          style: TextStyle(fontSize: 11.5, fontFamily: 'Courier', fontWeight: FontWeight.w600, color: muted),
        ),

        const SizedBox(height: 24),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isRechecking ? null : _checkManualStatus,
                  icon: _isRechecking
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(_isRechecking ? 'Checking Status...' : 'Check Status Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1570A6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _resetFlow,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cancel Request'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cardBg,
                    foregroundColor: muted,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SCREEN 4: PAYMENT SUCCESS & POS THERMAL RECEIPT
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep4Success() {
    if (_completedTransaction == null) return const SizedBox();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sleek Success Confirmation Banner
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.success.withValues(alpha: isDark ? 0.4 : 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              Text(
                'Payment Received · GH₵ ${_completedTransaction!.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.success,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),

        // Authentic POS Thermal Receipt Hero Card
        ThermalReceiptCard(transaction: _completedTransaction!),

        const SizedBox(height: 16),

        // Primary Action: Start New Collection
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _resetFlow,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Start New Collection', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1570A6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Center(
          child: TextButton.icon(
            onPressed: () => context.go('/teller/dashboard'),
            icon: Icon(Icons.dashboard_outlined, size: 16, color: muted),
            label: Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: muted)),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SCREEN 5: PAYMENT FAILED / DECLINED
  // ─────────────────────────────────────────────────────────────
  Widget _buildStep5Failed() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final heading = isDark ? Colors.white : const Color(0xFF1E293B);
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: isDark ? 0.15 : 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, size: 48, color: AppColors.error),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment Declined',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.error),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Customer declined prompt or insufficient MoMo wallet balance.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: muted, height: 1.4),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _currentStep = 2),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again (Same Amount)', style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1570A6),
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
            onPressed: () => setState(() => _currentStep = 1),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Change Amount', style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              backgroundColor: cardBg,
              foregroundColor: heading,
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              final user = ref.read(authProvider).currentUser;
              if (user == null) {
                setState(() => _errorMessage = 'This terminal has no active session. Sign in before recording a collection.');
                return;
              }
              final repo = ref.read(paymentRepositoryProvider);
              final posDevices = repo.getPosDevices();
              final effectivePos = (_selectedPosId != null && _selectedPosId!.isNotEmpty)
                  ? _selectedPosId!
                  : (user.assignedPos.firstOrNull?.isNotEmpty == true
                      ? user.assignedPos.first
                      : (posDevices.isNotEmpty ? posDevices.first.id : 'POS-01'));
              final txn = repo.recordOfflineTransaction(
                momoNumber: _phoneController.text.trim(),
                amount: _currentAmount,
                customerName: null,
                tellerId: user.id,
                tellerName: user.fullName,
                posId: effectivePos,
                network: _selectedNetwork,
              );
              _pollingTimer?.cancel();
              setState(() {
                _completedTransaction = txn;
                _currentStep = 4; // Success
              });
            },
            icon: const Icon(Icons.cloud_off_rounded, size: 18),
            label: const Text(
              'Record in Offline Counter Queue',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: cardBg,
              foregroundColor: heading,
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Color _getNetworkBrandColor(MoMoNetwork network) {
    switch (network) {
      case MoMoNetwork.mtn:
        return const Color(0xFFE5A900);
      case MoMoNetwork.vodafone:
        return const Color(0xFFE60000);
      case MoMoNetwork.airtel:
        return const Color(0xFF00377B);
    }
  }

  Color _getNetworkSelectedBg(MoMoNetwork network, bool isDark) {
    switch (network) {
      case MoMoNetwork.mtn:
        return isDark ? const Color(0xFF2E2405) : const Color(0xFFFFFBEB);
      case MoMoNetwork.vodafone:
        return isDark ? const Color(0xFF2E1015) : const Color(0xFFFFF1F2);
      case MoMoNetwork.airtel:
        return isDark ? const Color(0xFF0C1F38) : const Color(0xFFF0F9FF);
    }
  }
}
