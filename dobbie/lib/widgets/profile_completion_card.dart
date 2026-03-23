import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProfileCompletionCard extends StatelessWidget {
  final bool isComplete;
  final bool isStarted;
  final VoidCallback onTap;

  const ProfileCompletionCard({
    super.key,
    required this.isComplete,
    required this.isStarted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F2FE), Color(0xFFD1FAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes, color: AppTheme.text),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'PERSONALIZATION',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Complete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (isStarted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0369A1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'In Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Make content sound like you',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              child: Text(
                isComplete
                    ? 'Update Profile'
                    : (isStarted
                          ? 'Continue Personalization'
                          : 'Set Up Personalization'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
