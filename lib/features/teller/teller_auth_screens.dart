import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/state/providers.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInit();
  }

  Future<void> _checkInit() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (!auth.isDeviceAuthorized) {
      context.go('/device-unauthorized');
    } else if (auth.isAuthenticated) {
      if (auth.isAdmin) {
        context.go('/admin/dashboard');
      } else {
        context.go('/teller/dashboard');
      }
    } else {
      context.go('/teller/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 56,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'SWAGPAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enterprise Collection & POS Terminal Suite',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'v1.0.0 • Encrypted POS Node',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TellerLoginScreen extends ConsumerStatefulWidget {
  const TellerLoginScreen({super.key});

  @override
  ConsumerState<TellerLoginScreen> createState() => _TellerLoginScreenState();
}

class _TellerLoginScreenState extends ConsumerState<TellerLoginScreen> {
  final _emailController = TextEditingController(text: 'teller@swagpay.com');
  final _passwordController = TextEditingController(text: '1234');
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.toLowerCase().contains('admin')) {
      final success = await ref.read(authProvider.notifier).loginAdmin(identifier, password);
      if (success && mounted) {
        context.go('/admin/dashboard');
      }
    } else {
      final success = await ref.read(authProvider.notifier).loginTeller(identifier, password);
      if (success && mounted) {
        context.go('/teller/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Brand logo
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SwagPay POS Login',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please sign in to access your POS terminal portal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              if (auth.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Email / Identifier
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email or Teller / Admin ID',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password / Passcode',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (val) => setState(() => _rememberMe = val ?? true),
                      ),
                      const Text('Remember me', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('OTP sent to registered phone number for password reset')),
                      );
                    },
                    child: const Text('Forgot PIN/Pass?'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Login to Portal'),
              ),
              const SizedBox(height: 20),

              // Quick login convenience buttons
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('OR QUICK SIGN IN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _emailController.text = 'teller@swagpay.com';
                        _passwordController.text = '1234';
                        _submit();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Teller Demo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _emailController.text = 'admin@swagpay.com';
                        _passwordController.text = 'admin123';
                        _submit();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Admin Demo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceUnauthorizedScreen extends ConsumerWidget {
  const DeviceUnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_person_rounded, size: 72, color: AppColors.error),
              const SizedBox(height: 20),
              const Text(
                'Device Not Authorized',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              const Text(
                'This mobile device or POS terminal has not been whitelisted by your administrator. Contact Super Admin to register this device hardware fingerprint.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Text('DEVICE HARDWARE IDENTIFIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    SelectableText(
                      'POS-FINGERPRINT-MAC-7A:3F:82:11:BC',
                      style: TextStyle(fontSize: 13, fontFamily: 'Courier', fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ref.read(authProvider.notifier).setDeviceAuthorization(true);
                  context.go('/teller/dashboard');
                },
                child: const Text('Simulate Admin Approval & Authorize'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
