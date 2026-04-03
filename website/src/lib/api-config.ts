const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';
const API_PREFIX = '/api/v1';

export const API_CONFIG = {
  baseUrl: API_BASE_URL,
  apiPrefix: API_PREFIX,

  // Auth endpoints
  register: `${API_PREFIX}/auth/register`,
  login: `${API_PREFIX}/auth/login`,
  googleLogin: `${API_PREFIX}/auth/google`,
  refresh: `${API_PREFIX}/auth/refresh`,
  logout: `${API_PREFIX}/auth/logout`,
  me: `${API_PREFIX}/auth/me`,
  changePassword: `${API_PREFIX}/auth/change-password`,

  // AI/Content Generation endpoints
  generatePost: `${API_PREFIX}/ai/generate-post`,
  researchTopics: `${API_PREFIX}/ai/research-topics`,

  // Profile personalization endpoints
  profileUploadPdf: `${API_PREFIX}/profile/upload-pdf`,
  profileSave: `${API_PREFIX}/profile/save`,
  profileMe: `${API_PREFIX}/profile/me`,

  // LinkedIn OAuth & API endpoints
  linkedinAuthorize: `${API_PREFIX}/auth/linkedin/authorize`,
  linkedinStatus: `${API_PREFIX}/auth/linkedin/status`,
  linkedinGenerateImage: `${API_PREFIX}/auth/linkedin/generate-image`,
  linkedinPost: `${API_PREFIX}/auth/linkedin/post`,
  linkedinDisconnect: `${API_PREFIX}/auth/linkedin/disconnect`,
  linkedinCallback: `${API_PREFIX}/auth/linkedin/callback`,
};

export const getFullUrl = (endpoint: string): string => {
  return `${API_BASE_URL}${endpoint}`;
};