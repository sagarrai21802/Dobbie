'use client';

import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Input } from '@/components/input';
import { PrimaryButton, SecondaryButton } from '@/components/buttons';
import { LoadingSpinner } from '@/components/loading';
import { linkedInService } from '@/lib/linkedin';
import { geminiService } from '@/lib/gemini';

type Step = 0 | 1 | 2;

interface ResearchTopic {
  topic: string;
  content: string;
}

export default function CreatePostPage() {
  const router = useRouter();
  const [currentStep, setCurrentStep] = useState<Step>(0);
  const [topic, setTopic] = useState('');
  const [generatedPost, setGeneratedPost] = useState('');
  const [editedPost, setEditedPost] = useState('');
  const [previewImageUrl, setPreviewImageUrl] = useState<string | null>(null);
  const [previewImageStatus, setPreviewImageStatus] = useState<string | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isGeneratingImage, setIsGeneratingImage] = useState(false);
  const [isResearching, setIsResearching] = useState(false);
  const [error, setError] = useState('');
  const [researchTopics, setResearchTopics] = useState<ResearchTopic[]>([]);
  const [isPosting, setIsPosting] = useState(false);
  const [postSuccess, setPostSuccess] = useState(false);

  useEffect(() => {
    checkLinkedInStatus();
  }, []);

  const checkLinkedInStatus = async () => {
    try {
      const status = await linkedInService.getStatus();
      setIsConnected(status.connected);
    } catch {
      const connected = await linkedInService.isConnected();
      setIsConnected(connected);
    }
  };

  const handleGeneratePost = async () => {
    if (!topic.trim()) return;
    setIsLoading(true);
    setError('');
    try {
      const content = await geminiService.generateLinkedInPost(topic);
      setGeneratedPost(content);
      setEditedPost(content);
    } catch (err) {
      setError('Failed to generate post. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleResearchTopics = async () => {
    setIsResearching(true);
    setError('');
    try {
      const topics = await geminiService.generateResearchTopics();
      setResearchTopics(topics);
    } catch (err) {
      setError('Failed to fetch research topics. Please try again.');
    } finally {
      setIsResearching(false);
    }
  };

  const handleSelectResearchTopic = (item: ResearchTopic) => {
    setGeneratedPost(item.content);
    setEditedPost(item.content);
    setResearchTopics([]);
    setCurrentStep(1);
  };

  const handleGenerateImage = async () => {
    const postContent = editedPost || generatedPost;
    if (!postContent.trim()) return;
    
    setIsGeneratingImage(true);
    setError('');
    try {
      const result = await linkedInService.generateImageForPost(postContent);
      setPreviewImageUrl(result.image_url || null);
      setPreviewImageStatus(result.image_status);
    } catch (err) {
      setError('Failed to generate image. You can still post text-only.');
    } finally {
      setIsGeneratingImage(false);
    }
  };

  const handlePostToLinkedIn = async () => {
    const postContent = editedPost || generatedPost;
    if (!postContent.trim()) return;

    setIsPosting(true);
    setError('');
    try {
      await linkedInService.postToLinkedIn(postContent, previewImageUrl || undefined, previewImageStatus || undefined);
      setPostSuccess(true);
    } catch (err) {
      setError('Failed to post to LinkedIn. Please try again.');
    } finally {
      setIsPosting(false);
    }
  };

  const handleConnectLinkedIn = async () => {
    try {
      const oauthUrl = await linkedInService.getOAuthUrl();
      window.location.href = oauthUrl;
    } catch {
      setError('Failed to initiate LinkedIn connection');
    }
  };

  const buildStepCircle = (step: Step, label: string) => {
    const isActive = currentStep >= step;
    const isCurrent = currentStep === step;
    return (
      <div className="flex flex-col items-center">
        <div
          className={`w-10 h-10 rounded-full flex items-center justify-center
            ${isActive ? 'bg-[var(--primary)]' : 'bg-gray-300'}
            ${isCurrent ? 'ring-2 ring-[var(--secondary)] ring-4' : ''}`}
        >
          {step === 0 && (
            <svg className={`w-5 h-5 ${isActive ? 'text-white' : 'text-gray-500'}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
            </svg>
          )}
          {step === 1 && (
            <svg className={`w-5 h-5 ${isActive ? 'text-white' : 'text-gray-500'}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
          )}
          {step === 2 && (
            <svg className={`w-5 h-5 ${isActive ? 'text-white' : 'text-gray-500'}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          )}
        </div>
        <span className={`text-xs mt-1 ${isActive ? 'text-[var(--foreground)] font-semibold' : 'text-gray-500'}`}>{label}</span>
      </div>
    );
  };

  const buildStepLine = (step: number) => {
    const isActive = currentStep > step;
    return (
      <div className="flex-1 h-1 mx-2">
        <div className={`h-full ${isActive ? 'bg-[var(--primary)]' : 'bg-gray-300'}`}></div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-[var(--background)]">
      {/* Header */}
      <header className="bg-[var(--primary)] px-4 py-4 flex items-center">
        <Link href="/" className="text-white mr-4">
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </Link>
        <h1 className="text-xl font-bold text-white">Create LinkedIn Post</h1>
      </header>

      {/* Progress Indicator */}
      <div className="flex items-center px-6 py-4">
        {buildStepCircle(0, 'Topic')}
        {buildStepLine(0)}
        {buildStepCircle(1, 'Generate')}
        {buildStepLine(1)}
        {buildStepCircle(2, 'Post')}
      </div>

      {/* Content */}
      <main className="px-6 pb-8">
        {/* Step 0: Topic */}
        {currentStep === 0 && (
          <div>
            <h2 className="text-2xl font-bold text-[var(--foreground)] mb-2">What do you want to post about?</h2>
            <p className="text-[var(--muted)] mb-6">Enter a topic or idea, and we'll create an engaging LinkedIn post for you.</p>

            {!researchTopics.length ? (
              <div className="space-y-4">
                <PrimaryButton
                  text="Research"
                  onClick={handleResearchTopics}
                  isLoading={isResearching}
                />
                <p className="text-center text-[var(--muted)] text-sm">or create manually</p>
                <Input
                  value={topic}
                  onChange={setTopic}
                  placeholder="e.g., How I increased my productivity by 300%"
                  multiline
                  rows={4}
                />
                {error && <p className="text-[var(--error)] text-sm">{error}</p>}
                <PrimaryButton
                  text="Generate Post"
                  onClick={handleGeneratePost}
                  isLoading={isLoading}
                  disabled={!topic.trim()}
                />
              </div>
            ) : (
              <div>
                <h3 className="text-lg font-semibold mb-4">Trending Topics for Today</h3>
                <div className="space-y-3">
                  {researchTopics.map((item, index) => (
                    <button
                      key={index}
                      onClick={() => handleSelectResearchTopic(item)}
                      className="w-full p-4 bg-white rounded-xl border border-[var(--border)] text-left hover:border-[var(--primary)] transition-colors"
                    >
                      <p className="font-medium text-[var(--foreground)]">{item.topic}</p>
                    </button>
                  ))}
                </div>
                <button
                  onClick={() => setResearchTopics([])}
                  className="mt-4 text-[var(--primary)] text-sm"
                >
                  ← Use custom topic instead
                </button>
              </div>
            )}
          </div>
        )}

        {/* Step 1: Generate */}
        {currentStep === 1 && (
          <div>
            <h2 className="text-2xl font-bold text-[var(--foreground)] mb-2">Your Generated Post</h2>
            <p className="text-[var(--muted)] mb-6">Edit the post, generate an image preview, then proceed to posting.</p>

            <textarea
              value={editedPost}
              onChange={(e) => setEditedPost(e.target.value)}
              className="w-full p-4 bg-white border-2 border-[var(--border)] rounded-xl text-[var(--foreground)] resize-none focus:border-[var(--primary)] focus:outline-none"
              rows={10}
            />

            <div className="mt-4">
              <PrimaryButton
                text={previewImageUrl ? 'Regenerate Image' : 'Generate Image'}
                onClick={handleGenerateImage}
                isLoading={isGeneratingImage}
              />
              {isGeneratingImage && (
                <p className="text-[var(--muted)] text-sm mt-2 text-center">This may take time...</p>
              )}
            </div>

            {previewImageUrl && (
              <div className="mt-4 p-3 bg-white rounded-xl border border-[var(--border)]">
                <p className="font-semibold mb-2">Image Preview</p>
                <img src={previewImageUrl} alt="Preview" className="w-full rounded-lg" />
              </div>
            )}

            {previewImageStatus && !previewImageUrl && (
              <div className="mt-4 p-3 bg-white rounded-xl border border-[var(--border)]">
                <p className="text-[var(--muted)]">
                  {previewImageStatus === 'skipped_rate_limited' && 'Image skipped due to quota/rate limit. You can still post text-only.'}
                  {previewImageStatus === 'skipped_timeout' && 'Image generation timed out. You can still post text-only.'}
                  {previewImageStatus === 'skipped_failed' && 'Image generation failed. You can still post text-only.'}
                </p>
              </div>
            )}

            {error && <p className="text-[var(--error)] text-sm mt-4">{error}</p>}

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setCurrentStep(0)}
                className="flex-1 h-14 rounded-xl font-semibold text-[var(--primary)] border-2 border-[var(--primary)]"
              >
                Back
              </button>
              <button
                onClick={() => setCurrentStep(2)}
                className="flex-1 h-14 rounded-xl font-semibold text-white bg-[var(--primary)]"
              >
                Continue
              </button>
            </div>
          </div>
        )}

        {/* Step 2: Post */}
        {currentStep === 2 && (
          <div>
            <h2 className="text-2xl font-bold text-[var(--foreground)] mb-2">Post to LinkedIn</h2>
            <p className="text-[var(--muted)] mb-6">
              {!isConnected 
                ? 'Connect your LinkedIn account to post.' 
                : "You're connected to LinkedIn. Ready to post!"}
            </p>

            <div className="p-4 bg-white rounded-xl border border-[var(--border)]">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-lg bg-[#0077B5] flex items-center justify-center">
                  <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                  </svg>
                </div>
                <div className="flex-1">
                  <p className="font-semibold">LinkedIn Account</p>
                  <p className={`text-sm ${isConnected ? 'text-[var(--cta)]' : 'text-[var(--error)]'}`}>
                    {isConnected ? 'Connected' : 'Not connected'}
                  </p>
                </div>
                <svg className={`w-6 h-6 ${isConnected ? 'text-[var(--cta)]' : 'text-[var(--error)]'}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  {isConnected ? (
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  ) : (
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  )}
                </svg>
              </div>
            </div>

            {error && (
              <div className="mt-4 p-3 bg-[var(--error)]/10 rounded-xl flex items-center gap-2">
                <svg className="w-5 h-5 text-[var(--error)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <p className="text-[var(--error)] text-sm">{error}</p>
              </div>
            )}

            {!isConnected ? (
              <div className="mt-6">
                <PrimaryButton
                  text="Connect LinkedIn"
                  onClick={handleConnectLinkedIn}
                  isLoading={isLoading}
                />
              </div>
            ) : (
              <div className="mt-6 space-y-3">
                <PrimaryButton
                  text="Post to LinkedIn"
                  onClick={handlePostToLinkedIn}
                  isLoading={isPosting}
                />
                <button
                  onClick={() => setCurrentStep(1)}
                  className="w-full h-14 rounded-xl font-semibold text-[var(--primary)] border-2 border-[var(--primary)]"
                >
                  Edit Post
                </button>
              </div>
            )}
          </div>
        )}

        {/* Success Dialog */}
        {postSuccess && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-6">
            <div className="bg-white rounded-2xl p-6 max-w-sm w-full">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-8 h-8 rounded-full bg-[var(--cta)] flex items-center justify-center">
                  <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <h3 className="text-xl font-bold">Success!</h3>
              </div>
              <p className="text-[var(--muted)] mb-6">Your post has been published to LinkedIn!</p>
              <PrimaryButton
                text="Great!"
                onClick={() => {
                  setPostSuccess(false);
                  router.push('/');
                }}
              />
            </div>
          </div>
        )}
      </main>
    </div>
  );
}