import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile_model.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';

class PersonalizationWizard extends StatefulWidget {
  final UserProfile? initialProfile;
  final VoidCallback? onCompleted;

  const PersonalizationWizard({
    super.key,
    this.initialProfile,
    this.onCompleted,
  });

  @override
  State<PersonalizationWizard> createState() => _PersonalizationWizardState();
}

class _PersonalizationWizardState extends State<PersonalizationWizard> {
  int _step = 0;
  String? _uploadedFileName;
  bool _uploadSuccess = false;

  late final TextEditingController _nameController;
  late final TextEditingController _headlineController;
  late final TextEditingController _locationController;
  late final TextEditingController _roleController;
  late final TextEditingController _industryController;
  late final TextEditingController _yearsController;
  final TextEditingController _skillInputController = TextEditingController();

  String _tone = 'conversational';
  List<String> _skills = [];

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile ?? UserProfile.empty();
    _nameController = TextEditingController(text: profile.name);
    _headlineController = TextEditingController(text: profile.headline);
    _locationController = TextEditingController(text: profile.location);
    _roleController = TextEditingController(text: profile.currentRole);
    _industryController = TextEditingController(text: profile.industry);
    _yearsController = TextEditingController(
      text: profile.yearsExperience?.toString() ?? '',
    );
    _tone = profile.preferredTone;
    _skills = List<String>.from(profile.skills);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _locationController.dispose();
    _roleController.dispose();
    _industryController.dispose();
    _yearsController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / 4;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Consumer<ProfileProvider>(
          builder: (context, profileProvider, _) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: progress,
                            backgroundColor: const Color(0xFFE2E8F0),
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_step + 1}/4',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(child: _buildStep(profileProvider)),
                  const SizedBox(height: 12),
                  _buildFooter(profileProvider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStep(ProfileProvider profileProvider) {
    switch (_step) {
      case 0:
        return _buildValueStep();
      case 1:
        return _buildUploadStep(profileProvider);
      case 2:
        return _buildReviewStep();
      case 3:
        return _buildConfirmationStep(profileProvider);
      default:
        return _buildValueStep();
    }
  }

  Widget _buildValueStep() {
    return ListView(
      children: const [
        Text(
          'Your posts will sound like YOU',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 14),
        _Point(text: 'Tone matched to your voice'),
        _Point(text: 'Industry-specific language'),
        _Point(text: 'Your achievements highlighted'),
      ],
    );
  }

  Widget _buildUploadStep(ProfileProvider profileProvider) {
    return ListView(
      children: [
        const Text(
          'Upload your LinkedIn Profile PDF',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text('How to get it:'),
        const SizedBox(height: 8),
        const Text('1. Go to LinkedIn and open your profile'),
        const Text('2. Tap More and choose Save to PDF'),
        const Text('3. Upload that file here'),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: profileProvider.isUploading ? null : _pickAndUploadPdf,
          icon: profileProvider.isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.attach_file),
          label: Text(profileProvider.isUploading ? 'Uploading...' : 'Choose PDF File'),
        ),
        if (profileProvider.isExtracting)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Extracting your profile data...',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        if (_uploadSuccess && _uploadedFileName != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Expanded(child: Text(_uploadedFileName!)),
              ],
            ),
          ),
        if (profileProvider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              profileProvider.errorMessage!,
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        const SizedBox(height: 16),
        const Center(child: Text('or skip this step')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _step = 2;
            });
          },
          child: const Text('Fill manually instead'),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return ListView(
      children: [
        const Text(
          'Extracted from your PDF',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildCard(
          title: 'Basic Info',
          children: [
            _input(_nameController, 'Name'),
            _input(_headlineController, 'Headline'),
            _input(_locationController, 'Location'),
          ],
        ),
        _buildCard(
          title: 'Experience',
          children: [
            _input(_roleController, 'Current Role'),
            _input(_industryController, 'Industry'),
            _input(_yearsController, 'Years of Experience', number: true),
          ],
        ),
        _buildCard(
          title: 'Skills',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._skills.map(
                  (skill) => InputChip(
                    label: Text(skill),
                    onDeleted: () {
                      setState(() {
                        _skills.remove(skill);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillInputController,
                    decoration: const InputDecoration(
                      hintText: 'Add skill',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final value = _skillInputController.text.trim();
                    if (value.isEmpty) {
                      return;
                    }
                    setState(() {
                      if (!_skills.contains(value)) {
                        _skills.add(value);
                      }
                      _skillInputController.clear();
                    });
                  },
                  icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                ),
              ],
            ),
          ],
        ),
        _buildCard(
          title: 'Writing Tone',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['professional', 'conversational', 'inspirational', 'technical']
                  .map(
                    (tone) => ChoiceChip(
                      label: Text(_titleCase(tone)),
                      selected: _tone == tone,
                      onSelected: (_) {
                        setState(() {
                          _tone = tone;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmationStep(ProfileProvider profileProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'You are all set!',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text('Your content will now be personalized to match:'),
        const SizedBox(height: 10),
        const _Point(text: 'Your industry and role'),
        const _Point(text: 'Your tone preference'),
        const _Point(text: 'Your skills and experience'),
        const SizedBox(height: 16),
        if (profileProvider.errorMessage != null)
          Text(
            profileProvider.errorMessage!,
            style: const TextStyle(color: AppTheme.error),
          ),
      ],
    );
  }

  Widget _buildFooter(ProfileProvider profileProvider) {
    final isLast = _step == 3;
    final isFirst = _step == 0;

    return Row(
      children: [
        if (!isFirst)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _step -= 1;
                });
              },
              child: const Text('Back'),
            ),
          ),
        if (!isFirst) const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: profileProvider.isSaving
                ? null
                : () async {
                    if (!isLast) {
                      setState(() {
                        _step += 1;
                      });
                      return;
                    }

                    final success = await profileProvider.saveProfile(_buildProfilePayload());
                    if (!mounted || !success) {
                      return;
                    }
                    widget.onCompleted?.call();
                    Navigator.of(context).pop();
                  },
            child: Text(
              isLast
                  ? (profileProvider.isSaving ? 'Saving...' : 'Start Creating')
                  : (_step == 0 ? 'Let\'s Start' : 'Continue'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _input(TextEditingController controller, String hint, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPdf() async {
    final profileProvider = context.read<ProfileProvider>();
    profileProvider.clearError();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final name = file.name;
    final bytes = file.bytes;

    if (!name.toLowerCase().endsWith('.pdf')) {
      profileProvider.setError('Only PDF files are supported');
      return;
    }

    if ((file.size) > 5 * 1024 * 1024) {
      profileProvider.setError('PDF file size must be 5MB or less');
      return;
    }

    if (bytes == null) {
      profileProvider.setError('Could not read selected file');
      return;
    }

    final extracted = await profileProvider.uploadPdf(bytes: bytes, fileName: name);
    if (extracted == null) {
      return;
    }

    _applyExtractedData(extracted);
    setState(() {
      _uploadedFileName = name;
      _uploadSuccess = true;
      _step = 2;
    });
  }

  void _applyExtractedData(UserProfile profile) {
    _nameController.text = profile.name;
    _headlineController.text = profile.headline;
    _locationController.text = profile.location;
    _roleController.text = profile.currentRole;
    _industryController.text = profile.industry;
    _yearsController.text = profile.yearsExperience?.toString() ?? '';
    _skills = List<String>.from(profile.skills);
    _tone = profile.preferredTone;
  }

  UserProfile _buildProfilePayload() {
    return UserProfile(
      name: _nameController.text.trim(),
      headline: _headlineController.text.trim(),
      location: _locationController.text.trim(),
      currentRole: _roleController.text.trim(),
      industry: _industryController.text.trim(),
      skills: _skills,
      yearsExperience: int.tryParse(_yearsController.text.trim()),
      preferredTone: _tone,
      isComplete: false,
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _Point extends StatelessWidget {
  final String text;

  const _Point({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check, color: AppTheme.cta, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
