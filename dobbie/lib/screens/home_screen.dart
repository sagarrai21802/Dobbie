import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'linkedin_post_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Dobbie',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final user = authProvider.user;
                return PopupMenuButton<_ProfileMenuAction>(
                  tooltip: 'Profile',
                  onSelected: (action) =>
                      _onProfileMenuSelected(context, action),
                  itemBuilder: (context) => [
                    PopupMenuItem<_ProfileMenuAction>(
                      enabled: false,
                      child: SizedBox(
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user?.fullName ?? 'Account',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? 'No email',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.text.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<_ProfileMenuAction>(
                      value: _ProfileMenuAction.logout,
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Log Out',
                            style: TextStyle(color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [_buildLinkedInCard(context)],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinkedInCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LinkedInPostScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0077B5), Color(0xFF00A0DC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0077B5).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.link, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Post to LinkedIn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate and share engaging posts with one click',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onProfileMenuSelected(BuildContext context, _ProfileMenuAction action) {
    switch (action) {
      case _ProfileMenuAction.logout:
        _handleLogout(context);
    }
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
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }
}

enum _ProfileMenuAction { logout }
