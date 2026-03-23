class UserProfile {
  final String name;
  final String headline;
  final String location;
  final String currentRole;
  final String industry;
  final List<String> skills;
  final int? yearsExperience;
  final String preferredTone;
  final bool isComplete;

  const UserProfile({
    required this.name,
    required this.headline,
    required this.location,
    required this.currentRole,
    required this.industry,
    required this.skills,
    required this.yearsExperience,
    required this.preferredTone,
    required this.isComplete,
  });

  factory UserProfile.empty() {
    return const UserProfile(
      name: '',
      headline: '',
      location: '',
      currentRole: '',
      industry: '',
      skills: [],
      yearsExperience: null,
      preferredTone: 'conversational',
      isComplete: false,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final skillsRaw = json['skills'];
    final skills = skillsRaw is List
        ? skillsRaw.map((e) => (e ?? '').toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final yearsRaw = json['years_experience'];
    int? years;
    if (yearsRaw is int) {
      years = yearsRaw;
    } else if (yearsRaw is String && yearsRaw.trim().isNotEmpty) {
      years = int.tryParse(yearsRaw.trim());
    }

    return UserProfile(
      name: (json['name'] ?? '').toString().trim(),
      headline: (json['headline'] ?? '').toString().trim(),
      location: (json['location'] ?? '').toString().trim(),
      currentRole: (json['current_role'] ?? '').toString().trim(),
      industry: (json['industry'] ?? '').toString().trim(),
      skills: skills,
      yearsExperience: years,
      preferredTone: (json['preferred_tone'] ?? 'conversational').toString(),
      isComplete: json['is_complete'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'headline': headline,
      'location': location,
      'current_role': currentRole,
      'industry': industry,
      'skills': skills,
      'years_experience': yearsExperience,
      'preferred_tone': preferredTone,
    };
  }

  UserProfile copyWith({
    String? name,
    String? headline,
    String? location,
    String? currentRole,
    String? industry,
    List<String>? skills,
    int? yearsExperience,
    String? preferredTone,
    bool? isComplete,
  }) {
    return UserProfile(
      name: name ?? this.name,
      headline: headline ?? this.headline,
      location: location ?? this.location,
      currentRole: currentRole ?? this.currentRole,
      industry: industry ?? this.industry,
      skills: skills ?? this.skills,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      preferredTone: preferredTone ?? this.preferredTone,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}
