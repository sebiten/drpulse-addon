import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const [archive, runtime] = process.argv.slice(2);
if (!archive || !runtime) throw new Error('Usage: verify-runtime.mts reference.zip fengari-module-path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(runtime);
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
let source = 'ReferenceModules = {}\n';
for (const name of ['Store', 'Catalog', 'Engine', 'Sources']) {
  const original = execFileSync('tar', ['-xOf', archive, `ForeverDR/${name}.lua`], { encoding: 'utf8' });
  if (original.includes(']====]')) throw new Error('Unexpected Lua delimiter');
  source += `ReferenceModules.${name} = [====[${original}]====]\n`;
}
const modules = ['Drpulse/Drpulse.toc', 'Drpulse/Drpulse_Camelot.toc'].flatMap(toc =>
  readFileSync(toc, 'utf8').split(/\r?\n/).filter(line => !line.startsWith('#') && line.trim().endsWith('.lua'))
    .map(line => `Drpulse/${line.trim().replaceAll('\\', '/')}`));
source += `TocModules = { ${modules.map(path => JSON.stringify(path)).join(', ')} }\n`;
source += readFileSync('tests/Runtime.spec.lua', 'utf8');
const result = lauxlib.luaL_dostring(state, to_luastring(source));
if (result !== lua.LUA_OK) {
  console.error(to_jsstring(lua.lua_tostring(state, -1)));
  process.exitCode = 1;
}
