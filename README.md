# Markdown Preview (macOS)

A personal, native macOS port of the Markdown Live Preview web tool. Edit Markdown on the left, see the rendered result on the right.

- **Native editor** (NSTextView): monospaced, word wrap, undo, Find bar (Cmd+F), no smart-quote corruption.
- **Same renderer as the web tool**, running in a WKWebView: `marked` + `DOMPurify` + Mermaid + the GitHub Markdown stylesheets (light and dark dimmed, following the system appearance live).
- **Document based**: open and save `.md` files, multiple windows. Relative images (`![x](images/a.png)`) resolve next to the file.
- **Scratchpad** (Cmd+Shift+0): one autosaved buffer in `~/Library/Application Support/MarkdownPreview/scratchpad.md`, like the web app's saved buffer.
- Menu: Copy Markdown, Copy HTML, Export HTML, Sync Scroll, stacked/side-by-side layout, Reset to Sample.

Distribution is personal: ad-hoc signed, no sandbox, no notarization. Requires macOS 14+.

## Build and run

```bash
brew install xcodegen
xcodegen generate
open MarkdownPreview.xcodeproj
```

The Xcode project is generated from `project.yml` and is not committed. The first time you open a downloaded or CI-built app, right-click it and choose Open (it is not notarized).

Change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` if you want your own id.

## Renderer

The preview page lives in `renderer/` and is built into `App/Resources/Renderer/`, which **is committed**, so building the app needs no Node. After changing anything in `renderer/src`:

```bash
cd renderer                     # Node 26 (.nvmrc) and pnpm: `corepack enable`
pnpm install --frozen-lockfile
pnpm build
pnpm lint && pnpm format:check  # oxlint and oxfmt, settings from erakor/toolchain
pnpm exec playwright install webkit   # once
pnpm test:e2e                   # Playwright on WebKit, the engine WKWebView uses
```

CI rebuilds the bundle and fails if the committed copy is stale.

## CI

`.github/workflows/ci.yml` has three jobs: the renderer's lint and format checks (the shared job from erakor/toolchain), the renderer's build, bundle freshness and Playwright WebKit tests (Linux), and the app (`xcodegen`, `swift-format lint`, `xcodebuild build test` on macOS 15, with the built `.app` uploaded as an artifact). It can also be started by hand (`workflow_dispatch`).
