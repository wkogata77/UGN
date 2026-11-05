import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';

const executable =
  '/tmp/field-command-browsers/chromium-1243/chrome-linux64/chrome';
const libs =
  '/tmp/field-command-browser-libs/extracted/usr/lib/x86_64-linux-gnu';
const output = `test-results/depth-grounding/${process.env.GROUNDING_LABEL || 'current'}`;
mkdirSync(output, { recursive: true });
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
      ? {
          LD_LIBRARY_PATH: `${libs}:${process.env.LD_LIBRARY_PATH || ''}`,
        }
      : {}),
  },
});
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});
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
  const results = await page.evaluate(async () => {
    const THREE = await import('/node_modules/three/build/three.module.js');
    const r = window.__depthDemo.renderer,
      renderer = r.renderer;
    const scene = new THREE.Scene();
    const camera = r.camera.clone();
    Object.assign(camera, { left: -42, right: 42, top: 70, bottom: -14 });
    camera.position.set(0, 1250, 720);
    camera.lookAt(0, 0, 0);
    camera.updateProjectionMatrix();
    camera.updateMatrixWorld();
    const target = new THREE.WebGLRenderTarget(192, 192);
    const terrain = new THREE.Mesh(
      new THREE.PlaneGeometry(800, 800, 32, 32),
      new THREE.MeshBasicMaterial({ color: '#73905d', colorWrite: false }),
    );
    terrain.geometry.rotateX(-Math.PI / 2);
    terrain.renderOrder = -1;
    scene.add(terrain);
    const original = {
      height: r.surfaceHeight,
      camera: r.camera,
      color: renderer.getClearColor(new THREE.Color()),
      alpha: renderer.getClearAlpha(),
    };
    const canvas = document.createElement('canvas');
    canvas.width = 192 * 6;
    canvas.height = 192 * 4;
    const ctx = canvas.getContext('2d');
    const results = [];
    const read = () => {
      renderer.setRenderTarget(target);
      renderer.render(scene, camera);
      const pixels = new Uint8Array(192 * 192 * 4);
      renderer.readRenderTargetPixels(target, 0, 0, 192, 192, pixels);
      return pixels;
    };
    const visible = (pixels) =>
      pixels.filter((v, i) => i % 4 === 3 && v > 128).length;
    try {
      r.camera = camera;
      renderer.setClearColor('#73905d', 0);
      const slopes = [
        [0, -1],
        [0, 1],
        [-1, 0],
        [1, 0],
      ];
      for (let row = 0; row < slopes.length; row++) {
        const [dx, dz] = slopes[row];
        r.surfaceHeight = (x, z) => x * dx + z * dz;
        const p = terrain.geometry.attributes.position;
        for (let i = 0; i < p.count; i++)
          p.setY(i, r.surfaceHeight(p.getX(i), p.getZ(i)));
        p.needsUpdate = true;
        terrain.geometry.computeBoundingSphere();
        for (let column = 0; column < 6; column++) {
          const wagon = column >= 3;
          const direction = column % 3;
          const unit = {
            id: 'grounding',
            x: 0,
            y: 0,
            kind: wagon ? 'wagon' : 'infantry',
            side: 'player',
            men: 1,
            formation: 'line',
            facing: [0, -Math.PI / 2, Math.PI / 2][direction],
          };
          r.populateTroops([unit]);
          const mesh = r.troops[wagon ? 7 : 0];
          // A single representative sprite, using the renderer's actual placement and materials.
          const matrix = new THREE.Matrix4();
          mesh.getMatrixAt(0, matrix);
          const sprite = new THREE.InstancedMesh(
            mesh.geometry,
            mesh.material,
            1,
          );
          sprite.setMatrixAt(0, matrix);
          sprite.frustumCulled = false;
          scene.add(sprite);
          terrain.visible = false;
          const reference = visible(read());
          terrain.visible = true;
          const actual = visible(read());
          terrain.material.colorWrite = true;
          const pixels = read(),
            upright = new Uint8ClampedArray(pixels.length);
          for (let y = 0; y < 192; y++)
            upright.set(
              pixels.subarray(y * 192 * 4, (y + 1) * 192 * 4),
              (191 - y) * 192 * 4,
            );
          ctx.putImageData(
            new ImageData(upright, 192, 192),
            column * 192,
            row * 192,
          );
          terrain.material.colorWrite = false;
          results.push({
            kind: unit.kind,
            direction,
            slope: [dx, dz],
            reference,
            actual,
            retained: actual / reference,
          });
          // A tall ridge in front must still occlude the sprite.
          terrain.position.y = 150;
          const hidden = visible(read());
          terrain.position.y = 0;
          results.at(-1).behindRidge = hidden;
          scene.remove(sprite);
          sprite.dispose();
        }
      }
    } finally {
      r.surfaceHeight = original.height;
      r.camera = original.camera;
      renderer.setClearColor(original.color, original.alpha);
      renderer.setRenderTarget(null);
      target.dispose();
      terrain.geometry.dispose();
      terrain.material.dispose();
      r.invalidate();
      r.render(0);
    }
    canvas.dataset.groundingGallery = '';
    Object.assign(canvas.style, {
      position: 'fixed',
      top: '0',
      left: '0',
      zIndex: '10000',
    });
    document.body.append(canvas);
    return results;
  });
  await page
    .locator('[data-grounding-gallery]')
    .screenshot({ path: `${output}/slopes.png` });
  await page.locator('[data-grounding-gallery]').evaluate((e) => e.remove());
  for (const mode of ['battle', 'campaign']) {
    if (mode === 'campaign') {
      await page.getByRole('button', { name: 'Campaign', exact: true }).click();
      await page.waitForFunction(
        () =>
          window.__depthDemo?.model.state.mode === 'campaign' &&
          window.__depthDemo.renderer.stats.frames > 0,
      );
    }
    await page.evaluate(() => {
      const { model, renderer: r } = window.__depthDemo;
      const campaign = model.state.mode === 'campaign';
      const x = campaign ? 1130 : 1100,
        y = campaign ? 55 : 680;
      if (campaign) Object.assign(model.state.army, { x, y });
      else {
        for (const unit of model.state.battle.units) unit.arrival = 9999;
        Object.assign(model.state.battle.units[0], {
          x,
          y,
          arrival: 0,
          facing: -Math.PI / 2,
        });
        Object.assign(model.state.battle.wagons[0], {
          x: x + 65,
          y,
          facing: Math.PI / 2,
        });
      }
      r.center = { x, y: y - 40 };
      r.zoom = 2.7;
      r.updateCamera();
      r.render(0);
    });
    for (const width of [1280, 390]) {
      await page.setViewportSize({ width, height: 844 });
      await page.waitForFunction(
        () => window.__depthDemo.renderer.width === innerWidth,
      );
      await page.evaluate(() => {
        const r = window.__depthDemo.renderer;
        const campaign = r.model.state.mode === 'campaign';
        r.center = { x: campaign ? 1130 : 1135, y: campaign ? 15 : 640 };
        r.zoom = 2.7;
        r.updateCamera();
        r.render(0);
      });
      await page.waitForTimeout(300);
      await page.screenshot({ path: `${output}/${mode}-${width}.png` });
    }
  }
  writeFileSync(
    `${output}/verification.json`,
    JSON.stringify({ results, errors }, null, 2),
  );
  console.log(JSON.stringify(results, null, 2));
  assert.deepEqual(errors, []);
  for (const result of results) {
    assert.ok(result.reference > 20, `blank sprite: ${JSON.stringify(result)}`);
    assert.ok(
      result.retained > 0.99,
      `terrain intersects sprite: ${JSON.stringify(result)}`,
    );
    assert.equal(
      result.behindRidge,
      0,
      'true foreground terrain must still occlude units',
    );
  }
} finally {
  await browser.close();
}
