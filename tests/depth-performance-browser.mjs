import { chromium } from '@playwright/test';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';

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
page.setDefaultTimeout(60000);
const errors = [],
  results = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});
mkdirSync('test-results/depth-performance', { recursive: true });
try {
  await page.goto(process.env.DEMO_URL || 'http://localhost:5174/?demo=depth');
  await page.waitForFunction(
    () => window.__depthDemo?.renderer.stats.frames > 0,
  );
  await page.getByRole('button', { name: 'Battlefield', exact: true }).click();
  await page.waitForFunction(
    () =>
      window.__depthDemo?.model.state.mode === 'battle' &&
      window.__depthDemo.renderer.stats.frames > 0,
  );
  for (const scenario of (
    process.env.PERF_SCENARIOS || 'paused-desktop,march-desktop,march-mobile'
  ).split(',')) {
    await page.setViewportSize(
      scenario.endsWith('mobile')
        ? { width: 390, height: 844 }
        : { width: 1280, height: 800 },
    );
    await page.waitForTimeout(300);
    const result = await page.evaluate(async (scenario) => {
      const { model, renderer } = window.__depthDemo;
      const moving = scenario.startsWith('march');
      model.state.paused = !moving;
      if (moving) {
        model.state.selected = ['u1'];
        model.moveUnits({ x: 625, y: 320 });
      }
      const samples = {},
        originals = [];
      const wrap = (object, name, label = name) => {
        const original = object[name];
        object[name] = function (...args) {
          const start = performance.now();
          try {
            return original.apply(this, args);
          } finally {
            (samples[label] ||= []).push(performance.now() - start);
          }
        };
        originals.push(() => {
          object[name] = original;
        });
      };
      for (const name of [
        'ground',
        'populateTroops',
        'range',
        'drawFog',
        'drawLabels',
        'drawMinimap',
        'render',
      ])
        wrap(renderer, name);
      wrap(renderer.renderer, 'render', 'webgl');
      const frames = [];
      let previous = performance.now();
      for (let i = 0; i < 48; i++) {
        const now = await new Promise(requestAnimationFrame);
        if (i > 7) frames.push(now - previous);
        previous = now;
      }
      originals.forEach((restore) => restore());
      const stats = (values) => {
        const sorted = [...values].sort((a, b) => a - b);
        return {
          calls: values.length,
          mean: values.reduce((a, b) => a + b, 0) / values.length,
          median: sorted[Math.floor(sorted.length * 0.5)],
          p95: sorted[Math.floor(sorted.length * 0.95)],
        };
      };
      const result = {
        scenario,
        frame: stats(frames),
        stages: Object.fromEntries(
          Object.entries(samples).map(([key, values]) => [key, stats(values)]),
        ),
        triangles: renderer.renderer.info.render.triangles,
        drawCalls: renderer.renderer.info.render.calls,
        troops: renderer.stats.troops,
        moving: renderer.stats.animation.moving,
        meshes: renderer.troops.map((mesh) => ({
          count: mesh.count,
          vertices: mesh.geometry.attributes.position.count,
        })),
      };
      model.state.paused = true;
      return result;
    }, scenario);
    results.push(result);
    console.log(JSON.stringify(result));
  }
  assert.deepEqual(errors, []);
  const label = process.env.PERF_LABEL || 'current';
  writeFileSync(
    `test-results/depth-performance/${label}.json`,
    JSON.stringify(
      {
        note: 'Controlled Chromium SwiftShader comparison; not a real-device FPS claim.',
        results,
        errors,
      },
      null,
      2,
    ),
  );
} finally {
  await browser.close();
}
