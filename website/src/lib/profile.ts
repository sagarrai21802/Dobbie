import apiClient from './api';
import { API_CONFIG } from './api-config';

export interface UserProfile {
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

export interface ProfileSaveRequest {
  name?: string;
  headline?: string;
  location?: string;
  current_role?: string;
  industry?: string;
  skills?: string[];
  years_experience?: number;
  preferred_tone?: string;
}

export interface ProfileResponse {
  profile: UserProfile;
  updated_at: string;
}

class ProfileService {
  async uploadPdf(file: File): Promise<UserProfile> {
    const formData = new FormData();
    formData.append('file', file);

    const response = await apiClient.postMultipart<{ extracted: UserProfile }>(
      API_CONFIG.profileUploadPdf,
      formData
    );
    return response.extracted;
  }

  async saveProfile(profile: ProfileSaveRequest): Promise<ProfileResponse> {
    const response = await apiClient.post<ProfileResponse>(API_CONFIG.profileSave, profile);
    return response;
  }

  async getProfile(): Promise<UserProfile | null> {
    try {
      const response = await apiClient.get<ProfileResponse>(API_CONFIG.profileMe);
      return response.profile;
    } catch {
      return null;
    }
  }
}

export const profileService = new ProfileService();
export default profileService;