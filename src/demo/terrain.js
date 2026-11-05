import * as THREE from 'three';
import { WORLD, FORESTS, riverY } from '../game/model.js';
import { fieldFor, elevation, channelX } from '../game/battlefields.js';
import { DEMO_TOWNS } from './model.js';

export const PADDING = 1400;
export const EXTENT = {
  width: WORLD.width + PADDING * 2,
  height: WORLD.height + PADDING * 2,
};
export function seeded(seed) {
  return () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 4294967296;
  };
}
const campaignHills = [
  { x: 230, y: 195, rx: 360, ry: 230, h: 95 },
  { x: 780, y: 145, rx: 330, ry: 175, h: 80 },
  { x: 1280, y: 820, rx: 340, ry: 230, h: 70 },
  { x: 80, y: 950, rx: 300, ry: 250, h: 55 },
  { x: 1140, y: -130, rx: 400, ry: 210, h: 155 },
  { x: 260, y: -190, rx: 490, ry: 260, h: 170 },
];

export function landscapeFor(state) {
  const campaign = state.mode === 'campaign';
  const field = fieldFor(state.battle);
  return {
    campaign,
    forests: campaign ? FORESTS.campaign : field.forests,
    towns: campaign
      ? DEMO_TOWNS
      : field.towns.map((t, i) => ({
          ...t,
          name: i ? 'West hamlet' : 'Valeggio',
        })),
    roads: campaign
      ? [
          [
            { x: -400, y: 790 },
            DEMO_TOWNS[0],
            DEMO_TOWNS[1],
            { x: 395, y: riverY(395) },
            { x: 470, y: 320 },
            DEMO_TOWNS[3],
            DEMO_TOWNS[5],
          ],
          [
            DEMO_TOWNS[0],
            { x: 510, y: 750 },
            DEMO_TOWNS[4],
            { x: 1300, y: 950 },
          ],
          [DEMO_TOWNS[4], { x: 900, y: riverY(900) }, DEMO_TOWNS[3]],
          [DEMO_TOWNS[1], DEMO_TOWNS[2], { x: 900, y: riverY(900) }],
        ]
      : field.roads,
    height(x, y) {
      let h = campaign
        ? Math.max(
            0,
            ...campaignHills.map(
              (a) =>
                Math.max(
                  0,
                  1 - ((x - a.x) / a.rx) ** 2 - ((y - a.y) / a.ry) ** 2,
                ) **
                  1.5 *
                a.h,
            ),
          )
        : elevation({ x, y }, field) * 70;
      const bank = campaign
        ? Math.abs(y - riverY(x))
        : field.river
          ? Math.abs(x - channelX(y))
          : 1000;
      h *= Math.min(1, Math.max(0, (bank - 36) / 75));
      return h - 5 * Math.max(0, 1 - bank / 42);
    },
    water: campaign || field.river,
  };
}

function stroke(ctx, points, color, width) {
  ctx.strokeStyle = color;
  ctx.lineWidth = width;
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  ctx.beginPath();
  points.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
  ctx.stroke();
}

export function groundTexture(source, data, renderer) {
  const canvas = document.createElement('canvas');
  canvas.width = 3072;
  canvas.height = 2730;
  const ctx = canvas.getContext('2d');
  ctx.scale(canvas.width / EXTENT.width, canvas.height / EXTENT.height);
  ctx.translate(PADDING, PADDING);
  for (let row = -2; row < 3; row++)
    for (let col = -2; col < 3; col++) {
      ctx.save();
      ctx.translate(
        col * WORLD.width + (col % 2 ? WORLD.width : 0),
        row * WORLD.height + (row % 2 ? WORLD.height : 0),
      );
      ctx.scale(col % 2 ? -1 : 1, row % 2 ? -1 : 1);
      ctx.drawImage(source, 0, 0, WORLD.width, WORLD.height);
      ctx.restore();
    }
  ctx.fillStyle = 'rgba(84,111,71,.10)';
  ctx.fillRect(-PADDING, -PADDING, EXTENT.width, EXTENT.height);
  if (data.water) {
    const points = Array.from({ length: 520 }, (_, i) => {
      const n = i * 10 - PADDING;
      return data.campaign ? { x: n, y: riverY(n) } : { x: channelX(n), y: n };
    });
    stroke(ctx, points, '#546951', data.campaign ? 55 : 85);
    stroke(ctx, points, '#7d8870', data.campaign ? 45 : 75);
    stroke(ctx, points, '#5d8f99', data.campaign ? 34 : 63);
  }
  for (const road of data.roads) {
    stroke(ctx, road, 'rgba(66,59,36,.28)', data.campaign ? 10 : 15);
    stroke(ctx, road, '#a99f80', data.campaign ? 6 : 10);
    stroke(ctx, road, '#bbb08e', data.campaign ? 1.2 : 2);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  return texture;
}

export function reliefGeometry(data, relief) {
  const geometry = new THREE.PlaneGeometry(
    EXTENT.width,
    EXTENT.height,
    176,
    156,
  );
  geometry.rotateX(-Math.PI / 2);
  geometry.translate(WORLD.width / 2, 0, WORLD.height / 2);
  const positions = geometry.attributes.position;
  for (let i = 0; i < positions.count; i++)
    positions.setY(
      i,
      data.height(positions.getX(i), positions.getZ(i)) * relief,
    );
  positions.needsUpdate = true;
  geometry.computeVertexNormals();
  return geometry;
}

export function waterGeometry(data) {
  const positions = [],
    indices = [],
    uvs = [];
  const width = data.campaign ? 16 : 29;
  for (let i = 0; i < 520; i++) {
    const n = i * 10 - PADDING;
    const x = data.campaign ? n : channelX(n),
      y = data.campaign ? riverY(n) : n;
    for (const side of [-1, 1]) {
      positions.push(
        x + (data.campaign ? 0 : side * width),
        -0.4,
        y + (data.campaign ? side * width : 0),
      );
      uvs.push(i / 12, (side + 1) / 2);
    }
    if (i) {
      const a = (i - 1) * 2;
      indices.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
    }
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute(
    'position',
    new THREE.Float32BufferAttribute(positions, 3),
  );
  geometry.setIndex(indices);
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.computeVertexNormals();
  return geometry;
}

export function waterTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 128;
  const ctx = canvas.getContext('2d'),
    random = seeded(113);
  ctx.fillStyle = '#6c9491';
  ctx.fillRect(0, 0, 256, 128);
  for (let i = 0; i < 4000; i++) {
    ctx.fillStyle =
      random() > 0.5 ? 'rgba(184,214,197,.12)' : 'rgba(41,75,75,.09)';
    ctx.fillRect(random() * 256, random() * 128, 1 + random() * 8, 1);
  }
  for (let i = 0; i < 65; i++) {
    const x = random() * 256,
      y = random() * 128;
    stroke(
      ctx,
      [
        { x, y },
        { x: x + 8 + random() * 30, y: y + 1.5 },
      ],
      'rgba(198,218,209,.19)',
      0.8,
    );
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = THREE.RepeatWrapping;
  return texture;
}

export function stoneTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 128;
  const ctx = canvas.getContext('2d'),
    random = seeded(461);
  ctx.fillStyle = '#73796e';
  ctx.fillRect(0, 0, 256, 128);
  for (let row = 0; row < 8; row++)
    for (let col = -1; col < 9; col++) {
      const x = col * 34 + (row % 2) * 17,
        y = row * 16;
      const value = 143 + Math.floor(random() * 33);
      ctx.fillStyle = `rgb(${value + 5},${value + 3},${value - 12})`;
      ctx.fillRect(x + 1, y + 1, 32, 14);
      ctx.fillStyle = 'rgba(231,232,211,.22)';
      ctx.fillRect(x + 1, y + 1, 32, 1);
      ctx.fillStyle = 'rgba(69,77,64,.14)';
      ctx.fillRect(x + 2, y + 13, 31, 2);
    }
  for (let i = 0; i < 3500; i++) {
    ctx.fillStyle = random() > 0.5 ? '#edeac010' : '#414c4114';
    ctx.fillRect(random() * 256, random() * 128, 1, 1);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}
