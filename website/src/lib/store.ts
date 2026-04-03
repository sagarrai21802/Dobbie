'use client';

import { create } from 'zustand';
import { User } from './auth';

export type AuthState = 'initial' | 'loading' | 'authenticated' | 'unauthenticated' | 'error';

interface AuthStore {
  state: AuthState;
  user: User | null;
  errorMessage: string | null;
  
  setState: (state: AuthState) => void;
  setUser: (user: User | null) => void;
  setError: (message: string | null) => void;
  clearError: () => void;
}

export const useAuthStore = create<AuthStore>((set) => ({
  state: 'initial',
  user: null,
  errorMessage: null,

  setState: (state) => set({ state }),
  setUser: (user) => set({ user }),
  setError: (errorMessage) => set({ errorMessage }),
  clearError: () => set({ errorMessage: null }),
}));

interface LinkedInStore {
  isConnected: boolean;
  isLoading: boolean;
  isPosting: boolean;
  isGeneratingPost: boolean;
  isGeneratingImage: boolean;
  isResearching: boolean;
  
  generatedPost: string | null;
  editedPost: string | null;
  previewImageUrl: string | null;
  previewImageStatus: string | null;
  errorMessage: string | null;
  
  researchTopics: Array<{ topic: string; content: string }>;
  selectedTopic: string | null;
  
  lastPublishedFingerprint: string | null;
  lastImageStatus: string | null;
  
  setConnected: (connected: boolean) => void;
  setLoading: (loading: boolean) => void;
  setPosting: (posting: boolean) => void;
  setGeneratingPost: (generating: boolean) => void;
  setGeneratingImage: (generating: boolean) => void;
  setResearching: (researching: boolean) => void;
  
  setGeneratedPost: (post: string | null) => void;
  setEditedPost: (post: string | null) => void;
  setPreviewImage: (url: string | null, status: string | null) => void;
  setError: (message: string | null) => void;
  clearError: () => void;
  
  setResearchTopics: (topics: Array<{ topic: string; content: string }>) => void;
  setSelectedTopic: (topic: string | null) => void;
  clearResearchTopics: () => void;
  
  setLastPublished: (fingerprint: string, imageStatus: string | null) => void;
  clearPost: () => void;
}

export const useLinkedInStore = create<LinkedInStore>((set) => ({
  isConnected: false,
  isLoading: false,
  isPosting: false,
  isGeneratingPost: false,
  isGeneratingImage: false,
  isResearching: false,
  
  generatedPost: null,
  editedPost: null,
  previewImageUrl: null,
  previewImageStatus: null,
  errorMessage: null,
  
  researchTopics: [],
  selectedTopic: null,
  
  lastPublishedFingerprint: null,
  lastImageStatus: null,
  
  setConnected: (connected) => set({ isConnected: connected }),
  setLoading: (loading) => set({ isLoading: loading }),
  setPosting: (posting) => set({ isPosting: posting }),
  setGeneratingPost: (generating) => set({ isGeneratingPost: generating }),
  setGeneratingImage: (generating) => set({ isGeneratingImage: generating }),
  setResearching: (researching) => set({ isResearching: researching }),
  
  setGeneratedPost: (post) => set({ generatedPost: post, editedPost: null }),
  setEditedPost: (post) => set({ editedPost: post }),
  setPreviewImage: (url, status) => set({ previewImageUrl: url, previewImageStatus: status }),
  setError: (message) => set({ errorMessage: message }),
  clearError: () => set({ errorMessage: null }),
  
  setResearchTopics: (topics) => set({ researchTopics: topics, selectedTopic: null }),
  setSelectedTopic: (topic) => set({ selectedTopic: topic }),
  clearResearchTopics: () => set({ researchTopics: [], selectedTopic: null }),
  
  setLastPublished: (fingerprint, imageStatus) => set({ 
    lastPublishedFingerprint: fingerprint, 
    lastImageStatus: imageStatus 
  }),
  clearPost: () => set({
    generatedPost: null,
    editedPost: null,
    previewImageUrl: null,
    previewImageStatus: null,
    errorMessage: null,
    researchTopics: [],
    selectedTopic: null,
    lastPublishedFingerprint: null,
    lastImageStatus: null,
  }),
}));

interface ProfileStore {
  profile: ProfileData | null;
  isLoading: boolean;
  isSaving: boolean;
  isUploading: boolean;
  isExtracting: boolean;
  errorMessage: string | null;

  setProfile: (profile: ProfileData | null) => void;
  setLoading: (loading: boolean) => void;
  setSaving: (saving: boolean) => void;
  setUploading: (uploading: boolean) => void;
  setExtracting: (extracting: boolean) => void;
  setError: (message: string | null) => void;
  clearError: () => void;
}

export interface ProfileData {
  name?: string;
  headline?: string;
  location?: string;
  current_role?: string;
  industry?: string;
  skills?: string[];
  years_experience?: number;
  preferred_tone?: string;
  is_complete?: boolean;
}

export const useProfileStore = create<ProfileStore>((set) => ({
  profile: null,
  isLoading: false,
  isSaving: false,
  isUploading: false,
  isExtracting: false,
  errorMessage: null,

  setProfile: (profile) => set({ profile }),
  setLoading: (loading) => set({ isLoading: loading }),
  setSaving: (saving) => set({ isSaving: saving }),
  setUploading: (uploading) => set({ isUploading: uploading }),
  setExtracting: (extracting) => set({ isExtracting: extracting }),
  setError: (message) => set({ errorMessage: message }),
  clearError: () => set({ errorMessage: null }),
}));

export type { ProfileData as UserProfile };