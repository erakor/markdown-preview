import { marked } from 'marked';
import DOMPurify from 'dompurify';
import mermaid from 'mermaid';

// Renderer for the macOS app's WKWebView. Port of the render pipeline in
// understood/markdown-preview src/main.js. Two invariants carry over:
//  1. Sanitization is not optional: marked output ALWAYS goes through DOMPurify.
//  2. mermaidRenderVersion cancels stale Mermaid renders.

const output = document.getElementById('output');
const darkQuery = window.matchMedia('(prefers-color-scheme: dark)');

// Handler name must match PreviewBridge.handlerName in App/PreviewBridge.swift.
const post = (message) => {
    window.webkit?.messageHandlers?.bridge?.postMessage(message);
};

const escapeHtml = (value) => value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const createMarkedRenderer = () => {
    const renderer = new marked.Renderer();
    const renderCode = renderer.code.bind(renderer);

    renderer.code = (token) => {
        const lang = (token.lang || '').match(/^\S*/)?.[0].toLowerCase();
        if (lang !== 'mermaid') {
            return renderCode(token);
        }
        return `<pre class="mermaid">${escapeHtml(token.text)}</pre>\n`;
    };

    return renderer;
};

marked.use({ renderer: createMarkedRenderer() });

// ----- Mermaid -----

let mermaidRenderTimer = null;
let mermaidRenderVersion = 0;
// Promise of the most recent Mermaid pass, so callers (export, tests) can wait for it.
let mermaidInflight = Promise.resolve();
let configuredTheme = null;

// Every edit replaces innerHTML, which wipes drawn diagrams. Finished SVGs are
// kept by (theme, source) so an unchanged diagram is not laid out again.
const SVG_CACHE_LIMIT = 50;
const svgCache = new Map();

const getMermaidTheme = () => (darkQuery.matches ? 'dark' : 'default');

const showMermaidError = (element, error) => {
    const message = error && error.message ? error.message : 'Unable to render Mermaid chart.';
    element.classList.add('mermaid-error');
    element.textContent = `Mermaid render error: ${message}`;
};

const renderMermaidPass = async () => {
    const version = ++mermaidRenderVersion;
    const theme = getMermaidTheme();
    if (theme !== configuredTheme) {
        mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme });
        configuredTheme = theme;
    }

    const elements = Array.from(output.querySelectorAll('.mermaid'));
    for (const [index, element] of elements.entries()) {
        if (version !== mermaidRenderVersion) {
            return;
        }

        const source = element.dataset.mermaidSource || element.textContent;
        element.dataset.mermaidSource = source;
        element.classList.remove('mermaid-error');

        const key = `${theme}\u0000${source}`;
        const cached = svgCache.get(key);
        if (cached) {
            element.innerHTML = cached.svg;
            cached.bindFunctions?.(element);
            continue;
        }

        try {
            const renderId = `mermaid-${Date.now()}-${version}-${index}`;
            const { svg, bindFunctions } = await mermaid.render(renderId, source);
            if (version !== mermaidRenderVersion) {
                return;
            }
            svgCache.set(key, { svg, bindFunctions });
            if (svgCache.size > SVG_CACHE_LIMIT) {
                svgCache.delete(svgCache.keys().next().value);
            }
            element.innerHTML = svg;
            bindFunctions?.(element);
        } catch (error) {
            showMermaidError(element, error);
        }
    }
};

// Runs a pass now, replacing any pending scheduled one.
const startMermaid = () => {
    clearTimeout(mermaidRenderTimer);
    mermaidRenderTimer = null;
    mermaidInflight = renderMermaidPass();
    return mermaidInflight;
};

const scheduleMermaidRender = () => {
    clearTimeout(mermaidRenderTimer);
    mermaidRenderTimer = setTimeout(startMermaid, 150);
};

// The stylesheet follows the OS via media queries; only Mermaid, which bakes
// colours into its SVG, needs a redraw.
darkQuery.addEventListener('change', startMermaid);

// ----- public API -----

const renderMarkdown = (markdown) => {
    const html = marked.parse(markdown);
    output.innerHTML = DOMPurify.sanitize(html);
    scheduleMermaidRender();
};

const setScrollRatio = (ratio) => {
    const el = document.scrollingElement || document.documentElement;
    const max = el.scrollHeight - el.clientHeight;
    window.scrollTo(0, max * Math.min(1, Math.max(0, ratio)));
};

window.renderMarkdown = renderMarkdown;
window.setScrollRatio = setScrollRatio;
window.getHTML = () => output.innerHTML;
// Resolves once every pending Mermaid render has finished (used by tests/export).
window.whenIdle = () => (mermaidRenderTimer ? startMermaid() : mermaidInflight);

// Relative links and images resolve against the open document's folder; the
// app points this at mdpreview://doc/ (see LocalFileSchemeHandler).
window.setBaseHref = (href) => {
    let base = document.querySelector('base');
    if (!base) {
        base = document.createElement('base');
        document.head.prepend(base);
    }
    base.href = href;
};

// With a <base> tag, "#section" would resolve to another URL and navigate
// away, so in-page anchors are handled here instead.
output.addEventListener('click', (event) => {
    const link = event.target.closest?.('a[href^="#"]');
    if (!link) {
        return;
    }
    event.preventDefault();
    const raw = link.getAttribute('href').slice(1);
    let id = raw;
    try {
        id = decodeURIComponent(raw);
    } catch {
        // keep the raw fragment
    }
    (document.getElementById(id) || document.getElementsByName(id)[0])?.scrollIntoView();
});

post({ type: 'ready' });
