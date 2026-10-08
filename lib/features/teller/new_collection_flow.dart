import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/models/transaction.dart';
import '../../core/services/receipt_service.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/carrier_brand_icon.dart';
import '../../core/widgets/lively_widgets.dart';
import '../../core/widgets/notification_dropdown_button.dart';
import '../../core/widgets/teller_bottom_nav_bar.dart';
import '../../core/widgets/teller_user_avatar_menu.dart';
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

  String? _liveCustomerName;
  bool _isLiveLookingUp = false;

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

  void _triggerAutoPrintReceipt(PaymentTransaction txn) {
    final shouldAutoPrint = ref.read(autoPrintReceiptProvider);
    if (!shouldAutoPrint) return;

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted && _currentStep == 4) {
        ReceiptService.printReceipt(context, txn);
      }
    });
  }


  void _onNumpadTap(String val) {
    HapticFeedback.selectionClick();
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

  void _proceedToStep2() {
    if (_currentAmount <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than GH₵ 0.00'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 2;
    });
    _triggerLiveLookup();
  }

  void _selectNetwork(MoMoNetwork network) {
    HapticFeedback.lightImpact();
    setState(() => _selectedNetwork = network);
    _triggerLiveLookup();
  }

  void _triggerLiveLookup() async {
    final clean = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10 && _selectedNetwork != null) {
      setState(() => _isLiveLookingUp = true);
      try {
        final cust = await ref.read(paymentRepositoryProvider).lookupCustomer(clean, network: _selectedNetwork);
        if (mounted && cust != null && cust.name.isNotEmpty) {
          setState(() {
            _liveCustomerName = cust.name;
            _isLiveLookingUp = false;
          });
          return;
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _isLiveLookingUp = false);
      }
    }
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
            _triggerAutoPrintReceipt(txn);
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
        _triggerAutoPrintReceipt(txn);
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
          NotificationDropdownButton(isDark: isDark),
          const SizedBox(width: 8),
          TellerUserAvatarMenu(isDark: isDark),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Dashboard',
            onPressed: () => context.go('/teller/dashboard'),
          ),
          const SizedBox(width: 4),
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
      bottomNavigationBar: const TellerBottomNavBar(currentRoute: '/teller/collection'),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 14,
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
                      color: Color(0xFF229ED9),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _amountController.text.isEmpty ? '0.00' : _amountController.text,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        color: _amountController.text.isEmpty
                            ? muted.withValues(alpha: 0.35)
                            : const Color(0xFF229ED9),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // POS Virtual Touch Numpad with Bouncy Feedback
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
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

        const SizedBox(height: 16),

        // Screen 1 Action Button: Continue to Screen 2
        BouncyTap(
          onTap: hasValidAmount ? _proceedToStep2 : null,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: hasValidAmount
                  ? const LinearGradient(
                      colors: [Color(0xFF229ED9), Color(0xFF0284C7)],
                    )
                  : null,
              color: hasValidAmount ? null : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(16),
              boxShadow: hasValidAmount
                  ? [
                      BoxShadow(
                        color: const Color(0xFF229ED9).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  hasValidAmount
                      ? 'Continue to Payment · GH₵ ${_currentAmount.toStringAsFixed(2)}'
                      : 'Enter Amount to Continue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: hasValidAmount ? Colors.white : muted,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: hasValidAmount ? Colors.white : muted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> keys, bool isDark, Color heading, Color cardBg, Color borderColor) {
    return Row(
      children: keys.map((key) {
        final isSpecial = key == '⌫' || key == '.';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: BouncyTap(
              onTap: () => _onNumpadTap(key),
              scaleFactor: 0.92,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262933) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: key == '⌫'
                    ? Icon(Icons.backspace_outlined, size: 20, color: heading)
                    : Text(
                        key,
                        style: TextStyle(
                          fontSize: isSpecial ? 24 : 22,
                          fontWeight: FontWeight.w800,
                          color: heading,
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
                onChanged: (_) {
                  setState(() {});
                  _triggerLiveLookup();
                },
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
              if (_isLiveLookingUp) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1570A6)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Checking registered name with telco...',
                      style: TextStyle(fontSize: 11.5, color: muted, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ] else if (_liveCustomerName != null && _liveCustomerName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: isDark ? 0.3 : 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Registered SIM Name: $_liveCustomerName',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
        // Pay Button carrying the amount dynamically
        BouncyTap(
          onTap: canPay ? _startMoMoCollection : null,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: canPay
                  ? LinearGradient(
                      colors: hasCarrier
                          ? [payButtonColor, payButtonColor.withValues(alpha: 0.85)]
                          : const [Color(0xFF229ED9), Color(0xFF0284C7)],
                    )
                  : null,
              color: canPay ? null : (isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(16),
              boxShadow: canPay
                  ? [
                      BoxShadow(
                        color: (hasCarrier ? payButtonColor : const Color(0xFF229ED9)).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isInitiating) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Sending Prompt to Customer...',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ] else ...[
                  Icon(Icons.payment_rounded, size: 20, color: canPay ? payButtonTextColor : muted),
                  const SizedBox(width: 10),
                  Text(
                    !hasValidPhone
                        ? 'Enter Customer MoMo Number'
                        : !hasCarrier
                            ? 'Select Carrier Network Above'
                            : 'Pay GH₵ ${_currentAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      color: canPay ? payButtonTextColor : muted,
                    ),
                  ),
                ],
              ],
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

    return BouncyTap(
      onTap: () => _selectNetwork(network),
      scaleFactor: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedBg
              : (isDark ? const Color(0xFF242730) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandColor : defaultBorderColor,
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: brandColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CarrierBrandIcon(network: network, size: 32),
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
    final brandColor = _selectedNetwork != null ? _getNetworkBrandColor(_selectedNetwork!) : const Color(0xFF229ED9);
    final isUrgent = _remainingSeconds <= 15;
    final countdownColor = isUrgent ? const Color(0xFFEF4444) : brandColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 10),

        // Dribbble Radar Pulse Waves & Carrier Center
        Stack(
          alignment: Alignment.center,
          children: [
            // Concentric radar wave effect
            PulsingBeacon(
              color: brandColor,
              size: 54,
              showRipple: true,
            ),
            // Carrier Icon
            if (_selectedNetwork != null)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: brandColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CarrierBrandIcon(network: _selectedNetwork!, size: 48),
              ),
          ],
        ),

        const SizedBox(height: 24),

        // Countdown Timer Ring with Clean Dribbble Styling
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: (_remainingSeconds.clamp(0, 60)) / 60.0,
                strokeWidth: 7,
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
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    color: countdownColor,
                  ),
                ),
                Text(
                  'SEC REMAINING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: muted,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 18),

        Text(
          'Awaiting Customer MoMo PIN',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: heading, letterSpacing: -0.3),
        ),
        const SizedBox(height: 8),
        Text(
          'Prompt of GH₵ ${_currentAmount.toStringAsFixed(2)} was sent to ${_phoneController.text}.\nCustomer is authorizing the transaction on their phone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13, height: 1.45),
        ),

        const SizedBox(height: 18),

        // Progress Steps Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              _buildProgressStep(
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF10B981),
                text: 'USSD prompt dispatched to customer handset',
                isDone: true,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildProgressStep(
                icon: Icons.lock_clock_rounded,
                iconColor: const Color(0xFFF59E0B),
                text: 'Waiting for customer to enter 4-digit PIN',
                isDone: false,
                isPulsing: true,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildProgressStep(
                icon: Icons.sync_rounded,
                iconColor: const Color(0xFF229ED9),
                text: 'Real-time gateway listener active (1.5s polling)',
                isDone: false,
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
        Text(
          'Reference: ${_activeReference ?? ''}',
          style: TextStyle(fontSize: 11, fontFamily: 'Courier', fontWeight: FontWeight.w700, color: muted),
        ),

        const SizedBox(height: 20),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BouncyTap(
                onTap: _isRechecking ? null : _checkManualStatus,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF229ED9), Color(0xFF0284C7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF229ED9).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isRechecking) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Checking Status...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ] else ...[
                        const Icon(Icons.sync_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          'Check Status Now',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              BouncyTap(
                onTap: _resetFlow,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close_rounded, size: 16, color: muted),
                      const SizedBox(width: 6),
                      Text(
                        'Cancel Request',
                        style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStep({
    required IconData icon,
    required Color iconColor,
    required String text,
    required bool isDone,
    bool isPulsing = false,
    required bool isDark,
  }) {
    return Row(
      children: [
        if (isPulsing)
          PulsingBeacon(color: iconColor, size: 8)
        else
          Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isDone ? FontWeight.w700 : FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
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
    final isOfflineQueued = _completedTransaction!.id.startsWith('tx_off_') ||
        _completedTransaction!.reference.startsWith('OFF-') ||
        _completedTransaction!.status == TransactionStatus.pending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dribbble Celebratory Confetti Burst Banner
        SuccessCelebrationBurst(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: isOfflineQueued
                  ? const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isOfflineQueued ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
                      .withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOfflineQueued ? Icons.cloud_off_rounded : Icons.check_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOfflineQueued ? 'Queued for Offline Sync' : 'Payment Approved & Verified!',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'GH₵ ${_completedTransaction!.amount.toStringAsFixed(2)} received from ${_completedTransaction!.customerName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Authentic POS Thermal Receipt Hero Card
        ThermalReceiptCard(transaction: _completedTransaction!)
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

        const SizedBox(height: 18),

        // Primary Action: Start New Collection
        BouncyTap(
          onTap: _resetFlow,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF229ED9), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF229ED9).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Start New Collection',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        BouncyTap(
          onTap: () => context.go('/teller/dashboard'),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dashboard_outlined, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    'Back to Dashboard',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: muted),
                  ),
                ],
              ),
            ),
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
              _triggerAutoPrintReceipt(txn);
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
