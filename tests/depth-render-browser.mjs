import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';

const executable =
  '/tmp/field-command-browsers/chromium-1243/chrome-linux64/chrome';
const libs =
  '/tmp/field-command-browser-libs/extracted/usr/lib/x86_64-linux-gnu';
const browser = await chromium.launch({
  executablePath:
    process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ||
    (existsSync(executable) ? executable : undefined),
  headless: true,
  args: [
    '--no-sandbox',
    '--use-angle=swiftshader',
    '--enable-unsafe-swiftshader',
  ],
  env: {
    ...process.env,
    ...(existsSync(libs)
      ? { LD_LIBRARY_PATH: `${libs}:${process.env.LD_LIBRARY_PATH || ''}` }
      : {}),
  },
});
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
const errors = [],
  results = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});
mkdirSync('test-results/depth-render', { recursive: true });
try {
  await page.goto(process.env.DEMO_URL || 'http://localhost:5174/?demo=depth');
  await page.waitForFunction(
    () => window.__depthDemo?.renderer.stats.frames > 0,
  );
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);
  const before = await page.evaluate(
    () => window.__depthDemo.renderer.stats.frames,
  );
  await page.waitForTimeout(500);
  assert.equal(
    await page.evaluate(() => window.__depthDemo.renderer.stats.frames),
    before,
    'paused scenes must not redraw without a change',
  );
  await page.getByRole('button', { name: 'Zoom in', exact: true }).click();
  await page.waitForFunction(
    (before) => window.__depthDemo.renderer.stats.frames > before,
    before,
  );
  for (const mode of ['campaign', 'battle']) {
    if (mode === 'battle') {
      await page.evaluate(() => {
        window.__previousDepth = window.__depthDemo;
      });
      await page
        .getByRole('button', { name: 'Battlefield', exact: true })
        .click();
      await page.waitForFunction(
        () =>
          window.__depthDemo?.model.state.mode === 'battle' &&
          window.__depthDemo.renderer.stats.frames > 0,
      );
      assert.deepEqual(
        await page.evaluate(() => {
          const previous = window.__previousDepth;
          delete window.__previousDepth;
          return {
            disposed: previous.renderer.disposed,
            listeners: previous.model.listeners.size,
          };
        }),
        { disposed: true, listeners: 0 },
        'switching maps must dispose the old renderer and its subscriptions',
      );
    }
    for (const mobile of [false, true]) {
      await page.setViewportSize(
        mobile ? { width: 390, height: 844 } : { width: 1280, height: 800 },
      );
      await page.waitForTimeout(200);
      const result = await page.evaluate(() => {
        const r = window.__depthDemo.renderer;
        const canvas = document.createElement('canvas');
        canvas.width = r.renderer.domElement.width;
        canvas.height = r.renderer.domElement.height;
        const ctx = canvas.getContext('2d');
        const capture = () => {
          r.render(0);
          ctx.drawImage(r.renderer.domElement, 0, 0);
          return ctx.getImageData(0, 0, canvas.width, canvas.height).data;
        };
        r.staticPass.enabled = false;
        const reference = capture();
        r.staticPass.enabled = true;
        r.staticPass.invalidate();
        const cached = capture();
        let sum = 0,
          changed = 0,
          total = 0;
        for (let i = 0; i < reference.length; i += 4) {
          const error = Math.max(
            ...[0, 1, 2].map((c) => Math.abs(reference[i + c] - cached[i + c])),
          );
          sum += error;
          if (error > 12) changed++;
          total++;
        }
        const captures = r.staticPass.captures;
        const ground = r.ground;
        let queries = 0;
        r.ground = function (...args) {
          queries++;
          return ground.apply(this, args);
        };
        r.render(0);
        r.render(0);
        const steadyQueries = queries,
          steadyCaptures = r.staticPass.captures - captures;
        r.center.x += 40;
        r.updateCamera();
        r.render(0);
        r.ground = ground;
        const cameraCaptures = r.staticPass.captures - captures;
        const details = [];
        for (const zoom of [0.65, 2.7]) {
          r.zoom = zoom;
          r.updateCamera();
          r.render(0);
          details.push(r.troops[0].geometry.attributes.position.count);
        }
        r.home();
        r.render(0);
        const reliefCaptures = r.staticPass.captures;
        const memory = [];
        for (let cycle = 0; cycle < 3; cycle++) {
          for (const relief of [false, true]) {
            r.setRelief(relief);
            r.render(0);
          }
          memory.push({ ...r.renderer.info.memory });
        }
        return {
          meanPixelError: sum / total,
          changedRatio: changed / total,
          steadyQueries,
          cameraQueries: queries - steadyQueries,
          steadyCaptures,
          cameraCaptures,
          reliefCaptures: r.staticPass.captures - reliefCaptures,
          memory,
          details,
          emptyVisible: r.troops.filter((mesh) => !mesh.count && mesh.visible)
            .length,
        };
      });
      results.push({ mode, mobile, ...result });
      writeFileSync(
        'test-results/depth-render/verification.json',
        JSON.stringify({ results, errors }, null, 2),
      );
      assert.ok(
        result.meanPixelError < 3,
        `${mode}: cached landscape changed its appearance (${result.meanPixelError})`,
      );
      assert.ok(
        result.changedRatio < 0.06,
        `${mode}: cached terrain depth/color mismatch (${result.changedRatio})`,
      );
      assert.equal(result.steadyQueries, 0);
      assert.equal(result.steadyCaptures, 0);
      assert.equal(result.cameraQueries, 4);
      assert.equal(result.cameraCaptures, 1);
      assert.equal(result.reliefCaptures, 6);
      assert.deepEqual(result.memory[2], result.memory[0]);
      assert.ok(result.details[1] > result.details[0]);
      assert.equal(result.emptyVisible, 0);
      await page.screenshot({
        path: `test-results/depth-render/${mode}-${mobile ? 'mobile' : 'desktop'}.png`,
      });
    }
  }
  assert.deepEqual(errors, []);
  console.log(JSON.stringify(results, null, 2));
} finally {
  await browser.close();
}
