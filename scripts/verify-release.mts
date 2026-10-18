import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const [baseline, runtime] = process.argv.slice(2);
if (!baseline || !runtime) throw new Error('Usage: node scripts/verify-release.mts baseline.zip fengari-module-path');
const require = createRequire(import.meta.url);
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(runtime);
function run(source: string): void {
    const state = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(state);
    try {
        const result = lauxlib.luaL_dostring(state, to_luastring('arg = {}\n' + source));
        if (result !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(state, -1)));
    } finally {
        lua.lua_close(state);
    }
}

let parity = 'ReferenceModules = {}\n';
for (const [reference, module] of Object.entries({ Store: 'State', Catalog: 'SpellCatalog', Engine: 'Tracker', Sources: 'Tracking' })) {
    const source = execFileSync('tar', ['-xOf', baseline, `Drpulse/Runtime/${module}.lua`], { encoding: 'utf8' });
    if (source.includes(']====]')) throw new Error('Unexpected Lua delimiter');
    parity += `ReferenceModules.${reference} = [====[${source}]====]\n`;
}
const modules = ['Drpulse/Drpulse.toc', 'Drpulse/Drpulse_Camelot.toc'].flatMap(path =>
    readFileSync(path, 'utf8').split(/\r?\n/).filter(line => !line.startsWith('#') && line.trim().endsWith('.lua'))
        .map(line => `Drpulse/${line.trim().replaceAll('\\', '/')}`));
parity += `TocModules = { ${modules.map(path => JSON.stringify(path)).join(', ')} }\n`;
console.log(`Enemy tracking parity baseline: ${baseline}`);
run(parity + readFileSync('tests/Runtime.spec.lua', 'utf8'));
for (const path of ['tests/Display.spec.lua', 'tests/ProfileTransfer.spec.lua', 'tests/Visibility.spec.lua']) {
    run(readFileSync(path, 'utf8'));
}
for (const path of ['tests/NameplatePlacement.spec.mts', 'tests/Player.spec.mts']) {
    execFileSync(process.execPath, [path, runtime], { stdio: 'inherit' });
}
