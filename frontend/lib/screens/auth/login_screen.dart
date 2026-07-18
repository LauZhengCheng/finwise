// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : login_screen.dart
// Description   : Login screen for FYP Neobanking.
//                 Handles user authentication via Supabase Auth.
// First Written : 21-May-2026
// Edited on     : 21-May-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).signIn(
        email: email,
        password: password,
      );

      final supabase = Supabase.instance.client;

      // Check onboarding status before navigating
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _errorMessage = 'Login failed. Please try again.');
        return;
      }

      // Check if onboarding_profiles row exists
      final onboardingCheck = await supabase
          .from('onboarding_profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      final onboardingComplete = onboardingCheck != null;
      if (mounted) {
        setState(() => _isLoading = false);
        // Brief success flash before navigating
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Welcome back!'),
          ]),
          backgroundColor: Color(0xFF059669),
          duration: Duration(milliseconds: 800),
        ));
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) context.go(onboardingComplete ? '/dashboard' : '/onboarding');
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      String friendly;
      if (msg.contains('invalid login credentials')) {
        friendly = 'Incorrect email or password. Please try again.';
      } else if (msg.contains('email not confirmed')) {
        friendly = 'Please verify your email before logging in.';
      } else if (msg.contains('too many requests') || msg.contains('rate limit')) {
        friendly = 'Too many attempts. Please wait a moment and try again.';
      } else if (msg.contains('network') || msg.contains('socket')) {
        friendly = 'No internet connection. Check your network and try again.';
      } else if (msg.contains('user not found')) {
        friendly = 'No account found with this email. Please register first.';
      } else {
        friendly = 'Something went wrong. Please try again.';
      }
      if (mounted) setState(() => _errorMessage = friendly);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                onPressed: () => context.go('/'),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Login to continue with your financial advisor',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login'),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}