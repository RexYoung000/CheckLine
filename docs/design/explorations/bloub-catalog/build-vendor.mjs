// Node 24+. No package install; types are erased without changing animation logic.
import { stripTypeScriptTypes } from 'node:module';
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
const root = new URL('./vendor/', import.meta.url);
for (const name of readdirSync(root).filter(n => n.endsWith('.ts'))) {
 const source = readFileSync(new URL(name, root), 'utf8');
 const js = stripTypeScriptTypes(source, { mode: 'strip' })
  .replace(/from '(\.\/[^']+)'/g, "from '$1.mjs'");
 writeFileSync(new URL(name.replace(/\.ts$/, '.mjs'), root), '// Generated from upstream MIT source; see ../NOTICE.md.\n' + js);
}
