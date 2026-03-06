import type { Project, SaveRequest, SaveResponse } from './types';
import { API_PATHS, DEFAULT_PORT, getBaseUrl } from './constants';

export class AIOStudioAPI {
  private baseUrl: string;

  constructor(port: number = DEFAULT_PORT) {
    this.baseUrl = getBaseUrl(port);
  }

  setPort(port: number): void {
    this.baseUrl = getBaseUrl(port);
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
      headers: { 'Content-Type': 'application/json' },
    });
    if (!res.ok) throw new Error(`获取项目列表失败: ${res.status}`);
    return res.json();
  }

  async saveMedia(request: SaveRequest): Promise<SaveResponse> {
    try {
      const mediaBlob = await this.downloadMedia(request.mediaUrl);
      const formData = new FormData();
      formData.append('file', mediaBlob, request.name);
      formData.append('mediaType', request.mediaType);
      formData.append('projectId', request.projectId);
      formData.append('name', request.name);
      formData.append('pageUrl', request.pageUrl);
      formData.append('pageTitle', request.pageTitle);
      formData.append('sourceUrl', request.mediaUrl);

      const res = await fetch(`${this.baseUrl}${API_PATHS.IMPORT}`, {
        method: 'POST',
        body: formData,
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

  private async downloadMedia(url: string): Promise<Blob> {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`下载媒体失败: ${res.status}`);
    return res.blob();
  }
}
