import { AIOStudioAPI } from '../shared/api';
import {
  HEARTBEAT_INTERVAL_MS,
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
let connectionStatus: ConnectionStatus = 'disconnected';

// ---------------------------------------------------------------------------
// Port initialization
// ---------------------------------------------------------------------------

async function loadPort(): Promise<void> {
  const data = await chrome.storage.local.get(PORT_KEY);
  const port = data[PORT_KEY] as number | undefined;
  if (port) api.setPort(port);
}

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && changes[PORT_KEY]?.newValue != null) {
    api.setPort(changes[PORT_KEY].newValue as number);
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
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  const srcUrl = info.srcUrl ?? info.linkUrl;
  if (!srcUrl || !tab?.id) return;

  const mediaType =
    info.menuItemId === 'save-video' ? 'video' : ('image' as const);

  chrome.tabs.sendMessage(tab.id, {
    action: 'CONTEXT_MENU_SAVE',
    payload: {
      srcUrl,
      mediaType,
      pageUrl: tab.url ?? '',
      pageTitle: tab.title ?? '',
    } satisfies ContextMenuSavePayload,
  } satisfies Message<ContextMenuSavePayload>);
});

// ---------------------------------------------------------------------------
// Heartbeat
// ---------------------------------------------------------------------------

async function heartbeat(): Promise<void> {
  const prev = connectionStatus;
  connectionStatus = 'connecting';

  const ok = await api.checkConnection();
  connectionStatus = ok ? 'connected' : 'disconnected';

  if (prev !== connectionStatus) {
    broadcastConnectionStatus();
  }
}

function broadcastConnectionStatus(): void {
  chrome.runtime.sendMessage({
    action: 'CONNECTION_STATUS_CHANGED',
    payload: connectionStatus,
  } satisfies Message<ConnectionStatus>).catch(() => {});
}

// ---------------------------------------------------------------------------
// Message handling
// ---------------------------------------------------------------------------

chrome.runtime.onMessage.addListener(
  (
    message: Message,
    _sender: chrome.runtime.MessageSender,
    sendResponse: (response: unknown) => void,
  ) => {
    handleMessage(message).then(sendResponse);
    return true; // async response
  },
);

async function handleMessage(message: Message): Promise<unknown> {
  switch (message.action) {
    case 'CHECK_CONNECTION': {
      const ok = await api.checkConnection();
      connectionStatus = ok ? 'connected' : 'disconnected';
      return connectionStatus;
    }

    case 'GET_CONNECTION_STATUS':
      return connectionStatus;

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

loadPort().then(() => {
  heartbeat();
  setInterval(heartbeat, HEARTBEAT_INTERVAL_MS);
});

