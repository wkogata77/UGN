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
const errors = [],
  results = [];
const url = process.env.DEMO_URL || 'http://localhost:5174/?demo=depth';
mkdirSync('test-results/depth', { recursive: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 960 } });
page.setDefaultTimeout(30000);
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});
const ready = async (mode) => {
  await page.waitForFunction(
    (mode) =>
      window.__depthDemo?.renderer.stats.frames > 0 &&
      (!mode || window.__depthDemo.model.state.mode === mode),
    mode,
  );
  await page.evaluate(() => document.fonts.ready);
};
const state = () =>
  page.evaluate(() => structuredClone(window.__depthDemo.model.state));
const point = (x, y) =>
  page.evaluate(
    ({ x, y }) => {
      const p = window.__depthDemo.renderer.project(x, y, 0),
        r = document.querySelector('.depth-map').getBoundingClientRect();
      return { x: p.x + r.left, y: p.y + r.top };
    },
    { x, y },
  );
const unitPoint = (id) =>
  page.evaluate((id) => {
    const renderer = window.__depthDemo.renderer,
      label = renderer.labels.find((l) => l.id === id);
    const u = renderer.entities().find((u) => u.id === id),
      p = label
        ? { x: label.x + label.w / 2, y: label.y + 10 }
        : renderer.project(u.x, u.y, 10);
    const r = document.querySelector('.depth-map').getBoundingClientRect();
    return { x: p.x + r.left, y: p.y + r.top };
  }, id);
const click = async (p, options) => page.mouse.click(p.x, p.y, options);
const snapshot = async (name) => {
  await page.mouse.move(0, 0);
  await page.waitForTimeout(180);
  const png = await page.screenshot({ path: `test-results/depth/${name}.png` });
  const stats = await page.evaluate(async (data) => {
    const image = new Image();
    image.src = `data:image/png;base64,${data}`;
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = image.width;
    canvas.height = image.height;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(image, 0, 0);
    const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
    const colors = new Set();
    let pink = 0,
      opaque = 0,
      total = 0;
    for (let y = 200; y < canvas.height - 120; y += 3)
      for (let x = 5; x < canvas.width - 5; x += 3) {
        const i = (y * canvas.width + x) * 4;
        colors.add(
          `${pixels[i] >> 4},${pixels[i + 1] >> 4},${pixels[i + 2] >> 4}`,
        );
        if (pixels[i] > 170 && pixels[i + 1] < 115 && pixels[i + 2] > 150)
          pink++;
        if (pixels[i + 3] === 255) opaque++;
        total++;
      }
    const renderer = window.__depthDemo.renderer;
    return {
      colors: colors.size,
      pink,
      opaque: opaque / total,
      troops: renderer.stats.troops,
      drawCalls: renderer.stats.drawCalls,
      overflow: document.documentElement.scrollWidth > innerWidth,
      covered: [
        [1, 1],
        [renderer.width - 1, 1],
        [1, renderer.height - 1],
        [renderer.width - 1, renderer.height - 1],
      ].every(([x, y]) => !!renderer.ground({ x, y })),
    };
  }, png.toString('base64'));
  assert.ok(stats.colors > 70, `${name}: blank or insufficiently varied map`);
  assert.ok(stats.opaque > 0.99, `${name}: transparent frame`);
  assert.ok(
    stats.pink < 15,
    `${name}: chroma-key matte leaking (${stats.pink})`,
  );
  assert.equal(stats.overflow, false, `${name}: horizontal overflow`);
  assert.equal(
    stats.covered,
    true,
    `${name}: camera shows outside the terrain`,
  );
  results.push({ name, ...stats });
  return png;
};

try {
  await page.goto(url);
  await ready('campaign');
  await page.evaluate(() =>
    localStorage.setItem('field-command-save', 'demo-save-isolation-sentinel'),
  );
  await page.reload();
  await ready('campaign');
  assert.equal((await state()).speed, 0.5);
  await snapshot('campaign-1440');
  await click(await unitPoint('army'));
  assert.ok(
    await page.getByLabel('Unit information', { exact: true }).isVisible(),
  );
  await click(await point(460, 730));
  assert.equal(
    (await state()).army.path.length,
    0,
    'left inspection must not order a march',
  );
  await click(await point(460, 730), { button: 'right' });
  assert.ok((await state()).army.path.length > 0);
  const before = (await state()).army.x;
  await page.getByRole('button', { name: 'Resume time', exact: true }).click();
  await page.waitForFunction(
    (before) => window.__depthDemo.model.state.army.x > before + 3,
    before,
  );
  await page.getByRole('button', { name: 'Pause time', exact: true }).click();
  await page
    .getByRole('button', { name: 'Army headquarters', exact: true })
    .click();
  assert.ok(
    await page.getByRole('dialog', { name: 'Army headquarters' }).isVisible(),
  );
  await page
    .getByRole('dialog')
    .getByRole('button', { name: 'Close', exact: true })
    .click();
  await page.getByRole('button', { name: 'Battlefield', exact: true }).click();
  await ready('battle');
  await snapshot('battle-1440');
  await click(await unitPoint('u1'));
  assert.deepEqual((await state()).selected, ['u1']);
  await page
    .getByRole('button', { name: 'Column formation', exact: true })
    .click();
  let unit = (await state()).battle.units.find((u) => u.id === 'u1');
  assert.ok(unit.formationChange && unit.formationChange.elapsed === 0);
  const beforeMoving = await snapshot('formation-start');
  await click(await point(580, 320), { button: 'right' });
  const initialX = unit.x;
  await page.getByRole('button', { name: 'Resume time', exact: true }).click();
  await page.waitForFunction(
    (x) =>
      window.__depthDemo.model.state.battle.units.find((u) => u.id === 'u1').x >
      x + 2,
    initialX,
  );
  await page.getByRole('button', { name: 'Pause time', exact: true }).click();
  unit = (await state()).battle.units.find((u) => u.id === 'u1');
  assert.ok(unit.formationChange.elapsed > 0);
  const afterMoving = await snapshot('formation-moving');
  assert.notDeepEqual(
    beforeMoving,
    afterMoving,
    'moving scene must change pixels',
  );
  const enemy = (await state()).battle.units.find(
    (u) => u.side === 'enemy' && u.visible,
  );
  const enemyPoint = await unitPoint(enemy.id);
  await page.mouse.move(enemyPoint.x, enemyPoint.y);
  assert.ok(
    (
      await page.locator('.depth-world').evaluate((c) => c.style.cursor)
    ).includes('data:image/svg'),
  );
  await click(enemyPoint);
  assert.deepEqual((await state()).selected, ['u1']);
  assert.ok(
    (
      await page.getByLabel('Unit information', { exact: true }).textContent()
    ).includes(enemy.name),
  );
  await click(enemyPoint, { button: 'right' });
  assert.equal(
    (await state()).battle.units.find((u) => u.id === 'u1').attackId,
    enemy.id,
  );
  await page
    .getByRole('button', { name: 'Close unit information', exact: true })
    .click();
  await page
    .getByRole('button', { name: 'Select army general', exact: true })
    .click();
  assert.equal((await state()).selectedCommander, 'general');
  await click(await point(410, 455), { button: 'right' });
  assert.ok(
    (await state()).battle.commanders.find((c) => c.id === 'general').target,
  );
  await page
    .getByRole('button', { name: 'Select supply train', exact: true })
    .click();
  assert.equal((await state()).selectedSupply, true);

  for (const viewport of [
    { width: 1920, height: 1080 },
    { width: 2560, height: 1080 },
    { width: 768, height: 1024 },
    { width: 390, height: 844 },
    { width: 360, height: 800 },
  ]) {
    await page.setViewportSize(viewport);
    await page.waitForTimeout(200);
    await snapshot(`battle-${viewport.width}`);
    await page.evaluate(() => {
      const r = window.__depthDemo.renderer;
      r.setZoom(0.01);
      r.center = { x: -10000, y: 10000 };
      r.updateCamera();
    });
    await snapshot(`edge-${viewport.width}`);
    await page.evaluate(() => window.__depthDemo.renderer.home());
    await page.getByRole('button', { name: 'Campaign', exact: true }).click();
    await ready('campaign');
    await snapshot(`campaign-${viewport.width}`);
    await page
      .getByRole('button', { name: 'Battlefield', exact: true })
      .click();
    await ready('battle');
  }
  await page.setViewportSize({ width: 1440, height: 960 });
  await page
    .getByRole('button', {
      name: 'Terrain relief on; compare with flat terrain',
      exact: true,
    })
    .click();
  assert.equal(
    await page.evaluate(() => window.__depthDemo.renderer.relief),
    0,
  );
  await snapshot('battle-flat-comparison');
  await page
    .getByRole('button', { name: 'Restore terrain relief', exact: true })
    .click();
  await page
    .getByRole('button', { name: 'Withdraw from battle', exact: true })
    .click();
  await page
    .getByRole('dialog')
    .getByRole('button', { name: 'Withdraw', exact: true })
    .click();
  await page
    .getByRole('dialog')
    .getByRole('button', { name: 'Return to campaign', exact: true })
    .click();
  await ready('campaign');
  assert.equal(
    await page.evaluate(() => localStorage.getItem('field-command-save')),
    'demo-save-isolation-sentinel',
  );
  const metrics = await page.evaluate(() => {
    const r = window.__depthDemo.renderer,
      times = [...r.stats.frameTimes].sort((a, b) => a - b);
    return {
      renderer: r.renderer
        .getContext()
        .getParameter(r.renderer.getContext().RENDERER),
      medianMs: times[Math.floor(times.length / 2)],
      p95Ms: times[Math.floor(times.length * 0.95)],
      drawCalls: r.stats.drawCalls,
      note: 'Headless software-rendered smoke test, not reference-hardware performance approval.',
    };
  });
  // These checks are sequential; release the completed desktop GPU context.
  await page.close();
  const touch = await browser.newPage({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 1,
  });
  touch.on('pageerror', (e) => errors.push(e.message));
  touch.on('console', (m) => {
    if (m.type() === 'error') errors.push(m.text());
  });
  await touch.goto(url);
  await touch.waitForFunction(
    () => window.__depthDemo?.renderer.stats.frames > 0,
  );
  assert.ok(
    await touch.evaluate(() =>
      window.__depthDemo.renderer.labels.some((l) => l.id === 'army'),
    ),
    'the army must be visible on the initial mobile campaign map',
  );
  await touch
    .getByRole('button', { name: 'Touch order mode', exact: true })
    .click();
  const destination = await touch.evaluate(() => {
    const r = document.querySelector('.depth-map').getBoundingClientRect(),
      p = window.__depthDemo.renderer.project(460, 730);
    return { x: r.left + p.x, y: r.top + p.y };
  });
  await touch.touchscreen.tap(destination.x, destination.y);
  assert.ok(
    await touch.evaluate(
      () => window.__depthDemo.model.state.army.path.length > 0,
    ),
  );
  await touch
    .getByRole('button', { name: 'Touch order mode', exact: true })
    .click();
  await touch.getByRole('button', { name: 'Battlefield', exact: true }).click();
  await touch.waitForFunction(
    () =>
      window.__depthDemo?.model.state.mode === 'battle' &&
      window.__depthDemo.renderer.stats.frames > 0,
  );
  const second = await touch.evaluate(() => {
    const r = document.querySelector('.depth-map').getBoundingClientRect(),
      l = window.__depthDemo.renderer.labels.find((l) => l.id === 'u2');
    return { x: r.left + l.x + l.w / 2, y: r.top + l.y + 10 };
  });
  await touch.touchscreen.tap(second.x, second.y);
  assert.deepEqual(
    await touch.evaluate(() => window.__depthDemo.model.state.selected),
    ['u2'],
  );
  const centerBefore = await touch.evaluate(
    () => window.__depthDemo.renderer.center.x,
  );
  const cdp = await touch.context().newCDPSession(touch);
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchStart',
    touchPoints: [{ x: 260, y: 345 }],
  });
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchMove',
    touchPoints: [{ x: 305, y: 380 }],
  });
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchEnd',
    touchPoints: [],
  });
  assert.notEqual(
    await touch.evaluate(() => window.__depthDemo.renderer.center.x),
    centerBefore,
    'touch drag must pan outside order mode',
  );
  await touch.waitForTimeout(350);
  const stalePixels = await touch.evaluate(() => {
    const r = window.__depthDemo.renderer;
    r.render(0);
    const before = r.ctx.getImageData(
      0,
      0,
      r.overlay.width,
      r.overlay.height,
    ).data;
    r.overlay.width = r.overlay.width;
    r.render(0);
    const after = r.ctx.getImageData(
      0,
      0,
      r.overlay.width,
      r.overlay.height,
    ).data;
    let changed = 0;
    for (let i = 0; i < before.length; i += 4) {
      if (
        Math.max(
          ...[0, 1, 2, 3].map((c) => Math.abs(before[i + c] - after[i + c])),
        ) > 10
      )
        changed++;
    }
    return changed;
  });
  assert.ok(
    stalePixels < 50,
    `Panning retained ${stalePixels} stale overlay pixels`,
  );
  await touch.screenshot({ path: 'test-results/depth/touch-controls.png' });
  results.push({
    name: 'touch-controls',
    initialArmyVisible: true,
    tapOrders: true,
    tapSelection: true,
    dragPan: true,
    stalePixels,
  });
  await touch.close();
  assert.deepEqual(errors, []);
  writeFileSync(
    'test-results/depth/verification.json',
    JSON.stringify({ results, metrics, errors }, null, 2),
  );
  console.log(
    `Depth demo browser checks passed: ${results.length} screenshots, orders, formations, both maps, HQ, withdrawal, and save isolation.`,
  );
  console.log(metrics);
} finally {
  await browser.close();
}
