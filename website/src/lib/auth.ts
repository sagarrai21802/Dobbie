import apiClient from './api';
import { API_CONFIG } from './api-config';

export interface User {
  id: string;
  email: string;
  full_name: string;
  is_active: boolean;
  profile?: UserProfile | null;
  created_at: string;
  updated_at: string;
}

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

export interface TokenResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
}

export interface ApiError {
  detail: string;
}

class AuthService {
  async register(email: string, password: string, fullName: string): Promise<User> {
    const response = await apiClient.post<User>(API_CONFIG.register, {
      email,
      password,
      full_name: fullName,
    });
    return response;
  }

  async login(email: string, password: string): Promise<TokenResponse> {
    const response = await apiClient.post<TokenResponse>(API_CONFIG.login, {
      email,
      password,
    });
    apiClient.setTokens(response.access_token, response.refresh_token);
    return response;
  }

  async googleSignIn(idToken: string): Promise<TokenResponse> {
    const response = await apiClient.post<TokenResponse>(API_CONFIG.googleLogin, {
      id_token: idToken,
    });
    apiClient.setTokens(response.access_token, response.refresh_token);
    return response;
  }

  async refreshToken(): Promise<TokenResponse> {
    const refreshToken = apiClient.getRefreshToken();
    if (!refreshToken) {
      throw new Error('No refresh token found');
    }

    const response = await apiClient.post<TokenResponse>(API_CONFIG.refresh, {
      refresh_token: refreshToken,
    });
    apiClient.setTokens(response.access_token, response.refresh_token);
    return response;
  }

  async logout(): Promise<void> {
    const refreshToken = apiClient.getRefreshToken();
    if (refreshToken) {
      try {
        await apiClient.post(API_CONFIG.logout, { refresh_token: refreshToken });
      } catch {
        // Ignore errors on logout
      }
    }
    apiClient.clearTokens();
  }

  async getCurrentUser(): Promise<User | null> {
    if (!apiClient.isAuthenticated()) {
      return null;
    }

    try {
      const user = await apiClient.get<User>(API_CONFIG.me);
      return user;
    } catch {
      // Token might be expired, try to refresh
      try {
        await this.refreshToken();
        const user = await apiClient.get<User>(API_CONFIG.me);
        return user;
      } catch {
        apiClient.clearTokens();
        return null;
      }
    }
  }

  async changePassword(currentPassword: string, newPassword: string): Promise<void> {
    await apiClient.post(API_CONFIG.changePassword, {
      current_password: currentPassword,
      new_password: newPassword,
    });
  }

  isAuthenticated(): boolean {
    return apiClient.isAuthenticated();
  }
}

export const authService = new AuthService();
export default authService;