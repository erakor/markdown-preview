import { test, expect } from '@playwright/test'

const SIMPLE_MERMAID = '```mermaid\ngraph TD\n  A-->B\n```'

const render = async (page, md) => {
  await page.evaluate((m) => window.renderMarkdown(m), md)
}

test.beforeEach(async ({ page }) => {
  await page.goto('/preview.html')
  await page.waitForFunction(() => typeof window.renderMarkdown === 'function')
})

test('renders headings and tables', async ({ page }) => {
  await render(page, '# Title\n\n| a | b |\n|---|---|\n| 1 | 2 |\n')
  await expect(page.locator('#output h1')).toHaveText('Title')
  await expect(page.locator('#output table td').first()).toHaveText('1')
})

test('re-renders on every call (live typing)', async ({ page }) => {
  await render(page, '# One')
  await render(page, '# Two')
  await expect(page.locator('#output h1')).toHaveText('Two')
})

test('sanitizes <img onerror> and script tags', async ({ page }) => {
  const alerts = []
  page.on('dialog', async (d) => {
    alerts.push(d.message())
    await d.dismiss()
  })
  await render(
    page,
    '<img src=x onerror=alert(1)>\n\n<script>alert(2)</script>\n\n[x](javascript:alert(3))',
  )
  await page.evaluate(() => window.whenIdle())
  expect(alerts).toEqual([])
  expect(await page.locator('#output [onerror]').count()).toBe(0)
  expect(await page.locator('#output script').count()).toBe(0)
  expect(await page.locator('#output a[href^="javascript"]').count()).toBe(0)
})

test('mermaid fence becomes an svg', async ({ page }) => {
  await render(page, SIMPLE_MERMAID)
  await expect(page.locator('#output .mermaid svg')).toBeVisible({ timeout: 10000 })
})

test('mermaid errors are shown, not thrown', async ({ page }) => {
  await render(page, '```mermaid\nnot a diagram !!!\n```')
  await expect(page.locator('#output .mermaid-error')).toBeVisible({ timeout: 10000 })
})

test('mermaid source is escaped, not parsed as HTML', async ({ page }) => {
  await render(page, '```mermaid\ngraph TD\n  A["<b>x</b>"]-->B\n```')
  await expect(page.locator('#output .mermaid')).toHaveCount(1)
  expect(await page.locator('#output pre.mermaid > b').count()).toBe(0)
})

test('stale mermaid renders are cancelled', async ({ page }) => {
  await render(page, '```mermaid\ngraph TD\n  OLD-->X\n```')
  await render(page, '```mermaid\ngraph TD\n  NEW-->Y\n```')
  await expect(page.locator('#output .mermaid svg')).toBeVisible({ timeout: 10000 })
  await page.evaluate(() => window.whenIdle())
  expect(await page.locator('#output .mermaid svg').count()).toBe(1)
  const text = await page.locator('#output .mermaid').innerText()
  expect(text).toContain('NEW')
  expect(text).not.toContain('OLD')
})

test('list bullets and inline images keep browser defaults (no Preflight)', async ({ page }) => {
  await render(
    page,
    '* a\n* b\n\n1. x\n2. y\n\ntext ![i](data:image/gif;base64,R0lGODlhAQABAAAAACw=) more',
  )
  expect(
    await page.locator('#output ul').evaluate((el) => getComputedStyle(el).listStyleType),
  ).toBe('disc')
  expect(
    await page.locator('#output ol').evaluate((el) => getComputedStyle(el).listStyleType),
  ).toBe('decimal')
  expect(await page.locator('#output img').evaluate((el) => getComputedStyle(el).display)).toBe(
    'inline',
  )
})

test('follows the OS colour scheme via CSS', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light' })
  const lightBg = await page
    .locator('#output')
    .evaluate((el) => getComputedStyle(el).backgroundColor)
  await page.emulateMedia({ colorScheme: 'dark' })
  const darkBg = await page
    .locator('#output')
    .evaluate((el) => getComputedStyle(el).backgroundColor)
  expect(lightBg).toBe('rgb(255, 255, 255)')
  expect(darkBg).toBe('rgb(33, 40, 48)')
})

test('mermaid redraws when the scheme changes', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light' })
  await render(page, SIMPLE_MERMAID)
  await expect(page.locator('#output .mermaid svg')).toBeVisible({ timeout: 10000 })
  const before = await page.locator('#output .mermaid').innerHTML()
  await page.emulateMedia({ colorScheme: 'dark' })
  await expect
    .poll(async () => page.locator('#output .mermaid').innerHTML(), { timeout: 10000 })
    .not.toBe(before)
})

test('setScrollRatio scrolls proportionally and tolerates out-of-range ratios', async ({
  page,
}) => {
  await page.setViewportSize({ width: 600, height: 300 })
  await render(page, Array.from({ length: 80 }, (_, i) => `line ${i}\n`).join('\n'))
  await page.evaluate(() => window.setScrollRatio(0.5))
  const half = await page.evaluate(() => {
    const el = document.scrollingElement
    return el.scrollTop / (el.scrollHeight - el.clientHeight)
  })
  expect(half).toBeGreaterThan(0.45)
  expect(half).toBeLessThan(0.55)
  await page.evaluate(() => window.setScrollRatio(5))
  const end = await page.evaluate(() => {
    const el = document.scrollingElement
    return Math.abs(el.scrollTop - (el.scrollHeight - el.clientHeight))
  })
  expect(end).toBeLessThan(2)
})

test('setBaseHref rewrites how relative images resolve', async ({ page }) => {
  await page.evaluate(() => window.setBaseHref(new URL('/docs/', location.href).href))
  await render(page, '![x](images/a.png)')
  expect(await page.locator('#output img').evaluate((el) => el.src)).toBe(
    new URL('/docs/images/a.png', page.url()).href,
  )
})

test('whenIdle resolves only after mermaid has drawn', async ({ page }) => {
  await render(page, SIMPLE_MERMAID)
  const html = await page.evaluate(async () => {
    await window.whenIdle()
    return window.getHTML()
  })
  expect(html).toContain('<svg')
})

test('in-page anchors scroll instead of navigating, even with a base href', async ({ page }) => {
  await page.setViewportSize({ width: 600, height: 300 })
  await page.evaluate(() => window.setBaseHref(new URL('/docs/', location.href).href))
  const filler = Array.from({ length: 60 }, (_, i) => `line ${i}\n`).join('\n')
  await render(
    page,
    `[go](#my-section)\n\n${filler}\n\n<h2 id="my-section">Target</h2>\n\n${filler}`,
  )
  const before = page.url()
  await page.locator('#output a', { hasText: 'go' }).click()
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(100)
  expect(page.url()).toBe(before)
})

test('unchanged mermaid diagrams are redrawn from cache after an edit', async ({ page }) => {
  await render(page, SIMPLE_MERMAID)
  await page.evaluate(() => window.whenIdle())
  await render(page, `${SIMPLE_MERMAID}\n\nmore text`)
  await expect(page.locator('#output .mermaid svg')).toBeVisible({ timeout: 10000 })
  await page.evaluate(() => window.whenIdle())
  expect(await page.locator('#output .mermaid svg').count()).toBe(1)
})

test('cached diagrams are back in the DOM synchronously after an edit', async ({ page }) => {
  await render(page, SIMPLE_MERMAID)
  await page.evaluate(() => window.whenIdle())
  const hasSvg = await page.evaluate((m) => {
    window.renderMarkdown(`${m}\n\nmore text`)
    return !!document.querySelector('#output .mermaid svg') // no waiting for the 150 ms timer
  }, SIMPLE_MERMAID)
  expect(hasSvg).toBe(true)
})

test('a bare # link scrolls to the top', async ({ page }) => {
  await page.setViewportSize({ width: 600, height: 300 })
  const filler = Array.from({ length: 60 }, (_, i) => `line ${i}\n`).join('\n')
  await render(page, `[top](#)\n\n${filler}`)
  await page.evaluate(() => window.scrollTo(0, 500))
  await page.locator('#output a', { hasText: 'top' }).scrollIntoViewIfNeeded()
  await page.evaluate(() => document.querySelector('#output a').click())
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(0)
})
