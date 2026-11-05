import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync } from 'node:fs';

const localBrowser =
  '/tmp/field-command-browsers/chromium-1243/chrome-linux64/chrome';
const localLibs =
  '/tmp/field-command-browser-libs/extracted/usr/lib/x86_64-linux-gnu';
const executablePath =
  process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ||
  (existsSync(localBrowser) ? localBrowser : undefined);
const browser = await chromium.launch({
  executablePath,
  headless: true,
  args: ['--no-sandbox'],
  env: {
    ...process.env,
    ...(existsSync(localLibs)
      ? { LD_LIBRARY_PATH: `${localLibs}:${process.env.LD_LIBRARY_PATH || ''}` }
      : {}),
  },
});
const errors = [];
mkdirSync('test-results', { recursive: true });
const snapshot = async (p, name) => {
  await p.mouse.move(0, 0);
  await p.waitForTimeout(300);
  await p.screenshot({
    path: `test-results/${name}.png`,
    animations: 'disabled',
  });
};
const page = await browser.newPage({
  viewport: { width: 1440, height: 960 },
  deviceScaleFactor: 1,
});
page.setDefaultTimeout(12000);
page.on('pageerror', (error) => errors.push(error.message));
page.on('console', (message) => {
  if (message.type() === 'error') errors.push(message.text());
});

const ready = async (p) => {
  await p.goto(process.env.GAME_URL || 'http://localhost:5173/');
  await p.waitForFunction(
    () => window.__fieldCommand?.controls.current?.scene?.ink,
    { timeout: 30000 },
  );
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(350);
};
const state = async () =>
  page.evaluate(() => structuredClone(window.__fieldCommand.model.state));
const screenPoint = async (x, y) =>
  page.evaluate(
    ({ x, y }) => {
      const scene = window.__fieldCommand.controls.current.scene,
        cam = scene.cameras.main;
      const r = document
        .querySelector('.game-map canvas')
        .getBoundingClientRect();
      return {
        x: r.left + (x - cam.worldView.x) * cam.zoom,
        y: r.top + (y - cam.worldView.y) * cam.zoom,
      };
    },
    { x, y },
  );
const assertCanvas = async (p) => {
  const stats = await p.evaluate(() => {
    const canvas = document.querySelector('.game-map canvas'),
      ctx = canvas.getContext('2d');
    const { data } = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const colors = new Set();
    let opaque = 0;
    for (let i = 0; i < data.length; i += 404) {
      colors.add(`${data[i]},${data[i + 1]},${data[i + 2]}`);
      if (data[i + 3] > 0) opaque++;
    }
    return {
      colors: colors.size,
      opaque,
      width: canvas.width,
      height: canvas.height,
    };
  });
  assert.ok(
    stats.colors > 500,
    `Terrain canvas appears blank: ${JSON.stringify(stats)}`,
  );
  assert.ok(stats.opaque > 500);
  assert.ok(stats.width > 300 && stats.height > 300);
};

const assertMapEdges = async (p) => {
  const edges = await p.evaluate(() => {
    const canvas = document.querySelector('.game-map canvas'),
      ctx = canvas.getContext('2d');
    return [
      [2, 2, 12, canvas.height - 4],
      [canvas.width - 14, 2, 12, canvas.height - 4],
      [2, 2, canvas.width - 4, 12],
      [2, canvas.height - 14, canvas.width - 4, 12],
    ].map(([x, y, w, h]) => {
      const pixels = ctx.getImageData(x, y, w, h).data,
        colors = new Set();
      let blank = 0;
      for (let i = 0; i < pixels.length; i += 16) {
        colors.add(`${pixels[i]},${pixels[i + 1]},${pixels[i + 2]}`);
        if (
          !pixels[i + 3] ||
          (pixels[i] === 111 && pixels[i + 1] === 128 && pixels[i + 2] === 83)
        )
          blank++;
      }
      return { colors: colors.size, blank, samples: pixels.length / 16 };
    });
  });
  for (const edge of edges) {
    assert.ok(edge.colors > 80, `Flat map edge: ${JSON.stringify(edge)}`);
    assert.ok(
      edge.blank / edge.samples < 0.01,
      `Exposed camera background: ${JSON.stringify(edge)}`,
    );
  }
};

const checkZoom = async (p) => {
  for (let i = 0; i < 8; i++)
    await p.getByRole('button', { name: 'Zoom out', exact: true }).click();
  await p.waitForTimeout(180);
  await assertMapEdges(p);
  for (const [x, y] of [
    [-10000, -10000],
    [10000, 10000],
  ]) {
    await p.evaluate(
      ({ x, y }) => {
        window.__fieldCommand.controls.current.scene.cameras.main.setScroll(
          x,
          y,
        );
      },
      { x, y },
    );
    await p.waitForTimeout(120);
    await assertMapEdges(p);
  }
  await p.getByRole('button', { name: 'Center map', exact: true }).click();
};

try {
  await ready(page);
  await assertCanvas(page);
  await page.getByRole('button', { name: '0.5x speed', exact: true }).click();
  assert.equal((await state()).speed, 0.5);
  assert.equal(
    await page
      .getByRole('button', { name: '0.5x speed', exact: true })
      .getAttribute('aria-pressed'),
    'true',
  );
  await page.evaluate(() => document.activeElement.blur());
  for (const [key, speed] of [
    ['1', 1],
    ['2', 2],
    ['3', 4],
    ['0', 0.5],
  ]) {
    await page.keyboard.press(key);
    assert.equal((await state()).speed, speed);
  }
  await page.getByRole('button', { name: '1x speed', exact: true }).click();
  await snapshot(page, 'campaign-desktop');
  if (process.env.SCREENSHOT_ONLY) {
    console.log('Screenshot saved. Browser errors:', errors);
    process.exitCode = errors.length ? 1 : 0;
  } else if (process.env.EXPANSION_ONLY) {
    for (const width of [1440, 390, 360, 1024]) {
      await page.setViewportSize({ width, height: width < 500 ? 844 : 960 });
      await page.evaluate(() => {
        const { model, controls } = window.__fieldCommand;
        model.reset();
        controls.current.scene.fit();
      });
      await page
        .getByRole('button', { name: 'Army camp', exact: true })
        .click();
      await snapshot(page, `headquarters-army-${width}`);
      assert.equal(await page.locator('.hq-regiment').count(), 5);
      for (const tab of ['Armory', 'Officers']) {
        await page.getByRole('tab', { name: tab, exact: true }).click();
        await snapshot(page, `headquarters-${tab.toLowerCase()}-${width}`);
      }
      if (width === 1440) {
        await page
          .locator('.hq-officer-card')
          .filter({ hasText: 'Charles Delmas' })
          .click();
        await page
          .locator('.hq-inspector')
          .getByRole('button', { name: /^Commission/ })
          .click();
        await page
          .getByRole('combobox', { name: 'Assignment for Charles Delmas' })
          .selectOption('u1');
        assert.equal((await state()).units[0].officerId, 'reserve-0');
        await page.getByRole('tab', { name: 'Armory', exact: true }).click();
        await page
          .getByRole('spinbutton', {
            name: 'Quantity for Charleville AN IX',
            exact: true,
          })
          .fill('100');
        await page
          .getByRole('button', { name: 'Buy Charleville AN IX', exact: true })
          .click();
        assert.equal((await state()).inventory.improved, 100);
        await page.getByRole('tab', { name: 'Army', exact: true }).click();
        await page.locator('.hq-regiment').first().click();
        await page
          .getByRole('textbox', { name: 'Regiment name', exact: true })
          .fill('1st Imperial Guard');
        await page
          .getByRole('textbox', { name: 'Regiment name', exact: true })
          .press('Enter');
        assert.equal((await state()).units[0].name, '1st Imperial Guard');
        await page
          .getByRole('slider', { name: 'Authorized strength', exact: true })
          .focus();
        await page.keyboard.press('End');
        await page
          .getByRole('spinbutton', { name: 'Replacement count', exact: true })
          .fill('100');
        await page.getByRole('button', { name: /^Replenish/ }).click();
        assert.equal((await state()).units[0].men, 900);
        await page.getByRole('button', { name: '450 F', exact: true }).click();
        assert.equal((await state()).units[0].skills.firearms, 37);
        await page.evaluate(() => {
          const m = window.__fieldCommand.model;
          m.state.units[0].experience = 1;
          m.state.units[0].ammo = 70;
          m.state.supply = 400;
          m.publish();
        });
        await page.getByRole('button', { name: /Disciplined volleys/ }).click();
        assert.equal((await state()).units[0].perk, 'volley');
        await page
          .locator('.hq-sidebar')
          .getByRole('button', { name: /Resupply/ })
          .click();
        assert.equal((await state()).units[0].ammo, 100);
        assert.equal((await state()).supply, 500);
        await snapshot(page, 'headquarters-regiment-detail');
      } else if (width < 500) {
        await page.getByRole('tab', { name: 'Army', exact: true }).click();
        await page.locator('.hq-regiment').first().click();
        assert.ok(
          await page
            .getByRole('textbox', { name: 'Regiment name', exact: true })
            .isVisible(),
        );
        const detailTop = await page
          .locator('.hq-inspector')
          .evaluate((el) => el.getBoundingClientRect().top);
        assert.ok(
          detailTop >= 120 && detailTop < 240,
          'Mobile selection must bring details into view',
        );
        await snapshot(page, `headquarters-detail-${width}`);
        await page
          .getByRole('button', { name: 'Army organization', exact: true })
          .last()
          .click();
      }
      assert.ok(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth,
        ),
        'Headquarters must fit viewport',
      );
      await page.getByRole('button', { name: 'Close', exact: true }).click();
      await page.evaluate(() => window.__fieldCommand.model.startBattle('e1'));
      await snapshot(page, `expanded-battle-${width}`);
      await assertCanvas(page);
      if (width === 1440) {
        await page.locator('.unit-card').first().click();
        await page
          .getByRole('button', { name: 'Detach skirmishers', exact: true })
          .click();
        assert.equal((await state()).selected[0], 'u1-skirmish');
        await page
          .getByRole('button', {
            name: 'Rejoin parent regiment within 90 m',
            exact: true,
          })
          .click();
        assert.equal((await state()).selected[0], 'u1');
        await page
          .getByRole('button', { name: 'Double time (V)', exact: true })
          .click();
        assert.equal((await state()).battle.units[0].running, true);
        await page
          .getByRole('button', {
            name: 'Fall back facing enemy (F)',
            exact: true,
          })
          .click();
        assert.equal((await state()).battle.units[0].fallingBack, true);
        await page
          .getByRole('button', { name: 'Select supply train', exact: true })
          .click();
        assert.equal((await state()).selectedSupply, true);
        await snapshot(page, 'supply-train-desktop');
      }
      await checkZoom(page);
    }
    await page.evaluate(() => {
      const m = window.__fieldCommand.model;
      m.finishBattle(true);
    });
    await snapshot(page, 'expanded-after-action');
    assert.equal(await page.locator('.after-action tbody tr').count(), 5);
    await page
      .getByRole('button', { name: 'Campaign map', exact: true })
      .click();
    await page.setViewportSize({ width: 1440, height: 960 });
    for (const scenario of ['bridge', 'ridge']) {
      await page.evaluate((scenario) => {
        const m = window.__fieldCommand.model;
        m.reset();
        m.startBattle(scenario === 'ridge' ? 'e2' : 'e1');
        m.state.battle.scenario = scenario;
        m.state.battle.visibleCells = null;
        m.publish();
      }, scenario);
      await snapshot(page, `battle-${scenario}-desktop`);
      await assertCanvas(page);
      await checkZoom(page);
    }
    assert.deepEqual(errors, []);
    console.log(
      'Passed: headquarters tabs across four widths, new battle controls, three terrain maps, and nonblank map edges.',
    );
  } else if (process.env.VISUAL_ONLY) {
    for (const width of [360, 390, 1440]) {
      await page.setViewportSize({ width, height: width < 500 ? 844 : 960 });
      await page.evaluate(() => {
        const { model, controls } = window.__fieldCommand;
        model.reset();
        controls.current.scene.fit();
      });
      await page
        .getByRole('button', { name: '0.5x speed', exact: true })
        .click();
      await snapshot(page, `final-campaign-${width}`);
      assert.ok(
        await page.evaluate(() =>
          [...document.querySelectorAll('.speed-button')].every(
            (button) => button.scrollWidth <= button.clientWidth,
          ),
        ),
        'Speed labels must fit their buttons',
      );
      assert.equal((await state()).speed, 0.5);
      await page.evaluate(() => {
        const m = window.__fieldCommand.model;
        m.startBattle('e1');
        m.selectCommander('general');
      });
      await snapshot(page, `final-command-${width}`);
      const overlaps = await page.evaluate(() => {
        const scene = window.__fieldCommand.controls.current.scene;
        const canvas = document
          .querySelector('.game-map canvas')
          .getBoundingClientRect();
        const heading = document
          .querySelector('.map-heading')
          .getBoundingClientRect();
        const h = {
          x: heading.left - canvas.left,
          y: heading.top - canvas.top,
          width: heading.width,
          height: heading.height,
        };
        return scene.landmarkBounds.filter(
          (r) =>
            r.x < h.x + h.width &&
            r.x + r.width > h.x &&
            r.y < h.y + h.height &&
            r.y + r.height > h.y,
        ).length;
      });
      assert.equal(
        overlaps,
        0,
        'Terrain names must not overlap the battlefield heading',
      );
      await page.evaluate(() =>
        window.__fieldCommand.controls.current.scene.zoom(0.01),
      );
      await snapshot(page, `final-battle-overview-${width}`);
      await assertMapEdges(page);
      await assertCanvas(page);
      assert.ok(
        await page.evaluate(() =>
          window.__fieldCommand.controls.current.scene.labelHits.every(
            (r) =>
              r.x >= 0 &&
              r.y >= 0 &&
              r.x + r.width <= 1440 &&
              r.y + r.height <= 960,
          ),
        ),
        'Unit and commander labels must fit inside the overlay canvas',
      );
    }
    assert.deepEqual(errors, []);
    console.log(
      'Passed: final desktop/mobile rendering, terrain label visibility, and map-edge pixels.',
    );
  } else {
    await checkZoom(page);
    await snapshot(page, 'campaign-overview-desktop');
    await page.evaluate(() => {
      const s = window.__fieldCommand.controls.current.scene;
      s.zoom(1 / s.zoomFactor);
      s.center();
    });
    assert.equal((await state()).paused, true);
    await page
      .getByRole('button', { name: 'Intercept nearest Austrian army' })
      .click();
    assert.ok((await state()).army.path.length > 0);
    await page.getByRole('button', { name: '4x speed' }).click();
    await page
      .getByRole('button', { name: 'Resume time (Space)', exact: true })
      .click();
    await page.waitForFunction(
      () => window.__fieldCommand.model.state.mode === 'battle',
      { timeout: 30000 },
    );
    assert.equal((await state()).paused, true);
    await page.waitForTimeout(250);
    await snapshot(page, 'battle-deployment-desktop');
    assert.ok(
      await page.evaluate(
        () =>
          window.__fieldCommand.controls.current.scene.labelHits.filter((r) =>
            r.id?.startsWith('u'),
          ).length >= 4,
      ),
      'Most deployed French regiments must have visible map labels',
    );
    await assertCanvas(page);
    await page.locator('.unit-card').first().click();
    assert.deepEqual((await state()).selected, ['u1']);
    await page
      .getByRole('button', { name: 'Infantry square', exact: true })
      .click();
    assert.equal((await state()).battle.units[0].formation, 'line');
    assert.equal((await state()).battle.units[0].formationChange.to, 'square');
    await page.evaluate(() => {
      const m = window.__fieldCommand.model;
      m.state.speed = 1;
      m.state.paused = false;
      for (let i = 0; i < 45; i++) m.update(0.1);
      m.state.paused = true;
      m.publish();
    });
    await page.waitForTimeout(150);
    assert.ok((await state()).battle.units[0].formationChange.elapsed > 0);
    await snapshot(page, 'formation-transition-desktop');
    await page
      .getByRole('button', { name: 'Line formation', exact: true })
      .click();
    assert.equal((await state()).battle.units[0].queuedFormation, 'line');
    await page.evaluate(() => {
      const m = window.__fieldCommand.model;
      m.state.paused = false;
      for (let i = 0; i < 215; i++) m.update(0.1);
      m.state.paused = true;
      m.publish();
    });
    assert.equal((await state()).battle.units[0].formation, 'line');
    assert.equal((await state()).battle.units[0].formationChange, null);
    const dest = await screenPoint(380, 270);
    await page.mouse.click(dest.x, dest.y);
    assert.ok((await state()).battle.units[0].target);
    await page
      .getByRole('button', { name: 'Select all regiments (A)' })
      .click();
    assert.equal((await state()).selected.length, 5);
    await page
      .getByRole('button', { name: 'Select II Corps (W)', exact: true })
      .click();
    assert.deepEqual((await state()).selected, ['u5']);
    await page
      .getByRole('button', { name: 'Select army general (G)', exact: true })
      .click();
    assert.equal((await state()).selectedCommander, 'general');
    const leaderDestination = await screenPoint(90, 650);
    await page.mouse.click(leaderDestination.x, leaderDestination.y);
    assert.equal((await state()).battle.commanders[0].following, false);
    await snapshot(page, 'general-command-desktop');
    await page
      .getByRole('button', { name: 'Follow assigned troops', exact: true })
      .click();
    assert.equal((await state()).battle.commanders[0].following, true);
    await page
      .getByRole('button', { name: 'Select all regiments (A)' })
      .click();
    await page.getByRole('button', { name: 'Hold fire', exact: true }).click();
    assert.ok(
      (await state()).battle.units
        .filter((u) => u.side === 'player')
        .every((u) => u.holdFire),
    );
    await page.getByRole('button', { name: 'Hold fire', exact: true }).click();
    await page.getByRole('button', { name: 'Halt and hold (H)' }).click();
    await page.evaluate(() => {
      const m = window.__fieldCommand.model;
      m.state.paused = false;
      m.state.speed = 1;
      for (let i = 0; i < 350 && m.state.mode === 'battle'; i++) m.update(0.1);
      m.state.paused = true;
      m.publish();
    });
    await page.waitForTimeout(200);
    await snapshot(page, 'battle-combat-desktop');
    await page.evaluate(() => {
      const m = window.__fieldCommand.model;
      m.state.paused = false;
      for (let i = 0; i < 6000 && m.state.mode === 'battle'; i++) m.update(0.1);
      m.publish();
    });
    await page.getByRole('dialog', { name: 'Victory on the field' }).waitFor();
    const won = await state();
    assert.equal(won.report.won, true);
    assert.equal(won.cash, 11600);
    assert.ok(won.report.casualties > 0);
    await snapshot(page, 'victory-desktop');
    await page
      .getByRole('button', { name: 'Return to camp', exact: true })
      .click();
    await page.getByRole('tab', { name: 'Army', exact: true }).click();
    await page
      .locator('.hq-regiment')
      .filter({ hasText: '1st Line Regiment' })
      .click();
    await page
      .getByRole('combobox', {
        name: 'Corps for 1st Line Regiment',
        exact: true,
      })
      .selectOption('c2');
    assert.equal((await state()).units[0].corpsId, 'c2');
    await snapshot(page, 'organization-desktop');
    await page.getByRole('tab', { name: 'Armory', exact: true }).click();
    const before = await state();
    await page
      .getByRole('spinbutton', {
        name: 'Quantity for Charleville AN IX',
        exact: true,
      })
      .fill('100');
    await page
      .getByRole('button', { name: 'Buy Charleville AN IX', exact: true })
      .click();
    assert.equal(
      (await state()).inventory.improved,
      before.inventory.improved + 100,
    );
    await page
      .getByRole('button', { name: 'Sell Charleville AN IX', exact: true })
      .click();
    assert.equal((await state()).inventory.improved, before.inventory.improved);
    await snapshot(page, 'market-desktop');
    await page.getByRole('tab', { name: 'Army', exact: true }).click();
    const oldMen = (await state()).units[0].men;
    if (oldMen < 800) {
      await page.getByRole('button', { name: /^Replenish/ }).click();
      assert.ok((await state()).units[0].men > oldMen);
    }
    await snapshot(page, 'army-desktop');
    await page
      .getByRole('button', { name: 'Return to campaign', exact: true })
      .click();
    const persisted = await state();
    await page.reload();
    await page.waitForFunction(
      () => window.__fieldCommand?.controls.current?.scene?.ink,
    );
    const restored = await state();
    assert.equal(restored.cash, persisted.cash);
    assert.equal(restored.victories, 1);
    assert.deepEqual(restored.units, persisted.units);
    await page
      .getByRole('button', { name: 'New campaign', exact: true })
      .click();
    await page.getByRole('button', { name: 'Cancel', exact: true }).click();
    assert.equal((await state()).victories, 1);
    for (const width of [390, 360, 768, 1920, 2560]) {
      const mobile = await browser.newPage({
        viewport: {
          width,
          height: width === 2560 ? 800 : width > 1000 ? 1080 : 844,
        },
        deviceScaleFactor: 1,
        hasTouch: width < 500,
      });
      mobile.on('pageerror', (e) => errors.push(e.message));
      await ready(mobile);
      await assertCanvas(mobile);
      await checkZoom(mobile);
      await snapshot(mobile, `overview-${width}`);
      await mobile.evaluate(() => {
        const s = window.__fieldCommand.controls.current.scene;
        s.zoom(1 / s.zoomFactor);
        s.center();
      });
      assert.equal(
        await mobile.evaluate(
          () => document.documentElement.scrollWidth > innerWidth,
        ),
        false,
        `Horizontal overflow at ${width}px`,
      );
      await snapshot(mobile, `campaign-${width}`);
      if (width < 500) {
        await mobile.locator('.main-nav button').nth(1).click();
        await mobile.getByRole('tab', { name: 'Army', exact: true }).click();
        await snapshot(mobile, `organization-${width}`);
        assert.equal(
          await mobile.evaluate(
            () =>
              document.querySelector('.modal').scrollWidth >
              document.querySelector('.modal').clientWidth + 1,
          ),
          false,
        );
        await mobile.getByRole('tab', { name: 'Armory', exact: true }).click();
        await snapshot(mobile, `market-${width}`);
        assert.equal(
          await mobile.evaluate(
            () =>
              document.querySelector('.modal').scrollWidth >
              document.querySelector('.modal').clientWidth + 1,
          ),
          false,
        );
        await mobile
          .getByRole('button', { name: 'Buy Charleville 1777', exact: true })
          .click();
        await mobile
          .getByRole('button', { name: 'Close', exact: true })
          .click();
        await mobile.evaluate(() =>
          window.__fieldCommand.model.startBattle('e1'),
        );
        await mobile.waitForTimeout(200);
        await snapshot(mobile, `battle-${width}`);
        await mobile
          .getByRole('button', { name: 'Select army general (G)' })
          .click();
        await snapshot(mobile, `general-${width}`);
        await checkZoom(mobile);
      }
      await mobile.close();
    }
    assert.deepEqual(errors, [], 'Browser console should contain no errors');
    console.log(
      'Passed: timed formations, corps organization, independent commanders, hold fire, trading quantities, campaign/battle flow, persistence, and zoom/pan edge pixels across five viewports.',
    );
  }
} catch (error) {
  await snapshot(page, 'browser-failure');
  console.error('Browser errors:', errors);
  throw error;
} finally {
  await browser.close();
}
