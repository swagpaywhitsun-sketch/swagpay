import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/customer.dart';
import '../../core/models/pos_device.dart';
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
  // 4 = Payment Failed (Authoritatively Declined)
  // 5 = Gateway Verification In-Flight / Timeout (Reconciliation Guard)
  int _currentStep = 1;

  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  MoMoNetwork? _selectedNetwork;
  Customer? _lookupCustomer;
  bool _isLookingUp = false;
  Future<Customer?>? _lookupFuture;
  String? _selectedPosId;

  String? _activeReference;
  PaymentTransaction? _completedTransaction;
  String? _errorMessage;
  bool _isRechecking = false;

  Timer? _pollingTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 60;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _selectNetwork(MoMoNetwork network) {
    if (_selectedNetwork == network) return;
    setState(() => _selectedNetwork = network);
    final clean = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (clean.length >= 10) {
      _performCustomerLookup(clean, network: network);
    }
  }

  void _onPhoneChanged(String val) {
    final clean = val.replaceAll(RegExp(r'\D'), '');
    // Strictly require teller to select carrier first. No auto-detection based on prefix!
    if (clean.length >= 10 && _selectedNetwork != null) {
      _performCustomerLookup(clean, network: _selectedNetwork);
    } else {
      if (_lookupCustomer != null || _isLookingUp) {
        setState(() {
          _isLookingUp = false;
          _lookupCustomer = null;
        });
      }
      _lookupFuture = null;
    }
  }

  void _performCustomerLookup(String cleanPhone, {MoMoNetwork? network}) async {
    setState(() {
      _isLookingUp = true;
      _lookupCustomer = null;
    });
    final net = network ?? _selectedNetwork;
    final future = ref.read(paymentRepositoryProvider).lookupCustomer(cleanPhone, network: net);
    _lookupFuture = future;
    final cust = await future;
    if (mounted && _lookupFuture == future) {
      setState(() {
        _isLookingUp = false;
        _lookupCustomer = cust;
      });
    }
  }

  double get _currentAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  void _startMoMoCollection() async {
    if (_selectedNetwork == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a carrier network (MTN, Vodafone, or Airtel) first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = ref.read(authProvider).currentUser;
    final repo = ref.read(paymentRepositoryProvider);
    if (user == null) {
      setState(() => _errorMessage = 'This terminal has no active session. Sign in before collecting money.');
      return;
    }

    setState(() {
      _currentStep = 2; // Awaiting Customer PIN
      _remainingSeconds = 60; // 60s active countdown
      _errorMessage = null;
    });

    try {
      // Never fire the MoMo prompt with an unverified name — wait for a pending lookup
      if (_lookupCustomer == null && _lookupFuture != null) {
        _lookupCustomer = await _lookupFuture;
      }
      final posDevices = repo.getPosDevices();
      final effectivePos = (_selectedPosId != null && _selectedPosId!.isNotEmpty)
          ? _selectedPosId!
          : (user.assignedPos.firstOrNull?.isNotEmpty == true
              ? user.assignedPos.first
              : (posDevices.isNotEmpty ? posDevices.first.id : 'POS-01'));

      final initRes = await repo.initiateMoMoPayment(
        momoNumber: _phoneController.text.trim(),
        amount: _currentAmount,
        customerName: _lookupCustomer?.name,
        tellerId: user.id,
        posId: effectivePos,
        network: _selectedNetwork,
      );

      _activeReference = initRes['reference'] as String;

      // Active 1-second countdown timer for visible countdown
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _currentStep != 2) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            timer.cancel();
            _pollingTimer?.cancel();
            _errorMessage = 'Customer MoMo prompt timed out (60s). Customer did not enter PIN on handset.';
            _currentStep = 4; // Failed
          }
        });
      });

      // Rapid status polling every 1.5 seconds for instant decline/approval response
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
        if (!mounted || _currentStep != 2) {
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
              _currentStep = 3; // Success
            });
          } else if (txn.status == TransactionStatus.failed) {
            timer.cancel();
            _countdownTimer?.cancel();
            setState(() {
              _completedTransaction = txn;
              _errorMessage = txn.failureReason ?? 'Payment declined by customer on handset';
              _currentStep = 4; // Immediately show Failed / Declined!
            });
          }
        } catch (_) {
          // Network fluctuation during polling — do not treat as failure
        }
      });
    } catch (e) {
      _countdownTimer?.cancel();
      _pollingTimer?.cancel();
      setState(() {
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
        _currentStep = 4;
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
        setState(() => _currentStep = 3);
      } else if (txn.status == TransactionStatus.failed) {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
        setState(() {
          _errorMessage = txn.failureReason ?? 'Payment declined by customer on handset';
          _currentStep = 4;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prompt is still pending on customer handset. Awaiting PIN entry...'),
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

  Future<void> _recheckStatus() async {
    return _checkManualStatus();
  }

  void _resetFlow() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _currentStep = 1;
      _remainingSeconds = 60;
      _selectedNetwork = null;
      _phoneController.clear();
      _amountController.clear();
      _lookupCustomer = null;
      _lookupFuture = null;
      _activeReference = null;
      _completedTransaction = null;
      _errorMessage = null;
      _isRechecking = false;
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
                      : _currentStep == 4
                          ? 'Collection Failed'
                          : 'Verification In-Flight',
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
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
        return _buildStep1Entry();
      case 2:
        return _buildStep2AwaitingPin();
      case 3:
        return _buildStep3Success();
      case 4:
        return _buildStep4Failed();
      case 5:
        return _buildStep5InFlight();
      default:
        return const SizedBox();
    }
  }

  // --- STEP 1: PHONE NUMBER & AMOUNT ENTRY ---
  Widget _buildStep1Entry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final heading = isDark ? Colors.white : const Color(0xFF303030);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Active POS Terminal selector (allow any user or teller to operate from any POS)
        Consumer(
          builder: (context, ref, _) {
            final repo = ref.watch(paymentRepositoryProvider);
            final user = ref.watch(authProvider).currentUser;
            final devices = repo.getPosDevices();
            final currentPos = (_selectedPosId != null && _selectedPosId!.isNotEmpty)
                ? _selectedPosId!
                : (user?.assignedPos.firstOrNull?.isNotEmpty == true
                    ? user!.assignedPos.first
                    : (devices.isNotEmpty ? devices.first.id : 'POS-01'));
            final currentDeviceName = devices.firstWhere(
              (p) => p.id == currentPos || p.serialNumber == currentPos,
              orElse: () => PosDevice(
                id: currentPos,
                name: currentPos,
                serialNumber: currentPos,
                location: 'Front Counter',
                branch: 'Main Branch',
                deviceFingerprint: 'DEV-$currentPos',
                lastSeen: DateTime.now(),
              ),
            ).name;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1570A6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF1570A6), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ACTIVE POS TERMINAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: muted, letterSpacing: 0.5)),
                        const SizedBox(height: 1),
                        Text('$currentDeviceName ($currentPos)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: heading)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Switch POS Terminal',
                    offset: const Offset(0, 36),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 20, color: Color(0xFF1570A6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: isDark ? const Color(0xFF27272A) : Colors.white,
                    onSelected: (val) {
                      setState(() => _selectedPosId = val);
                    },
                    itemBuilder: (ctx) {
                      final allOptions = devices.isNotEmpty
                          ? devices
                          : [
                              PosDevice(
                                id: 'POS-01',
                                name: 'Counter Terminal 01',
                                serialNumber: 'POS-01',
                                location: 'Main Desk',
                                branch: 'Main Branch',
                                deviceFingerprint: 'DEV-POS-01',
                                lastSeen: DateTime.now(),
                              ),
                            ];
                      return allOptions.map((p) => PopupMenuItem(
                        value: p.id,
                        child: Row(
                          children: [
                            Icon(
                              p.id == currentPos ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 16,
                              color: p.id == currentPos ? const Color(0xFF1570A6) : muted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${p.name} (${p.serialNumber})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      )).toList();
                    },
                  ),
                ],
              ),
            );
          },
        ),

        // 1. CARRIER SELECTION (FIRST STEP)
        _card(
          cardBg: cardBg,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel('1. SELECT CARRIER NETWORK', muted),
                  if (_selectedNetwork != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: _getNetworkBrandColor(_selectedNetwork!).withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedNetwork!.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _getNetworkBrandColor(_selectedNetwork!),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: _buildCarrierCard(
                      network: MoMoNetwork.mtn,
                      isDark: isDark,
                      defaultBorderColor: borderColor,
                      muted: muted,
                      heading: heading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCarrierCard(
                      network: MoMoNetwork.vodafone,
                      isDark: isDark,
                      defaultBorderColor: borderColor,
                      muted: muted,
                      heading: heading,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCarrierCard(
                      network: MoMoNetwork.airtel,
                      isDark: isDark,
                      defaultBorderColor: borderColor,
                      muted: muted,
                      heading: heading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _selectedNetwork == null
                      ? const Color(0xFF1570A6).withValues(alpha: isDark ? 0.15 : 0.08)
                      : _getNetworkBrandColor(_selectedNetwork!).withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedNetwork == null ? Icons.touch_app_rounded : Icons.check_circle_rounded,
                      size: 15,
                      color: _selectedNetwork == null
                          ? const Color(0xFF1570A6)
                          : _getNetworkBrandColor(_selectedNetwork!),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _selectedNetwork == null
                            ? 'Please select carrier first (MTN, Vodafone, or Airtel)'
                            : 'Selected: ${_selectedNetwork!.carrierName} (${_selectedNetwork!.serviceName}) — ready for number',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _selectedNetwork == null
                              ? (isDark ? Colors.white70 : const Color(0xFF1570A6))
                              : _getNetworkBrandColor(_selectedNetwork!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. CUSTOMER PHONE NUMBER (SECOND STEP)
        _card(
          cardBg: cardBg,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel('2. CUSTOMER PHONE NUMBER', muted),
                  if (_selectedNetwork != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Carrier: ${_selectedNetwork!.carrierName}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _getNetworkBrandColor(_selectedNetwork!),
                        ),
                      ),
                    ),
                ],
              ),
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
                  prefixIcon: Icon(
                    Icons.phone_android_rounded,
                    size: 20,
                    color: _selectedNetwork != null ? _getNetworkBrandColor(_selectedNetwork!) : muted,
                  ),
                  suffixIcon: _isLookingUp
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : (_selectedNetwork != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _getNetworkBrandColor(_selectedNetwork!).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedNetwork!.serviceName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _getNetworkBrandColor(_selectedNetwork!),
                                ),
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
                    borderSide: BorderSide(
                      color: _selectedNetwork != null ? _getNetworkBrandColor(_selectedNetwork!) : const Color(0xFF1570A6),
                      width: 1.5,
                    ),
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

        // 3. AMOUNT TO COLLECT (THIRD STEP)
        _card(
          cardBg: cardBg,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel('3. AMOUNT TO COLLECT (GHS)', muted),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1570A6)),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: muted.withValues(alpha: 0.4)),
                  prefixText: 'GH₵ ',
                  prefixStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1570A6)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF7F8F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1570A6), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [10, 20, 50, 100, 200, 500].map((val) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _amountController.text = val.toStringAsFixed(2);
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        'GH₵ $val',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: heading,
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

        // Primary action
        Builder(
          builder: (context) {
            final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
            final hasCarrier = _selectedNetwork != null;
            final hasValidPhone = cleanPhone.length >= 9;
            final hasValidAmount = _currentAmount > 0;
            final canSubmit = hasCarrier && hasValidPhone && hasValidAmount;

            String buttonText;
            if (!hasCarrier) {
              buttonText = 'Step 1: Select Carrier Network Above';
            } else if (!hasValidPhone) {
              buttonText = 'Step 2: Enter Customer Phone Number';
            } else if (!hasValidAmount) {
              buttonText = 'Step 3: Enter Amount to Collect';
            } else {
              buttonText = 'Send ${_selectedNetwork!.carrierName} MoMo Prompt (GH₵ ${_currentAmount.toStringAsFixed(2)})';
            }

            return SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: canSubmit ? _startMoMoCollection : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  buttonText,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasCarrier ? _getNetworkBrandColor(_selectedNetwork!) : const Color(0xFF1570A6),
                  foregroundColor: _selectedNetwork == MoMoNetwork.mtn ? Colors.black : Colors.white,
                  disabledBackgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE1E3E5),
                  disabledForegroundColor: muted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- STEP 2: AWAITING CUSTOMER PIN ---
  Widget _buildStep2AwaitingPin() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final heading = isDark ? Colors.white : const Color(0xFF303030);
    final brandColor = _selectedNetwork != null ? _getNetworkBrandColor(_selectedNetwork!) : const Color(0xFF1570A6);
    final isUrgent = _remainingSeconds <= 15;
    final countdownColor = isUrgent ? const Color(0xFFE65100) : brandColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                value: (_remainingSeconds.clamp(0, 60)) / 60.0,
                strokeWidth: 8,
                backgroundColor: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(countdownColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_remainingSeconds',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    color: countdownColor,
                  ),
                ),
                Text(
                  'SEC REMAINING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: muted,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_selectedNetwork != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: brandColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cell_tower_rounded, size: 16, color: brandColor),
                const SizedBox(width: 6),
                Text(
                  _selectedNetwork!.label,
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
          '${_selectedNetwork?.label ?? "MoMo"} prompt of GH₵ ${_currentAmount.toStringAsFixed(2)} was sent to ${_phoneController.text}.\nCustomer is entering their PIN or confirming prompt on their phone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13.5, height: 1.5),
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
                'Listening for Gateway Response (1.5s polling)',
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isRechecking ? null : _checkManualStatus,
                icon: _isRechecking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(_isRechecking ? 'Checking...' : 'Check Status Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1570A6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- STEP 3: PAYMENT SUCCESS ---
  Widget _buildStep3Success() {
    if (_completedTransaction == null) return const SizedBox();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;

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
          child: OutlinedButton(
            onPressed: () => context.go('/teller/dashboard'),
            style: OutlinedButton.styleFrom(
              backgroundColor: cardBg,
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
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final heading = isDark ? Colors.white : const Color(0xFF303030);
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;

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
          'Payment Declined',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.error),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Customer cancelled prompt or insufficient MoMo wallet balance.',
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
                customerName: _lookupCustomer?.name,
                tellerId: user.id,
                tellerName: user.fullName,
                posId: effectivePos,
                network: _selectedNetwork,
              );
              _pollingTimer?.cancel();
              setState(() {
                _completedTransaction = txn;
                _currentStep = 3; // Success (Receipt)
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

  // --- STEP 5: GATEWAY VERIFICATION IN-FLIGHT ---
  Widget _buildStep5InFlight() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFE1E3E5);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final heading = isDark ? Colors.white : const Color(0xFF303030);
    final cardBg = isDark ? const Color(0xFF1E1E22) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pending.withValues(alpha: isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_top_rounded, size: 52, color: AppColors.pending),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Verification In-Progress',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: heading),
        ),
        const SizedBox(height: 8),
        Text(
          'The prompt was sent to the customer, but the telco gateway has not returned final confirmation yet. '
          'Do NOT recharge the customer or declare declined until authoritative status is verified.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Text('TRANSACTION REFERENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted)),
              const SizedBox(height: 4),
              SelectableText(
                _activeReference ?? 'N/A',
                style: TextStyle(fontSize: 14, fontFamily: 'Courier', fontWeight: FontWeight.w800, color: heading),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isRechecking ? null : _recheckStatus,
            icon: _isRechecking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Re-check Gateway Status Now', style: TextStyle(fontWeight: FontWeight.w800)),
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
            onPressed: () => context.go('/teller/history'),
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text('Check in Shift History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
          child: TextButton(
            onPressed: _resetFlow,
            child: Text('Start New Collection', style: TextStyle(fontWeight: FontWeight.w700, color: muted)),
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

  Widget _buildCarrierCard({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedBg
              : (isDark ? const Color(0xFF27272A) : const Color(0xFFF8F9FA)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? brandColor : defaultBorderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    network.carrierName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: network == MoMoNetwork.mtn ? Colors.black : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isSelected ? brandColor : muted.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              network.carrierName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
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

  Color _getNetworkBrandColor(MoMoNetwork network) {
    switch (network) {
      case MoMoNetwork.mtn:
        return const Color(0xFFE5A900);
      case MoMoNetwork.vodafone:
        return const Color(0xFFE11D48);
      case MoMoNetwork.airtel:
        return const Color(0xFF0284C7);
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
