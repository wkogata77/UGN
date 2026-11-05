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
const page = await browser.newPage({ viewport: { width: 1280, height: 844 } });
const errors = [],
  results = {};
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});
const output = 'test-results/depth-engagement';
mkdirSync(output, { recursive: true });
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
  results.idle = await page.evaluate(() => {
    const { model, renderer: r } = window.__depthDemo,
      b = model.state.battle;
    const own = b.units[0],
      enemy = b.units.find((u) => u.side === 'enemy');
    for (const u of b.units) {
      u.arrival = 9999;
      u.holdFire = true;
    }
    Object.assign(own, {
      x: 550,
      y: 340,
      facing: 0,
      arrival: 0,
      holdFire: false,
      condition: 60,
    });
    Object.assign(enemy, {
      x: 430,
      y: 340,
      facing: 0,
      arrival: 0,
      visible: true,
      condition: 60,
      men: 5000,
      startMen: 5000,
    });
    b.aiClock = -100000;
    b.visibilityClock = -100000;
    b.visibleCells = [];
    model.select([own.id]);
    model.state.paused = false;
    for (let i = 0; i < 240; i++) model.update(1 / 60);
    model.state.paused = true;
    r.center = { x: 500, y: 330 };
    r.zoom = 3.4;
    r.updateCamera();
    r.render(0);
    return { facing: own.facing, ammo: own.ammo, x: own.x, target: own.target };
  });
  assert.deepEqual(results.idle, {
    facing: 0,
    ammo: 100,
    x: 550,
    target: null,
  });
  await page.getByRole('button', { name: 'Engage enemy', exact: true }).click();
  results.acquisition = await page.evaluate(() => {
    const { model, renderer: r } = window.__depthDemo,
      b = model.state.battle;
    const own = b.units[0];
    const order = own.attackId;
    model.state.paused = false;
    for (let i = 0; i < 2000 && !own.aimComplete; i++) {
      model.update(1 / 60);
      if (i % 30 === 0) r.render(0);
    }
    model.state.paused = true;
    r.render(0);
    return {
      order,
      facing: own.facing,
      complete: own.aimComplete,
      ammo: own.ammo,
      x: own.x,
    };
  });
  assert.ok(
    results.acquisition.order &&
      results.acquisition.complete &&
      results.acquisition.ammo < 100,
  );
  assert.ok(results.acquisition.facing > 2 && results.acquisition.facing < 2.5);
  assert.equal(results.acquisition.x, 550);
  await page.screenshot({ path: `${output}/engaged.png` });
  results.fatigue = await page.evaluate(() => {
    const { model } = window.__depthDemo,
      b = model.state.battle;
    const own = b.units[0],
      enemy = b.units.find((u) => u.id === own.attackId);
    enemy.y += 15;
    const before = {
      facing: own.facing,
      own: own.condition,
      enemy: enemy.condition,
    };
    model.state.paused = false;
    for (let i = 0; i < 360; i++) model.update(1 / 60);
    model.state.paused = true;
    return {
      before,
      facing: own.facing,
      own: own.condition,
      enemy: enemy.condition,
    };
  });
  assert.equal(results.fatigue.facing, results.fatigue.before.facing);
  assert.ok(
    results.fatigue.own < results.fatigue.before.own &&
      results.fatigue.enemy < results.fatigue.before.enemy,
  );
  results.motion = await page.evaluate(() => {
    const { model, renderer: r } = window.__depthDemo,
      b = model.state.battle,
      own = b.units[0];
    for (const u of b.units) u.arrival = u === own ? 0 : 9999;
    Object.assign(own, {
      x: 550,
      y: 400,
      facing: 0,
      target: null,
      attackId: null,
      desiredFacing: null,
      fireTargetId: null,
      shotTime: undefined,
      shotKind: null,
      reload: 0,
      holdFire: true,
      condition: 90,
      fightingUntil: 0,
      meleeUntil: 0,
      turnVelocity: 0,
    });
    model.soldierPositions(own);
    model.moveUnits({ x: 550, y: 640 });
    model.state.paused = false;
    for (let i = 0; i < 360; i++) {
      model.update(1 / 60);
      if (i % 30 === 0) r.render(0);
    }
    model.state.paused = true;
    r.center = { x: own.x, y: own.y - 10 };
    r.updateCamera();
    r.render(0);
    const points = model.soldierPositions(own);
    const errors = points.map((p) => Math.hypot(p.x - p.goalX, p.y - p.goalY));
    return {
      min: Math.min(...errors),
      max: Math.max(...errors),
      moving: r.stats.animation.moving,
      headingSpread: Math.max(
        ...points.map((p) =>
          Math.abs(
            Math.atan2(
              Math.sin(p.facing - points[0].facing),
              Math.cos(p.facing - points[0].facing),
            ),
          ),
        ),
      ),
    };
  });
  assert.ok(
    results.motion.max > results.motion.min + 0.7 && results.motion.moving > 20,
  );
  assert.ok(results.motion.headingSpread > 0.2);
  for (let i = 0; i < 8; i++)
    await page.getByRole('button', { name: 'Zoom in', exact: true }).click();
  assert.equal(await page.evaluate(() => window.__depthDemo.renderer.zoom), 6);
  await page.screenshot({ path: `${output}/individual-turn-6x.png` });
  results.pause = await page.evaluate(() => {
    const { model, renderer: r, clock } = window.__depthDemo;
    const before = JSON.stringify(
      model.soldierPositions(model.state.battle.units[0]),
    );
    clock.advance(1);
    r.render(0);
    return (
      before ===
      JSON.stringify(model.soldierPositions(model.state.battle.units[0]))
    );
  });
  assert.equal(results.pause, true);
  await page.mouse.move(600, 390);
  await page.mouse.wheel(0, 400);
  await page.waitForFunction(() => window.__depthDemo.renderer.zoom < 6);
  assert.ok(await page.evaluate(() => window.__depthDemo.renderer.zoom > 2.7));
  results.zoom = [];
  for (const mode of ['battle', 'campaign']) {
    if (mode === 'campaign') {
      await page.getByRole('button', { name: 'Campaign', exact: true }).click();
      await page.waitForFunction(
        () =>
          window.__depthDemo?.model.state.mode === 'campaign' &&
          window.__depthDemo.renderer.stats.frames > 0,
      );
    }
    for (const width of [1280, 390]) {
      await page.setViewportSize({ width, height: 844 });
      await page.waitForFunction(
        () => window.__depthDemo.renderer.width === innerWidth,
      );
      const zoom = await page.evaluate(() => {
        const { model, renderer: r } = window.__depthDemo;
        const subject =
          model.state.mode === 'battle'
            ? model.state.battle.units[0]
            : model.state.army;
        r.center = { x: subject.x, y: subject.y - 10 };
        r.setZoom(100);
        r.render(0);
        const points = [
          [3, 3],
          [r.width - 3, 3],
          [3, r.height - 3],
          [r.width - 3, r.height - 3],
        ];
        const canvas = document.createElement('canvas');
        canvas.width = r.width;
        canvas.height = r.height;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(r.renderer.domElement, 0, 0, r.width, r.height);
        const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
        const colors = new Set();
        for (let i = 0; i < pixels.length; i += 64)
          colors.add(`${pixels[i]},${pixels[i + 1]},${pixels[i + 2]}`);
        return {
          zoom: r.zoom,
          corners: points.every(([x, y]) => !!r.ground({ x, y })),
          troops: r.stats.troops,
          colors: colors.size,
          overflow: document.documentElement.scrollWidth > innerWidth,
        };
      });
      results.zoom.push({ mode, width, ...zoom });
      assert.ok(
        zoom.zoom === 6 &&
          zoom.corners &&
          zoom.troops > 0 &&
          zoom.colors > 500 &&
          !zoom.overflow,
      );
      await page.screenshot({ path: `${output}/${mode}-${width}-6x.png` });
    }
  }
  assert.deepEqual(errors, []);
  writeFileSync(
    `${output}/verification.json`,
    JSON.stringify({ results, errors }, null, 2),
  );
  console.log(JSON.stringify(results, null, 2));
} finally {
  await browser.close();
}
