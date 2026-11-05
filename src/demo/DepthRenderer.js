import * as THREE from 'three';
import { MeshBVH, acceleratedRaycast } from 'three-mesh-bvh';
import { StaticLandscapePass } from './StaticLandscapePass.js';
import { cameraMovement } from './cameraMovement.js';
import {
  terrainSampler,
  uprightSpriteFrame,
  placeGroundedSprite,
  withBridgeDecks,
} from './spriteGround.js';
import {
  FrameInvalidation,
  TROOP_DETAILS,
  troopDetail,
  uploadInstances,
} from './renderPerformance.js';
import { formationRange } from './formationGeometry.js';
import { WORLD, WEAPONS, countMen, distance, riverY } from '../game/model.js';
import { fieldFor } from '../game/battlefields.js';
import { clearShot } from '../game/tactics.js';
import { BattleAudio } from '../game/audio.js';
import { legalGround } from './model.js';
import {
  TroopAnimator,
  animationTime,
  combatPose,
  animatedGeometry,
  animateMaterial,
  spriteDirection,
} from './troopAnimation.js';
import {
  PADDING,
  EXTENT,
  landscapeFor,
  groundTexture,
  reliefGeometry,
  waterGeometry,
  waterTexture,
  stoneTexture,
  seeded,
} from './terrain.js';

const loadImage = (src) =>
  new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`Unable to load ${src}`));
    image.src = src;
  });
const clamp = THREE.MathUtils.clamp;
const friendly = '#b8dfe4',
  hostile = '#edb2a3',
  gold = '#f4d58d';

export class DepthRenderer {
  static async create(parent, model, options) {
    const sources = {};
    for (const [key, path] of Object.entries({
      ground: 'terrain.png',
      trees: 'trees.png',
      village: 'village.png',
      units: 'depth-units-keyed.png',
      actions: 'depth-unit-actions-keyed.png',
      directions: 'depth-unit-directions-v2.png',
    })) {
      sources[key] = await loadImage(`/assets/${path}`);
    }
    const instance = new DepthRenderer(parent, model, options, sources);
    try {
      await instance.renderer.compileAsync(instance.scene, instance.camera);
      await instance.renderer.compileAsync(
        instance.staticPass.scene,
        instance.staticPass.camera,
      );
      return instance;
    } catch (error) {
      instance.dispose();
      throw error;
    }
  }
  constructor(parent, model, options, sources) {
    this.parent = parent;
    this.model = model;
    this.options = options;
    this.sources = sources;
    this.disposed = false;
    this.frameGate = new FrameInvalidation();
    this.cameraKeys = new Set();
    this.unsubscribe = model.subscribe(() => this.invalidate());
    this.relief = 1;
    this.showRanges = true;
    this.zoom = 1;
    this.center = { x: 720, y: 480 };
    this.hitAreas = [];
    this.labels = [];
    this.assets = new Set();
    this.meshes = [];
    this.shots = new Map();
    this.smoke = [];
    this.animation = new TroopAnimator();
    this.muzzleEffects = [];
    this.stats = {
      frames: 0,
      drawCalls: 0,
      troops: 0,
      frameTimes: [],
      idleSkips: 0,
    };
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: false,
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.98;
    this.renderer.setClearColor('#94a592');
    this.renderer.info.autoReset = false;
    this.staticPass = new StaticLandscapePass();
    // Float color retains lighting highlights until the final tone-mapped copy.
    this.staticPass.enabled = this.renderer.extensions.has(
      'EXT_color_buffer_float',
    );
    this.renderer.domElement.className = 'depth-world';
    this.overlay = document.createElement('canvas');
    this.overlay.className = 'depth-overlay';
    this.overlay.setAttribute('aria-hidden', 'true');
    parent.append(this.renderer.domElement, this.overlay);
    this.ctx = this.overlay.getContext('2d');
    this.scene = new THREE.Scene();
    this.camera = new THREE.OrthographicCamera(-720, 720, 480, -480, 1, 6000);
    this.scene.add(new THREE.HemisphereLight('#e5eff2', '#536848', 1.7));
    const sun = new THREE.DirectionalLight('#fff4df', 2.1);
    sun.position.set(-800, 1200, -700);
    this.scene.add(sun);
    this.scene.fog = new THREE.Fog('#b5c4b0', 2900, 5400);
    this.raycaster = new THREE.Raycaster();
    this.raycaster.firstHitOnly = true;
    this.projectPoint = new THREE.Vector3();
    this.pointerNdc = new THREE.Vector2();
    this.audio = new BattleAudio(() => model.state.settings);
    this.resize();
    this.makeTroops();
    this.buildLandscape();
    this.home();
    this.bindInput();
    this.resizeObserver = new ResizeObserver(() => this.resize());
    this.resizeObserver.observe(parent);
    document.fonts.ready.then(() => {
      if (!this.disposed) this.invalidate();
    });
  }
  keep(asset) {
    this.assets.add(asset);
    return asset;
  }
  texture(image) {
    const t = this.keep(new THREE.Texture(image));
    t.colorSpace = THREE.SRGBColorSpace;
    t.needsUpdate = true;
    return t;
  }
  resize() {
    const wasPhone = this.width < 650;
    const rect = this.parent.getBoundingClientRect();
    this.width = Math.max(1, rect.width);
    this.height = Math.max(1, rect.height);
    this.renderer.setSize(this.width, this.height);
    this.overlay.width = Math.round(this.width * this.renderer.getPixelRatio());
    this.overlay.height = Math.round(
      this.height * this.renderer.getPixelRatio(),
    );
    this.overlay.style.width = `${this.width}px`;
    this.overlay.style.height = `${this.height}px`;
    if (this.data && wasPhone !== this.width < 650) this.home();
    else this.updateCamera();
  }
  updateCamera() {
    this.invalidate();
    this.staticPass.invalidate();
    this.minimapView = null;
    const aspect = this.width / this.height;
    this.baseHeight = this.width < 650 ? 650 / aspect : 970;
    const sine = Math.sin(Math.atan2(1250, 720));
    const minimum = Math.max(
      0.62,
      (this.baseHeight * aspect) / (EXTENT.width - 220),
      this.baseHeight / sine / (EXTENT.height - 300),
    );
    this.zoom = clamp(this.zoom, minimum, 6);
    const halfH = this.baseHeight / (2 * this.zoom),
      halfW = halfH * aspect;
    this.center.x = clamp(
      this.center.x,
      -PADDING + halfW + 80,
      WORLD.width + PADDING - halfW - 80,
    );
    this.center.y = clamp(
      this.center.y,
      -PADDING + halfH / sine + 100,
      WORLD.height + PADDING - halfH / sine - 100,
    );
    Object.assign(this.camera, {
      left: -halfW,
      right: halfW,
      top: halfH,
      bottom: -halfH,
    });
    this.camera.position.set(this.center.x, 1250, this.center.y + 720);
    this.camera.lookAt(this.center.x, 0, this.center.y);
    this.camera.updateProjectionMatrix();
    this.camera.updateMatrixWorld();
  }
  setZoom(multiplier) {
    this.zoom *= multiplier;
    this.updateCamera();
  }
  home() {
    const s = this.model.state;
    this.center =
      this.width < 650
        ? s.mode === 'campaign'
          ? { x: s.army.x + 120, y: s.army.y - 90 }
          : { x: 630, y: 480 }
        : { x: 720, y: 480 };
    this.zoom = 1;
    this.updateCamera();
  }
  setRelief(value) {
    this.relief = value ? 1 : 0;
    this.buildLandscape();
  }
  project(x, y, above = 0) {
    const point = this.projectPoint
      .set(x, this.surfaceHeight(x, y) + above, y)
      .project(this.camera);
    return {
      x: ((point.x + 1) * this.width) / 2,
      y: ((1 - point.y) * this.height) / 2,
    };
  }
  ground(screen) {
    this.raycaster.setFromCamera(
      this.pointerNdc.set(
        (screen.x / this.width) * 2 - 1,
        1 - (screen.y / this.height) * 2,
      ),
      this.camera,
    );
    const hit = this.raycaster.intersectObject(this.terrain, false)[0];
    return hit ? { x: hit.point.x, y: hit.point.z } : null;
  }
  clearLandscape() {
    if (!this.landscape) return;
    this.scene.remove(this.landscape);
    const materials = new Set(),
      geometries = new Set();
    this.landscape.traverse((o) => {
      if (o.isInstancedMesh) o.dispose();
      if (o.geometry) geometries.add(o.geometry);
      if (o.material) materials.add(o.material);
    });
    for (const g of geometries) {
      g.boundsTree = null;
      g.dispose();
    }
    for (const m of materials) {
      if (m.userData.localMap) m.map?.dispose();
      m.dispose();
    }
  }
  buildLandscape() {
    this.invalidate();
    this.staticPass.invalidate();
    this.minimapView = null;
    this.clearLandscape();
    this.data = landscapeFor(this.model.state);
    this.mode = this.model.state.mode;
    this.landscape = new THREE.Group();
    this.scene.add(this.landscape);
    const map = groundTexture(this.sources.ground, this.data, this.renderer);
    const material = new THREE.MeshStandardMaterial({
      map,
      color: '#c8d8d0',
      roughness: 1,
      metalness: 0,
    });
    material.userData.localMap = true;
    this.terrain = new THREE.Mesh(
      reliefGeometry(this.data, this.relief),
      material,
    );
    // Local to this terrain mesh: leave Three.js and the original game untouched.
    this.terrain.geometry.boundsTree = new MeshBVH(this.terrain.geometry);
    this.terrain.raycast = acceleratedRaycast;
    this.surfaceHeight = terrainSampler(this.terrain.geometry);
    const decks = [];
    this.landscape.add(this.terrain);
    if (this.data.water) {
      const water = new THREE.Mesh(
        waterGeometry(this.data),
        new THREE.MeshStandardMaterial({
          map: waterTexture(),
          color: '#c3dad6',
          roughness: 0.7,
          metalness: 0.08,
          side: THREE.DoubleSide,
        }),
      );
      water.material.userData.localMap = true;
      this.landscape.add(water);
      const crossings = this.data.campaign
        ? [
            { x: 395, y: riverY(395), rotate: true },
            { x: 900, y: riverY(900), rotate: true },
          ]
        : [{ x: 720, y: 480 }];
      for (const p of crossings) {
        const group = new THREE.Group();
        const stone = new THREE.MeshStandardMaterial({
          map: stoneTexture(),
          color: '#b4b09a',
          roughness: 1,
        });
        stone.userData.localMap = true;
        const deck = new THREE.Mesh(new THREE.BoxGeometry(98, 7, 56), stone);
        deck.position.y = 3;
        group.add(deck);
        for (const x of [-36, 0, 36]) {
          const pier = new THREE.Mesh(new THREE.BoxGeometry(12, 15, 56), stone);
          pier.position.set(x, -5, 0);
          group.add(pier);
        }
        for (const z of [-29, 29]) {
          const parapet = new THREE.Mesh(
            new THREE.BoxGeometry(102, 6, 4),
            stone,
          );
          parapet.position.set(0, 9, z);
          group.add(parapet);
        }
        group.position.set(p.x, 0, p.y);
        group.rotation.y = p.rotate ? Math.PI / 2 : 0;
        if (this.data.campaign) group.scale.set(0.63, 0.75, 0.63);
        decks.push({
          x: p.x,
          y: p.y,
          halfX: (p.rotate ? 28 : 49) * group.scale.x,
          halfY: (p.rotate ? 49 : 28) * group.scale.z,
          height: 6.5 * group.scale.y,
        });
        this.landscape.add(group);
      }
    }
    this.surfaceHeight = withBridgeDecks(this.surfaceHeight, decks);
    this.makeScenery();
  }
  makeScenery() {
    const random = seeded(this.data.campaign ? 89 : 371);
    this.treeTexture ||= this.texture(this.sources.trees);
    this.villageTexture ||= this.texture(this.sources.village);
    const forestPoints = [];
    for (const forest of this.data.forests) {
      const count = Math.round((forest.rx * forest.ry) / 550);
      for (let i = 0; i < count; i++) {
        const angle = random() * Math.PI * 2,
          radius = Math.sqrt(random());
        const x = forest.x + Math.cos(angle) * radius * forest.rx;
        const y = forest.y + Math.sin(angle) * radius * forest.ry;
        forestPoints.push({ x, y, size: 25 + random() * 21 });
      }
    }
    const material = new THREE.MeshBasicMaterial({
      map: this.treeTexture,
      alphaTest: 0.25,
      side: THREE.DoubleSide,
      color: '#d0d8bc',
    });
    const trees = new THREE.InstancedMesh(
      new THREE.PlaneGeometry(1, 1),
      material,
      forestPoints.length,
    );
    const shade = new THREE.InstancedMesh(
      new THREE.PlaneGeometry(1, 1),
      new THREE.MeshBasicMaterial({
        map: this.shadowTexture,
        transparent: true,
        depthWrite: false,
        color: '#152416',
        opacity: 0.44,
      }),
      forestPoints.length,
    );
    const transform = new THREE.Object3D();
    forestPoints.forEach((p, i) => {
      transform.position.set(
        p.x,
        this.data.height(p.x, p.y) * this.relief + p.size * 0.24,
        p.y,
      );
      transform.quaternion.copy(this.camera.quaternion);
      transform.scale.set(p.size * 1.25, p.size, 1);
      transform.updateMatrix();
      trees.setMatrixAt(i, transform.matrix);
      transform.rotation.set(-Math.PI / 2, 0, 0);
      transform.position.set(
        p.x + 7,
        this.data.height(p.x, p.y) * this.relief + 0.8,
        p.y + 9,
      );
      transform.scale.set(p.size * 1.4, p.size * 0.85, 1);
      transform.updateMatrix();
      shade.setMatrixAt(i, transform.matrix);
    });
    trees.frustumCulled = false;
    shade.frustumCulled = false;
    this.landscape.add(shade, trees);
    for (const town of this.data.towns) {
      const size = this.data.campaign ? (town.major ? 100 : 77) : 130;
      const mesh = new THREE.Mesh(
        new THREE.PlaneGeometry(size, size * 0.67),
        new THREE.MeshBasicMaterial({
          map: this.villageTexture,
          alphaTest: 0.2,
          side: THREE.DoubleSide,
        }),
      );
      mesh.quaternion.copy(this.camera.quaternion);
      mesh.position.set(
        town.x,
        this.data.height(town.x, town.y) * this.relief + size * 0.15,
        town.y,
      );
      this.landscape.add(mesh);
    }
  }
  makeTroops() {
    const canvas = document.createElement('canvas');
    canvas.width = 64;
    canvas.height = 64;
    const ctx = canvas.getContext('2d'),
      gradient = ctx.createRadialGradient(32, 32, 1, 32, 32, 32);
    gradient.addColorStop(0, 'rgba(0,0,0,.8)');
    gradient.addColorStop(0.45, 'rgba(0,0,0,.48)');
    gradient.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 64, 64);
    this.shadowTexture = this.keep(new THREE.CanvasTexture(canvas));
    const atlas = this.texture(this.sources.units);
    const actions = this.texture(this.sources.actions);
    const directions = this.texture(this.sources.directions);
    for (const texture of [atlas, actions, directions]) {
      texture.generateMipmaps = false;
      texture.minFilter = THREE.LinearFilter;
      texture.needsUpdate = true;
    }
    this.troops = Array.from({ length: 16 }, (_, i) => {
      const type = i < 8 ? i : (i - 8) % 4;
      const pose = i < 8 ? 0 : i < 12 ? 1 : 2;
      const geometries = Object.fromEntries(
        Object.keys(TROOP_DETAILS).map((detail) => [
          detail,
          this.keep(animatedGeometry(type, pose, 1200, detail)),
        ]),
      );
      const material = this.keep(
        new THREE.MeshBasicMaterial({
          map: pose ? actions : atlas,
          alphaTest: 0.4,
          side: THREE.DoubleSide,
        }),
      );
      animateMaterial(material, type, pose, directions);
      const mesh = new THREE.InstancedMesh(geometries.low, material, 1200);
      mesh.userData.geometries = geometries;
      mesh.userData.type = type;
      mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
      mesh.frustumCulled = false;
      mesh.count = 0;
      mesh.visible = false;
      this.scene.add(mesh);
      return mesh;
    });
    const shadowMaterial = this.keep(
      new THREE.MeshBasicMaterial({
        map: this.shadowTexture,
        transparent: true,
        color: '#182317',
        opacity: 0.5,
        depthWrite: false,
      }),
    );
    this.troopShadows = new THREE.InstancedMesh(
      this.keep(new THREE.PlaneGeometry(0.75, 1)),
      shadowMaterial,
      2600,
    );
    this.troopShadows.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.troopShadows.frustumCulled = false;
    this.scene.add(this.troopShadows);
    this.dummy = new THREE.Object3D();
  }
  entities() {
    const s = this.model.state;
    if (s.mode === 'campaign')
      return [
        {
          ...s.army,
          id: 'army',
          side: 'player',
          kind: 'army',
          name: 'Army of Italy',
          men: countMen(s.units),
          condition: s.army.condition,
          morale: 100,
        },
        ...s.enemies
          .filter((e) => !e.defeated)
          .map((e) =>
            this.model.enemyVisible(e)
              ? { ...e, side: 'enemy', kind: 'army', men: e.strength }
              : {
                  id: e.id,
                  name: e.name,
                  x: e.intel.x,
                  y: e.intel.y,
                  kind: 'report',
                  side: 'enemy',
                  uncertain: true,
                  men: e.intel.strength,
                },
          ),
      ];
    const b = s.battle;
    return [
      ...b.units.filter((u) => u.visible && u.men > 0 && u.arrival <= b.time),
      ...b.commanders
        .filter((c) => !c.hostId)
        .map((c) => ({ ...c, kind: 'general', side: 'player' })),
      ...b.wagons
        .filter((w) => w.health > 0 && (w.side === 'player' || w.visible))
        .map((w) => ({
          ...w,
          kind: 'wagon',
          name: w.side === 'player' ? 'Supply train' : 'Enemy supply',
        })),
    ];
  }
  populateTroops(entities) {
    const s = this.model.state,
      counts = Array(16).fill(0),
      t = animationTime(s);
    this.animation.begin();
    this.muzzleEffects = [];
    const pixelsPerWorld = this.height / (this.camera.top - this.camera.bottom);
    const infantrySize =
      s.mode === 'campaign' ? 22 : entities.some((u) => u.dismounted) ? 23 : 17;
    for (const mesh of this.troops) {
      const type = mesh.userData.type;
      const size =
        type < 2
          ? infantrySize
          : type < 4
            ? 23
            : type < 6
              ? 31
              : type === 6
                ? 39
                : 43;
      mesh.geometry =
        mesh.userData.geometries[troopDetail(size * pixelsPerWorld)];
    }
    const spriteFrame = uprightSpriteFrame(this.camera.quaternion);
    let shadows = 0;
    let animated = 0,
      firing = 0,
      reloading = 0;
    const place = (type, x, y, size, unit, index, soldierFacing) => {
      const motion = this.animation.sample(
        `${unit.id}:${index}`,
        x,
        y,
        t,
        type,
        index,
      );
      const action = combatPose(unit, t, index, type);
      const slot = action.pose ? 8 + (action.pose - 1) * 4 + type : type;
      if (counts[slot] >= 1200 || shadows >= 2600) return;
      const mesh = this.troops[slot],
        instance = counts[slot]++;
      const facing =
        unit.kind === 'army'
          ? (motion.facing ?? 0)
          : ((action.age >= 0 ? unit.facing : soldierFacing) ??
            unit.facing ??
            motion.facing ??
            0);
      const direction = spriteDirection(
        facing,
        motion.direction,
        ((index % 7) - 3) * 0.008,
      );
      motion.direction = direction;
      const mirror = !direction && Math.cos(facing) < 0 ? -1 : 1;
      const obj = this.dummy;
      placeGroundedSprite(
        obj,
        spriteFrame,
        this.surfaceHeight,
        x,
        y,
        size,
        mirror,
      );
      mesh.setMatrixAt(instance, obj.matrix);
      mesh.geometry.attributes.troopDirection.setX(instance, direction);
      mesh.geometry.attributes.troopMotion.setXYZW(
        instance,
        motion.phase,
        motion.amount,
        action.recoil,
        action.work,
      );
      mesh.geometry.attributes.troopCombat.setX(instance, action.melee);
      if (motion.amount > 0.1) animated++;
      if (action.flash > 0) firing++;
      if (action.pose === 2 || action.work) reloading++;
      if (action.smoke > 0) {
        const muzzle = new THREE.Vector3(
          type < 2 ? 0.28 : type < 4 ? 0.22 : 0.2,
          type < 2 ? 0.16 : type < 4 ? 0.25 : 0.14,
          0,
        )
          .applyMatrix4(obj.matrix)
          .project(this.camera);
        this.muzzleEffects.push({
          x: ((muzzle.x + 1) * this.width) / 2,
          y: ((1 - muzzle.y) * this.height) / 2,
          cannon: type === 4 || type === 5,
          mirror,
          ...action,
        });
      }
      obj.rotation.set(-Math.PI / 2, 0, 0);
      obj.position.set(
        x + 2.5,
        this.surfaceHeight(x + 2.5, y + 2.5) + 0.8,
        y + 2.5,
      );
      obj.scale.set(size * 0.85, size * 0.38, 1);
      obj.updateMatrix();
      this.troopShadows.setMatrixAt(shadows++, obj.matrix);
    };
    for (const u of entities) {
      if (u.uncertain) continue;
      const center = this.project(u.x, u.y),
        margin = 200 * pixelsPerWorld + 50;
      if (
        center.x < -margin ||
        center.x > this.width + margin ||
        center.y < -margin ||
        center.y > this.height + margin
      )
        continue;
      const enemy = u.side === 'enemy';
      if (u.kind === 'general' || u.kind === 'wagon') {
        place(
          u.kind === 'general' ? 6 : 7,
          u.x,
          u.y,
          u.kind === 'general' ? 39 : 43,
          u,
          0,
        );
        continue;
      }
      if (u.kind === 'army') {
        for (let i = 0; i < 18; i++)
          place(
            enemy ? 1 : 0,
            u.x - 26 + (i % 6) * 10,
            u.y + Math.floor(i / 6) * 7,
            22,
            u,
            i,
          );
        place(6, u.x - 30, u.y + 17, 33, u, 18);
        continue;
      }
      const artillery = u.kind === 'artillery';
      const positions = this.model.soldierPositions(u);
      for (let i = 0; i < positions.length; i++) {
        const { x, y, facing } = positions[i];
        const type = artillery
          ? enemy
            ? 5
            : 4
          : u.kind === 'cavalry' && !u.dismounted
            ? enemy
              ? 3
              : 2
            : enemy
              ? 1
              : 0;
        place(
          type,
          x,
          y,
          artillery ? 31 : u.kind === 'cavalry' ? 23 : 17,
          u,
          i,
          facing,
        );
      }
    }
    this.troops.forEach((mesh, i) => {
      mesh.count = counts[i];
      mesh.visible = counts[i] > 0;
      uploadInstances(mesh.instanceMatrix, counts[i]);
      uploadInstances(mesh.geometry.attributes.troopMotion, counts[i]);
      uploadInstances(mesh.geometry.attributes.troopCombat, counts[i]);
      uploadInstances(mesh.geometry.attributes.troopDirection, counts[i]);
    });
    this.troopShadows.count = shadows;
    this.troopShadows.visible = shadows > 0;
    uploadInstances(this.troopShadows.instanceMatrix, shadows);
    this.stats.troops = shadows;
    this.animation.end();
    this.stats.animation = {
      moving: animated,
      firing,
      reloading,
      tracks: this.animation.tracks.size,
    };
  }
  drawMuzzles() {
    const ctx = this.ctx,
      reduced = this.options.reducedMotion();
    for (const p of this.muzzleEffects) {
      const drift = p.age * 7,
        radius = (p.cannon ? 3.5 : 1.5) + p.age * 3;
      ctx.fillStyle = `rgba(222,225,212,${p.smoke * (p.cannon ? 0.48 : 0.3)})`;
      ctx.beginPath();
      ctx.ellipse(
        p.x + drift,
        p.y - drift * 0.6,
        radius * 1.5,
        radius,
        -0.4,
        0,
        Math.PI * 2,
      );
      ctx.fill();
      if (p.flash && !reduced) {
        const length = (p.cannon ? 12 : 6) * p.flash;
        ctx.fillStyle = '#ffba55';
        ctx.beginPath();
        ctx.moveTo(p.x, p.y - 1.5);
        ctx.lineTo(p.x + length * p.mirror, p.y);
        ctx.lineTo(p.x, p.y + 1.5);
        ctx.fill();
        ctx.fillStyle = '#fff3c2';
        ctx.fillRect(p.x - 1, p.y - 1, 2, 2);
      }
    }
  }
  line(points, color, width = 1.5, dash = []) {
    if (!points.length) return;
    const ctx = this.ctx;
    ctx.beginPath();
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.setLineDash(dash);
    points.forEach((p, i) => {
      const q = this.project(p.x, p.y, p.height || 1);
      i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y);
    });
    ctx.stroke();
    ctx.setLineDash([]);
  }
  circle(entity, radius, color, width = 1, dash = []) {
    this.line(
      Array.from({ length: 81 }, (_, i) => ({
        x: entity.x + Math.cos((i / 80) * Math.PI * 2) * radius,
        y: entity.y + Math.sin((i / 80) * Math.PI * 2) * radius,
      })),
      color,
      width,
      dash,
    );
  }
  range(unit) {
    const b = this.model.state.battle,
      r = WEAPONS[unit.weapon].range;
    const {
      arc: points,
      front,
      outline,
    } = formationRange(unit, r, this.model.soldierPositions(unit));
    const ctx = this.ctx;
    ctx.beginPath();
    outline.forEach((p, i) => {
      const q = this.project(p.x, p.y);
      i ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y);
    });
    ctx.closePath();
    ctx.fillStyle = 'rgba(180,218,218,.08)';
    ctx.fill();
    if (front) {
      this.line([front.left, points[0]], '#b5d5d180', 1, [4, 4]);
      this.line([front.right, points.at(-1)], '#b5d5d180', 1, [4, 4]);
    }
    for (let i = 1; i < points.length; i++) {
      const clear = clearShot(unit, points[i], b, fieldFor(b));
      this.line(
        [points[i - 1], points[i]],
        clear ? '#d7e6b9cc' : '#cc907baa',
        clear ? 1.8 : 1,
        clear ? [] : [2, 3],
      );
    }
    const q = this.project(
      unit.x + Math.cos(unit.facing) * r,
      unit.y + Math.sin(unit.facing) * r,
    );
    this.caption(`${r} range`, q.x, q.y - 9, '#eef1d6', 11);
  }
  caption(value, x, y, color = '#fff9e7', size = 12) {
    const ctx = this.ctx;
    ctx.font = `500 ${size}px Inter, Arial`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.lineWidth = 3;
    ctx.strokeStyle = '#25372dc0';
    ctx.strokeText(value, x, y);
    ctx.fillStyle = color;
    ctx.fillText(value, x, y);
  }
  drawFlag(u, p) {
    const ctx = this.ctx,
      colors =
        u.side === 'player'
          ? ['#456d9d', '#faf0d6', '#bd5045']
          : ['#e2bf57', '#3c3930', '#e2bf57'];
    ctx.strokeStyle = '#4e472c';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(p.x, p.y - 10);
    ctx.lineTo(p.x, p.y - 32);
    ctx.stroke();
    colors.forEach((color, i) => {
      ctx.fillStyle = color;
      ctx.fillRect(p.x + i * 5, p.y - 32, 5, 10);
    });
  }
  drawLabels(entities) {
    const ctx = this.ctx,
      s = this.model.state;
    ctx.textBaseline = 'middle';
    const bounds = this.parent.getBoundingClientRect();
    const occupied = [
      ...this.parent.parentElement.querySelectorAll('[data-map-obstacle]'),
    ].map((el) => {
      const r = el.getBoundingClientRect();
      return {
        x: r.x - bounds.x - 4,
        y: r.y - bounds.y - 4,
        w: r.width + 8,
        h: r.height + 8,
      };
    });
    const overlaps = (a, b) =>
      a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
    this.labels = [];
    this.hitAreas = [];
    for (const u of entities) {
      if (u.kind !== 'wagon' && !u.uncertain)
        this.drawFlag(u, this.project(u.x, u.y, 14));
    }
    const sorted = [...entities].sort(
      (a, b) =>
        Number(s.selected.includes(b.id)) - Number(s.selected.includes(a.id)),
    );
    for (const u of sorted) {
      const p = this.project(u.x, u.y, 14),
        selected =
          s.selected.includes(u.id) ||
          s.selectedCommander === u.id ||
          (s.selectedSupply && u.kind === 'wagon');
      this.hitAreas.push({
        id: u.id,
        x: p.x - 27,
        y: p.y - 30,
        w: 54,
        h: 58,
        entity: u,
      });
      if (
        p.x < -20 ||
        p.y < 0 ||
        p.x > this.width + 20 ||
        p.y > this.height + 40
      )
        continue;
      const w = this.width < 650 ? 104 : 122,
        h = u.kind === 'general' || u.kind === 'wagon' || u.uncertain ? 36 : 43;
      const offsets = [
        [-w / 2, 22],
        [-w - 34, -15],
        [34, -15],
        [-w / 2, -83],
        [-w / 2, 66],
      ];
      const rect = offsets
        .map(([x, y]) => ({ x: p.x + x, y: p.y + y, w, h }))
        .find(
          (r) =>
            r.x > 5 &&
            r.y > 5 &&
            r.x + w < this.width - 5 &&
            r.y + h < this.height - 5 &&
            !occupied.some((other) => overlaps(r, other)),
        );
      if (!rect) continue;
      occupied.push(rect);
      this.labels.push({ ...rect, id: u.id });
      this.hitAreas.push({ ...rect, entity: u });
      ctx.fillStyle =
        u.side === 'player' ? 'rgba(28,47,49,.92)' : 'rgba(83,48,42,.92)';
      ctx.fillRect(rect.x, rect.y, w, h);
      ctx.strokeStyle = selected
        ? gold
        : u.side === 'player'
          ? '#718c87'
          : '#a17a64';
      ctx.lineWidth = selected ? 1.5 : 0.7;
      ctx.strokeRect(rect.x, rect.y, w, h);
      const wavering =
        u.side === 'enemy' && !u.uncertain && u.morale < 35 && !u.routed;
      if (wavering && !this.options.reducedMotion()) {
        ctx.fillStyle = `rgba(255,255,255,${0.12 + (0.16 * (1 + Math.sin((s.battle?.time || 0) * 2.5))) / 2})`;
        ctx.fillRect(rect.x, rect.y, w, 19);
      }
      const host = s.battle?.commanders.find((c) => c.hostId === u.id);
      let title = u.routed ? 'Routing' : wavering ? 'Wavering' : u.name;
      ctx.font = '500 10px Inter, Arial';
      while (
        ctx.measureText(title).width > w - (host ? 28 : 10) &&
        title.length > 3
      )
        title = title.slice(0, -2).trimEnd() + '.';
      ctx.fillStyle = '#f3efdf';
      ctx.textAlign = 'center';
      ctx.fillText(title, rect.x + w / 2 + (host ? 7 : 0), rect.y + 10);
      if (host) {
        ctx.fillStyle = '#e8cd8b';
        ctx.textAlign = 'left';
        ctx.fillText(
          host.corpsId === 'c1' ? 'I' : 'II',
          rect.x + 6,
          rect.y + 10,
        );
      }
      const sub = u.uncertain
        ? 'Last reported'
        : u.kind === 'general'
          ? 'Army command'
          : u.kind === 'wagon'
            ? `${Math.round(u.stock)} supplies`
            : u.formationChange
              ? `${u.formationChange.to} ${Math.ceil(u.formationChange.duration - u.formationChange.elapsed)}s`
              : u.side === 'player'
                ? `${Math.ceil(u.men).toLocaleString()} / ${Math.round(100 - (u.condition ?? 100))}% fatigue`
                : `${Math.ceil(u.men).toLocaleString()} men`;
      ctx.font = '10px Inter, Arial';
      ctx.fillStyle = '#d0d6c9';
      ctx.textAlign = 'center';
      ctx.fillText(
        sub.length > 23 ? sub.slice(0, 22) + '.' : sub,
        rect.x + w / 2,
        rect.y + 25,
      );
      if (h === 43) {
        ctx.fillStyle = '#182c29';
        ctx.fillRect(rect.x + 5, rect.y + 32, w - 10, 7);
        ctx.fillStyle = u.routed ? '#dd9378' : '#a6c6b3';
        ctx.fillRect(
          rect.x + 5,
          rect.y + 32,
          (w - 10) * clamp((u.morale ?? 100) / 100, 0, 1),
          3,
        );
        if (u.side === 'player') {
          ctx.fillStyle = '#d4bc7b';
          ctx.fillRect(
            rect.x + 5,
            rect.y + 37,
            (w - 10) * clamp((u.condition ?? 100) / 100, 0, 1),
            2,
          );
        }
      }
    }
    for (const town of this.data.towns) {
      const p = this.project(town.x, town.y + 46, 2);
      const r = { x: p.x - 64, y: p.y - 9, w: 128, h: 18 };
      if (
        p.x > 70 &&
        p.x < this.width - 70 &&
        p.y > 100 &&
        p.y < this.height - 100 &&
        !occupied.some((o) => overlaps(r, o))
      )
        this.caption(town.name, p.x, p.y, '#eee9d2', 12);
    }
  }
  drawFog() {
    const b = this.model.state.battle;
    if (!b?.visibleCells) return;
    if (!this.fogMask) {
      this.fogMask = document.createElement('canvas');
      this.fogMask.width = 30;
      this.fogMask.height = 20;
      this.fogSoft = document.createElement('canvas');
      this.fogSoft.width = 720;
      this.fogSoft.height = 480;
    }
    if (this.fogCells !== b.visibleCells) {
      const mask = this.fogMask.getContext('2d');
      mask.clearRect(0, 0, 30, 20);
      mask.fillStyle = 'rgba(30,49,45,.42)';
      b.visibleCells.forEach((visible, i) => {
        if (!visible) mask.fillRect(i % 30, Math.floor(i / 30), 1, 1);
      });
      // Keep blur off the live HUD canvas to avoid retaining old labels after pan.
      const soft = this.fogSoft.getContext('2d');
      soft.clearRect(0, 0, 720, 480);
      soft.filter = 'blur(6px)';
      soft.drawImage(this.fogMask, 0, 0, 720, 480);
      this.fogCells = b.visibleCells;
    }
    const a = this.project(0, 0),
      c = this.project(WORLD.width, 0),
      d = this.project(0, WORLD.height);
    const ctx = this.ctx;
    ctx.save();
    ctx.transform(
      (c.x - a.x) / WORLD.width,
      (c.y - a.y) / WORLD.width,
      (d.x - a.x) / WORLD.height,
      (d.y - a.y) / WORLD.height,
      a.x,
      a.y,
    );
    ctx.drawImage(this.fogSoft, 0, 0, WORLD.width, WORLD.height);
    ctx.restore();
  }
  drawMinimap(entities) {
    const canvas = this.options.minimap?.();
    if (!canvas) return;
    const ctx = canvas.getContext('2d'),
      source = this.terrain.material.map.image;
    ctx.clearRect(0, 0, 150, 100);
    ctx.drawImage(
      source,
      (PADDING / EXTENT.width) * source.width,
      (PADDING / EXTENT.height) * source.height,
      (WORLD.width / EXTENT.width) * source.width,
      (WORLD.height / EXTENT.height) * source.height,
      0,
      0,
      150,
      100,
    );
    if (this.model.state.mode === 'battle') {
      ctx.fillStyle = '#223c34a0';
      this.model.state.battle.visibleCells?.forEach((visible, i) => {
        if (!visible) ctx.fillRect((i % 30) * 5, Math.floor(i / 30) * 5, 5, 5);
      });
      const o = fieldFor(this.model.state.battle).objective;
      ctx.strokeStyle = gold;
      ctx.strokeRect(o.x / 9.6 - 4, o.y / 9.6 - 4, 8, 8);
    }
    for (const u of entities) {
      ctx.fillStyle =
        u.kind === 'general'
          ? gold
          : u.side === 'player'
            ? '#aeddea'
            : '#ecae9c';
      ctx.globalAlpha = u.uncertain ? 0.5 : 1;
      ctx.fillRect(u.x / 9.6 - 1.8, u.y / 9.6 - 1.8, 3.6, 3.6);
    }
    ctx.globalAlpha = 1;
    ctx.strokeStyle = '#f5e7b3';
    ctx.lineWidth = 1;
    ctx.beginPath();
    if (!this.minimapView) {
      this.minimapView = [
        [0, 0],
        [this.width, 0],
        [this.width, this.height],
        [0, this.height],
      ].map(([x, y]) => this.ground({ x, y }));
      this.minimapView.push(this.minimapView[0]);
    }
    this.minimapView.forEach((p, i) => {
      if (p)
        i ? ctx.lineTo(p.x / 9.6, p.y / 9.6) : ctx.moveTo(p.x / 9.6, p.y / 9.6);
    });
    ctx.stroke();
  }
  invalidate() {
    this.frameGate.invalidate();
  }
  drawArtilleryImpacts() {
    const b = this.model.state.battle,
      ctx = this.ctx;
    this.stats.impacts = 0;
    for (const impact of b.artilleryImpacts || []) {
      const age = b.time - impact.time;
      if (!impact.visible || age < 0 || age >= 6) continue;
      const p = this.project(impact.x, impact.y, 1);
      if (p.x < 0 || p.y < 0 || p.x > this.width || p.y > this.height) continue;
      this.stats.impacts++;
      const fade = Math.min(1, (6 - age) / 2);
      ctx.save();
      ctx.globalAlpha = fade;
      ctx.strokeStyle = impact.hit ? '#f0d093' : '#d5d6c0';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.ellipse(p.x, p.y, 4.5, 2.8, 0, 0, Math.PI * 2);
      ctx.fillStyle = '#34352ed9';
      ctx.fill();
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(p.x - 7, p.y);
      ctx.lineTo(p.x - 4, p.y);
      ctx.moveTo(p.x + 4, p.y);
      ctx.lineTo(p.x + 7, p.y);
      ctx.stroke();
      if (age < 0.9) {
        ctx.globalAlpha = (1 - age / 0.9) * 0.6;
        ctx.fillStyle = impact.kind === 'canister' ? '#d0c8a7' : '#b4aa89';
        ctx.beginPath();
        ctx.ellipse(
          p.x + age * 5,
          p.y - age * 6,
          3 + age * 9,
          2 + age * 6,
          0,
          0,
          Math.PI * 2,
        );
        ctx.fill();
      }
      ctx.restore();
    }
  }
  frame(delta) {
    if (this.disposed || document.hidden) return;
    if (this.model.state.report || this.options.cameraBlocked?.())
      this.cameraKeys.clear();
    const pan = cameraMovement(
      this.cameraKeys,
      delta,
      (this.camera.right - this.camera.left) / this.width,
    );
    if (pan.x || pan.y) {
      this.center.x += pan.x;
      this.center.y += pan.y;
      this.updateCamera();
    }
    const active = !this.model.state.paused && !this.model.state.report;
    if (!this.frameGate.consume(active)) {
      this.stats.idleSkips++;
      return;
    }
    this.render(delta);
  }
  render(delta) {
    if (this.disposed) return;
    this.frameGate.dirty = false;
    const s = this.model.state;
    if (s.mode !== this.mode) {
      this.buildLandscape();
      this.home();
      this.shots.clear();
      this.smoke = [];
      this.animation.clear();
    }
    const entities = this.entities();
    this.populateTroops(entities);
    this.renderer.info.reset();
    this.staticPass.render(
      this.renderer,
      this.scene,
      this.camera,
      this.landscape,
      [...this.troops, this.troopShadows],
    );
    const ctx = this.ctx,
      ratio = this.renderer.getPixelRatio();
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    ctx.clearRect(0, 0, this.width, this.height);
    if (s.mode === 'battle') {
      this.audio.tick(s.battle, s.paused);
      this.drawFog();
      const objective = fieldFor(s.battle).objective;
      this.circle(objective, objective.radius, '#f0d79399', 1.5, [5, 6]);
      const p = this.project(objective.x, objective.y, 10);
      this.caption('CROSSING', p.x, p.y - 10, '#ffe7a4', 11);
      const selected = entities.filter(
        (u) => s.selected.includes(u.id) && !u.routed,
      );
      if (this.showRanges && selected.length) this.range(selected[0]);
      const commander = s.battle.commanders.find(
        (c) =>
          c.id === s.selectedCommander ||
          (selected.length === 1 && c.hostId === selected[0].id),
      );
      if (commander)
        this.circle(commander, commander.radius, '#a8cdda88', 1.2, [3, 5]);
      for (const u of selected) {
        this.circle(u, 26, '#f7dd9dcc', 1.5);
        if (u.target)
          this.line(
            [
              u,
              u.target,
              ...(u.waypoints || []),
              ...(u.orderQueue || []).map((o) => o.point),
            ],
            gold,
            1.7,
            [5, 5],
          );
      }
      for (const u of entities)
        if (u.flash > 0 && u.firedAt) {
          const ranged = u.shotKind !== 'melee';
          if (ranged && u.shotKind === 'cannon' && u.artilleryImpacts) {
            for (const impact of u.artilleryImpacts)
              this.line([u, impact], '#ffe8ad80', 1);
          } else if (ranged)
            this.line(
              [u, u.firedAt],
              u.kind === 'artillery' ? '#ffe8adb0' : '#fff3c65a',
              u.kind === 'artillery' ? 2 : 1,
            );
          if (this.shots.get(u.id) !== u.shotTime) {
            this.shots.set(u.id, u.shotTime);
            if (ranged)
              this.smoke.push({
                x: u.x,
                y: u.y,
                t: s.battle.time,
                large: u.kind === 'artillery',
              });
            if (!s.paused) this.audio.play(u.shotKind || 'musket', u.x);
          }
        }
      this.smoke = this.smoke.filter((p) => s.battle.time - p.t < 3.5);
      for (const puff of this.smoke) {
        const age = s.battle.time - puff.t,
          p = this.project(puff.x + age * 9, puff.y - age * 5, 10 + age * 4),
          r = (puff.large ? 12 : 7) + age * 7;
        const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, r);
        g.addColorStop(0, `rgba(234,235,221,${0.6 * (1 - age / 3.5)})`);
        g.addColorStop(1, 'rgba(234,235,221,0)');
        ctx.fillStyle = g;
        ctx.fillRect(p.x - r, p.y - r, r * 2, r * 2);
      }
      this.drawMuzzles();
      this.drawArtilleryImpacts();
    } else if (s.army.path.length) {
      this.line([s.army, ...s.army.path], gold, 2, [6, 6]);
      this.circle(s.army.path.at(-1), 12, gold, 2);
    }
    if (
      this.hover?.entity?.side === 'enemy' &&
      !this.hover.entity.uncertain &&
      s.selected.length
    )
      this.circle(this.hover.entity, 31, hostile, 2);
    this.drawLabels(entities);
    this.drawMinimap(entities);
    if (
      this.drag?.end &&
      !this.drag.pan &&
      Math.hypot(this.drag.end.x - this.drag.x, this.drag.end.y - this.drag.y) >
        8
    ) {
      if (this.drag.button === 2) {
        const to = this.ground(this.drag.end);
        if (to && this.drag.world)
          this.line([this.drag.world, to], gold, 2, [6, 4]);
      } else {
        ctx.fillStyle = '#a0ccd21a';
        ctx.strokeStyle = '#d7e6c4';
        ctx.lineWidth = 1;
        ctx.fillRect(
          this.drag.x,
          this.drag.y,
          this.drag.end.x - this.drag.x,
          this.drag.end.y - this.drag.y,
        );
        ctx.strokeRect(
          this.drag.x,
          this.drag.y,
          this.drag.end.x - this.drag.x,
          this.drag.end.y - this.drag.y,
        );
      }
    }
    this.stats.frames++;
    this.stats.drawCalls = this.renderer.info.render.calls;
    this.stats.triangles = this.renderer.info.render.triangles;
    this.stats.landscapeCaptures = this.staticPass.captures;
    if (delta > 0) {
      this.stats.frameTimes.push(delta * 1000);
      if (this.stats.frameTimes.length > 600) this.stats.frameTimes.shift();
    }
  }
  hit(point) {
    return [...this.hitAreas]
      .reverse()
      .find(
        (r) =>
          point.x >= r.x &&
          point.x <= r.x + r.w &&
          point.y >= r.y &&
          point.y <= r.y + r.h,
      )?.entity;
  }
  bindInput() {
    const canvas = this.renderer.domElement;
    this.handlers = [];
    const on = (type, fn, options) => {
      const handler = (event) => {
        this.invalidate();
        fn(event);
      };
      canvas.addEventListener(type, handler, options);
      this.handlers.push([type, handler, options]);
    };
    const screen = (e) => {
      const r = canvas.getBoundingClientRect();
      return { x: e.clientX - r.left, y: e.clientY - r.top };
    };
    on('contextmenu', (e) => e.preventDefault());
    on('webglcontextlost', (e) => {
      e.preventDefault();
      this.model.state.paused = true;
      this.options.error(
        'Graphics interrupted. Reload the demo to reconnect. Your campaign save is unchanged.',
      );
    });
    on('pointerdown', (e) => {
      e.preventDefault();
      canvas.focus();
      this.audio.unlock();
      const p = screen(e);
      this.drag = {
        ...p,
        world: this.ground(p),
        button: e.button,
        shift: e.shiftKey,
        pan: e.button === 1 || e.altKey,
        center: { ...this.center },
        touch: e.pointerType === 'touch',
      };
      canvas.setPointerCapture(e.pointerId);
    });
    on('pointermove', (e) => {
      const p = screen(e),
        s = this.model.state,
        hit = this.hit(p);
      this.hover = { point: p, entity: hit };
      const canOrder =
        s.mode === 'campaign' ||
        s.selected.length ||
        s.selectedCommander ||
        s.selectedSupply;
      canvas.style.cursor = hit
        ? hit.side === 'enemy' && !hit.uncertain && canOrder
          ? this.options.cursors.attack
          : this.options.cursors.inspect
        : legalGround(this.ground(p), s) && canOrder
          ? this.options.cursors.move
          : this.options.cursors.blocked;
      if (!this.drag) return;
      this.drag.end = p;
      const moved = Math.hypot(p.x - this.drag.x, p.y - this.drag.y) > 8;
      if (
        this.drag.pan ||
        (this.drag.button === 0 &&
          moved &&
          (s.mode === 'campaign' || (this.drag.touch && !this.touchOrders)))
      ) {
        this.drag.pan = true;
        const scale = (this.camera.right - this.camera.left) / this.width;
        this.center.x = this.drag.center.x - (p.x - this.drag.x) * scale;
        this.center.y =
          this.drag.center.y - ((p.y - this.drag.y) * scale) / 0.866;
        this.updateCamera();
      }
    });
    on('pointercancel', () => {
      this.drag = null;
    });
    on('lostpointercapture', () => {
      this.drag = null;
    });
    on('pointerup', (e) => {
      const drag = this.drag;
      this.drag = null;
      if (!drag || drag.pan) return;
      const p = screen(e),
        world = this.ground(p),
        hit = this.hit(p),
        s = this.model.state;
      if (!world) return;
      const moved = Math.hypot(p.x - drag.x, p.y - drag.y) > 10;
      const order = drag.button === 2 || (drag.touch && this.touchOrders);
      if (order) {
        const destination =
          hit?.side === 'enemy' ? { x: hit.x, y: hit.y } : world;
        if (!legalGround(destination, s)) {
          this.options.notify('No legal route to that position.');
          return;
        }
        if (s.mode === 'campaign') this.model.moveArmy(destination);
        else if (moved && drag.world) {
          if (s.selected.length > 1) this.model.frontline(drag.world, world);
          else
            this.model.moveUnits(
              drag.world,
              null,
              drag.shift,
              Math.atan2(world.y - drag.world.y, world.x - drag.world.x),
            );
        } else if (
          hit?.side === 'enemy' &&
          !hit.uncertain &&
          hit.kind !== 'wagon'
        )
          this.model.moveUnits(destination, hit.id, drag.shift);
        else this.model.moveUnits(world, null, drag.shift);
        this.audio.play('order', world.x);
        return;
      }
      if (moved && s.mode === 'battle') {
        const ids = this.entities()
          .filter(
            (u) =>
              u.side === 'player' &&
              !u.routed &&
              s.battle.units.some((b) => b.id === u.id),
          )
          .filter((u) => {
            const q = this.project(u.x, u.y, 10);
            return (
              q.x >= Math.min(drag.x, p.x) &&
              q.x <= Math.max(drag.x, p.x) &&
              q.y >= Math.min(drag.y, p.y) &&
              q.y <= Math.max(drag.y, p.y)
            );
          })
          .map((u) => u.id);
        this.model.select(
          drag.shift ? [...new Set([...s.selected, ...ids])] : ids,
        );
        this.options.inspect(null);
        return;
      }
      if (hit) {
        if (hit.side === 'player' && s.mode === 'battle') {
          if (hit.kind === 'general') this.model.selectCommander(hit.id);
          else if (hit.kind === 'wagon') this.model.selectSupply();
          else
            this.model.select(
              drag.shift
                ? s.selected.includes(hit.id)
                  ? s.selected.filter((id) => id !== hit.id)
                  : [...s.selected, hit.id]
                : [hit.id],
            );
        }
        this.options.inspect(hit.id);
      } else {
        this.model.select([]);
        this.options.inspect(null);
      }
    });
    on(
      'wheel',
      (e) => {
        e.preventDefault();
        this.setZoom(e.deltaY < 0 ? 1.1 : 1 / 1.1);
      },
      { passive: false },
    );
    canvas.tabIndex = 0;
    canvas.setAttribute(
      'aria-label',
      'Tactical map. Left click to inspect. Right click to order.',
    );
  }
  dispose() {
    this.disposed = true;
    this.cameraKeys.clear();
    this.unsubscribe();
    this.resizeObserver.disconnect();
    for (const [type, fn, options] of this.handlers)
      this.renderer.domElement.removeEventListener(type, fn, options);
    this.clearLandscape();
    for (const asset of this.assets) asset.dispose();
    for (const mesh of this.troops) mesh.dispose();
    this.troopShadows.dispose();
    this.staticPass.dispose();
    this.renderer.dispose();
    this.renderer.forceContextLoss();
    this.audio.destroy();
    this.renderer.domElement.remove();
    this.overlay.remove();
  }
}
