export function extractFilename(url: string): string {
  try {
    if (url.startsWith('data:')) return '截图';
    const pathname = new URL(url).pathname;
    const segments = pathname.split('/');
    return segments[segments.length - 1] || 'untitled';
  } catch {
    return 'untitled';
  }
}
