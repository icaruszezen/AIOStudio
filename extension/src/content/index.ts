import html2canvas from 'html2canvas';
import type {
  ContextMenuSavePayload,
  MediaItem,
  Message,
  Project,
  SaveRequest,
  SaveResponse,
} from '../shared/types';
import { BG_IMAGE_SCAN_LIMIT, MIN_MEDIA_SIZE, SHORTCUT_REGION_CAPTURE } from '../shared/constants';
import { extractFilename } from '../shared/utils';

// ============================================================================
// Shadow DOM host
// ============================================================================

const HOST_ID = 'aio-studio-collector-host';

function getOrCreateHost(): ShadowRoot {
  let host = document.getElementById(HOST_ID);
  if (host?.shadowRoot) return host.shadowRoot;

  host = document.createElement('div');
  host.id = HOST_ID;
  host.style.cssText = 'all:initial;position:absolute;top:0;left:0;z-index:2147483647;pointer-events:none;';
  document.body.appendChild(host);

  const shadow = host.attachShadow({ mode: 'open' });
  shadow.innerHTML = `<style>${getStyles()}</style>`;
  return shadow;
}

// ============================================================================
// Styles (injected into Shadow DOM)
// ============================================================================

function getStyles(): string {
  return `
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }

    .aio-save-btn {
      position: fixed;
      width: 32px; height: 32px;
      border-radius: 50%;
      background: rgba(0,120,212,0.7);
      border: none;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      pointer-events: auto;
      transition: opacity .2s, transform .15s;
      opacity: 0.6;
      z-index: 2147483647;
      box-shadow: 0 2px 8px rgba(0,0,0,.25);
    }
    .aio-save-btn:hover { opacity: 1; transform: scale(1.1); }
    .aio-save-btn svg { width: 18px; height: 18px; fill: #fff; }

    .aio-panel {
      position: fixed;
      width: 320px;
      background: #fff;
      border-radius: 8px;
      box-shadow: 0 8px 32px rgba(0,0,0,.18);
      padding: 16px;
      pointer-events: auto;
      z-index: 2147483647;
      color: #1a1a1a;
      font-size: 13px;
    }
    .aio-panel-header {
      display: flex; align-items: center; justify-content: space-between;
      margin-bottom: 12px;
    }
    .aio-panel-header h3 { font-size: 14px; font-weight: 600; }
    .aio-panel-close {
      width: 24px; height: 24px; border: none; background: none;
      cursor: pointer; border-radius: 4px; font-size: 16px; color: #666;
      pointer-events: auto;
    }
    .aio-panel-close:hover { background: #f0f0f0; }

    .aio-panel-preview {
      width: 100%; max-height: 160px; object-fit: contain;
      border-radius: 4px; background: #f5f5f5; margin-bottom: 10px;
    }
    .aio-panel-info { font-size: 12px; color: #666; margin-bottom: 10px; word-break: break-all; }

    .aio-panel label { display: block; font-size: 12px; color: #444; margin-bottom: 4px; }
    .aio-panel select, .aio-panel input[type="text"] {
      width: 100%; padding: 6px 8px; border: 1px solid #d0d0d0;
      border-radius: 4px; font-size: 13px; margin-bottom: 10px;
      outline: none;
    }
    .aio-panel select:focus, .aio-panel input:focus { border-color: #0078D4; }

    .aio-panel-actions { display: flex; gap: 8px; justify-content: flex-end; }
    .aio-btn-primary {
      padding: 6px 16px; border: none; border-radius: 4px;
      background: #0078D4; color: #fff; font-size: 13px;
      cursor: pointer; pointer-events: auto;
    }
    .aio-btn-primary:hover { background: #106EBE; }
    .aio-btn-primary:disabled { background: #ccc; cursor: not-allowed; }

    .aio-status { margin-top: 8px; font-size: 12px; padding: 6px 8px; border-radius: 4px; }
    .aio-status.success { background: #DFF6DD; color: #107C10; }
    .aio-status.error { background: #FDE7E9; color: #D13438; }

    .aio-region-overlay {
      position: fixed; inset: 0;
      background: rgba(0,0,0,.3);
      cursor: crosshair;
      pointer-events: auto;
      z-index: 2147483647;
    }
    .aio-region-selection {
      position: fixed;
      border: 2px solid #0078D4;
      background: rgba(0,120,212,.08);
      z-index: 2147483647;
      pointer-events: none;
    }
    .aio-region-hint {
      position: fixed; top: 16px; left: 50%; transform: translateX(-50%);
      background: rgba(0,0,0,.75); color: #fff; padding: 8px 20px;
      border-radius: 6px; font-size: 13px; z-index: 2147483647;
      pointer-events: none;
    }
  `;
}

// ============================================================================
// SVG icon
// ============================================================================

const AIO_ICON_SVG = `<svg viewBox="0 0 24 24"><path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/></svg>`;

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// ============================================================================
// Media detection
// ============================================================================

function detectMedia(): MediaItem[] {
  const items: MediaItem[] = [];
  const seen = new Set<string>();

  const add = (item: MediaItem) => {
    if (seen.has(item.url) || !item.url) return;
    seen.add(item.url);
    items.push(item);
  };

  // <img>
  document.querySelectorAll('img').forEach((img) => {
    if (img.naturalWidth < MIN_MEDIA_SIZE || img.naturalHeight < MIN_MEDIA_SIZE) return;
    add({
      url: img.src || img.currentSrc,
      type: 'image',
      width: img.naturalWidth,
      height: img.naturalHeight,
      alt: img.alt,
      pageUrl: location.href,
      pageTitle: document.title,
    });
  });

  // <picture> / <source>
  document.querySelectorAll('picture source').forEach((source) => {
    const srcset = source.getAttribute('srcset');
    if (!srcset) return;
    const url = srcset.split(',')[0].trim().split(/\s+/)[0];
    if (!url) return;
    add({
      url: new URL(url, location.href).href,
      type: 'image',
      width: 0,
      height: 0,
      pageUrl: location.href,
      pageTitle: document.title,
    });
  });

  // CSS background-image (scoped to common container elements with a scan limit)
  const bgCandidates = document.querySelectorAll(
    'div, section, header, footer, main, aside, article, figure, span, a',
  );
  const bgScanCount = Math.min(bgCandidates.length, BG_IMAGE_SCAN_LIMIT);
  for (let i = 0; i < bgScanCount; i++) {
    const el = bgCandidates[i] as HTMLElement;
    const bg = getComputedStyle(el).backgroundImage;
    if (!bg || bg === 'none') continue;
    const match = bg.match(/url\(["']?(.+?)["']?\)/);
    if (!match) continue;
    const url = match[1];
    if (url.startsWith('data:')) continue;
    const rect = el.getBoundingClientRect();
    if (rect.width < MIN_MEDIA_SIZE || rect.height < MIN_MEDIA_SIZE) continue;
    add({
      url: new URL(url, location.href).href,
      type: 'image',
      width: Math.round(rect.width),
      height: Math.round(rect.height),
      pageUrl: location.href,
      pageTitle: document.title,
    });
  }

  // <video>
  document.querySelectorAll('video').forEach((video) => {
    const src = video.src || video.querySelector('source')?.src;
    if (!src) return;
    add({
      url: src,
      type: 'video',
      width: video.videoWidth || video.clientWidth,
      height: video.videoHeight || video.clientHeight,
      duration: isNaN(video.duration) ? undefined : video.duration,
      pageUrl: location.href,
      pageTitle: document.title,
    });
  });

  // YouTube iframes
  document.querySelectorAll('iframe').forEach((iframe) => {
    const src = iframe.src;
    if (!src) return;
    const ytMatch = src.match(/(?:youtube\.com\/embed|youtu\.be)\/([^?&#]+)/);
    if (ytMatch) {
      add({
        url: `https://www.youtube.com/watch?v=${ytMatch[1]}`,
        type: 'video',
        width: iframe.clientWidth,
        height: iframe.clientHeight,
        pageUrl: location.href,
        pageTitle: document.title,
      });
    }
  });

  return items;
}

// ============================================================================
// Floating save button
// ============================================================================

let currentBtn: HTMLButtonElement | null = null;
let currentPanel: HTMLDivElement | null = null;
let currentTarget: HTMLElement | null = null;

function showSaveButton(target: HTMLElement, mediaItem: MediaItem): void {
  if (currentPanel) return;
  if (currentTarget === target) return;

  removeSaveButton();
  currentTarget = target;

  const shadow = getOrCreateHost();
  const btn = document.createElement('button');
  btn.className = 'aio-save-btn';
  btn.innerHTML = AIO_ICON_SVG;

  const rect = target.getBoundingClientRect();
  btn.style.top = `${rect.top + 6}px`;
  btn.style.left = `${rect.right - 38}px`;

  btn.addEventListener('click', (e) => {
    e.stopPropagation();
    e.preventDefault();
    showSavePanel(mediaItem);
  });

  shadow.appendChild(btn);
  currentBtn = btn;
}

function removeSaveButton(): void {
  currentBtn?.remove();
  currentBtn = null;
  currentTarget = null;
}

// ============================================================================
// Save panel
// ============================================================================

let panelProjects: Project[] = [];

async function showSavePanel(item: MediaItem): Promise<void> {
  removeSaveButton();
  if (currentPanel) {
    currentPanel.remove();
    currentPanel = null;
  }

  const shadow = getOrCreateHost();
  const panel = document.createElement('div');
  panel.className = 'aio-panel';
  panel.style.top = '50%';
  panel.style.left = '50%';
  panel.style.transform = 'translate(-50%, -50%)';

  const filename = extractFilename(item.url);

  try {
    const projects = await chrome.runtime.sendMessage({
      action: 'GET_PROJECTS',
    } satisfies Message);
    panelProjects = (projects as Project[]) || [];
  } catch {
    panelProjects = [];
  }

  const projectOptions = panelProjects
    .map((p) => `<option value="${escapeHtml(p.id)}">${escapeHtml(p.name)}</option>`)
    .join('');

  const escapedUrl = escapeHtml(item.url);
  const previewTag =
    item.type === 'video'
      ? `<video class="aio-panel-preview" src="${escapedUrl}" controls muted></video>`
      : `<img class="aio-panel-preview" src="${escapedUrl}" alt="预览"/>`;

  const sizeInfo = item.width && item.height ? `${item.width} x ${item.height}` : '未知';

  panel.innerHTML = `
    <div class="aio-panel-header">
      <h3>保存到 AIO Studio</h3>
      <button class="aio-panel-close" data-action="close">&times;</button>
    </div>
    ${previewTag}
    <div class="aio-panel-info">
      <div>类型：${item.type === 'image' ? '图片' : '视频'} · 尺寸：${sizeInfo}</div>
      <div style="margin-top:4px;max-height:32px;overflow:hidden;text-overflow:ellipsis">${escapedUrl}</div>
    </div>
    <label>目标项目</label>
    <select data-field="project">
      <option value="">-- 选择项目 --</option>
      ${projectOptions}
    </select>
    <label>资产名称</label>
    <input type="text" data-field="name" value="${escapeHtml(filename)}"/>
    <div class="aio-panel-actions">
      <button class="aio-btn-primary" data-action="save">保存</button>
    </div>
    <div class="aio-status" style="display:none" data-el="status"></div>
  `;

  panel.querySelector('[data-action="close"]')!.addEventListener('click', () => {
    panel.remove();
    currentPanel = null;
  });

  panel.querySelector('[data-action="save"]')!.addEventListener('click', async () => {
    const projectSelect = panel.querySelector('[data-field="project"]') as HTMLSelectElement;
    const nameInput = panel.querySelector('[data-field="name"]') as HTMLInputElement;
    const statusEl = panel.querySelector('[data-el="status"]') as HTMLDivElement;
    const saveBtn = panel.querySelector('[data-action="save"]') as HTMLButtonElement;

    if (!projectSelect.value) {
      statusEl.textContent = '请选择目标项目';
      statusEl.className = 'aio-status error';
      statusEl.style.display = 'block';
      return;
    }

    saveBtn.disabled = true;
    saveBtn.textContent = '保存中...';

    const request: SaveRequest = {
      mediaUrl: item.url,
      mediaType: item.type,
      projectId: projectSelect.value,
      name: nameInput.value || filename,
      pageUrl: item.pageUrl,
      pageTitle: item.pageTitle,
    };

    const response = (await chrome.runtime.sendMessage({
      action: 'SAVE_MEDIA',
      payload: request,
    } satisfies Message<SaveRequest>)) as SaveResponse;

    if (response?.success) {
      statusEl.textContent = '保存成功！';
      statusEl.className = 'aio-status success';
    } else {
      statusEl.textContent = `保存失败：${response?.error ?? '未知错误'}`;
      statusEl.className = 'aio-status error';
    }
    statusEl.style.display = 'block';
    saveBtn.disabled = false;
    saveBtn.textContent = '保存';
  });

  shadow.appendChild(panel);
  currentPanel = panel;
}

// ============================================================================
// Hover listener for media elements
// ============================================================================

function getMediaItemFromElement(el: HTMLElement): MediaItem | null {
  if (el instanceof HTMLImageElement) {
    if (el.naturalWidth < MIN_MEDIA_SIZE || el.naturalHeight < MIN_MEDIA_SIZE) return null;
    return {
      url: el.src || el.currentSrc,
      type: 'image',
      width: el.naturalWidth,
      height: el.naturalHeight,
      alt: el.alt,
      pageUrl: location.href,
      pageTitle: document.title,
    };
  }

  if (el instanceof HTMLVideoElement) {
    const src = el.src || el.querySelector('source')?.src;
    if (!src) return null;
    return {
      url: src,
      type: 'video',
      width: el.videoWidth || el.clientWidth,
      height: el.videoHeight || el.clientHeight,
      duration: isNaN(el.duration) ? undefined : el.duration,
      pageUrl: location.href,
      pageTitle: document.title,
    };
  }

  return null;
}

document.addEventListener(
  'mouseover',
  (e) => {
    const target = e.target as HTMLElement;
    const item = getMediaItemFromElement(target);
    if (item) {
      showSaveButton(target, item);
    }
  },
  true,
);

document.addEventListener(
  'mouseout',
  (e) => {
    const target = e.target as HTMLElement;
    const related = e.relatedTarget as HTMLElement | null;

    if (currentTarget === target) {
      const host = document.getElementById(HOST_ID);
      if (related && (host?.contains(related) || host?.shadowRoot?.contains(related))) {
        return;
      }
      removeSaveButton();
    }
  },
  true,
);

// Reposition the save button on scroll (throttled via rAF)
let scrollRAF: number | null = null;

function updateSaveButtonPosition(): void {
  if (!currentBtn || !currentTarget) return;
  const rect = currentTarget.getBoundingClientRect();
  currentBtn.style.top = `${rect.top + 6}px`;
  currentBtn.style.left = `${rect.right - 38}px`;
}

document.addEventListener(
  'scroll',
  () => {
    if (!currentBtn || !currentTarget) return;
    if (scrollRAF) return;
    scrollRAF = requestAnimationFrame(() => {
      updateSaveButtonPosition();
      scrollRAF = null;
    });
  },
  { capture: true, passive: true },
);

// ============================================================================
// Region capture mode (Alt+Shift+S)
// ============================================================================

let isCapturing = false;

document.addEventListener('keydown', (e) => {
  if (
    e.altKey === SHORTCUT_REGION_CAPTURE.alt &&
    e.shiftKey === SHORTCUT_REGION_CAPTURE.shift &&
    e.key.toUpperCase() === SHORTCUT_REGION_CAPTURE.key &&
    !isCapturing
  ) {
    e.preventDefault();
    startRegionCapture();
  }
});

function startRegionCapture(): void {
  isCapturing = true;
  const shadow = getOrCreateHost();

  const overlay = document.createElement('div');
  overlay.className = 'aio-region-overlay';

  const hint = document.createElement('div');
  hint.className = 'aio-region-hint';
  hint.textContent = '拖拽选择区域 · ESC 取消';

  const selection = document.createElement('div');
  selection.className = 'aio-region-selection';
  selection.style.display = 'none';

  shadow.appendChild(overlay);
  shadow.appendChild(hint);
  shadow.appendChild(selection);

  let startX = 0;
  let startY = 0;
  let isDragging = false;

  const cleanup = () => {
    overlay.remove();
    hint.remove();
    selection.remove();
    isCapturing = false;
  };

  const onKeyDown = (ev: KeyboardEvent) => {
    if (ev.key === 'Escape') {
      cleanup();
      document.removeEventListener('keydown', onKeyDown, true);
    }
  };
  document.addEventListener('keydown', onKeyDown, true);

  overlay.addEventListener('mousedown', (ev) => {
    startX = ev.clientX;
    startY = ev.clientY;
    isDragging = true;
    selection.style.display = 'block';
    selection.style.left = `${startX}px`;
    selection.style.top = `${startY}px`;
    selection.style.width = '0';
    selection.style.height = '0';
  });

  overlay.addEventListener('mousemove', (ev) => {
    if (!isDragging) return;
    const x = Math.min(ev.clientX, startX);
    const y = Math.min(ev.clientY, startY);
    const w = Math.abs(ev.clientX - startX);
    const h = Math.abs(ev.clientY - startY);
    selection.style.left = `${x}px`;
    selection.style.top = `${y}px`;
    selection.style.width = `${w}px`;
    selection.style.height = `${h}px`;
  });

  overlay.addEventListener('mouseup', async (ev) => {
    if (!isDragging) return;
    isDragging = false;

    const x = Math.min(ev.clientX, startX);
    const y = Math.min(ev.clientY, startY);
    const w = Math.abs(ev.clientX - startX);
    const h = Math.abs(ev.clientY - startY);

    cleanup();
    document.removeEventListener('keydown', onKeyDown, true);

    if (w < 10 || h < 10) return;

    try {
      const canvas = await html2canvas(document.body, {
        x: x + window.scrollX,
        y: y + window.scrollY,
        width: w,
        height: h,
        useCORS: true,
      });
      const useJpeg = w * h > 500_000;
      const dataUrl = canvas.toDataURL(
        useJpeg ? 'image/jpeg' : 'image/png',
        useJpeg ? 0.85 : undefined,
      );

      const item: MediaItem = {
        url: dataUrl,
        type: 'image',
        width: w,
        height: h,
        alt: '区域截图',
        pageUrl: location.href,
        pageTitle: document.title,
      };
      showSavePanel(item);
    } catch (err) {
      console.error('[AIO Studio] 截图失败:', err);
    }
  });
}

// ============================================================================
// Message listener (from background / popup)
// ============================================================================

chrome.runtime.onMessage.addListener(
  (
    message: Message,
    _sender: chrome.runtime.MessageSender,
    sendResponse: (response: unknown) => void,
  ) => {
    if (message.action === 'SCAN_PAGE') {
      const items = detectMedia();
      sendResponse({ mediaItems: items });

      chrome.runtime.sendMessage({
        action: 'UPDATE_BADGE',
        payload: items,
      } satisfies Message<MediaItem[]>).catch(() => {});
    }

    if (message.action === 'CONTEXT_MENU_SAVE') {
      const payload = message.payload as ContextMenuSavePayload;
      showSavePanel({
        url: payload.srcUrl,
        type: payload.mediaType,
        width: 0,
        height: 0,
        pageUrl: payload.pageUrl,
        pageTitle: payload.pageTitle,
      });
    }

    return false;
  },
);

// ============================================================================
// Initial badge update
// ============================================================================

window.addEventListener('load', () => {
  setTimeout(() => {
    const items = detectMedia();
    chrome.runtime
      .sendMessage({
        action: 'UPDATE_BADGE',
        payload: items,
      } satisfies Message<MediaItem[]>)
      .catch(() => {});
  }, 1500);
});
