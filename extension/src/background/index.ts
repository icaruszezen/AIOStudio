import { AIOStudioAPI } from '../shared/api';
import {
  AUTH_TOKEN_KEY,
  CONNECTION_STATUS_KEY,
  HEARTBEAT_ALARM_NAME,
  HEARTBEAT_INTERVAL_MIN,
  PORT_KEY,
} from '../shared/constants';
import type {
  ConnectionStatus,
  ContextMenuSavePayload,
  MediaItem,
  Message,
  SaveRequest,
} from '../shared/types';

const api = new AIOStudioAPI();

// ---------------------------------------------------------------------------
// Connection status (persisted to survive SW restarts)
// ---------------------------------------------------------------------------

async function getConnectionStatus(): Promise<ConnectionStatus> {
  const data = await chrome.storage.session.get(CONNECTION_STATUS_KEY);
  return (data[CONNECTION_STATUS_KEY] as ConnectionStatus) ?? 'disconnected';
}

async function setConnectionStatus(status: ConnectionStatus): Promise<void> {
  await chrome.storage.session.set({ [CONNECTION_STATUS_KEY]: status });
}

// ---------------------------------------------------------------------------
// Port & auth token initialization
// ---------------------------------------------------------------------------

async function loadConfig(): Promise<void> {
  const data = await chrome.storage.local.get([PORT_KEY, AUTH_TOKEN_KEY]);
  const port = data[PORT_KEY] as number | undefined;
  const token = data[AUTH_TOKEN_KEY] as string | undefined;
  if (port) api.setPort(port);
  if (token) api.setAuthToken(token);
}

const configReady = loadConfig();

chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== 'local') return;
  if (changes[PORT_KEY]?.newValue != null) {
    api.setPort(changes[PORT_KEY].newValue as number);
  }
  if (changes[AUTH_TOKEN_KEY] !== undefined) {
    api.setAuthToken((changes[AUTH_TOKEN_KEY].newValue as string) ?? null);
  }
});

// ---------------------------------------------------------------------------
// Context menus
// ---------------------------------------------------------------------------

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'save-image',
    title: '保存图片到 AIO Studio',
    contexts: ['image'],
  });

  chrome.contextMenus.create({
    id: 'save-video',
    title: '保存视频到 AIO Studio',
    contexts: ['video'],
  });

  chrome.contextMenus.create({
    id: 'save-link-media',
    title: '保存链接中的媒体到 AIO Studio',
    contexts: ['link'],
  });

  chrome.alarms.create(HEARTBEAT_ALARM_NAME, {
    periodInMinutes: HEARTBEAT_INTERVAL_MIN,
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  const srcUrl = info.srcUrl ?? info.linkUrl;
  if (!srcUrl || !tab?.id) return;

  const mediaType =
    info.menuItemId === 'save-video' ? 'video' : ('image' as const);

  try {
    await chrome.tabs.sendMessage(tab.id, {
      action: 'CONTEXT_MENU_SAVE',
      payload: {
        srcUrl,
        mediaType,
        pageUrl: tab.url ?? '',
        pageTitle: tab.title ?? '',
      } satisfies ContextMenuSavePayload,
    } satisfies Message<ContextMenuSavePayload>);
  } catch {
    // Content script not available on this tab (e.g. chrome:// pages)
  }
});

// ---------------------------------------------------------------------------
// Heartbeat (via chrome.alarms for SW lifecycle safety)
// ---------------------------------------------------------------------------

async function heartbeat(): Promise<void> {
  const prev = await getConnectionStatus();
  await setConnectionStatus('connecting');

  const ok = await api.checkConnection();
  const next: ConnectionStatus = ok ? 'connected' : 'disconnected';
  await setConnectionStatus(next);

  if (prev !== next) {
    broadcastConnectionStatus(next);
  }
}

function broadcastConnectionStatus(status: ConnectionStatus): void {
  chrome.runtime
    .sendMessage({
      action: 'CONNECTION_STATUS_CHANGED',
      payload: status,
    } satisfies Message<ConnectionStatus>)
    .catch(() => {});
}

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === HEARTBEAT_ALARM_NAME) {
    configReady.then(() => heartbeat()).catch(() => {});
  }
});

// ---------------------------------------------------------------------------
// Message handling
// ---------------------------------------------------------------------------

chrome.runtime.onMessage.addListener(
  (
    message: Message,
    _sender: chrome.runtime.MessageSender,
    sendResponse: (response: unknown) => void,
  ) => {
    configReady.then(() => handleMessage(message)).then(sendResponse);
    return true;
  },
);

async function handleMessage(message: Message): Promise<unknown> {
  switch (message.action) {
    case 'CHECK_CONNECTION': {
      const ok = await api.checkConnection();
      const status: ConnectionStatus = ok ? 'connected' : 'disconnected';
      await setConnectionStatus(status);
      return status;
    }

    case 'GET_CONNECTION_STATUS':
      return getConnectionStatus();

    case 'GET_PROJECTS':
      return api.getProjects();

    case 'SAVE_MEDIA':
      return api.saveMedia(message.payload as SaveRequest);

    case 'UPDATE_BADGE': {
      const items = message.payload as MediaItem[];
      const count = items.length;
      const text = count > 0 ? String(count) : '';
      await chrome.action.setBadgeText({ text });
      if (count > 0) {
        await chrome.action.setBadgeBackgroundColor({ color: '#0078D4' });
      }
      return true;
    }

    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------

configReady.then(async () => {
  heartbeat().catch(() => {});
  const existing = await chrome.alarms.get(HEARTBEAT_ALARM_NAME);
  if (!existing) {
    chrome.alarms.create(HEARTBEAT_ALARM_NAME, {
      periodInMinutes: HEARTBEAT_INTERVAL_MIN,
    });
  }
});
