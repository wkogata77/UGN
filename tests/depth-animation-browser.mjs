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
const page = await browser.newPage({ viewport: { width: 1536, height: 1100 } });
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});
mkdirSync('test-results/depth-animation', { recursive: true });
try {
  await page.goto(process.env.DEMO_URL || 'http://localhost:5174/?demo=depth');
  await page.waitForFunction(
    () => window.__depthDemo?.renderer.stats.frames > 0,
  );
  const campaign = await page.evaluate(() => {
    const { model, renderer } = window.__depthDemo;
    model.moveArmy({ x: 410, y: 620 });
    model.state.paused = false;
    for (let i = 0; i < 20; i++) {
      model.update(0.05);
      renderer.render(0);
    }
    model.state.paused = true;
    return renderer.stats.animation;
  });
  assert.ok(
    campaign.moving >= 19,
    'the campaign escort and mounted general must march',
  );
  await page.getByRole('button', { name: 'Battlefield', exact: true }).click();
  await page.waitForFunction(
    () =>
      window.__depthDemo?.model.state.mode === 'battle' &&
      window.__depthDemo.renderer.stats.frames > 0,
  );
  const integration = await page.evaluate(() => {
    const { model, renderer } = window.__depthDemo;
    const b = model.state.battle,
      initialTime = b.time;
    const fixtures = Array.from({ length: 8 }, (_, type) => ({
      id: `animation-${type}`,
      x: 390 + type * 65,
      y: 400,
      facing: 0,
      side: type % 2 && type < 6 ? 'enemy' : 'player',
      men: 18,
      kind:
        type < 2
          ? 'infantry'
          : type < 4
            ? 'cavalry'
            : type < 6
              ? 'artillery'
              : type === 6
                ? 'general'
                : 'wagon',
      formation: 'line',
      frontWidth: 1,
    }));
    renderer.animation.clear();
    renderer.populateTroops(fixtures);
    // Individual followers accelerate before reaching their steady marching gait.
    for (let step = 0; step < 12; step++) {
      b.time += 0.1;
      fixtures.forEach((u) => {
        u.x += 2;
      });
      renderer.populateTroops(fixtures);
    }
    const moving = renderer.stats.animation.moving;
    const kinds = renderer.troops.slice(0, 8).map((mesh) => ({
      count: mesh.count,
      amount: mesh.geometry.attributes.troopMotion.getY(0),
    }));
    const frozen = JSON.stringify(
      renderer.troops.map((m) =>
        Array.from(
          m.geometry.attributes.troopMotion.array.slice(0, m.count * 4),
        ),
      ),
    );
    renderer.populateTroops(fixtures);
    const paused =
      frozen ===
      JSON.stringify(
        renderer.troops.map((m) =>
          Array.from(
            m.geometry.attributes.troopMotion.array.slice(0, m.count * 4),
          ),
        ),
      );
    fixtures.forEach((u, i) => {
      if (i < 6)
        Object.assign(u, {
          shotTime: b.time,
          shotKind: i >= 4 ? 'cannon' : 'musket',
          reload: 2,
        });
    });
    b.time += 0.06;
    renderer.populateTroops(fixtures);
    const firingSlots = renderer.troops.slice(8, 12).map((mesh) => mesh.count);
    const muzzles = renderer.muzzleEffects.length;
    b.time += 0.9;
    renderer.populateTroops(fixtures);
    const reloadSlots = renderer.troops.slice(12).map((mesh) => mesh.count);
    b.time = initialTime;
    renderer.animation.clear();
    renderer.render(0);
    return { moving, kinds, paused, firingSlots, muzzles, reloadSlots };
  });
  assert.ok(integration.moving > 8);
  for (const kind of integration.kinds)
    assert.ok(kind.count > 0 && kind.amount > 0.8, JSON.stringify(kind));
  assert.ok(
    integration.paused,
    'rendering a paused frame must not change the gait',
  );
  assert.ok(
    integration.firingSlots.every((count) => count > 0),
    'both armies and both armed troop types must switch to firing poses',
  );
  assert.ok(integration.reloadSlots.every((count) => count > 0));
  assert.ok(integration.muzzles >= 6);

  const liveCombat = await page.evaluate(() => {
    const { model, renderer } = window.__depthDemo;
    const own = model.state.battle.units.find((u) => u.id === 'u1');
    const enemy = model.state.battle.units.find((u) => u.side === 'enemy');
    Object.assign(own, { x: 500, y: 340, facing: 0, target: null, reload: 0 });
    Object.assign(enemy, {
      x: 650,
      y: 340,
      facing: Math.PI,
      target: null,
      visible: true,
    });
    const ammo = own.ammo;
    model.state.paused = false;
    for (let i = 0; i < 100 && own.shotTime == null; i++) {
      model.update(0.05);
      renderer.render(0);
    }
    for (let i = 0; i < 3; i++) {
      model.update(0.05);
      renderer.render(0);
    }
    model.state.paused = true;
    renderer.zoom = 1.7;
    renderer.center = { x: 580, y: 410 };
    renderer.updateCamera();
    renderer.render(0);
    return {
      ammoSpent: ammo - own.ammo,
      shotKind: own.shotKind,
      muzzles: renderer.muzzleEffects.length,
    };
  });
  assert.ok(
    liveCombat.ammoSpent > 0 &&
      liveCombat.shotKind === 'musket' &&
      liveCombat.muzzles > 0,
  );
  await page.screenshot({
    path: 'test-results/depth-animation/battle-volley-desktop.png',
  });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(300);
  await page.screenshot({
    path: 'test-results/depth-animation/battle-volley-mobile.png',
  });
  const mobile = await page.evaluate(() => {
    const { model, renderer } = window.__depthDemo;
    model.state.selected = ['u2'];
    model.moveUnits({ x: 560, y: 440 });
    model.state.paused = false;
    for (let i = 0; i < 12; i++) {
      model.update(0.05);
      renderer.render(0);
    }
    model.state.paused = true;
    const canvas = document.createElement('canvas');
    canvas.width = renderer.renderer.domElement.width;
    canvas.height = renderer.renderer.domElement.height;
    const ctx = canvas.getContext('2d');
    const capture = () => {
      renderer.render(0);
      ctx.drawImage(renderer.renderer.domElement, 0, 0);
      return ctx.getImageData(0, 0, canvas.width, canvas.height).data;
    };
    const a = capture(),
      b = capture();
    let changes = 0;
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) changes++;
    return {
      moving: renderer.stats.animation.moving,
      pausedPixelChanges: changes,
      overflow: document.documentElement.scrollWidth > innerWidth,
    };
  });
  assert.ok(mobile.moving > 0);
  assert.equal(mobile.pausedPixelChanges, 0);
  assert.equal(mobile.overflow, false);
  await page.screenshot({
    path: 'test-results/depth-animation/battle-march-mobile.png',
  });
  const melee = await page.evaluate(() => {
    const { model, renderer } = window.__depthDemo;
    const u = model.state.battle.units.find((unit) => unit.id === 'u1');
    const play = renderer.audio.play,
      calls = [];
    renderer.audio.play = (kind) => calls.push(kind);
    renderer.smoke = [];
    Object.assign(u, {
      shotTime: model.state.battle.time,
      shotKind: 'melee',
      flash: 0.45,
    });
    model.state.paused = false;
    renderer.render(0);
    renderer.render(0);
    model.state.paused = true;
    renderer.audio.play = play;
    return {
      sounds: calls.filter((kind) => kind === 'melee').length,
      smoke: renderer.smoke.length,
    };
  });
  assert.equal(melee.sounds, 1);
  assert.equal(melee.smoke, 0);
  await page.setViewportSize({ width: 1536, height: 1100 });

  const pixels = await page.evaluate(async () => {
    const THREE = await import('/node_modules/three/build/three.module.js');
    const { animatedGeometry, animateMaterial, combatPose } =
      await import('/src/demo/troopAnimation.js');
    const { renderer: depth } = window.__depthDemo,
      renderer = depth.renderer;
    const width = 192,
      height = 216;
    const target = new THREE.WebGLRenderTarget(width, height);
    target.texture.colorSpace = THREE.SRGBColorSpace;
    const camera = new THREE.OrthographicCamera(
      -0.5,
      0.5,
      0.5625,
      -0.5625,
      0.1,
      10,
    );
    camera.position.z = 2;
    const scene = new THREE.Scene();
    scene.background = new THREE.Color('#526e57');
    const atlas = new THREE.Texture(depth.sources.units),
      actions = new THREE.Texture(depth.sources.actions);
    for (const texture of [atlas, actions]) {
      texture.colorSpace = THREE.SRGBColorSpace;
      texture.generateMipmaps = false;
      texture.minFilter = THREE.LinearFilter;
      texture.needsUpdate = true;
    }
    const canvas = document.createElement('canvas');
    canvas.width = width * 8;
    canvas.height = height * 5;
    const ctx = canvas.getContext('2d');
    const results = [];
    for (let type = 0; type < 8; type++) {
      const frames = [];
      for (let row = 0; row < 5; row++) {
        const action = combatPose(
          { shotTime: 0, shotKind: type >= 4 ? 'cannon' : 'musket', reload: 2 },
          row === 3 ? 0.06 : 1,
          0,
          type,
        );
        const pose = row < 3 ? 0 : action.pose;
        const geometry = animatedGeometry(type, pose, 1);
        const material = new THREE.MeshBasicMaterial({
          map: pose ? actions : atlas,
          alphaTest: 0.4,
          side: THREE.DoubleSide,
        });
        animateMaterial(material, type, pose);
        const mesh = new THREE.InstancedMesh(geometry, material, 1);
        mesh.setMatrixAt(0, new THREE.Matrix4());
        const phase = row === 2 ? Math.PI * 1.5 : Math.PI * 0.5;
        geometry.attributes.troopMotion.setXYZW(
          0,
          phase,
          row === 1 || row === 2 ? 1 : 0,
          row >= 3 ? action.recoil : 0,
          row >= 3 ? action.work : 0,
        );
        geometry.attributes.troopCombat.setX(0, 0);
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
        frames.push(upright);
        ctx.putImageData(
          new ImageData(upright, width, height),
          type * width,
          row * height,
        );
        scene.remove(mesh);
        mesh.dispose();
        geometry.dispose();
        material.dispose();
      }
      const difference = (a, b, lower = false) => {
        let count = 0;
        for (
          let i = lower ? width * Math.floor(height * 0.68) * 4 : 0;
          i < a.length;
          i += 4
        )
          if (
            Math.abs(a[i] - b[i]) +
              Math.abs(a[i + 1] - b[i + 1]) +
              Math.abs(a[i + 2] - b[i + 2]) >
            35
          )
            count++;
        return count;
      };
      let pink = 0;
      for (const frame of frames)
        for (let i = 0; i < frame.length; i += 4)
          if (frame[i] > 170 && frame[i + 1] < 115 && frame[i + 2] > 150)
            pink++;
      results.push({
        type,
        gait: difference(frames[1], frames[2]),
        feet: difference(frames[1], frames[2], true),
        fire: difference(frames[0], frames[3]),
        reload: difference(frames[3], frames[4]),
        pink,
      });
    }
    renderer.setRenderTarget(null);
    target.dispose();
    atlas.dispose();
    actions.dispose();
    depth.render(0);
    canvas.dataset.animationGallery = '';
    Object.assign(canvas.style, {
      position: 'fixed',
      top: '0',
      left: '0',
      zIndex: '10000',
      width: '1536px',
      height: '1080px',
    });
    document.body.append(canvas);
    return results;
  });
  await page
    .locator('[data-animation-gallery]')
    .screenshot({ path: 'test-results/depth-animation/sprite-actions.png' });
  for (const type of pixels) {
    assert.ok(type.gait > 100, `type ${type.type}: no visible gait`);
    assert.ok(type.feet > 50, `type ${type.type}: feet are static`);
    assert.ok(type.pink < 20, `type ${type.type}: chroma-key leak`);
    if (type.type < 6) {
      assert.ok(type.fire > 100, `type ${type.type}: no firing reaction`);
      assert.ok(type.reload > 100, `type ${type.type}: no reload motion`);
    }
  }
  assert.deepEqual(errors, []);
  writeFileSync(
    'test-results/depth-animation/verification.json',
    JSON.stringify(
      { campaign, integration, liveCombat, mobile, pixels },
      null,
      2,
    ),
  );
  console.log(
    JSON.stringify(
      { campaign, integration, liveCombat, mobile, pixels },
      null,
      2,
    ),
  );
} finally {
  await browser.close();
}
