import * as THREE from 'three';
import { TROOP_DETAILS } from './renderPerformance.js';

const TAU = Math.PI * 2;
const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const smooth = (a, b, x) => {
  const t = clamp((x - a) / (b - a));
  return t * t * (3 - 2 * t);
};

export function gaitCadence(speed, type) {
  const mounted = type === 2 || type === 3 || type === 6;
  // At 0.5x, normal marching alternates the two leg poses every 1-2 seconds.
  return clamp(speed / (mounted ? 52 : type === 7 ? 44 : 36), 0.4, 0.8);
}

export function spriteDirection(facing, previous, bias = 0) {
  const vertical = Math.sin(facing || 0);
  // A small dead band prevents flickering between views near diagonal headings.
  const threshold =
    (previous == null ? 0.72 : previous === 0 ? 0.77 : 0.65) + bias;
  return Math.abs(vertical) < threshold ? 0 : vertical < 0 ? 1 : 2;
}

export function animationTime(state) {
  return state.mode === 'battle' ? state.battle.time : (state.hours - 6) / 0.08;
}

// Cosmetic state only: displacement is observed, never written back to the army.
export class TroopAnimator {
  constructor() {
    this.tracks = new Map();
    this.frame = 0;
  }
  begin() {
    this.frame++;
  }
  sample(key, x, y, time, type, index = 0) {
    let track = this.tracks.get(key);
    if (!track || time < track.time) {
      let seed = 0;
      for (const c of key) seed = (seed * 31 + c.charCodeAt(0)) >>> 0;
      track = {
        x,
        y,
        time,
        phase: ((seed % 997) / 997) * TAU + index * 2.4,
        amount: 0,
      };
      this.tracks.set(key, track);
    }
    const dt = time - track.time;
    if (dt > 0) {
      const travel = Math.hypot(x - track.x, y - track.y);
      const speed = travel / dt;
      const mounted = type === 2 || type === 3 || type === 6;
      // Ignore deployment/teleport jumps; cap missed-frame gait catch-up.
      const moving = travel > 0.005 && speed < 240 && dt < 1;
      const target = moving ? clamp(speed / (mounted ? 18 : 10), 0.25, 1) : 0;
      track.amount += (target - track.amount) * (1 - Math.exp(-dt * 18));
      if (moving) {
        track.phase = (track.phase + dt * gaitCadence(speed, type) * TAU) % TAU;
        const bearing = Math.atan2(y - track.y, x - track.x);
        if (track.facing == null) track.facing = bearing;
        else {
          const error = Math.atan2(
            Math.sin(bearing - track.facing),
            Math.cos(bearing - track.facing),
          );
          track.facing += clamp(error, -dt * 0.75, dt * 0.75);
        }
      }
      Object.assign(track, { x, y, time });
    }
    track.frame = this.frame;
    return track;
  }
  end() {
    for (const [key, track] of this.tracks)
      if (track.frame !== this.frame) this.tracks.delete(key);
  }
  clear() {
    this.tracks.clear();
  }
}

export function combatPose(unit, time, index, type) {
  const idle = {
    pose: 0,
    recoil: 0,
    work: 0,
    melee: 0,
    flash: 0,
    smoke: 0,
    age: -1,
  };
  if (
    type > 5 ||
    unit.routed ||
    !Number.isFinite(unit.shotTime) ||
    !unit.shotKind
  )
    return idle;
  const delay = ((index * 7) % 11) * (type >= 4 ? 0.017 : 0.012);
  const age = time - unit.shotTime - delay;
  if (age < 0 || age > (type >= 4 ? 4 : 2.6)) return idle;
  if (unit.shotKind === 'melee')
    return {
      ...idle,
      age,
      melee: age < 0.65 ? Math.sin((age / 0.65) * Math.PI) : 0,
    };
  const loading = age > 0.38 && unit.reload > 0;
  return {
    pose: type >= 4 ? 0 : age < 0.38 ? 1 : loading ? 2 : 0,
    recoil:
      Math.min(1, age / 0.055) *
      Math.exp(-Math.max(0, age - 0.055) * (type >= 4 ? 5 : 11)),
    work: loading ? Math.sin(age * (type >= 4 ? 7 : 10)) : 0,
    melee: 0,
    flash: age < 0.14 ? Math.sin((age / 0.14) * Math.PI) : 0,
    smoke: age < 1.8 ? Math.min(1, age * 9) * (1 - age / 1.8) : 0,
    age,
  };
}

export function rigWeights(type, x, y, pose = 0) {
  // Coordinates are fractions of the painted cell, measured from its top left.
  if (type < 2) {
    const legs = smooth(pose ? 0.55 : 0.58, 0.85, y);
    const split = smooth(0.32, 0.4, x);
    return [
      legs * (1 - split * 2),
      legs,
      1 - smooth(0.47, 0.7, y),
      smooth(0.25, 0.45, x) *
        smooth(0.2, 0.32, y) *
        (1 - smooth(0.52, 0.67, y)),
    ];
  }
  if (type === 2 || type === 3 || type === 6) {
    const legs = smooth(type === 6 ? 0.57 : 0.62, 0.86, y);
    const split = smooth(0.42, 0.63, x);
    return [
      legs * (1 - split * 2),
      legs,
      1 - smooth(0.43, 0.67, y),
      (1 - smooth(0.4, 0.65, y)) * smooth(0.1, 0.3, x),
    ];
  }
  if (type === 7) {
    const legs = smooth(0.65, 0.89, y) * (1 - smooth(0.48, 0.64, x));
    return [legs * Math.cos(x * 23), legs, 0, 0];
  }
  const crew = 1 - smooth(0.28, 0.47, x);
  // The rear crewman's legs overlap the loader's head in this painted view.
  // Articulate only the unobstructed lower legs, not the occluded silhouette.
  const legs = crew * smooth(0.77, 0.91, y);
  const barrel =
    Math.exp(-Math.pow((y - (0.81 - x * 0.6)) / 0.07, 2)) *
    smooth(0.3, 0.48, x);
  return [legs * Math.cos(x * 22), legs, barrel, crew * (1 - legs)];
}

export function animatedGeometry(type, pose, capacity, detail = 'high') {
  let [columns, rows] = TROOP_DETAILS[detail];
  // Put mesh boundaries in the gap between legs, preserving each boot's width.
  const files =
    type < 2
      ? detail === 'high'
        ? [0, 0.16, 0.27, 0.32, 0.4, 0.48, 0.54, 0.65, 0.75, 0.86, 1]
        : [0, 0.32, 0.4, 0.48, 0.54, 0.75, 1]
      : null;
  if (files) columns = files.length - 1;
  const geometry = new THREE.PlaneGeometry(0.75, 1, columns, rows);
  geometry.userData.detail = detail;
  const uv = geometry.attributes.uv;
  if (files) {
    for (let i = 0; i < uv.count; i++) {
      const x = files[i % (columns + 1)];
      uv.setX(i, x);
      geometry.attributes.position.setX(i, (x - 0.5) * 0.75);
    }
  }
  const rig = new Float32Array(uv.count * 4);
  for (let i = 0; i < uv.count; i++)
    rig.set(rigWeights(type, uv.getX(i), 1 - uv.getY(i), pose), i * 4);
  geometry.setAttribute('troopRig', new THREE.BufferAttribute(rig, 4));
  geometry.setAttribute(
    'troopDirection',
    new THREE.InstancedBufferAttribute(new Float32Array(capacity), 1).setUsage(
      THREE.DynamicDrawUsage,
    ),
  );
  geometry.setAttribute(
    'troopMotion',
    new THREE.InstancedBufferAttribute(
      new Float32Array(capacity * 4),
      4,
    ).setUsage(THREE.DynamicDrawUsage),
  );
  geometry.setAttribute(
    'troopCombat',
    new THREE.InstancedBufferAttribute(new Float32Array(capacity), 1).setUsage(
      THREE.DynamicDrawUsage,
    ),
  );
  // Register the supplemental poses to the original sprite's foot line.
  if (pose) {
    const scale = type < 2 ? (pose === 1 ? 0.93 : 0.9) : 0.97;
    geometry.scale(scale, scale, 1);
    geometry.translate(
      type < 2 ? 0.035 : 0,
      type < 2 ? (pose === 1 ? 0.021 : -0.049) : pose === 1 ? 0.024 : 0.006,
      0,
    );
  }
  return geometry;
}

export function animateMaterial(
  material,
  type,
  pose,
  directions = material.map,
) {
  const artillery = type === 4 || type === 5;
  material.onBeforeCompile = (shader) => {
    shader.uniforms.directionMap = { value: directions };
    shader.vertexShader =
      `
      attribute vec4 troopRig;
      attribute vec4 troopMotion;
      attribute float troopCombat;
      attribute float troopDirection;
      varying vec2 vTroopUv;
      varying float vTroopDirection;
    ` + shader.vertexShader;
    shader.vertexShader = shader.vertexShader.replace(
      '#include <begin_vertex>',
      `
      #include <begin_vertex>
      vTroopUv = uv;
      vTroopDirection = troopDirection;
      vec4 rig = troopRig;
      if (troopDirection > 0.5) {
        float legs = smoothstep(${type < 2 ? '0.57, 0.88' : '0.70, 0.96'}, 1.0 - uv.y);
        rig.xy = vec2(legs * (1.0 - 2.0 * smoothstep(${type < 2 ? '0.48, 0.54' : '0.35, 0.65'}, uv.x)), legs);
      }
      float poseBlend = smoothstep(-1.0, 1.0, sin(troopMotion.x));
      float stepWave = mix(-1.0, 1.0, poseBlend);
      float stride = troopMotion.y;
      float leg = rig.x;
      float lift = max(0.0, stepWave * sign(leg));
      transformed.x += stepWave * leg * stride * ${type < 2 ? '0.060' : artillery || type === 7 ? '0.042' : '0.052'};
      transformed.y += lift * rig.y * stride * ${artillery ? '0.035' : '0.050'};
      transformed.x += sin(troopMotion.x + 1.3) * troopRig.z * stride * 0.008;
      transformed.y += abs(cos(troopMotion.x)) * stride * ${artillery || type === 7 ? '0.004' : '0.012'};
      transformed.x -= troopMotion.z * troopRig.z * ${artillery ? '0.075' : '0.030'};
      transformed.y -= troopMotion.z * troopRig.z * ${artillery ? '0.050' : '0.007'};
      transformed.x += troopMotion.w * troopRig.w * 0.014;
      transformed.y += troopMotion.w * troopRig.w * 0.009;
      transformed.x += troopCombat * troopRig.w * 0.075;
      transformed.y += troopCombat * troopRig.w * ${type < 2 ? '0.018' : '0.080'};
    `,
    );
    shader.fragmentShader =
      `
      varying vec2 vTroopUv;
      varying float vTroopDirection;
      uniform sampler2D directionMap;
    ` + shader.fragmentShader;
    // A few painted props cross their atlas cell boundary. Exclude those gutters.
    const gutter =
      !pose && (type < 2 || type === 3)
        ? 'if (cell.y < 0.085) discard;'
        : (!pose && type === 6) || (pose && type === 1)
          ? 'if (cell.x > 0.94) discard;'
          : '';
    const column = (type % 4) / 4;
    const row = pose ? (pose === 1 ? 0.5 : 0) : type < 4 ? 0.5 : 0;
    shader.fragmentShader = shader.fragmentShader.replace(
      '#include <map_fragment>',
      `
      vec2 cell = vTroopUv;
      vec4 painted;
      if (vTroopDirection > 0.5) {
        float directionRow = (vTroopDirection < 1.5 ? 0.75 : 0.25) - ${type >= 4 ? '0.25' : '0.0'};
        vec2 directionUv = cell * 0.25 + vec2(${column.toFixed(2)}, directionRow);
        ${type === 2 || type === 3 ? 'if (vTroopDirection < 1.5) directionUv.y = cell.y * 0.26 + 0.74;' : ''}
        ${type >= 4 ? 'if (vTroopDirection < 1.5 && cell.y > 0.97) discard;' : ''}
        painted = texture2D(directionMap, directionUv);
      } else {
        ${gutter}
        painted = texture2D(map, cell * vec2(0.25, 0.5) + vec2(${column.toFixed(2)}, ${row.toFixed(1)}));
      }
      if (min(painted.r, painted.b) - painted.g > 0.035) discard;
      diffuseColor *= painted;
    `,
    );
  };
  material.customProgramCacheKey = () => `depth-rig-v3-${type}-${pose}`;
}
