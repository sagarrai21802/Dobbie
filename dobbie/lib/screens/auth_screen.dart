import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildLogo(),
              const SizedBox(height: 16),
              _buildWelcomeText(context),
              const Spacer(flex: 2),
              _buildAuthButtons(context),
              const SizedBox(height: 24),
              _buildSkipButton(context),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.diamond_outlined, size: 56, color: Colors.white),
    );
  }

  Widget _buildWelcomeText(BuildContext context) {
    return Column(
      children: [
        Text(
          'Welcome to Dobbie',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Your personal AI assistant for everyday tasks',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAuthButtons(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SignInScreen()));
          },
          child: const Text('Sign In'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SignUpScreen()));
          },
          child: const Text('Sign Up'),
        ),
        const SizedBox(height: 24),
        _buildDivider(),
        const SizedBox(height: 24),
        _buildGoogleButton(context),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFCBD5E1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(
              color: AppTheme.text.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFCBD5E1))),
      ],
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Google Sign In (Coming soon)'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
            child: const Icon(
              Icons.g_mobiledata,
              size: 28,
              color: Color(0xFF4285F4),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Continue with Google'),
        ],
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Skip (Coming soon)'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Text(
        'Skip for now',
        style: TextStyle(
          color: AppTheme.text.withValues(alpha: 0.6),
          fontSize: 14,
        ),
      ),
    );
  }
}
