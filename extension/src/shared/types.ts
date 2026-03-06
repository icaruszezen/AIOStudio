export interface MediaItem {
  url: string;
  type: 'image' | 'video';
  width: number;
  height: number;
  alt?: string;
  duration?: number;
  pageUrl: string;
  pageTitle: string;
}

export interface SaveRequest {
  mediaUrl: string;
  mediaType: 'image' | 'video';
  projectId: string;
  name: string;
  pageUrl: string;
  pageTitle: string;
}

export interface SaveResponse {
  success: boolean;
  assetId?: string;
  error?: string;
}

export interface Project {
  id: string;
  name: string;
}

export type ConnectionStatus = 'connected' | 'disconnected' | 'connecting';

export type MessageAction =
  | 'CHECK_CONNECTION'
  | 'GET_PROJECTS'
  | 'SAVE_MEDIA'
  | 'SCAN_PAGE'
  | 'SCAN_PAGE_RESULT'
  | 'GET_CONNECTION_STATUS'
  | 'CONNECTION_STATUS_CHANGED'
  | 'UPDATE_BADGE'
  | 'CONTEXT_MENU_SAVE';

export interface Message<T = unknown> {
  action: MessageAction;
  payload?: T;
}

export interface ScanPageResult {
  mediaItems: MediaItem[];
}

export interface ContextMenuSavePayload {
  srcUrl: string;
  mediaType: 'image' | 'video';
  pageUrl: string;
  pageTitle: string;
}
