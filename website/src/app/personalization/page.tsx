'use client';

import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { profileService, UserProfile } from '@/lib/profile';

type Step = 0 | 1 | 2 | 3;

interface FormData {
  name: string;
  headline: string;
  location: string;
  current_role: string;
  industry: string;
  years_experience: string;
  skills: string[];
  preferred_tone: string;
}

export default function PersonalizationPage() {
  const router = useRouter();
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  const [step, setStep] = useState<Step>(0);
  const [guideSlideIndex, setGuideSlideIndex] = useState(0);
  const [uploadedFileName, setUploadedFileName] = useState<string | null>(null);
  const [uploadSuccess, setUploadSuccess] = useState(false);
  
  const [formData, setFormData] = useState<FormData>({
    name: '',
    headline: '',
    location: '',
    current_role: '',
    industry: '',
    years_experience: '',
    skills: [],
    preferred_tone: 'conversational',
  });
  
  const [skillInput, setSkillInput] = useState('');
  
  const [isUploading, setIsUploading] = useState(false);
  const [isExtracting, setIsExtracting] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    loadExistingProfile();
  }, []);

  const loadExistingProfile = async () => {
    try {
      const profile = await profileService.getProfile();
      if (profile) {
        setFormData({
          name: profile.name || '',
          headline: profile.headline || '',
          location: profile.location || '',
          current_role: profile.current_role || '',
          industry: profile.industry || '',
          years_experience: profile.years_experience?.toString() || '',
          skills: profile.skills || [],
          preferred_tone: profile.preferred_tone || 'conversational',
        });
      }
    } catch {
      // Ignore
    }
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.name.toLowerCase().endsWith('.pdf')) {
      setError('Only PDF files are supported');
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      setError('PDF file size must be 5MB or less');
      return;
    }

    setIsUploading(true);
    setIsExtracting(true);
    setError('');

    try {
      const extracted = await profileService.uploadPdf(file);
      setFormData({
        ...formData,
        name: extracted.name || formData.name,
        headline: extracted.headline || formData.headline,
        location: extracted.location || formData.location,
        current_role: extracted.current_role || formData.current_role,
        industry: extracted.industry || formData.industry,
        years_experience: extracted.years_experience?.toString() || formData.years_experience,
        skills: extracted.skills || formData.skills,
        preferred_tone: extracted.preferred_tone || formData.preferred_tone,
      });
      setUploadedFileName(file.name);
      setUploadSuccess(true);
      setStep(2);
    } catch (err) {
      setError('Failed to upload PDF. Please try again.');
    } finally {
      setIsUploading(false);
      setIsExtracting(false);
    }
  };

  const handleAddSkill = () => {
    const trimmed = skillInput.trim();
    if (trimmed && !formData.skills.includes(trimmed)) {
      setFormData({ ...formData, skills: [...formData.skills, trimmed] });
      setSkillInput('');
    }
  };

  const handleRemoveSkill = (skill: string) => {
    setFormData({ ...formData, skills: formData.skills.filter(s => s !== skill) });
  };

  const handleSave = async () => {
    setIsSaving(true);
    setError('');

    try {
      await profileService.saveProfile({
        name: formData.name,
        headline: formData.headline,
        location: formData.location,
        current_role: formData.current_role,
        industry: formData.industry,
        years_experience: formData.years_experience ? parseInt(formData.years_experience) : undefined,
        skills: formData.skills,
        preferred_tone: formData.preferred_tone,
      });
      router.push('/account');
    } catch (err) {
      setError('Failed to save profile. Please try again.');
    } finally {
      setIsSaving(false);
    }
  };

  const progress = (step + 1) / 4;

  const guideSlides = [
    {
      imageUrl: 'https://res.cloudinary.com/dywwto9il/image/upload/v1774232768/home_view_gmhn6e.png',
      title: 'Step 1: Open LinkedIn in browser',
      subtitle: 'Open browser, go to LinkedIn, and switch to Desktop site.',
    },
    {
      imageUrl: 'https://res.cloudinary.com/dywwto9il/image/upload/v1774232768/profile_sffspu.png',
      title: 'Step 2: Open profile and tap 3 dots',
      subtitle: 'From profile, tap the 3-dot menu, then choose Save to PDF.',
    },
  ];

  return (
    <div className="min-h-screen bg-[var(--background)]">
      {/* Header */}
      <header className="bg-[var(--primary)] px-4 py-4">
        <h1 className="text-xl font-bold text-white">Personalization</h1>
      </header>

      {/* Progress */}
      <div className="px-6 py-4">
        <div className="flex items-center gap-3">
          <div className="flex-1 h-2 bg-[#E2E8F0] rounded-full overflow-hidden">
            <div 
              className="h-full bg-[var(--primary)] transition-all"
              style={{ width: `${progress * 100}%` }}
            />
          </div>
          <span className="text-sm font-medium">{step + 1}/4</span>
        </div>
      </div>

      {/* Content */}
      <main className="px-6 pb-6">
        {/* Step 0: Value Proposition */}
        {step === 0 && (
          <div>
            <h2 className="text-2xl font-bold text-[var(--foreground)] mb-4">Your posts will sound like YOU</h2>
            <div className="space-y-3">
              <div className="flex items-center gap-3">
                <svg className="w-5 h-5 text-[var(--cta)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                <p className="text-[var(--foreground)]">Tone matched to your voice</p>
              </div>
              <div className="flex items-center gap-3">
                <svg className="w-5 h-5 text-[var(--cta)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                <p className="text-[var(--foreground)]">Industry-specific language</p>
              </div>
              <div className="flex items-center gap-3">
                <svg className="w-5 h-5 text-[var(--cta)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                <p className="text-[var(--foreground)]">Your achievements highlighted</p>
              </div>
            </div>
          </div>
        )}

        {/* Step 1: Upload PDF */}
        {step === 1 && (
          <div>
            <h2 className="text-2xl font-bold text-[var(--foreground)] mb-3">Upload your LinkedIn Profile PDF</h2>
            
            <div className="p-3 bg-[#F8FAFC] rounded-xl border border-[var(--border)] mb-4">
              <div className="flex items-start gap-2">
                <svg className="w-5 h-5 text-[var(--primary)] mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <p className="text-sm text-[#334155]">Use LinkedIn in browser only (not LinkedIn app). Turn on Desktop site first.</p>
              </div>
            </div>

            <div className="h-64 bg-white rounded-xl border border-[var(--border)] overflow-hidden mb-3">
              <img 
                src={guideSlides[guideSlideIndex].imageUrl}
                alt={guideSlides[guideSlideIndex].title}
                className="w-full h-40 object-cover"
              />
              <div className="p-3">
                <p className="font-semibold text-sm">{guideSlides[guideSlideIndex].title}</p>
                <p className="text-xs text-[var(--muted)]">{guideSlides[guideSlideIndex].subtitle}</p>
              </div>
            </div>

            <div className="flex justify-center gap-2 mb-3">
              {guideSlides.map((_, index) => (
                <button
                  key={index}
                  onClick={() => setGuideSlideIndex(index)}
                  className={`w-2 h-2 rounded-full transition-colors ${guideSlideIndex === index ? 'bg-[var(--primary)]' : 'bg-[#CBD5E1]'}`}
                />
              ))}
            </div>

            <p className="text-center text-sm text-[var(--muted)] mb-4">
              {guideSlideIndex === 0 ? 'After enabling Desktop site, open your profile.' : 'Download the PDF, then return here and upload it.'}
            </p>

            <input
              ref={fileInputRef}
              type="file"
              accept=".pdf"
              onChange={handleFileSelect}
              className="hidden"
            />

            <button
              onClick={() => fileInputRef.current?.click()}
              disabled={isUploading}
              className="w-full h-14 rounded-xl font-semibold text-white bg-[var(--primary)] flex items-center justify-center gap-2"
            >
              {isUploading ? (
                <>
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  {isExtracting ? 'Extracting...' : 'Uploading...'}
                </>
              ) : (
                <>
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
                  </svg>
                  Choose PDF File
                </>
              )}
            </button>

            {uploadSuccess && uploadedFileName && (
              <div className="flex items-center gap-2 mt-3 text-[var(--cta)]">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                <span className="text-sm">{uploadedFileName}</span>
              </div>
            )}

            {error && (
              <p className="text-[var(--error)] text-sm mt-3">{error}</p>
            )}

            <p className="text-center text-[var(--muted)] text-sm mt-4">or skip this step</p>
            <button
              onClick={() => setStep(2)}
              className="w-full h-12 rounded-xl font-semibold text-[var(--primary)] border-2 border-[var(--primary)] mt-2"
            >
              Fill manually instead
            </button>
          </div>
        )}

        {/* Step 2: Review/Edit */}
        {step === 2 && (
          <div>
            <h2 className="text-2xl font-bold text-[var(--foreground)] mb-4">Your Profile</h2>

            <div className="space-y-4">
              {/* Basic Info */}
              <div className="bg-white p-4 rounded-xl border border-[var(--border)]">
                <p className="font-semibold mb-3">Basic Info</p>
                <div className="space-y-3">
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    placeholder="Name"
                    className="w-full px-3 py-2 border border-[var(--border)] rounded-lg text-sm"
                  />
                  <input
                    type="text"
                    value={formData.headline}
                    onChange={(e) => setFormData({ ...formData, headline: e.target.value })}
                    placeholder="Headline"
                    className="w-full px-3 py-2 border border-[var(--border)] rounded-lg text-sm"
                  />
                  <input
                    type="text"
                    value={formData.location}
                    onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                    placeholder="Location"
                    className="w-full px-3 py-2 border border-[var(--border)] rounded-lg text-sm"
                  />
                </div>
              </div>

              {/* Experience */}
              <div className="bg-white p-4 rounded-xl border border-[var(--border)]">
                <p className="font-semibold mb-3">Experience</p>
                <div className="space-y-3">
                  <input
                    type="text"
                    value={formData.current_role}
                    onChange={(e) => setFormData({ ...formData, current_role: e.target.value })}
                    placeholder="Current Role"
                    className="w-full px-3 py-2 border border-[var(--border)] rounded-lg text-sm"
                  />
                  <input
                    type="text"
                    value={formData.industry}
                    onChange={(e) => setFormData({ ...formData, industry: e.target.value })}
                    placeholder="Industry"
                    className="w-full px-3 py-2 border border-[var(--border)] rounded-lg text-sm"
                  />
                  <input
                    type="number"
                    value={formData.years_experience}
                    onChange={(e) => setFormData({ ...formData, years_experience: e.target.value })}
                    placeholder="Years of Experience"
                    className="w-full px-3 py-2 border border-[var(--border)] rounded-lg text-sm"
                  />
                </div>
              </div>

              {/* Skills */}
              <div className="bg-white p-4 rounded-xl border border-[var(--border)]">
                <p className="font-semibold mb-3">Skills</p>
                <div className="flex flex-wrap gap-2 mb-3">
                  {formData.skills.map((skill) => (
                    <span 
                      key={skill}
                      className="px-3 py-1 bg-[var(--primary)]/10 text-[var(--primary)] rounded-full text-sm flex items-center gap-1"
                    >
                      {skill}
                      <button onClick={() => handleRemoveSkill(skill)} className="hover:text-[var(--error)]">
                        ×
                      </button>
                    </span>
                  ))}
                </div>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={skillInput}
                    onChange={(e) => setSkillInput(e.target.value)}
                    placeholder="Add skill"
                    className="flex-1 px-3 py-2 border border-[var(--border)] rounded-lg text-sm"
                    onKeyPress={(e) => e.key === 'Enter' && handleAddSkill()}
                  />
                  <button
                    onClick={handleAddSkill}
                    className="px-3 py-2 text-[var(--primary)]"
                  >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                    </svg>
                  </button>
                </div>
              </div>

              {/* Tone */}
              <div className="bg-white p-4 rounded-xl border border-[var(--border)]">
                <p className="font-semibold mb-3">Writing Tone</p>
                <div className="flex flex-wrap gap-2">
                  {['professional', 'conversational', 'inspirational', 'technical'].map((tone) => (
                    <button
                      key={tone}
                      onClick={() => setFormData({ ...formData, preferred_tone: tone })}
                      className={`px-4 py-2 rounded-full text-sm font-medium ${
                        formData.preferred_tone === tone
                          ? 'bg-[var(--primary)] text-white'
                          : 'bg-[var(--background)] text-[var(--foreground)] border border-[var(--border)]'
                      }`}
                    >
                      {tone.charAt(0).toUpperCase() + tone.slice(1)}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Step 3: Confirmation */}
        {step === 3 && (
          <div className="text-center">
            <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-[var(--cta)]/10 flex items-center justify-center">
              <svg className="w-8 h-8 text-[var(--cta)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h2 className="text-2xl font-bold text-[var(--foreground)] mb-2">You are all set!</h2>
            <p className="text-[var(--muted)] mb-4">Your content will now be personalized to match:</p>
            <div className="text-left space-y-2 bg-white p-4 rounded-xl">
              <div className="flex items-center gap-2">
                <svg className="w-4 h-4 text-[var(--cta)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                <span>Your industry and role</span>
              </div>
              <div className="flex items-center gap-2">
                <svg className="w-4 h-4 text-[var(--cta)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                <span>Your tone preference</span>
              </div>
              <div className="flex items-center gap-2">
                <svg className="w-4 h-4 text-[var(--cta)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                <span>Your skills and experience</span>
              </div>
            </div>
            {error && (
              <p className="text-[var(--error)] text-sm mt-4">{error}</p>
            )}
          </div>
        )}

        {/* Footer Buttons */}
        <div className="flex gap-3 mt-6">
          {step > 0 && step < 3 && (
            <button
              onClick={() => setStep(step - 1 as Step)}
              className="flex-1 h-14 rounded-xl font-semibold text-[var(--primary)] border-2 border-[var(--primary)]"
            >
              Back
            </button>
          )}
          <button
            onClick={() => {
              if (step === 3) {
                handleSave();
              } else {
                setStep((step + 1) as Step);
              }
            }}
            disabled={isSaving}
            className="flex-1 h-14 rounded-xl font-semibold text-white bg-[var(--primary)] disabled:opacity-50"
          >
            {step === 0 && "Let's Start"}
            {step === 1 && 'Continue'}
            {step === 2 && 'Continue'}
            {step === 3 && (isSaving ? 'Saving...' : 'Start Creating')}
          </button>
        </div>
      </main>
    </div>
  );
}