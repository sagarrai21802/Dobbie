import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/linkedin_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_completion_card.dart';
import 'auth_screen.dart';
import 'personalization_wizard.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
      context.read<LinkedInProvider>().checkConnectionStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFFBAE6FD),
                    child: Icon(Icons.person, color: AppTheme.text),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'User',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Consumer<ProfileProvider>(
              builder: (context, profileProvider, _) {
                return ProfileCompletionCard(
                  isComplete: profileProvider.isProfileComplete,
                  isStarted: profileProvider.hasPersonalizationStarted,
                  onTap: () =>
                      _openPersonalizationWizard(context, profileProvider),
                );
              },
            ),
            const SizedBox(height: 14),
            _tile(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'App preferences and account',
              onTap: () {},
            ),
            Consumer<LinkedInProvider>(
              builder: (context, linkedInProvider, _) {
                final connected = linkedInProvider.isConnected;
                final isBusy = linkedInProvider.state == LinkedInState.loading;
                return _tile(
                  icon: Icons.link,
                  title: 'LinkedIn Connection',
                  subtitle: connected ? 'Connected' : 'Not connected',
                  trailing: Switch.adaptive(
                    value: connected,
                    activeColor: const Color(0xFF059669),
                    onChanged: isBusy
                        ? null
                        : (value) => _handleLinkedInToggle(
                            provider: linkedInProvider,
                            targetValue: value,
                          ),
                  ),
                );
              },
            ),
            _tile(
              icon: Icons.logout,
              title: 'Sign Out',
              subtitle: 'Log out from this device',
              trailingColor: AppTheme.error,
              onTap: () => _handleLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color trailingColor = AppTheme.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.text),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ?? Icon(Icons.chevron_right, color: trailingColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLinkedInToggle({
    required LinkedInProvider provider,
    required bool targetValue,
  }) async {
    if (targetValue) {
      await _connectLinkedIn(provider);
      return;
    }

    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect LinkedIn?'),
        content: const Text(
          'This will disconnect your LinkedIn account. To connect again, you will need to log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (shouldDisconnect != true || !mounted) {
      return;
    }

    await provider.disconnectLinkedIn();
    if (!mounted) {
      return;
    }

    if (provider.errorMessage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('LinkedIn disconnected.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.errorMessage!),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  Future<void> _connectLinkedIn(LinkedInProvider provider) async {
    try {
      final oauthUrl = await provider.getOAuthUrl();
      final callbackUrl = await FlutterWebAuth2.authenticate(
        url: oauthUrl,
        callbackUrlScheme: ApiConfig.linkedinCallbackScheme,
      );
      final callbackUri = Uri.parse(callbackUrl);
      final status = callbackUri.queryParameters['status'];
      final message = callbackUri.queryParameters['message'];

      if (status == 'error') {
        throw Exception(message ?? 'LinkedIn authorization failed');
      }

      await provider.checkConnectionStatus();
      if (!mounted) {
        return;
      }

      if (provider.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LinkedIn connected successfully.'),
            backgroundColor: AppTheme.cta,
          ),
        );
        return;
      }

      throw Exception('LinkedIn connection could not be confirmed.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _openPersonalizationWizard(
    BuildContext context,
    ProfileProvider profileProvider,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => PersonalizationWizard(
        initialProfile: profileProvider.profile,
        onCompleted: () {
          profileProvider.loadProfile();
        },
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await context.read<AuthProvider>().signOut();
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }
}
