export const DEFAULT_PORT = 52140;
export const BASE_URL_KEY = 'aio_studio_base_url';
export const PORT_KEY = 'aio_studio_port';
export const AUTH_TOKEN_KEY = 'aio_studio_auth_token';

export const API_PATHS = {
  HEALTH: '/api/health',
  PROJECTS: '/api/projects',
  IMPORT: '/api/assets/import-from-extension',
  BATCH_IMPORT: '/api/assets/batch-import',
} as const;

export const HEARTBEAT_INTERVAL_MS = 30_000;

export const SHORTCUT_REGION_CAPTURE = { alt: true, shift: true, key: 'S' };

export const MIN_MEDIA_SIZE = 50;

export function getBaseUrl(port: number = DEFAULT_PORT): string {
  return `http://localhost:${port}`;
}
