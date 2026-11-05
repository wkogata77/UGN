import Phaser from 'phaser';
import { soldierPosition, FORMATIONS } from './formations.js';
import { BATTLEFIELDS, fieldFor, channelX } from './battlefields.js';
import { BattleAudio } from './audio.js';
import {
  WORLD,
  TOWNS,
  FORESTS,
  riverY,
  distance,
  countMen,
  WEAPONS,
  inEllipse,
} from './model.js';

export const MAP_PADDING = 560;
const LANDMARKS = {
  campaign: [
    ...TOWNS.map((town) => ({
      name: town.name,
      x: town.x,
      y: town.y + 45,
      size: town.major ? 22 : 18,
    })),
    { name: 'D A N U B E', x: 702, y: riverY(702) + 9, size: 17 },
  ],
};

function random(seed) {
  return () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 4294967296;
  };
}
function line(ctx, points, color, width, dash = []) {
  ctx.beginPath();
  ctx.strokeStyle = color;
  ctx.lineWidth = width;
  ctx.setLineDash(dash);
  points.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
  ctx.stroke();
  ctx.setLineDash([]);
}
function text(ctx, label, x, y, size = 16, color = '#edeade', serif = false) {
  ctx.font = `${serif ? 'italic ' : '600 '}${size}px ${serif ? 'Georgia' : 'Arial'}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.lineWidth = 3;
  ctx.strokeStyle = 'rgba(32,40,29,.62)';
  ctx.strokeText(label, x, y);
  ctx.fillStyle = color;
  ctx.fillText(label, x, y);
}
function tree(ctx, x, y, size, rand, sprite) {
  if (sprite) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate((rand() - 0.5) * 1.8);
    ctx.drawImage(sprite, -size * 2, -size * 2, size * 4, size * 4);
    ctx.restore();
    return;
  }
  ctx.fillStyle = 'rgba(25,35,22,.19)';
  ctx.beginPath();
  ctx.ellipse(
    x + size * 0.45,
    y + size * 0.6,
    size,
    size * 0.7,
    -0.4,
    0,
    Math.PI * 2,
  );
  ctx.fill();
  const colors = ['#445d3d', '#536b41', '#5b7347', '#6c7d45', '#647245'];
  for (let i = 0; i < 7; i++) {
    const tx = x + (rand() - 0.5) * size,
      ty = y + (rand() - 0.5) * size;
    ctx.fillStyle = colors[Math.floor(rand() * colors.length)];
    ctx.beginPath();
    ctx.arc(tx, ty, size * (0.35 + rand() * 0.35), 0, 7);
    ctx.fill();
    ctx.fillStyle = 'rgba(175,187,108,.15)';
    ctx.beginPath();
    ctx.arc(tx - size * 0.16, ty - size * 0.23, size * 0.3, 0, 7);
    ctx.fill();
  }
}
function house(ctx, x, y, angle, size = 1) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);
  ctx.scale(size, size);
  ctx.fillStyle = 'rgba(36,36,24,.25)';
  ctx.fillRect(-5, -1, 17, 13);
  ctx.fillStyle = '#d3c9ac';
  ctx.fillRect(-7, -5, 15, 11);
  ctx.fillStyle = '#765f4c';
  ctx.beginPath();
  ctx.moveTo(-9, -3);
  ctx.lineTo(0, -10);
  ctx.lineTo(10, -3);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = '#a08264';
  ctx.beginPath();
  ctx.moveTo(0, -10);
  ctx.lineTo(10, -3);
  ctx.lineTo(9, 5);
  ctx.lineTo(-1, -1);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = '#484535';
  ctx.fillRect(-4, 0, 3, 5);
  ctx.restore();
}
function paintLandscape(ctx, sources, mode, field = BATTLEFIELDS.village) {
  ctx.drawImage(sources.ground, 0, 0, WORLD.width, WORLD.height);
  ctx.fillStyle = 'rgba(80,117,94,.14)';
  ctx.fillRect(0, 0, WORLD.width, WORLD.height);
  const rand = random(mode === 'campaign' ? 87 : 331);
  if (mode === 'campaign') {
    const water = Array.from(
      { length: (WORLD.width + MAP_PADDING * 2) / 5 + 1 },
      (_, i) => {
        const x = i * 5 - MAP_PADDING;
        return { x, y: riverY(x) + Math.sin(x * 0.08) * 1.2 };
      },
    );
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.shadowColor = '#3e5b45';
    ctx.shadowBlur = 7;
    line(ctx, water, '#788768', 44);
    ctx.shadowBlur = 0;
    line(ctx, water, '#8d9f8d', 37);
    line(ctx, water, '#819d9a', 32);
    line(ctx, water, 'rgba(159,183,174,.42)', 24);
    for (let i = 0; i < 600; i++) {
      const x = rand() * (WORLD.width + MAP_PADDING * 2) - MAP_PADDING,
        y = riverY(x) + (rand() - 0.5) * 22;
      line(
        ctx,
        [
          { x, y },
          { x: x + 4 + rand() * 12, y: y + 1 },
        ],
        'rgba(213,225,208,.2)',
        0.8,
      );
    }
    const roads = [
      [
        { x: -MAP_PADDING, y: 960 },
        { x: -20, y: 755 },
        TOWNS[0],
        TOWNS[1],
        { x: 395, y: riverY(395) },
        { x: 390, y: 315 },
        { x: 710, y: 305 },
        { x: 900, y: 407 },
        TOWNS[5],
      ],
      [
        TOWNS[0],
        { x: 460, y: 719 },
        TOWNS[4],
        { x: 1130, y: 628 },
        { x: 1470, y: 725 },
        { x: WORLD.width + MAP_PADDING, y: 890 },
      ],
      [TOWNS[4], { x: 900, y: riverY(900) }, TOWNS[3], TOWNS[5]],
      [TOWNS[1], TOWNS[2], { x: 900, y: riverY(900) }],
    ];
    for (const road of roads) {
      line(ctx, road, 'rgba(83,73,43,.18)', 8);
      line(ctx, road, '#bab28e', 5);
      line(ctx, road, 'rgba(227,218,179,.35)', 2);
    }
    for (const x of [395, 900]) {
      ctx.save();
      ctx.translate(x, riverY(x));
      ctx.rotate(0.05);
      ctx.fillStyle = '#655f49';
      ctx.fillRect(-16, -29, 32, 58);
      ctx.fillStyle = '#b9b198';
      ctx.fillRect(-12, -30, 24, 60);
      for (let y = -26; y < 28; y += 6)
        line(
          ctx,
          [
            { x: -12, y },
            { x: 12, y },
          ],
          '#938c72',
          1,
        );
      ctx.restore();
    }
  } else {
    for (const h of field.hills) {
      for (let scale = 1.3; scale > 0.2; scale -= 0.15) {
        ctx.beginPath();
        ctx.strokeStyle = 'rgba(72,86,48,.13)';
        ctx.lineWidth = 1.3;
        ctx.ellipse(h.x, h.y, h.rx * scale, h.ry * scale, -0.3, 0, Math.PI * 2);
        ctx.stroke();
      }
    }
    if (field.river) {
      const water = Array.from({ length: 417 }, (_, i) => {
        const y = i * 5 - MAP_PADDING;
        return { x: channelX(y), y };
      });
      line(ctx, water, '#8da28c', 76);
      line(ctx, water, '#77979b', 61);
      line(ctx, water, '#9eb8af', 42);
    }
    for (const road of field.roads) {
      line(ctx, road, 'rgba(105,96,62,.2)', 13);
      line(ctx, road, '#b7ac80', 8);
      line(ctx, road, '#c1b893', 3);
    }
    if (field.river) {
      ctx.fillStyle = '#68614d';
      ctx.fillRect(675, 447, 90, 66);
      ctx.fillStyle = '#b5ad94';
      ctx.fillRect(673, 453, 94, 54);
      for (let x = 677; x < 767; x += 7)
        line(
          ctx,
          [
            { x, y: 453 },
            { x, y: 507 },
          ],
          '#8b846e',
          1,
        );
    }
  }
  for (const forest of mode === 'campaign' ? FORESTS.campaign : field.forests) {
    const points = [];
    const count = Math.round((forest.rx * forest.ry) / 240);
    for (let i = 0; i < count; i++) {
      const p = {
        x: forest.x + (rand() - 0.5) * forest.rx * 2,
        y: forest.y + (rand() - 0.5) * forest.ry * 2,
      };
      if (
        inEllipse(p, forest) &&
        (mode !== 'campaign' || Math.abs(p.y - riverY(p.x)) > 40)
      )
        points.push(p);
    }
    points
      .sort((a, b) => a.y - b.y)
      .forEach((p) => tree(ctx, p.x, p.y, 9 + rand() * 8, rand, sources.trees));
  }
  const towns = mode === 'campaign' ? TOWNS : field.towns;
  for (const town of towns) {
    if (sources.village) {
      const width = mode === 'battle' ? 140 : town.major ? 100 : 76;
      ctx.drawImage(
        sources.village,
        town.x - width / 2,
        town.y - width / 3,
        width,
        (width * 2) / 3,
      );
    } else {
      for (let i = 0; i < (town.major ? 22 : 10); i++)
        house(
          ctx,
          town.x + (rand() - 0.5) * 80,
          town.y + (rand() - 0.5) * 54,
          rand() * 0.5,
          0.6 + rand() * 0.6,
        );
      house(ctx, town.x, town.y - 4, 0, 1.8);
    }
  }
}
function flag(ctx, x, y, french, t = 0, scale = 1) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  ctx.strokeStyle = '#d9c38a';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(0, 14);
  ctx.lineTo(0, -29);
  ctx.stroke();
  const wave = Math.sin(t * 2) * 1.5;
  const colors = french
    ? ['#426d9a', '#f0ead7', '#b84940']
    : ['#e7c35e', '#302f28', '#e7c35e'];
  colors.forEach((color, i) => {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(i * 9 + 1, -28 + (i / 3) * wave);
    ctx.lineTo(i * 9 + 10, -28 + ((i + 1) / 3) * wave);
    ctx.lineTo(i * 9 + 10, -9 + ((i + 1) / 3) * wave);
    ctx.lineTo(i * 9 + 1, -9 + (i / 3) * wave);
    ctx.closePath();
    ctx.fill();
  });
  ctx.fillStyle = '#cfb574';
  ctx.beginPath();
  ctx.arc(0, -32, 3, 0, 7);
  ctx.fill();
  ctx.restore();
}
function soldier(ctx, x, y, player, kind, time, moving) {
  const stride = moving ? Math.sin(time * 14 + y) * 1.3 : 0;
  ctx.fillStyle = 'rgba(30,30,20,.3)';
  ctx.beginPath();
  ctx.ellipse(x + 2, y + 3, kind === 'cavalry' ? 5 : 3, 2, 0.3, 0, 7);
  ctx.fill();
  if (kind === 'cavalry') {
    ctx.fillStyle = '#685141';
    ctx.fillRect(x - 4, y - 1, 9, 4);
    ctx.fillStyle = '#413b2b';
    ctx.fillRect(x + 3, y - 3, 3, 4);
  }
  ctx.fillStyle = '#dad3bb';
  ctx.fillRect(x - 1.5 + stride * 0.3, y + 1, 1.4, 3);
  ctx.fillRect(x + 0.5 - stride * 0.3, y + 1, 1.4, 3);
  ctx.fillStyle = player ? '#263c5d' : '#e2d9bc';
  ctx.fillRect(x - 2, y - 2, 4, 4);
  ctx.fillStyle = player ? '#e5dfc9' : '#b14136';
  ctx.fillRect(x - 1, y - 2, 0.8, 4);
  ctx.fillStyle = '#c9aa87';
  ctx.fillRect(x - 1, y - 4, 2, 2);
  ctx.fillStyle = '#252b29';
  ctx.fillRect(x - 1.7, y - 6, 3.4, 2.5);
  ctx.strokeStyle = '#8d7c58';
  ctx.lineWidth = 0.7;
  ctx.beginPath();
  ctx.moveTo(x + 3, y + 1);
  ctx.lineTo(x + 3, y - 6);
  ctx.stroke();
}

export function createGame(parent, model, onReady) {
  class FieldScene extends Phaser.Scene {
    preload() {
      this.load.image('ground', '/assets/terrain.png');
      this.load.image('trees', '/assets/trees.png');
      this.load.image('village-art', '/assets/village.png');
    }
    create() {
      const sources = Object.fromEntries(
        ['ground', 'trees', 'village'].map((key) => [
          key,
          this.textures
            .get(key === 'village' ? 'village-art' : key)
            .getSourceImage(),
        ]),
      );
      const smallTrees = document.createElement('canvas');
      smallTrees.width = 160;
      smallTrees.height = 160;
      smallTrees.getContext('2d').drawImage(sources.trees, 0, 0, 160, 160);
      sources.trees = smallTrees;
      this.audio = new BattleAudio(() => model.state.settings);
      this.events.once('shutdown', () => this.audio.destroy());
      const fringe = this.textures.createCanvas(
        'fringe',
        WORLD.width + MAP_PADDING * 2,
        WORLD.height + MAP_PADDING * 2,
      );
      const fc = fringe.context;
      for (let row = -1; row <= 1; row++)
        for (let col = -1; col <= 1; col++) {
          fc.save();
          fc.translate(
            MAP_PADDING + col * WORLD.width + (col % 2 ? WORLD.width : 0),
            MAP_PADDING + row * WORLD.height + (row % 2 ? WORLD.height : 0),
          );
          fc.scale(col % 2 ? -1 : 1, row % 2 ? -1 : 1);
          fc.drawImage(sources.ground, 0, 0, WORLD.width, WORLD.height);
          fc.restore();
        }
      fc.fillStyle = 'rgba(80,117,94,.14)';
      fc.fillRect(0, 0, fringe.width, fringe.height);
      fringe.refresh();
      for (const key of ['campaign', ...Object.keys(BATTLEFIELDS)]) {
        const mode = key === 'campaign' ? 'campaign' : 'battle';
        const tex = this.textures.createCanvas(
          key,
          fringe.width,
          fringe.height,
        );
        tex.context.drawImage(fringe.getSourceImage(), 0, 0);
        tex.context.save();
        tex.context.translate(MAP_PADDING, MAP_PADDING);
        paintLandscape(tex.context, sources, mode, BATTLEFIELDS[key]);
        tex.context.restore();
        tex.refresh();
      }
      this.textures.remove('fringe');
      this.land = this.add
        .image(
          -MAP_PADDING,
          -MAP_PADDING,
          model.state.mode === 'battle'
            ? model.state.battle.scenario
            : 'campaign',
        )
        .setOrigin(0);
      this.ink = this.textures.createCanvas('ink', WORLD.width, WORLD.height);
      this.add.image(0, 0, 'ink').setOrigin(0);
      this.lastMode = model.state.mode;
      this.lastScenario = model.state.battle?.scenario;
      this.smoke = [];
      this.seenShots = new Map();
      this.cameraUiClock = 0;
      this.lastCameraView = '';
      this.zoomFactor = 1;
      this.drag = null;
      this.cameras.main.setBackgroundColor('#6f8053');
      this.fit();
      this.scale.on('resize', () => this.fit());
      this.input.mouse.disableContextMenu();
      this.input.on('pointerdown', (p) => {
        this.audio.unlock();
        this.drag = {
          x: p.x,
          y: p.y,
          wx: p.worldX,
          wy: p.worldY,
          scrollX: this.cameras.main.scrollX,
          scrollY: this.cameras.main.scrollY,
          pan: p.middleButtonDown() || p.event.altKey,
          touch: p.wasTouch,
          shift: p.event.shiftKey,
          right: p.rightButtonDown(),
        };
      });
      this.input.on('pointermove', (p) => {
        if (!this.drag || !p.isDown) return;
        if (
          this.drag.pan ||
          ((model.state.mode === 'campaign' ||
            (this.drag.touch && model.state.orderMode === 'move')) &&
            Math.hypot(p.x - this.drag.x, p.y - this.drag.y) > 8)
        ) {
          this.drag.pan = true;
          this.cameras.main.setScroll(
            this.drag.scrollX - (p.x - this.drag.x) / this.cameras.main.zoom,
            this.drag.scrollY - (p.y - this.drag.y) / this.cameras.main.zoom,
          );
        }
      });
      this.input.on('pointerup', (p) => {
        const drag = this.drag;
        this.drag = null;
        if (!drag || drag.pan) return;
        const point = this.cameras.main.getWorldPoint(p.x, p.y);
        if (point.x < 0 || point.y < 0 || point.x > 1440 || point.y > 960)
          return;
        this.audio.play('order', point.x);
        if (model.state.mode === 'campaign') model.moveArmy(point);
        else {
          if (model.state.orderMode === 'deploy') {
            model.deploy(point);
            return;
          }
          if (
            (drag.right || model.state.orderMode === 'frontline') &&
            Math.hypot(p.x - drag.x, p.y - drag.y) > 12
          ) {
            if (
              model.state.selected.length > 1 ||
              model.state.orderMode === 'frontline'
            )
              model.frontline({ x: drag.wx, y: drag.wy }, point);
            else
              model.moveUnits(
                { x: drag.wx, y: drag.wy },
                null,
                drag.shift,
                Math.atan2(point.y - drag.wy, point.x - drag.wx),
              );
            return;
          }
          const b = model.state.battle;
          const active = b.units.filter(
            (u) => !u.routed && u.men > 0 && u.arrival <= b.time && u.visible,
          );
          if (Math.hypot(p.x - drag.x, p.y - drag.y) > 12) {
            const ids = active
              .filter(
                (u) =>
                  u.side === 'player' &&
                  u.x >= Math.min(point.x, drag.wx) &&
                  u.x <= Math.max(point.x, drag.wx) &&
                  u.y >= Math.min(point.y, drag.wy) &&
                  u.y <= Math.max(point.y, drag.wy),
              )
              .map((u) => u.id);
            if (ids.length)
              model.select(
                drag.shift
                  ? [...new Set([...model.state.selected, ...ids])]
                  : ids,
              );
          } else {
            const labelHit = this.labelHits.find(
              (r) =>
                point.x >= r.x &&
                point.x <= r.x + r.width &&
                point.y >= r.y &&
                point.y <= r.y + r.height,
            );
            const commander = b.commanders.find(
              (c) => c.id === labelHit?.id || distance(c, point) < 23,
            );
            const wagon = b.wagons.find(
              (w) =>
                w.side === 'player' &&
                w.health > 0 &&
                (distance(w, point) < 30 || labelHit?.id === w.id),
            );
            if (wagon && !p.rightButtonReleased()) {
              model.selectSupply();
              return;
            }
            if (commander && !p.rightButtonReleased()) {
              model.selectCommander(commander.id);
              return;
            }
            const hit =
              active.find((u) => u.id === labelHit?.id) ||
              active
                .filter((u) => distance(u, point) < 55)
                .sort((a, b) => distance(a, point) - distance(b, point))[0];
            if (hit?.side === 'player' && !p.rightButtonReleased())
              model.select(
                drag.shift
                  ? [...new Set([...model.state.selected, hit.id])]
                  : [hit.id],
              );
            else
              model.moveUnits(
                point,
                hit?.side === 'enemy' ? hit.id : null,
                drag.shift,
              );
          }
        }
      });
      this.input.on('wheel', (_p, _objects, _dx, dy) =>
        this.zoom(dy < 0 ? 1.15 : 1 / 1.15),
      );
      onReady({
        zoom: (amount) => this.zoom(amount),
        center: () => this.center(),
        scene: this,
        audio: this.audio,
      });
    }
    fit() {
      const w = this.scale.width,
        h = this.scale.height;
      this.baseZoom =
        w < 600 ? Math.max(w / 900, h / 960) : Math.max(w / 1440, h / 960);
      this.minimumZoom = Math.max(
        this.baseZoom * 0.58,
        w / (WORLD.width + MAP_PADDING * 2),
        h / (WORLD.height + MAP_PADDING * 2),
      );
      this.zoomFactor = Math.max(
        this.minimumZoom / this.baseZoom,
        this.zoomFactor,
      );
      this.cameras.main.setZoom(this.baseZoom * this.zoomFactor);
      this.cameras.main.setBounds(
        -MAP_PADDING,
        -MAP_PADDING,
        WORLD.width + MAP_PADDING * 2,
        WORLD.height + MAP_PADDING * 2,
      );
      this.center();
    }
    center() {
      const s = model.state;
      if (this.scale.width < 600)
        this.cameras.main.centerOn(
          s.mode === 'campaign' ? s.army.x + 180 : 520,
          s.mode === 'campaign' ? s.army.y : 480,
        );
      else this.cameras.main.centerOn(720, 480);
    }
    zoom(amount) {
      this.zoomFactor = Phaser.Math.Clamp(
        this.zoomFactor * amount,
        this.minimumZoom / this.baseZoom,
        2.8,
      );
      this.cameras.main.setZoom(this.baseZoom * this.zoomFactor);
      model.publish(false);
    }
    labelPosition(unit, preferred) {
      const camera = this.cameras.main,
        view = camera.worldView;
      if (
        unit.x < view.x - 30 ||
        unit.y < view.y - 30 ||
        unit.x > view.right + 30 ||
        unit.y > view.bottom + 30
      )
        return null;
      const candidates = [
        preferred,
        { x: -97, y: 8 },
        { x: 97, y: 8 },
        { x: -97, y: 78 },
        { x: 97, y: 78 },
        { x: -97, y: 110 },
        { x: 97, y: 110 },
        { x: -97, y: -70 },
        { x: 97, y: -70 },
        { x: 0, y: -85 },
        { x: 0, y: 95 },
      ];
      const overlaps = (a, b) =>
        a.x < b.x + b.width &&
        a.x + a.width > b.x &&
        a.y < b.y + b.height &&
        a.y + a.height > b.y;
      for (const offset of candidates) {
        const x = unit.x + offset.x,
          y = unit.y + offset.y;
        const rect = {
          x: (x - 65 - view.x) * camera.zoom,
          y: (y - 16 - view.y) * camera.zoom,
          width: 130 * camera.zoom,
          height: 50 * camera.zoom,
        };
        if (
          x - 65 < 0 ||
          y - 16 < 0 ||
          x + 65 > WORLD.width ||
          y + 34 > WORLD.height ||
          rect.x < 5 ||
          rect.y < 5 ||
          rect.x + rect.width > this.scale.width - 5 ||
          rect.y + rect.height > this.scale.height - 5
        )
          continue;
        if (this.labelObstacles.some((obstacle) => overlaps(rect, obstacle)))
          continue;
        this.labelObstacles.push(rect);
        this.labelHits.push({
          id: unit.id,
          x: x - 65,
          y: y - 16,
          width: 130,
          height: 50,
        });
        return { x, y };
      }
      return null;
    }
    update(_time, delta) {
      if (!this.ink) return;
      model.update(delta / 1000);
      const s = model.state;
      if (
        this.lastMode !== s.mode ||
        this.lastScenario !== s.battle?.scenario
      ) {
        this.lastMode = s.mode;
        this.lastScenario = s.battle?.scenario;
        this.land.setTexture(
          s.mode === 'battle' ? s.battle.scenario : 'campaign',
        );
        this.smoke = [];
        this.seenShots.clear();
        this.audio.lastMarch = 0;
        this.zoomFactor = 1;
        this.fit();
      }
      this.cameraUiClock += delta;
      if (this.cameraUiClock >= 120) {
        this.cameraUiClock = 0;
        const camera = this.cameras.main;
        const view = `${camera.scrollX.toFixed(1)},${camera.scrollY.toFixed(1)},${camera.zoom.toFixed(3)}`;
        if (view !== this.lastCameraView) {
          this.lastCameraView = view;
          model.publish(false);
        }
      }
      const ctx = this.ink.context;
      ctx.clearRect(0, 0, 1440, 960);
      ctx.strokeStyle = 'rgba(233,225,186,.45)';
      ctx.lineWidth = 2;
      ctx.setLineDash([12, 10]);
      ctx.strokeRect(3, 3, WORLD.width - 6, WORLD.height - 6);
      ctx.setLineDash([]);
      // Keep unit names clear of the fixed HUD and previously placed names.
      const bounds = parent.getBoundingClientRect();
      this.labelHits = [];
      this.labelObstacles = [
        ...parent.parentElement.querySelectorAll(
          '.map-heading, .time-panel, .objective-panel, .orders-bar, .advanced-orders, .order-context, .minimap, .map-tools, .dispatch-panel, .toast',
        ),
      ]
        .map((el) => {
          const r = el.getBoundingClientRect();
          return {
            x: r.left - bounds.left - 5,
            y: r.top - bounds.top - 5,
            width: r.width + 10,
            height: r.height + 10,
          };
        })
        .filter((r) => r.width > 10 && r.height > 10);
      if (s.mode === 'battle') {
        const camera = this.cameras.main,
          view = camera.worldView;
        for (const u of s.battle.units.filter(
          (u) => u.men > 0 && u.arrival <= s.battle.time && u.visible,
        )) {
          this.labelObstacles.push({
            x: (u.x - 25 - view.x) * camera.zoom,
            y: (u.y - 65 - view.y) * camera.zoom,
            width: 50 * camera.zoom,
            height: 130 * camera.zoom,
          });
        }
      }
      if (s.mode === 'campaign') this.drawCampaign(ctx, s);
      else this.drawBattle(ctx, s);
      this.drawLandmarks(ctx, s.mode);
      this.ink.refresh();
    }
    drawLandmarks(ctx, mode) {
      const camera = this.cameras.main,
        view = camera.worldView;
      this.landmarkBounds = [];
      const field = fieldFor(model.state.battle);
      const landmarks =
        mode === 'campaign'
          ? LANDMARKS.campaign
          : [
              {
                name: field.name,
                x: field.towns[0].x,
                y: field.towns[0].y - 62,
                size: 18,
              },
              ...field.hills.map((h, i) => ({
                name: i ? 'Eastern heights' : 'West ridge',
                x: h.x,
                y: h.y + h.ry * 0.65,
                size: 17,
              })),
            ];
      for (const landmark of landmarks) {
        ctx.font = `italic ${landmark.size}px Georgia`;
        const width = ctx.measureText(landmark.name).width + 8;
        const rect = {
          x: (landmark.x - width / 2 - view.x) * camera.zoom,
          y: (landmark.y - landmark.size / 2 - 4 - view.y) * camera.zoom,
          width: width * camera.zoom,
          height: (landmark.size + 8) * camera.zoom,
        };
        if (
          rect.x < 0 ||
          rect.y < 0 ||
          rect.x + rect.width > this.scale.width ||
          rect.y + rect.height > this.scale.height ||
          [...this.labelObstacles, ...this.landmarkBounds].some(
            (other) =>
              rect.x < other.x + other.width &&
              rect.x + rect.width > other.x &&
              rect.y < other.y + other.height &&
              rect.y + rect.height > other.y,
          )
        )
          continue;
        this.landmarkBounds.push(rect);
        text(
          ctx,
          landmark.name,
          landmark.x,
          landmark.y,
          landmark.size,
          '#eee6cb',
          true,
        );
      }
    }
    drawCampaign(ctx, s) {
      if (s.army.path.length) {
        line(ctx, [s.army, ...s.army.path], 'rgba(29,45,35,.45)', 7);
        line(ctx, [s.army, ...s.army.path], '#edda9c', 2.5, [8, 7]);
        const dest = s.army.path.at(-1);
        ctx.strokeStyle = '#f7df9f';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(dest.x, dest.y, 12, 0, 7);
        ctx.stroke();
        line(
          ctx,
          [
            { x: dest.x - 18, y: dest.y },
            { x: dest.x + 18, y: dest.y },
          ],
          '#f7df9f',
          2,
        );
        line(
          ctx,
          [
            { x: dest.x, y: dest.y - 18 },
            { x: dest.x, y: dest.y + 18 },
          ],
          '#f7df9f',
          2,
        );
      }
      const armies = [
        {
          ...s.army,
          player: true,
          name: 'YOUR ARMY',
          strength: countMen(s.units),
        },
        ...s.enemies
          .filter((e) => !e.defeated)
          .map((e) => ({
            ...e,
            x: model.enemyVisible(e) ? e.x : e.intel.x,
            y: model.enemyVisible(e) ? e.y : e.intel.y,
            strength: e.intel.strength,
            uncertain: !model.enemyVisible(e),
          })),
      ];
      for (const army of armies) {
        ctx.save();
        ctx.translate(army.x, army.y);
        if (army.uncertain) ctx.globalAlpha = 0.45;
        ctx.fillStyle = 'rgba(32,40,25,.2)';
        ctx.beginPath();
        ctx.ellipse(0, 7, 44, 19, 0, 0, 7);
        ctx.fill();
        if (army.player) {
          ctx.strokeStyle = '#f0d99c';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.ellipse(0, 7, 48, 23, 0, 0, 7);
          ctx.stroke();
        }
        for (let i = 0; i < 21; i++)
          soldier(
            ctx,
            -29 + (i % 7) * 8,
            -2 + Math.floor(i / 7) * 7,
            army.player,
            'infantry',
            s.hours * 10,
            !!army.path.length,
          );
        flag(ctx, -6, -7, army.player, s.hours * 5, 1.2);
        ctx.restore();
        const label = this.labelPosition(army, { x: 0, y: 51 });
        if (!label) continue;
        ctx.save();
        ctx.translate(label.x, label.y - 51);
        const width = army.player ? 138 : 126;
        ctx.fillStyle = army.player ? '#2b4242' : '#633f39';
        ctx.fillRect(-width / 2, 37, width, 26);
        ctx.fillStyle = army.player ? '#d2bc7c' : '#bd8372';
        ctx.fillRect(-width / 2, 37, 3, 26);
        text(ctx, army.name, 0, 51, 13, '#f6edda');
        text(
          ctx,
          army.uncertain
            ? 'Last reported'
            : `${army.player ? '' : '~'}${army.strength.toLocaleString()}`,
          0,
          79,
          15,
          '#fff3ce',
        );
        ctx.restore();
      }
    }
    drawBattle(ctx, s) {
      const b = s.battle;
      this.audio.tick(b, s.paused);
      this.drawBattlefieldState(ctx, s);
      this.drawWagons(ctx, s);
      this.drawCommanders(ctx, s);
      for (const u of b.units) {
        if (u.arrival > b.time || u.men <= 0 || !u.visible) continue;
        const selected =
          s.selected.includes(u.id) && u.side === 'player' && !u.routed;
        if (selected && u.target)
          line(
            ctx,
            [
              u,
              u.target,
              ...(u.waypoints || []),
              ...(u.orderQueue || []).map((o) => o.point),
            ],
            '#dfc98b',
            2,
            [7, 6],
          );
        if (selected && s.selected.length === 1) {
          ctx.beginPath();
          ctx.strokeStyle = 'rgba(246,228,172,.25)';
          ctx.fillStyle = 'rgba(241,224,175,.025)';
          ctx.lineWidth = 1.5;
          ctx.arc(u.x, u.y, WEAPONS[u.weapon].range, 0, 7);
          ctx.fill();
          ctx.stroke();
        }
        ctx.save();
        ctx.translate(u.x, u.y);
        ctx.rotate(u.facing - Math.PI / 2);
        ctx.globalAlpha = u.routed ? 0.55 : 1;
        const count = Math.min(100, Math.max(4, Math.ceil(u.men / 8)));
        const positions = Array.from({ length: count }, (_, i) => {
          const p = soldierPosition(u, i, count);
          return u.role === 'skirmishers' ? { x: p.x * 2, y: p.y * 2.2 } : p;
        });
        const left = Math.min(...positions.map((p) => p.x)) - 7,
          top = Math.min(...positions.map((p) => p.y)) - 9;
        const width = Math.max(...positions.map((p) => p.x)) - left + 7,
          height = Math.max(...positions.map((p) => p.y)) - top + 9;
        if (selected) {
          ctx.fillStyle = 'rgba(232,212,155,.14)';
          ctx.strokeStyle = u.formationChange ? '#efbb71' : '#e7ce8e';
          ctx.lineWidth = 1.3;
          ctx.fillRect(left, top, width, height);
          ctx.strokeRect(left, top, width, height);
        }
        if (u.kind === 'artillery') {
          for (let i = 0; i < Math.ceil(u.men / 30); i++) {
            const x = (i - Math.ceil(u.men / 30) / 2) * 20;
            ctx.fillStyle = '#393e30';
            ctx.fillRect(x - 6, -3, 3, 10);
            ctx.fillRect(x + 5, -3, 3, 10);
            ctx.fillStyle = '#8d875d';
            ctx.fillRect(x - 2, -10 + u.flash * 9, 6, 18);
            if (u.limbered) {
              ctx.fillStyle = '#6a7452';
              ctx.fillRect(x - 5, 15, 13, 16);
              ctx.fillStyle = '#453d32';
              ctx.fillRect(x - 7, 18, 3, 10);
              ctx.fillRect(x + 7, 18, 3, 10);
            }
            soldier(
              ctx,
              x - 9,
              5,
              u.side === 'player',
              'infantry',
              b.time,
              !!u.target,
            );
          }
        } else {
          for (let i = 0; i < count; i++) {
            const { x, y } = positions[i];
            soldier(
              ctx,
              x,
              y,
              u.side === 'player',
              u.dismounted ? 'infantry' : u.kind,
              b.time,
              !!u.target || u.routed || !!u.formationChange,
            );
          }
        }
        ctx.restore();
        flag(ctx, u.x - 8, u.y - 30, u.side === 'player', b.time, 0.8);
        if (u.flash > 0 && u.firedAt) {
          if (this.seenShots.get(u.id) !== u.shotTime) {
            this.seenShots.set(u.id, u.shotTime);
            if (!s.paused)
              this.audio.play(
                u.shotKind || (u.kind === 'artillery' ? 'cannon' : 'musket'),
                u.x,
              );
            this.smoke.push({
              x: u.x + Math.cos(u.facing) * 20,
              y: u.y + Math.sin(u.facing) * 20,
              time: b.time,
              artillery: u.kind === 'artillery',
            });
          }
          ctx.globalAlpha = u.flash / 0.45;
          line(
            ctx,
            [u, u.firedAt],
            u.kind === 'artillery'
              ? 'rgba(230,207,136,.8)'
              : 'rgba(245,237,184,.35)',
            u.kind === 'artillery' ? 2.5 : 1,
          );
          ctx.globalAlpha = 1;
        }
        const label = this.labelPosition(u, {
          x: u.side === 'player' ? -97 : 97,
          y: 8,
        });
        if (!label) continue;
        const labelX = label.x,
          labelY = label.y;
        if (Math.abs(labelY - u.y) > 40)
          line(
            ctx,
            [u, { x: labelX + (labelX < u.x ? 62 : -62), y: labelY }],
            'rgba(227,220,170,.5)',
            1,
            [3, 4],
          );
        ctx.fillStyle = u.routed
          ? '#6d6351'
          : u.side === 'player'
            ? '#314752'
            : '#734940';
        ctx.fillRect(labelX - 62, labelY - 12, 124, 24);
        const name = u.routed
          ? 'ROUTING'
          : u.flankedUntil > b.time
            ? 'FLANKED'
            : u.name;
        text(
          ctx,
          name.length > 21 ? `${name.slice(0, 19)}..` : name,
          labelX,
          labelY,
          11,
          '#f3eddc',
        );
        ctx.fillStyle = '#423f32';
        ctx.fillRect(labelX - 62, labelY + 12, 124, 3);
        ctx.fillStyle = u.formationChange
          ? '#e6b86e'
          : u.side === 'player'
            ? '#96b1b1'
            : '#c38b7a';
        ctx.fillRect(
          labelX - 62,
          labelY + 12,
          124 *
            (u.formationChange
              ? u.formationChange.elapsed / u.formationChange.duration
              : u.morale / 100),
          3,
        );
        text(
          ctx,
          u.formationChange
            ? `${FORMATIONS[u.formationChange.to].name} ${Math.ceil(u.formationChange.duration - u.formationChange.elapsed)}s`
            : u.blocked || Math.ceil(u.men).toLocaleString(),
          labelX,
          labelY + 28,
          12,
          '#f8edce',
        );
      }
      this.smoke = this.smoke.filter((p) => b.time - p.time < 3.4);
      for (const puff of this.smoke) {
        const age = b.time - puff.time,
          radius = (puff.artillery ? 16 : 10) + age * 12;
        const x = puff.x + age * 11,
          y = puff.y - age * 6;
        const mist = ctx.createRadialGradient(x, y, 0, x, y, radius);
        mist.addColorStop(0, `rgba(232,230,212,${0.55 * (1 - age / 3.4)})`);
        mist.addColorStop(1, 'rgba(232,230,212,0)');
        ctx.fillStyle = mist;
        ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
      }
      if (this.drag && !this.drag.pan) {
        const p = this.input.activePointer,
          end = this.cameras.main.getWorldPoint(p.x, p.y);
        if (Math.hypot(p.x - this.drag.x, p.y - this.drag.y) > 12) {
          if (this.drag.right || s.orderMode === 'frontline') {
            line(
              ctx,
              [{ x: this.drag.wx, y: this.drag.wy }, end],
              '#ead399',
              3,
              [8, 5],
            );
            const units = model.selectedUnits();
            units.forEach((u, i) => {
              const t = units.length === 1 ? 0.5 : i / (units.length - 1),
                x = this.drag.wx + (end.x - this.drag.wx) * t,
                y = this.drag.wy + (end.y - this.drag.wy) * t;
              ctx.strokeStyle = '#eee0b1';
              ctx.strokeRect(x - 13, y - 7, 26, 14);
            });
            return;
          }
          ctx.fillStyle = 'rgba(230,216,155,.1)';
          ctx.strokeStyle = '#edda9c';
          ctx.lineWidth = 1;
          ctx.fillRect(
            this.drag.wx,
            this.drag.wy,
            end.x - this.drag.wx,
            end.y - this.drag.wy,
          );
          ctx.strokeRect(
            this.drag.wx,
            this.drag.wy,
            end.x - this.drag.wx,
            end.y - this.drag.wy,
          );
        }
      }
    }
    drawBattlefieldState(ctx, s) {
      const b = s.battle,
        field = fieldFor(b);
      if (b.visibleCells) {
        if (!this.fog) {
          this.fog = document.createElement('canvas');
          this.fog.width = 30;
          this.fog.height = 20;
        }
        if (this.fogCells !== b.visibleCells) {
          const fog = this.fog.getContext('2d');
          fog.clearRect(0, 0, 30, 20);
          b.visibleCells.forEach((visible, i) => {
            if (!visible) {
              fog.fillStyle = 'rgba(21,35,39,.67)';
              fog.fillRect(i % 30, Math.floor(i / 30), 1, 1);
            }
          });
          this.fogCells = b.visibleCells;
        }
        ctx.drawImage(this.fog, 0, 0, WORLD.width, WORLD.height);
      }
      const objective = field.objective;
      ctx.strokeStyle = b.objective.owner === 'enemy' ? '#ce9a85' : '#d5c790';
      ctx.fillStyle =
        b.objective.owner === 'player'
          ? 'rgba(142,187,195,.12)'
          : 'rgba(229,217,160,.05)';
      ctx.lineWidth = 2;
      ctx.setLineDash([10, 8]);
      ctx.beginPath();
      ctx.arc(objective.x, objective.y, objective.radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.setLineDash([]);
      flag(
        ctx,
        objective.x,
        objective.y - 5,
        b.objective.owner === 'player',
        b.time,
        0.65,
      );
      if (!b.time) {
        const x = b.playerEdge === 'west' ? 40 : 1050;
        ctx.fillStyle = 'rgba(129,179,189,.055)';
        ctx.strokeStyle = 'rgba(187,218,219,.55)';
        ctx.lineWidth = 1.5;
        ctx.setLineDash([7, 9]);
        ctx.fillRect(x, 65, 350, 830);
        ctx.strokeRect(x, 65, 350, 830);
        ctx.setLineDash([]);
      }
    }
    drawWagons(ctx, s) {
      for (const wagon of s.battle.wagons) {
        if (!wagon.visible) continue;
        const selected = s.selectedSupply && wagon.side === 'player';
        if (selected && wagon.health > 0) {
          ctx.strokeStyle = 'rgba(228,208,139,.6)';
          ctx.lineWidth = 1.5;
          ctx.setLineDash([6, 8]);
          ctx.beginPath();
          ctx.arc(wagon.x, wagon.y, 145, 0, Math.PI * 2);
          ctx.stroke();
          ctx.setLineDash([]);
          if (wagon.target)
            line(
              ctx,
              [wagon, wagon.target, ...wagon.waypoints],
              '#e4cf96',
              2,
              [6, 5],
            );
        }
        ctx.save();
        ctx.translate(wagon.x, wagon.y);
        ctx.globalAlpha = wagon.health > 0 ? 1 : 0.45;
        ctx.fillStyle = '#262a25';
        ctx.beginPath();
        ctx.ellipse(4, 10, 28, 17, 0, 0, 7);
        ctx.fill();
        for (const x of [-21, 17]) {
          ctx.fillStyle = '#423c2e';
          ctx.fillRect(x, -13, 5, 12);
          ctx.fillRect(x, 12, 5, 12);
        }
        ctx.fillStyle = '#6b684c';
        ctx.fillRect(-18, -14, 37, 37);
        ctx.fillStyle = wagon.health > 0 ? '#c6c4ad' : '#51483a';
        ctx.beginPath();
        ctx.roundRect(-17, -19, 35, 35, 8);
        ctx.fill();
        line(
          ctx,
          [
            { x: -13, y: -14 },
            { x: -13, y: 11 },
          ],
          '#919380',
          2,
        );
        line(
          ctx,
          [
            { x: 13, y: -14 },
            { x: 13, y: 11 },
          ],
          '#919380',
          2,
        );
        ctx.restore();
        const label = this.labelPosition(wagon, { x: -95, y: 10 });
        if (label) {
          ctx.fillStyle = '#4a5043';
          ctx.fillRect(label.x - 62, label.y - 12, 124, 24);
          text(
            ctx,
            wagon.health <= 0 ? 'TRAIN LOST' : 'SUPPLY TRAIN',
            label.x,
            label.y,
            10,
            '#ece0bb',
          );
          text(
            ctx,
            wagon.underAttack
              ? 'Under attack'
              : `${Math.ceil(wagon.stock)} stores`,
            label.x,
            label.y + 25,
            10,
            '#e4d8b2',
          );
        }
      }
    }
    drawCommanders(ctx, s) {
      for (const c of s.battle.commanders) {
        const selected = s.selectedCommander === c.id;
        if (selected || c.rallyFlash > 0) {
          ctx.fillStyle = c.shaken
            ? 'rgba(197,116,92,.06)'
            : 'rgba(219,197,127,.05)';
          ctx.strokeStyle = c.shaken ? '#b97d68' : 'rgba(233,212,152,.6)';
          ctx.lineWidth = 1.5;
          ctx.setLineDash([7, 7]);
          ctx.beginPath();
          ctx.arc(c.x, c.y, c.radius, 0, Math.PI * 2);
          ctx.fill();
          ctx.stroke();
          ctx.setLineDash([]);
          if (c.target) line(ctx, [c, c.target], '#ecd9a1', 1.5, [5, 5]);
        }
        ctx.save();
        ctx.translate(c.x, c.y);
        ctx.fillStyle = 'rgba(29,37,24,.3)';
        ctx.beginPath();
        ctx.ellipse(0, 7, 24, 13, 0, 0, 7);
        ctx.fill();
        ctx.strokeStyle = selected ? '#f0d491' : '#aa9d70';
        ctx.lineWidth = selected ? 2 : 1;
        ctx.beginPath();
        ctx.ellipse(0, 4, 24, 18, 0, 0, 7);
        ctx.stroke();
        ctx.save();
        ctx.scale(1.8, 1.8);
        soldier(ctx, 0, 0, true, 'cavalry', s.battle.time, !!c.target);
        ctx.restore();
        ctx.fillStyle = '#d5b665';
        ctx.fillRect(-5, -10, 10, 2);
        ctx.fillStyle = '#243544';
        ctx.fillRect(-6, -16, 12, 4);
        ctx.fillStyle = c.shaken ? '#c98978' : '#efd9a0';
        ctx.font = '15px Georgia';
        ctx.textAlign = 'center';
        ctx.fillText(
          c.corpsId ? (c.corpsId === 'c1' ? 'I' : 'II') : 'N',
          0,
          -25,
        );
        ctx.restore();
        const label = this.labelPosition(c, { x: -100, y: 5 });
        if (label) {
          line(
            ctx,
            [
              c,
              {
                x: Math.max(label.x - 62, Math.min(label.x + 62, c.x)),
                y: label.y,
              },
            ],
            selected ? '#f0d491' : 'rgba(236,215,158,.7)',
            1,
            [3, 3],
          );
          ctx.fillStyle = '#4b4733';
          ctx.fillRect(label.x - 62, label.y - 12, 124, 23);
          text(
            ctx,
            c.corpsId
              ? s.corps.find((corps) => corps.id === c.corpsId).name +
                  ' command'
              : 'NAPOLEON',
            label.x,
            label.y,
            11,
            '#efe1b2',
          );
          text(
            ctx,
            c.unavailable
              ? 'Unavailable'
              : c.shaken
                ? 'Under pressure'
                : c.following
                  ? 'Following'
                  : 'Holding',
            label.x,
            label.y + 25,
            10,
            '#e5d8b3',
          );
        }
      }
    }
  }
  const game = new Phaser.Game({
    type: Phaser.CANVAS,
    parent,
    width: parent.clientWidth,
    height: parent.clientHeight,
    backgroundColor: '#718056',
    scene: FieldScene,
    scale: { mode: Phaser.Scale.RESIZE },
    render: { antialias: true, roundPixels: false },
    fps: { target: 40, forceSetTimeOut: false },
    audio: { noAudio: true },
    banner: false,
  });
  return game;
}
