import { defineConfig } from '@playwright/test'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', 'App', 'Resources', 'Renderer')

// WebKit is the engine behind WKWebView and is what CI runs. Containers that
// only ship Chromium can run `npx playwright test --project=chromium`.
export default defineConfig({
  testDir: 'tests',
  webServer: {
    command: `npx http-server "${root}" -p 4173 -s -c-1`,
    url: 'http://localhost:4173/preview.html',
    reuseExistingServer: true,
  },
  use: { baseURL: 'http://localhost:4173' },
  projects: [
    { name: 'webkit', use: { browserName: 'webkit' } },
    {
      name: 'chromium',
      use: {
        browserName: 'chromium',
        launchOptions: { executablePath: process.env.CHROMIUM_PATH },
      },
    },
  ],
})
