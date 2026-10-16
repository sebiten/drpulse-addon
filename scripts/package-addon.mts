import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const tocPaths = ['Drpulse/Drpulse.toc', 'Drpulse/Drpulse_Camelot.toc'];
const tocs = tocPaths.map(path => readFileSync(path, 'utf8'));
const version = tocs[0].match(/^## Version: ([\w.-]+)$/m)?.[1];
if (!version || !tocs[1].includes(`## Version: ${version}`)) throw new Error('TOC version mismatch');
const entries = new Set(tocPaths);
for (const toc of tocs) {
  for (const line of toc.split(/\r?\n/)) {
    if (line.trim().endsWith('.lua') && !line.startsWith('#')) entries.add(`Drpulse/${line.trim().replaceAll('\\', '/')}`);
  }
}
for (const file of ['LICENSE', 'THIRD-PARTY-LICENSE.txt', 'README.md', 'CHANGELOG.md', 'AUDIT.md']) entries.add(`Drpulse/${file}`);
for (const file of entries) {
  if (file.includes('..') || !existsSync(file)) throw new Error(`Invalid package entry: ${file}`);
}
mkdirSync('releases', { recursive: true });
const zip = `releases/Drpulse-${version}-Forever.zip`;
if (existsSync(zip)) throw new Error(`Refusing to overwrite ${zip}`);
execFileSync('tar', ['-a', '-cf', zip, ...entries]);
const actual = execFileSync('tar', ['-tf', zip], { encoding: 'utf8' }).trim().split(/\r?\n/);
if (actual.length !== entries.size || actual.some(path => !entries.has(path))) throw new Error('Archive manifest mismatch');
for (const file of entries) {
  const packaged = execFileSync('tar', ['-xOf', zip, file]);
  if (!packaged.equals(readFileSync(file))) throw new Error(`Archive content mismatch: ${file}`);
}
console.log(`${zip}: ${entries.size} files verified byte-for-byte`);
console.log(`SHA256 ${createHash('sha256').update(readFileSync(zip)).digest('hex')}`);
