import apiClient from './api';
import { API_CONFIG } from './api-config';

export interface LinkedInStatus {
  connected: boolean;
  linkedin_user_id?: string;
}

export interface LinkedInPostResult {
  success: boolean;
  post_id?: string;
  image_url?: string;
  image_status: string;
}

export interface LinkedInImageResult {
  image_url?: string;
  image_status: string;
}

export interface ResearchTopic {
  topic: string;
  content: string;
}

class LinkedInService {
  private getWebRedirectUrl(): string {
    // Get the current origin for the callback URL
    if (typeof window !== 'undefined') {
      return `${window.location.origin}/auth/linkedin/callback`;
    }
    return 'http://localhost:3000/auth/linkedin/callback';
  }

  async getOAuthUrl(): Promise<string> {
    const redirectUrl = this.getWebRedirectUrl();
    const response = await apiClient.get<{ authorization_url: string }>(
      `${API_CONFIG.linkedinAuthorize}?redirect_url=${encodeURIComponent(redirectUrl)}`
    );
    return response.authorization_url;
  }

  async getStatus(): Promise<LinkedInStatus> {
    const response = await apiClient.get<LinkedInStatus>(API_CONFIG.linkedinStatus);
    return response;
  }

  async isConnected(): Promise<boolean> {
    try {
      const status = await this.getStatus();
      return status.connected;
    } catch {
      // Fallback to localStorage check
      if (typeof window !== 'undefined') {
        return localStorage.getItem('linkedin_connected') === 'true';
      }
      return false;
    }
  }

  async generateImageForPost(content: string): Promise<LinkedInImageResult> {
    const response = await apiClient.post<LinkedInImageResult>(API_CONFIG.linkedinGenerateImage, {
      content,
    });
    return response;
  }

  async postToLinkedIn(content: string, imageUrl?: string, imageStatus?: string): Promise<LinkedInPostResult> {
    const body: Record<string, unknown> = { content };
    if (imageUrl) {
      body.image_url = imageUrl;
    }
    if (imageStatus) {
      body.image_status = imageStatus;
    }

    const response = await apiClient.post<LinkedInPostResult>(API_CONFIG.linkedinPost, body);
    
    // Store connected status
    if (typeof window !== 'undefined') {
      localStorage.setItem('linkedin_connected', 'true');
    }
    
    return response;
  }

  async disconnect(): Promise<void> {
    await apiClient.post(API_CONFIG.linkedinDisconnect, {});
    
    if (typeof window !== 'undefined') {
      localStorage.setItem('linkedin_connected', 'false');
    }
  }
}

export const linkedInService = new LinkedInService();
export default linkedInService;