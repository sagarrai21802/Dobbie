import apiClient from './api';
import { API_CONFIG } from './api-config';

export interface GeneratePostRequest {
  topic: string;
}

export interface GeneratePostResponse {
  content: string;
}

export interface ResearchTopicResponse {
  topic: string;
  content: string;
}

class GeminiService {
  async generateLinkedInPost(topic: string): Promise<string> {
    const response = await apiClient.post<GeneratePostResponse>(API_CONFIG.generatePost, {
      topic,
    });
    return response.content;
  }

  async generateResearchTopics(): Promise<ResearchTopicResponse[]> {
    const response = await apiClient.post<ResearchTopicResponse[]>(API_CONFIG.researchTopics, {});
    return response;
  }
}

export const geminiService = new GeminiService();
export default geminiService;