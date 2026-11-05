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
  results = {};
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});
mkdirSync('test-results/depth-polish', { recursive: true });
try {
  await page.goto(process.env.DEMO_URL || 'http://localhost:5174/?demo=depth');
  await page.waitForFunction(
    () => window.__depthDemo?.renderer.stats.frames > 0,
  );
  for (const mode of ['campaign', 'battle']) {
    if (mode === 'battle') {
      await page
        .getByRole('button', { name: 'Battlefield', exact: true })
        .click();
      await page.waitForFunction(
        () =>
          window.__depthDemo?.model.state.mode === 'battle' &&
          window.__depthDemo.renderer.stats.frames > 0,
      );
    }
    const before = await page.evaluate(() => ({
      ...window.__depthDemo.renderer.center,
      selected: [...window.__depthDemo.model.state.selected],
    }));
    await page.keyboard.down('d');
    await page.waitForFunction(
      (x) => window.__depthDemo.renderer.center.x > x + 30,
      before.x,
    );
    await page.keyboard.up('d');
    await page.keyboard.down('w');
    await page.waitForFunction(
      (y) => window.__depthDemo.renderer.center.y < y - 30,
      before.y,
    );
    await page.keyboard.up('w');
    const stopped = await page.evaluate(() => ({
      ...window.__depthDemo.renderer.center,
    }));
    await page.waitForTimeout(300);
    assert.deepEqual(
      await page.evaluate(() => ({ ...window.__depthDemo.renderer.center })),
      stopped,
    );
    assert.deepEqual(
      await page.evaluate(() => window.__depthDemo.model.state.selected),
      before.selected,
      'W must no longer select II Corps',
    );
    assert.equal(
      await page.evaluate(() => window.__depthDemo.model.state.paused),
      true,
    );
    await page.keyboard.down('a');
    await page.evaluate(() => window.dispatchEvent(new Event('blur')));
    assert.equal(
      await page.evaluate(() => window.__depthDemo.renderer.cameraKeys.size),
      0,
    );
    await page.keyboard.up('a');
    await page.evaluate(() => {
      const input = document.createElement('input');
      input.id = 'camera-input';
      document.body.append(input);
      input.focus();
    });
    await page.keyboard.type('wasd');
    assert.equal(await page.locator('#camera-input').inputValue(), 'wasd');
    assert.equal(
      await page.evaluate(() => window.__depthDemo.renderer.cameraKeys.size),
      0,
    );
    await page.evaluate(() => {
      document.querySelector('#camera-input').remove();
      window.__depthDemo.renderer.home();
    });
    results[`${mode}Camera`] = true;
  }
  const cards = page.getByRole('group', { name: 'Army units', exact: true });
  assert.equal(
    await cards.locator('button').count(),
    await page.evaluate(() => {
      const b = window.__depthDemo.model.state.battle;
      return (
        b.units.filter((u) => u.side === 'player').length +
        b.commanders.filter((c) => !c.hostId).length +
        b.wagons.filter((w) => w.side === 'player').length
      );
    }),
  );
  await page
    .getByRole('button', { name: 'Select 1st Line Regiment', exact: true })
    .click();
  await page
    .getByRole('button', { name: 'Select 2nd Line Regiment', exact: true })
    .click({ modifiers: ['Shift'] });
  assert.equal(
    await page.evaluate(() => window.__depthDemo.model.state.selected.length),
    2,
  );
  await page.getByRole('button', { name: 'Run', exact: true }).click();
  await page
    .getByRole('button', { name: 'Melee only (hold fire)', exact: true })
    .click();
  assert.equal(
    await page.evaluate(() =>
      window.__depthDemo.model
        .selectedUnits()
        .every((u) => u.running && u.holdFire),
    ),
    true,
  );
  await page
    .getByRole('button', { name: 'Column formation', exact: true })
    .click();
  assert.equal(
    await page.evaluate(() =>
      window.__depthDemo.model
        .selectedUnits()
        .every((u) => u.formationChange?.to === 'column'),
    ),
    true,
  );
  const layout = await page.evaluate(() => {
    const roster = document
      .querySelector('.depth-roster')
      .getBoundingClientRect();
    const actions = document
      .querySelector('.depth-orders')
      .getBoundingClientRect();
    return {
      actionsAbove: actions.bottom <= roster.top,
      cardHeight: document
        .querySelector('.depth-roster-unit')
        .getBoundingClientRect().height,
    };
  });
  assert.ok(layout.actionsAbove && layout.cardHeight <= 55);
  results.roster = layout;
  await page.screenshot({
    path: 'test-results/depth-polish/battle-desktop.png',
  });
  for (const width of [900, 390]) {
    await page.setViewportSize({ width, height: 844 });
    await page.waitForTimeout(250);
    assert.equal(
      await page.evaluate(
        () => document.documentElement.scrollWidth > innerWidth,
      ),
      false,
    );
    const bad = await page.evaluate(() =>
      [
        ...document.querySelectorAll(
          '.depth-clock, .depth-corps, .depth-orders, .depth-roster',
        ),
      ].some((e) => {
        const r = e.getBoundingClientRect();
        return r.left < 0 || r.right > innerWidth + 1;
      }),
    );
    assert.equal(bad, false);
    await page.screenshot({
      path: `test-results/depth-polish/battle-${width}.png`,
    });
  }
  await page.setViewportSize({ width: 1280, height: 800 });
  results.artillery = await page.evaluate(() => {
    const { model, renderer: r } = window.__depthDemo,
      b = model.state.battle;
    const source = b.units.find((u) => u.kind === 'artillery');
    const target = b.units.find((u) => u.side !== source.side);
    for (const u of b.units) {
      u.holdFire = true;
      u.arrival = u === source || u === target ? 0 : 9999;
    }
    Object.assign(source, {
      x: 630,
      y: 340,
      facing: Math.PI,
      target: null,
      attackId: target.id,
      reload: 0,
      holdFire: false,
      limbered: false,
      limberChange: 0,
      formationChange: null,
    });
    Object.assign(target, {
      x: 450,
      y: 340,
      facing: 0,
      formation: 'line',
      formationChange: null,
      target: null,
    });
    const ammo = source.ammo;
    model.state.paused = false;
    for (let i = 0; i < 50 && !source.artilleryImpacts; i++) model.update(0.05);
    model.state.paused = true;
    r.center = { x: 535, y: 365 };
    r.zoom = 1.7;
    r.updateCamera();
    r.render(0);
    const visible = r.stats.impacts;
    const canvas = document.createElement('canvas');
    canvas.width = r.width;
    canvas.height = r.height;
    const original = r.ctx;
    r.ctx = canvas.getContext('2d');
    r.drawArtilleryImpacts();
    const pixels = r.ctx
      .getImageData(0, 0, canvas.width, canvas.height)
      .data.filter((v, i) => i % 4 === 3 && v > 0).length;
    const time = b.time;
    b.time += 7;
    r.ctx.clearRect(0, 0, canvas.width, canvas.height);
    r.drawArtilleryImpacts();
    const expired = r.stats.impacts;
    b.time = time;
    r.ctx = original;
    r.render(0);
    return {
      ammoSpent: ammo - source.ammo,
      visible,
      pixels,
      expired,
      impacts: source.artilleryImpacts,
    };
  });
  assert.ok(
    results.artillery.ammoSpent > 0 &&
      results.artillery.visible > 0 &&
      results.artillery.pixels > 20,
  );
  assert.equal(results.artillery.expired, 0);
  await page.screenshot({
    path: 'test-results/depth-polish/artillery-impact.png',
  });
  results.turning = [];
  for (const stage of [0, 1, 2, 3]) {
    const turn = await page.evaluate((stage) => {
      const { model, renderer: r } = window.__depthDemo;
      const b = model.state.battle;
      const unit = b.units[0];
      if (stage === 0) {
        for (const u of b.units) {
          u.arrival = 9999;
          u.holdFire = true;
        }
        Object.assign(unit, {
          x: 550,
          y: 360,
          arrival: 0,
          facing: 0,
          turnVelocity: 0,
          formation: 'line',
          formationChange: null,
          running: false,
          attackId: null,
          desiredFacing: null,
          target: { x: 550, y: 600 },
          waypoints: [],
          orderQueue: [],
        });
        r.center = { x: 550, y: 350 };
        r.zoom = 2;
        r.updateCamera();
      } else {
        model.state.paused = false;
        for (let i = 0; i < 120; i++) {
          model.update(1 / 60);
          if (i % 30 === 29) r.render(0);
        }
        model.state.paused = true;
      }
      r.invalidate();
      r.render(0);
      return {
        stage,
        facing: unit.facing,
        x: unit.x,
        y: unit.y,
        movingSprites: r.stats.animation.moving,
        troops: r.stats.troops,
      };
    }, stage);
    results.turning.push(turn);
    await page.screenshot({
      path: `test-results/depth-polish/turning-${stage}.png`,
    });
  }
  const turns = results.turning;
  assert.ok(turns[1].facing > 0.05 && turns[1].facing < 0.5);
  assert.ok(
    turns[1].y - turns[0].y < 5,
    'the line must not slide sideways during its initial wheel',
  );
  for (let i = 1; i < turns.length; i++) {
    assert.ok(
      turns[i].facing > turns[i - 1].facing && turns[i].facing < Math.PI / 2,
    );
    assert.ok(turns[i].movingSprites > 0 && turns[i].troops > 0);
  }
  results.directions = await page.evaluate(async () => {
    const THREE = await import('/node_modules/three/build/three.module.js');
    const { animatedGeometry } = await import('/src/demo/troopAnimation.js');
    const depth = window.__depthDemo.renderer,
      renderer = depth.renderer;
    const width = 128,
      height = 144;
    const target = new THREE.WebGLRenderTarget(width, height);
    target.texture.colorSpace = THREE.SRGBColorSpace;
    const scene = new THREE.Scene();
    scene.background = new THREE.Color('#526e57');
    const camera = new THREE.OrthographicCamera(
      -0.5,
      0.5,
      0.5625,
      -0.5625,
      0.1,
      10,
    );
    camera.position.z = 2;
    const canvas = document.createElement('canvas');
    canvas.width = width * 8;
    canvas.height = height * 3;
    const ctx = canvas.getContext('2d'),
      results = [];
    for (let type = 0; type < 8; type++) {
      const frames = [];
      for (let direction = 0; direction < 3; direction++) {
        const geometry = animatedGeometry(type, 0, 1);
        geometry.attributes.troopDirection.setX(0, direction);
        const mesh = new THREE.InstancedMesh(
          geometry,
          depth.troops[type].material,
          1,
        );
        mesh.setMatrixAt(0, new THREE.Matrix4());
        scene.add(mesh);
        renderer.setRenderTarget(target);
        renderer.render(scene, camera);
        const buffer = new Uint8Array(width * height * 4);
        renderer.readRenderTargetPixels(target, 0, 0, width, height, buffer);
        const upright = new Uint8ClampedArray(buffer.length);
        for (let y = 0; y < height; y++)
          upright.set(
            buffer.subarray(y * width * 4, (y + 1) * width * 4),
            (height - y - 1) * width * 4,
          );
        ctx.putImageData(
          new ImageData(upright, width, height),
          type * width,
          direction * height,
        );
        frames.push(upright);
        scene.remove(mesh);
        mesh.dispose();
        geometry.dispose();
      }
      results.push({
        type,
        rear: frames[1].filter((v, i) => Math.abs(v - frames[0][i]) > 20)
          .length,
        front: frames[2].filter((v, i) => Math.abs(v - frames[1][i]) > 20)
          .length,
      });
    }
    renderer.setRenderTarget(null);
    target.dispose();
    depth.render(0);
    canvas.dataset.directionGallery = '';
    Object.assign(canvas.style, {
      position: 'fixed',
      top: '0',
      left: '0',
      zIndex: '10000',
    });
    document.body.append(canvas);
    return results;
  });
  for (const d of results.directions)
    assert.ok(
      d.rear > 100 && d.front > 100,
      `type ${d.type}: missing direction art`,
    );
  await page
    .locator('[data-direction-gallery]')
    .screenshot({ path: 'test-results/depth-polish/directions.png' });
  results.lowDetailStride = await page.evaluate(async () => {
    const THREE = await import('/node_modules/three/build/three.module.js');
    const { animatedGeometry } = await import('/src/demo/troopAnimation.js');
    const depth = window.__depthDemo.renderer,
      renderer = depth.renderer;
    const target = new THREE.WebGLRenderTarget(24, 32);
    const scene = new THREE.Scene();
    scene.background = new THREE.Color('#526e57');
    const camera = new THREE.OrthographicCamera(
      -0.5,
      0.5,
      2 / 3,
      -2 / 3,
      0.1,
      10,
    );
    camera.position.z = 2;
    const results = [];
    for (const width of [24, 48])
      for (const type of [0, 1])
        for (const direction of [0, 1, 2]) {
          const height = (width * 4) / 3;
          target.setSize(width, height);
          const geometry = animatedGeometry(type, 0, 1, 'low');
          geometry.attributes.troopDirection.setX(0, direction);
          const mesh = new THREE.InstancedMesh(
            geometry,
            depth.troops[type].material,
            1,
          );
          mesh.setMatrixAt(0, new THREE.Matrix4());
          scene.add(mesh);
          const frames = [];
          for (const phase of [Math.PI / 2, Math.PI * 1.5]) {
            geometry.attributes.troopMotion.setXYZW(0, phase, 1, 0, 0);
            geometry.attributes.troopMotion.needsUpdate = true;
            renderer.setRenderTarget(target);
            renderer.render(scene, camera);
            const pixels = new Uint8Array(width * height * 4);
            renderer.readRenderTargetPixels(
              target,
              0,
              0,
              width,
              height,
              pixels,
            );
            frames.push(pixels);
          }
          let changedFeet = 0;
          // WebGL readback starts at the bottom row; inspect the lower third only.
          for (let i = 0; i < width * Math.floor(height * 0.35) * 4; i += 4)
            if (
              [0, 1, 2].some(
                (c) => Math.abs(frames[0][i + c] - frames[1][i + c]) > 12,
              )
            )
              changedFeet++;
          results.push({ width, type, direction, changedFeet });
          scene.remove(mesh);
          mesh.dispose();
          geometry.dispose();
        }
    renderer.setRenderTarget(null);
    target.dispose();
    depth.render(0);
    return results;
  });
  for (const stride of results.lowDetailStride)
    assert.ok(
      stride.changedFeet >= (stride.width === 24 ? 1 : 4),
      `low-detail feet must move: ${JSON.stringify(stride)}`,
    );
  assert.deepEqual(errors, []);
  writeFileSync(
    'test-results/depth-polish/verification.json',
    JSON.stringify({ results, errors }, null, 2),
  );
  console.log(JSON.stringify(results, null, 2));
} finally {
  await browser.close();
}
