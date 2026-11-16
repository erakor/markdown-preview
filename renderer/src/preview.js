import { marked } from 'marked';
import DOMPurify from 'dompurify';
import mermaid from 'mermaid';

// Renderer for the macOS app's WKWebView. Port of the render pipeline in
// understood/markdown-preview src/main.js. Two invariants carry over:
//  1. Sanitization is not optional: marked output ALWAYS goes through DOMPurify.
//  2. mermaidRenderVersion cancels stale Mermaid renders.

const output = document.getElementById('output');
const darkQuery = window.matchMedia('(prefers-color-scheme: dark)');

const post = (message) => {
    const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.bridge;
    if (handler) {
        handler.postMessage(message);
    }
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

const getMermaidTheme = () => (darkQuery.matches ? 'dark' : 'default');

const configureMermaid = (theme) => {
    mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme });
};

const showMermaidError = (element, error) => {
    const message = error && error.message ? error.message : 'Unable to render Mermaid chart.';
    element.classList.add('mermaid-error');
    element.textContent = `Mermaid render error: ${message}`;
};

const renderMermaidPass = async (theme) => {
    const version = ++mermaidRenderVersion;
    configureMermaid(theme);

    const elements = Array.from(output.querySelectorAll('.mermaid'));
    for (const [index, element] of elements.entries()) {
        if (version !== mermaidRenderVersion) {
            return;
        }

        const source = element.dataset.mermaidSource || element.textContent;
        element.dataset.mermaidSource = source;
        element.classList.remove('mermaid-error');

        try {
            const renderId = `mermaid-${Date.now()}-${version}-${index}`;
            const { svg, bindFunctions } = await mermaid.render(renderId, source);
            if (version !== mermaidRenderVersion) {
                return;
            }
            element.innerHTML = svg;
            if (typeof bindFunctions === 'function') {
                bindFunctions(element);
            }
        } catch (error) {
            showMermaidError(element, error);
        }
    }
};

const renderMermaidDiagramsNow = (theme = getMermaidTheme()) => {
    mermaidInflight = renderMermaidPass(theme);
    return mermaidInflight;
};

const scheduleMermaidRender = () => {
    if (mermaidRenderTimer) {
        clearTimeout(mermaidRenderTimer);
    }
    mermaidRenderTimer = setTimeout(() => {
        mermaidRenderTimer = null;
        renderMermaidDiagramsNow();
    }, 150);
};

const renderMermaidDiagrams = () => {
    if (mermaidRenderTimer) {
        clearTimeout(mermaidRenderTimer);
        mermaidRenderTimer = null;
    }
    return renderMermaidDiagramsNow();
};

// The stylesheet follows the OS via media queries; only Mermaid, which bakes
// colours into its SVG, needs a redraw.
darkQuery.addEventListener('change', () => renderMermaidDiagrams());

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

const getHTML = () => output.innerHTML;

window.renderMarkdown = renderMarkdown;
window.setScrollRatio = setScrollRatio;
window.getHTML = getHTML;
// Resolves once every pending Mermaid render has finished (used by tests/export).
window.whenIdle = async () => {
    if (mermaidRenderTimer) {
        await renderMermaidDiagrams();
    } else {
        await mermaidInflight;
    }
};

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

window.addEventListener('scroll', () => {
    const el = document.scrollingElement || document.documentElement;
    const max = el.scrollHeight - el.clientHeight;
    post({ type: 'scroll', ratio: max > 0 ? el.scrollTop / max : 0 });
}, { passive: true });

post({ type: 'ready' });
