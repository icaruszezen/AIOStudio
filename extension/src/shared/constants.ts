export const DEFAULT_PORT = 52140;
export const BASE_URL_KEY = 'aio_studio_base_url';
export const PORT_KEY = 'aio_studio_port';
export const AUTH_TOKEN_KEY = 'aio_studio_auth_token';
export const CONNECTION_STATUS_KEY = 'aio_connection_status';

export const API_PATHS = {
  HEALTH: '/api/health',
  PROJECTS: '/api/projects',
  IMPORT: '/api/assets/import-from-extension',
  BATCH_IMPORT: '/api/assets/batch-import',
} as const;

export const HEARTBEAT_ALARM_NAME = 'aio-heartbeat';
export const HEARTBEAT_INTERVAL_MIN = 1;

export const HEALTH_CHECK_TIMEOUT_MS = 5_000;
export const API_REQUEST_TIMEOUT_MS = 15_000;

export const SHORTCUT_REGION_CAPTURE = { alt: true, shift: true, key: 'S' };

export const MIN_MEDIA_SIZE = 50;
export const BG_IMAGE_SCAN_LIMIT = 500;

export function getBaseUrl(port: number = DEFAULT_PORT): string {
  return `http://localhost:${port}`;
}
