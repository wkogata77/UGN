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
const page = await browser.newPage({ viewport: { width: 1440, height: 960 } });
const errors = [],
  results = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});
mkdirSync('test-results/depth-range', { recursive: true });
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
  for (const fixture of [
    { name: 'line-desktop', formation: 'line' },
    { name: 'reforming-desktop', formation: 'line', reforming: true },
    { name: 'column-desktop', formation: 'column' },
    { name: 'artillery-desktop', artillery: true },
    { name: 'line-mobile', formation: 'line', mobile: true },
    {
      name: 'square-rotated-mobile',
      formation: 'square',
      mobile: true,
      facing: -0.55,
    },
  ]) {
    await page.setViewportSize(
      fixture.mobile
        ? { width: 390, height: 844 }
        : { width: 1440, height: 960 },
    );
    await page.waitForTimeout(200);
    const result = await page.evaluate(async (fixture) => {
      const { formationFront } = await import('/src/demo/formationGeometry.js');
      const { model, renderer } = window.__depthDemo;
      const u = model.state.battle.units.find((u) =>
        fixture.artillery
          ? u.side === 'player' && u.kind === 'artillery'
          : u.id === 'u1',
      );
      Object.assign(u, {
        x: 450,
        y: 340,
        facing: fixture.facing || 0,
        formation: fixture.formation || 'line',
        formationChange: fixture.reforming
          ? { from: 'line', to: 'column', elapsed: 4, duration: 8 }
          : null,
      });
      model.state.selected = [u.id];
      renderer.center = { x: fixture.artillery ? 640 : 530, y: 360 };
      renderer.zoom = fixture.mobile ? 1.25 : fixture.artillery ? 1.2 : 2.1;
      renderer.updateCamera();
      const line = renderer.line,
        sides = [];
      renderer.line = function (points, color, ...rest) {
        if (color === '#b5d5d180') sides.push(structuredClone(points));
        return line.call(this, points, color, ...rest);
      };
      try {
        renderer.range(u);
      } finally {
        renderer.line = line;
      }
      renderer.showRanges = false;
      renderer.render(0);
      const before = renderer.ctx.getImageData(
        0,
        0,
        renderer.overlay.width,
        renderer.overlay.height,
      ).data;
      renderer.showRanges = true;
      renderer.render(0);
      const after = renderer.ctx.getImageData(
        0,
        0,
        renderer.overlay.width,
        renderer.overlay.height,
      ).data;
      let changed = 0;
      for (let i = 0; i < before.length; i += 4)
        if (
          Math.max(
            ...[0, 1, 2, 3].map((c) => Math.abs(before[i + c] - after[i + c])),
          ) > 10
        )
          changed++;
      return {
        name: fixture.name,
        front: formationFront(u),
        sides,
        changed,
        troops: renderer.stats.troops,
        overflow: document.documentElement.scrollWidth > innerWidth,
      };
    }, fixture);
    assert.equal(result.sides.length, 2);
    assert.deepEqual(result.sides[0][0], result.front.left);
    assert.deepEqual(result.sides[1][0], result.front.right);
    assert.ok(
      result.changed > 100,
      'the range overlay must change visible pixels',
    );
    assert.ok(
      result.troops > 100,
      'the formation renderer must remain populated',
    );
    assert.equal(result.overflow, false);
    await page.screenshot({
      path: `test-results/depth-range/${fixture.name}.png`,
    });
    results.push(result);
  }
  assert.deepEqual(errors, []);
  writeFileSync(
    'test-results/depth-range/verification.json',
    JSON.stringify({ results, errors }, null, 2),
  );
  console.log(
    `Range browser checks passed: ${results.length} desktop/mobile formation captures, edge anchors, overlay pixels, and no browser errors.`,
  );
} finally {
  await browser.close();
}
