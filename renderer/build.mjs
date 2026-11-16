// Builds the renderer into ../App/Resources/Renderer (committed; CI checks it is fresh).
import { build } from 'esbuild';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '..', 'App', 'Resources', 'Renderer');
await mkdir(out, { recursive: true });

await build({
    entryPoints: [join(here, 'src/preview.js')],
    outfile: join(out, 'preview.js'),
    bundle: true,
    minify: true,
    format: 'iife',
    target: ['safari16'],
    legalComments: 'none',
    // Mermaid lazy-loads diagram chunks; inline them so one file is enough.
    splitting: false,
    logLevel: 'info',
});

const light = await readFile(join(here, 'src/vendor/github-markdown-light.css'), 'utf8');
const dark = await readFile(join(here, 'src/vendor/github-markdown-dark_dimmed.css'), 'utf8');

// Preflight-free on purpose (see the upstream style.css): no reset, so lists
// and inline images keep browser defaults that github-markdown relies on.
const extra = `
/* p { margin: 1em } is a deliberate survivor from the web app: it gives
   paragraphs their side margins. Keep it a bare selector. */
p { margin: 1em; }
body { margin: 0; }
#output { box-sizing: border-box; min-height: 100vh; padding: 16px; }
.markdown-body .mermaid { overflow-x: auto; padding: 16px; text-align: center; }
.markdown-body .mermaid svg { display: block; max-width: 100%; height: auto; margin: 0 auto; }
.markdown-body .mermaid-error { color: #cf222e; white-space: pre-wrap; text-align: left; }
@media (prefers-color-scheme: dark) { .markdown-body .mermaid-error { color: #ff7b72; } }
`;

const css = `@media (prefers-color-scheme: light) {\n${light}\n}\n@media (prefers-color-scheme: dark) {\n${dark}\n}\n${extra}`;
await writeFile(join(out, 'preview.css'), css);
await writeFile(join(out, 'preview.html'), await readFile(join(here, 'src/preview.html'), 'utf8'));
