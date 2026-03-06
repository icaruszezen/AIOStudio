import { useCallback, useEffect, useState } from 'react';
import type {
  ConnectionStatus,
  MediaItem,
  Message,
  Project,
  SaveRequest,
  SaveResponse,
  ScanPageResult,
} from '../shared/types';
import { DEFAULT_PORT, PORT_KEY } from '../shared/constants';
import { extractFilename } from '../shared/utils';

// ============================================================================
// App
// ============================================================================

export default function App() {
  const [status, setStatus] = useState<ConnectionStatus>('connecting');
  const [mediaItems, setMediaItems] = useState<MediaItem[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [projects, setProjects] = useState<Project[]>([]);
  const [projectId, setProjectId] = useState('');
  const [scanning, setScanning] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveProgress, setSaveProgress] = useState({ done: 0, total: 0 });
  const [saveResults, setSaveResults] = useState<SaveResponse[]>([]);
  const [showSettings, setShowSettings] = useState(false);
  const [port, setPort] = useState(DEFAULT_PORT);

  // Load port
  useEffect(() => {
    chrome.storage.local.get(PORT_KEY).then((data) => {
      if (data[PORT_KEY]) setPort(data[PORT_KEY] as number);
    });
  }, []);

  // Check connection
  useEffect(() => {
    chrome.runtime
      .sendMessage({ action: 'CHECK_CONNECTION' } satisfies Message)
      .then((result) => {
        setStatus(result as ConnectionStatus);
        if (result === 'connected') loadProjects();
      });

    const listener = (msg: Message) => {
      if (msg.action === 'CONNECTION_STATUS_CHANGED') {
        setStatus(msg.payload as ConnectionStatus);
      }
    };
    chrome.runtime.onMessage.addListener(listener);
    return () => chrome.runtime.onMessage.removeListener(listener);
  }, []);

  const loadProjects = useCallback(async () => {
    try {
      const list = (await chrome.runtime.sendMessage({
        action: 'GET_PROJECTS',
      } satisfies Message)) as Project[];
      setProjects(list ?? []);
    } catch {
      setProjects([]);
    }
  }, []);

  // Scan page
  const scanPage = useCallback(async () => {
    setScanning(true);
    setSaveResults([]);
    try {
      const [tab] = await chrome.tabs.query({
        active: true,
        currentWindow: true,
      });
      if (!tab?.id) return;

      const result = (await chrome.tabs.sendMessage(tab.id, {
        action: 'SCAN_PAGE',
      } satisfies Message)) as ScanPageResult;

      const items = result?.mediaItems ?? [];
      setMediaItems(items);
      setSelected(new Set(items.map((i) => i.url)));
    } catch {
      setMediaItems([]);
    } finally {
      setScanning(false);
    }
  }, []);

  // Selection
  const toggleSelect = (url: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(url)) next.delete(url);
      else next.add(url);
      return next;
    });
  };

  const selectAll = () => setSelected(new Set(mediaItems.map((i) => i.url)));
  const deselectAll = () => setSelected(new Set());

  // Batch save
  const batchSave = async () => {
    if (!projectId) return;
    const items = mediaItems.filter((i) => selected.has(i.url));
    if (items.length === 0) return;

    setSaving(true);
    setSaveProgress({ done: 0, total: items.length });
    setSaveResults([]);

    const requests: SaveRequest[] = items.map((item) => ({
      mediaUrl: item.url,
      mediaType: item.type,
      projectId,
      name: extractFilename(item.url),
      pageUrl: item.pageUrl,
      pageTitle: item.pageTitle,
    }));

    const results: SaveResponse[] = [];
    for (let i = 0; i < requests.length; i++) {
      const res = (await chrome.runtime.sendMessage({
        action: 'SAVE_MEDIA',
        payload: requests[i],
      } satisfies Message<SaveRequest>)) as SaveResponse;
      results.push(res);
      setSaveProgress({ done: i + 1, total: requests.length });
    }

    setSaveResults(results);
    setSaving(false);
  };

  // Settings: save port
  const savePort = async () => {
    await chrome.storage.local.set({ [PORT_KEY]: port });
    chrome.runtime
      .sendMessage({ action: 'CHECK_CONNECTION' } satisfies Message)
      .then((result) => setStatus(result as ConnectionStatus));
    setShowSettings(false);
  };

  // --------
  // Render
  // --------

  if (showSettings) {
    return (
      <div style={styles.container}>
        <Header />
        <div style={styles.section}>
          <h3 style={styles.sectionTitle}>设置</h3>
          <label style={styles.label}>通信端口</label>
          <input
            type="number"
            style={styles.input}
            value={port}
            min={1024}
            max={65535}
            onChange={(e) => setPort(Number(e.target.value))}
          />
          <div style={styles.actions}>
            <button style={styles.btnSecondary} onClick={() => setShowSettings(false)}>
              取消
            </button>
            <button style={styles.btnPrimary} onClick={savePort}>
              保存
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <Header />

      {/* Connection status */}
      <div style={styles.statusBar}>
        <span
          style={{
            ...styles.dot,
            background:
              status === 'connected' ? '#107C10' : status === 'connecting' ? '#FF8C00' : '#D13438',
          }}
        />
        <span>
          {status === 'connected' ? '已连接' : status === 'connecting' ? '连接中...' : '未连接'}
        </span>
      </div>

      {status === 'disconnected' && (
        <div style={styles.disconnected}>
          <p>无法连接到 AIO Studio 桌面应用。</p>
          <p style={{ marginTop: 8, fontSize: 12, color: '#666' }}>
            请确保 AIO Studio 已启动，且通信端口配置正确。
          </p>
        </div>
      )}

      {status === 'connected' && (
        <>
          {/* Scan */}
          <div style={styles.section}>
            <button
              style={styles.btnPrimary}
              onClick={scanPage}
              disabled={scanning}
            >
              {scanning ? '扫描中...' : '扫描当前页面'}
            </button>

            {mediaItems.length > 0 && (
              <div style={{ marginTop: 8, fontSize: 12, color: '#666' }}>
                检测到 {mediaItems.length} 个媒体文件
              </div>
            )}
          </div>

          {/* Media list */}
          {mediaItems.length > 0 && (
            <div style={styles.section}>
              <div style={styles.selectionBar}>
                <button style={styles.btnLink} onClick={selectAll}>
                  全选
                </button>
                <button style={styles.btnLink} onClick={deselectAll}>
                  取消全选
                </button>
                <span style={{ marginLeft: 'auto', fontSize: 12, color: '#666' }}>
                  已选 {selected.size}/{mediaItems.length}
                </span>
              </div>

              <div style={styles.mediaList}>
                {mediaItems.map((item) => (
                  <MediaRow
                    key={item.url}
                    item={item}
                    checked={selected.has(item.url)}
                    onToggle={() => toggleSelect(item.url)}
                  />
                ))}
              </div>

              {/* Project + save */}
              <label style={styles.label}>目标项目</label>
              <select
                style={styles.select}
                value={projectId}
                onChange={(e) => setProjectId(e.target.value)}
              >
                <option value="">-- 选择项目 --</option>
                {projects.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </select>

              <button
                style={{
                  ...styles.btnPrimary,
                  width: '100%',
                  marginTop: 8,
                  opacity: !projectId || selected.size === 0 || saving ? 0.5 : 1,
                }}
                disabled={!projectId || selected.size === 0 || saving}
                onClick={batchSave}
              >
                {saving
                  ? `保存中 (${saveProgress.done}/${saveProgress.total})`
                  : `批量保存选中项 (${selected.size})`}
              </button>

              {/* Results */}
              {saveResults.length > 0 && (
                <div style={{ marginTop: 8 }}>
                  <div style={{ fontSize: 12, color: '#107C10' }}>
                    成功：{saveResults.filter((r) => r.success).length}
                  </div>
                  {saveResults.some((r) => !r.success) && (
                    <div style={{ fontSize: 12, color: '#D13438' }}>
                      失败：{saveResults.filter((r) => !r.success).length}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}
        </>
      )}

      {/* Footer */}
      <div style={styles.footer}>
        <button style={styles.btnLink} onClick={() => setShowSettings(true)}>
          设置
        </button>
      </div>
    </div>
  );
}

// ============================================================================
// Sub-components
// ============================================================================

function Header() {
  return (
    <div style={styles.header}>
      <svg width="20" height="20" viewBox="0 0 24 24" fill="#0078D4">
        <path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z" />
      </svg>
      <span style={{ fontWeight: 600, fontSize: 14, marginLeft: 8 }}>AIO Studio Collector</span>
    </div>
  );
}

function MediaRow({
  item,
  checked,
  onToggle,
}: {
  item: MediaItem;
  checked: boolean;
  onToggle: () => void;
}) {
  const sizeStr = item.width && item.height ? `${item.width}×${item.height}` : '';
  const typeStr = item.type === 'image' ? '图片' : '视频';

  return (
    <label style={styles.mediaRow}>
      <input type="checkbox" checked={checked} onChange={onToggle} />
      {item.type === 'image' && !item.url.startsWith('data:') ? (
        <img
          src={item.url}
          alt=""
          style={styles.thumb}
          onError={(e) => ((e.target as HTMLImageElement).style.display = 'none')}
        />
      ) : (
        <div style={{ ...styles.thumb, background: '#e0e0e0', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, color: '#888' }}>
          {typeStr}
        </div>
      )}
      <div style={{ flex: 1, overflow: 'hidden' }}>
        <div style={{ fontSize: 12, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {extractFilename(item.url)}
        </div>
        <div style={{ fontSize: 11, color: '#888' }}>
          {typeStr} {sizeStr}
        </div>
      </div>
    </label>
  );
}

// ============================================================================
// Styles
// ============================================================================

const styles: Record<string, React.CSSProperties> = {
  container: {
    width: 360,
    fontFamily: "'Segoe UI', system-ui, sans-serif",
    fontSize: 13,
    color: '#1a1a1a',
    background: '#fafafa',
    minHeight: 200,
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    padding: '12px 16px',
    borderBottom: '1px solid #e8e8e8',
    background: '#fff',
  },
  statusBar: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    padding: '10px 16px',
    fontSize: 13,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: '50%',
    display: 'inline-block',
    flexShrink: 0,
  },
  disconnected: {
    padding: '12px 16px',
    fontSize: 13,
  },
  section: {
    padding: '8px 16px 12px',
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: 600,
    marginBottom: 8,
  },
  label: {
    display: 'block',
    fontSize: 12,
    color: '#444',
    marginBottom: 4,
    marginTop: 8,
  },
  input: {
    width: '100%',
    padding: '6px 8px',
    border: '1px solid #d0d0d0',
    borderRadius: 4,
    fontSize: 13,
    outline: 'none',
    boxSizing: 'border-box' as const,
  },
  select: {
    width: '100%',
    padding: '6px 8px',
    border: '1px solid #d0d0d0',
    borderRadius: 4,
    fontSize: 13,
    outline: 'none',
    boxSizing: 'border-box' as const,
  },
  btnPrimary: {
    padding: '7px 16px',
    border: 'none',
    borderRadius: 4,
    background: '#0078D4',
    color: '#fff',
    fontSize: 13,
    cursor: 'pointer',
  },
  btnSecondary: {
    padding: '7px 16px',
    border: '1px solid #d0d0d0',
    borderRadius: 4,
    background: '#fff',
    color: '#333',
    fontSize: 13,
    cursor: 'pointer',
  },
  btnLink: {
    background: 'none',
    border: 'none',
    color: '#0078D4',
    cursor: 'pointer',
    fontSize: 12,
    padding: '2px 4px',
  },
  actions: {
    display: 'flex',
    gap: 8,
    justifyContent: 'flex-end',
    marginTop: 12,
  },
  selectionBar: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    marginBottom: 8,
  },
  mediaList: {
    maxHeight: 260,
    overflowY: 'auto' as const,
    border: '1px solid #e8e8e8',
    borderRadius: 4,
    background: '#fff',
  },
  mediaRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    padding: '6px 8px',
    borderBottom: '1px solid #f0f0f0',
    cursor: 'pointer',
  },
  thumb: {
    width: 40,
    height: 40,
    objectFit: 'cover' as const,
    borderRadius: 4,
    flexShrink: 0,
  },
  footer: {
    padding: '8px 16px',
    borderTop: '1px solid #e8e8e8',
    display: 'flex',
    justifyContent: 'flex-end',
    background: '#fff',
  },
};
