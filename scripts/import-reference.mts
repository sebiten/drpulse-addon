import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

// Reproducible MIT-source import. Runtime behavior stays traceable to the ZIP;
// product integration lives separately in Integration.lua.
const archive = process.argv[2];
if (!archive) throw new Error('Pass the Forever DR reference ZIP path.');
const modules = {
  Store: 'State', Catalog: 'SpellCatalog', FlatMenu: 'Controls', Engine: 'Tracker',
  Sources: 'Tracking', Display: 'Display', PreviewKit: 'Preview', Settings: 'Settings', Core: 'Lifecycle',
};
const destination = resolve('Drpulse/Runtime');
if (existsSync(resolve(destination, 'Display.lua'))) {
  throw new Error('Initial import only: Runtime already exists and contains Drpulse customizations.');
}
mkdirSync(destination, { recursive: true });
for (const [original, renamed] of Object.entries(modules)) {
  let source = execFileSync('tar', ['-xOf', archive, `ForeverDR/${original}.lua`], { encoding: 'utf8' });
  source = source.replace(/ForeverDRDB/g, 'DrpulseV2DB')
    .replace(/FOREVERDR/g, 'DRPULSE').replace(/ForeverDR/g, 'Drpulse')
    .replace(/Forever DR/g, 'Drpulse').replace(/\/foreverdr\b/g, '/drpulse')
    .replace(/\/fdr\b/g, '/drpulse')
    .replace(/gold strip/g, 'blue strip');
  // Cosmetic accent only; semantic CC stage colors are retained.
  source = source.replace(/0\.95, 0\.76, 0\.35/g, '0.38, 0.85, 1.00')
    .replace(/0\.8, 0\.62, 0\.25/g, '0.24, 0.65, 0.82')
    .replace(/0\.24, 0\.20, 0\.12/g, '0.10, 0.20, 0.27')
    .replace(/\|cffffcc59/g, '|cff61dafb');
  source = source.replace('hover and 0.24 or 0.14, hover and 0.20 or 0.145, hover and 0.12 or 0.16',
    'hover and 0.10 or 0.10, hover and 0.20 or 0.13, hover and 0.27 or 0.17');
  if (original === 'Store') source = source.replace('ns.VERSION = "0.8.0"', 'ns.VERSION = "2.0.0-beta.5"');
  if (original === 'Core') {
    source = source.replace('ns.LoadSettings(DrpulseV2DB)', 'ns.LoadDrpulseSettings(DrpulseV2DB)')
      .replace('ns.BuildSettings()', 'ns.BuildSettings()\n        ns.StartDrpulseIntegration()');
  }
  const attribution = `-- Adapted from Forever DR ${original}.lua (MIT, Copyright 2026 Tarolg).\n-- Drpulse integration and visual adaptations: Copyright 2026 Joaqoz.\n`;
  writeFileSync(resolve(destination, `${renamed}.lua`), attribution + source);
}
writeFileSync(resolve('Drpulse/THIRD-PARTY-LICENSE.txt'), execFileSync('tar', ['-xOf', archive, 'ForeverDR/LICENSE']));
console.log('Imported 9 MIT modules and attribution.');
