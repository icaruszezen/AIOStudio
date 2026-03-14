import type { Project, SaveRequest, SaveResponse } from './types';
import { API_PATHS, DEFAULT_PORT, getBaseUrl } from './constants';

function extractFileName(url: string): string {
  try {
    const pathname = new URL(url).pathname;
    const segments = pathname.split('/');
    const raw = segments[segments.length - 1] || 'untitled';
    return decodeURIComponent(raw);
  } catch {
    return 'untitled';
  }
}

export class AIOStudioAPI {
  private baseUrl: string;
  private authToken: string | null = null;

  constructor(port: number = DEFAULT_PORT) {
    this.baseUrl = getBaseUrl(port);
  }

  setPort(port: number): void {
    this.baseUrl = getBaseUrl(port);
  }

  setAuthToken(token: string | null): void {
    this.authToken = token;
  }

  private getAuthHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (this.authToken) {
      headers['Authorization'] = `Bearer ${this.authToken}`;
    }
    return headers;
  }

  async checkConnection(): Promise<boolean> {
    try {
      const res = await fetch(`${this.baseUrl}${API_PATHS.HEALTH}`, {
        method: 'GET',
        signal: AbortSignal.timeout(5000),
      });
      return res.ok;
    } catch {
      return false;
    }
  }

  async getProjects(): Promise<Project[]> {
    const res = await fetch(`${this.baseUrl}${API_PATHS.PROJECTS}`, {
      method: 'GET',
      headers: this.getAuthHeaders(),
    });
    if (!res.ok) throw new Error(`获取项目列表失败: ${res.status}`);
    return res.json();
  }

  async saveMedia(request: SaveRequest): Promise<SaveResponse> {
    try {
      const fileName = request.fileName ?? extractFileName(request.mediaUrl);

      const res = await fetch(`${this.baseUrl}${API_PATHS.IMPORT}`, {
        method: 'POST',
        headers: this.getAuthHeaders(),
        body: JSON.stringify({
          mediaUrl: request.mediaUrl,
          mediaType: request.mediaType,
          fileName,
          projectId: request.projectId,
          name: request.name,
          pageUrl: request.pageUrl,
          pageTitle: request.pageTitle,
        }),
      });

      if (!res.ok) {
        const text = await res.text();
        return { success: false, error: text || `HTTP ${res.status}` };
      }

      const data = await res.json();
      return { success: true, assetId: data.assetId };
    } catch (err) {
      return {
        success: false,
        error: err instanceof Error ? err.message : '保存失败',
      };
    }
  }
}
