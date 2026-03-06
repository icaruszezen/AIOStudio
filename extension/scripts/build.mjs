import { build } from 'vite';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { copyFileSync, mkdirSync, existsSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');

// Build 1: Popup + Background (ESM, with code splitting)
await build({ configFile: resolve(root, 'vite.config.ts') });

// Build 2: Content Script (IIFE, self-contained, no ES module imports)
await build({ configFile: resolve(root, 'vite.config.content.ts') });

// Copy static files
const dist = resolve(root, 'dist');

copyFileSync(resolve(root, 'manifest.json'), resolve(dist, 'manifest.json'));

const distAssets = resolve(dist, 'assets');
if (!existsSync(distAssets)) mkdirSync(distAssets, { recursive: true });

const assetsDir = resolve(root, 'src/assets');
for (const icon of ['icon-16.png', 'icon-32.png', 'icon-48.png', 'icon-128.png']) {
  const src = resolve(assetsDir, icon);
  if (existsSync(src)) {
    copyFileSync(src, resolve(distAssets, icon));
  }
}

console.log('\n✓ Build complete. Load extension from dist/ directory.');
