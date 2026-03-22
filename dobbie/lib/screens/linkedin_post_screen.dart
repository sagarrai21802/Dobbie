import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/linkedin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

class LinkedInPostScreen extends StatefulWidget {
  const LinkedInPostScreen({super.key});

  @override
  State<LinkedInPostScreen> createState() => _LinkedInPostScreenState();
}

class _LinkedInPostScreenState extends State<LinkedInPostScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LinkedInProvider>().checkConnectionStatus();
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Create LinkedIn Post',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<LinkedInProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressIndicator(),
                const SizedBox(height: 24),
                _buildCurrentStep(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        _buildStepCircle(0, 'Topic'),
        _buildStepLine(0),
        _buildStepCircle(1, 'Generate'),
        _buildStepLine(1),
        _buildStepCircle(2, 'Post'),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primary : Colors.grey.shade300,
              shape: BoxShape.circle,
              border: isCurrent
                  ? Border.all(color: AppTheme.secondary, width: 3)
                  : null,
            ),
            child: Icon(
              step == 0
                  ? Icons.edit
                  : step == 1
                  ? Icons.auto_awesome
                  : Icons.send,
              color: isActive ? Colors.white : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppTheme.text : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int step) {
    final isActive = _currentStep > step;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 20),
        color: isActive ? AppTheme.primary : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildCurrentStep(LinkedInProvider provider) {
    switch (_currentStep) {
      case 0:
        return _buildTopicStep(provider);
      case 1:
        return _buildGenerateStep(provider);
      case 2:
        return _buildPostStep(provider);
      default:
        return _buildTopicStep(provider);
    }
  }

  Widget _buildTopicStep(LinkedInProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What do you want to post about?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter a topic or idea, and we\'ll create an engaging LinkedIn post for you.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _topicController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'e.g., How I increased my productivity by 300%',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        PrimaryButton(
          text: 'Generate Post',
          isLoading: provider.isGeneratingPost,
          onPressed: () async {
            if (_topicController.text.trim().isEmpty) {
              provider.clearError();
              provider.generatePost(_topicController.text);
              return;
            }
            await provider.generatePost(_topicController.text);
            if (provider.generatedPost != null && mounted) {
              setState(() {
                _currentStep = 1;
                _postController.text = provider.generatedPost!;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildGenerateStep(LinkedInProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Generated Post',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Edit the post if needed, then proceed to post on LinkedIn.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _postController,
          maxLines: 12,
          onChanged: (value) => provider.updateEditedPost(value),
          decoration: InputDecoration(
            hintText: 'Your generated post will appear here...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PrimaryButton(
                text: 'Continue',
                onPressed: () {
                  setState(() {
                    _currentStep = 2;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostStep(LinkedInProvider provider) {
    final isConnected = provider.isConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Post to LinkedIn',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isConnected
              ? 'You\'re connected to LinkedIn. Ready to post!'
              : 'Connect your LinkedIn account to post.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0077B5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.link, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LinkedIn Account',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          isConnected ? 'Connected' : 'Not connected',
                          style: TextStyle(
                            color: isConnected ? AppTheme.cta : AppTheme.error,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isConnected ? Icons.check_circle : Icons.cancel,
                    color: isConnected ? AppTheme.cta : AppTheme.error,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!isConnected)
          PrimaryButton(
            text: 'Connect LinkedIn',
            isLoading: provider.state == LinkedInState.loading,
            onPressed: () => _connectLinkedIn(provider),
          )
        else
          Column(
            children: [
              PrimaryButton(
                text: 'Post to LinkedIn',
                isLoading: provider.isPosting,
                onPressed: () => _postToLinkedIn(provider),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep = 1;
                  });
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Post'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _connectLinkedIn(LinkedInProvider provider) async {
    try {
      final oauthUrl = await provider.getOAuthUrl();
      final uri = Uri.parse(oauthUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Complete LinkedIn Connection'),
              content: const Text(
                'Please complete the LinkedIn authorization in your browser, then come back to this app.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await provider.checkConnectionStatus();
                    if (!context.mounted) {
                      return;
                    }
                    if (provider.isConnected) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('LinkedIn connected successfully!'),
                          backgroundColor: AppTheme.cta,
                        ),
                      );
                    }
                  },
                  child: const Text('I\'ve Connected'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _postToLinkedIn(LinkedInProvider provider) async {
    final success = await provider.postToLinkedIn();
    if (success && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.cta, size: 28),
              SizedBox(width: 8),
              Text('Success!'),
            ],
          ),
          content: const Text('Your post has been published to LinkedIn!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                provider.clearPost();
              },
              child: const Text('Great!'),
            ),
          ],
        ),
      );
    }
  }
}
