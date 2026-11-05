import React, { useEffect, useReducer, useRef, useState } from 'react';
import {
  ArrowLeft,
  ArrowRight,
  Check,
  Coins,
  Crosshair,
  Flag,
  Footprints,
  Crown,
  EyeOff,
  Navigation,
  Group,
  Heart,
  Map,
  Maximize,
  Minus,
  Pause,
  Play,
  Plus,
  RotateCcw,
  Rows3,
  Save,
  Shield,
  Square,
  Swords,
  Target,
  Tent,
  Trophy,
  Users,
  Truck,
  Volume2,
  VolumeX,
  Binoculars,
  MoveHorizontal,
  CornerDownLeft,
  PersonStanding,
  Split,
  Merge,
  Gauge,
  MapPin,
  X,
} from 'lucide-react';
import {
  Campaign,
  SPEEDS,
  WEAPONS,
  countMen,
  terrainAt,
} from './game/model.js';
import { createGame, MAP_PADDING } from './game/scene.js';
import { CommandStrip } from './components/CommandPanel.jsx';
import { FORMATIONS } from './game/formations.js';
import { fieldFor } from './game/battlefields.js';
import Headquarters from './components/Headquarters.jsx';

const format = (number) => Math.round(number).toLocaleString();
const timeOf = (hours) =>
  `${String(Math.floor(hours % 24)).padStart(2, '0')}:${String(Math.floor((hours % 1) * 60)).padStart(2, '0')}`;
const unitIcon = (kind) =>
  kind === 'artillery' ? Target : kind === 'cavalry' ? Swords : Shield;
function IconButton({ icon: Icon, label, className = '', ...props }) {
  return (
    <button
      type="button"
      className={`icon-button ${className}`}
      aria-label={label}
      data-tip={label}
      {...props}
    >
      <Icon size={17} strokeWidth={1.6} />
    </button>
  );
}
function Meter({ value, color = 'green' }) {
  return (
    <span className={`meter ${color}`}>
      <span style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
    </span>
  );
}
function FrenchFlag() {
  return (
    <span className="french-flag" aria-label="France">
      <i />
      <i />
      <i />
    </span>
  );
}
function Modal({ title, eyebrow, onClose, children, className = '' }) {
  const ref = useRef(null);
  const closeRef = useRef(onClose);
  closeRef.current = onClose;
  useEffect(() => {
    const before = document.activeElement;
    ref.current?.focus();
    const key = (e) => {
      if (e.key === 'Escape') closeRef.current?.();
      if (e.key === 'Tab') {
        const elements = [
          ...ref.current.querySelectorAll(
            'button:not([disabled]), select, input, [tabindex="0"]',
          ),
        ];
        const first = elements[0],
          last = elements.at(-1);
        if (
          e.shiftKey &&
          (document.activeElement === first ||
            document.activeElement === ref.current)
        ) {
          e.preventDefault();
          last?.focus();
        }
        if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first?.focus();
        }
      }
    };
    document.addEventListener('keydown', key);
    return () => {
      document.removeEventListener('keydown', key);
      before?.focus();
    };
  }, []);
  return (
    <div className="modal-backdrop">
      <section
        ref={ref}
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={`modal ${className}`}
      >
        <div className="modal-heading">
          <div>
            <span className="eyebrow">{eyebrow}</span>
            <h2>{title}</h2>
          </div>
          {onClose && <IconButton icon={X} label="Close" onClick={onClose} />}
        </div>
        {children}
      </section>
    </div>
  );
}

function MiniMap({ model, controls, revision }) {
  const ref = useRef(null);
  useEffect(() => {
    const canvas = ref.current,
      scene = controls.current?.scene;
    if (!canvas || !scene?.textures) return;
    const ctx = canvas.getContext('2d'),
      s = model.state;
    ctx.clearRect(0, 0, 180, 120);
    const texture = scene.textures
      .get(s.mode === 'battle' ? s.battle.scenario : 'campaign')
      .getSourceImage();
    ctx.drawImage(texture, MAP_PADDING, MAP_PADDING, 1440, 960, 0, 0, 180, 120);
    if (s.mode === 'battle') {
      ctx.fillStyle = '#17231dcc';
      s.battle.visibleCells?.forEach((visible, i) => {
        if (!visible) ctx.fillRect((i % 30) * 6, Math.floor(i / 30) * 6, 6, 6);
      });
      const objective = fieldFor(s.battle).objective;
      ctx.strokeStyle = '#e7c578';
      ctx.strokeRect(objective.x / 8 - 4, objective.y / 8 - 4, 8, 8);
    }
    const units =
      s.mode === 'campaign'
        ? [
            { ...s.army, side: 'player' },
            ...s.enemies
              .filter((e) => !e.defeated)
              .map((e) => (model.enemyVisible(e) ? e : { ...e, ...e.intel })),
          ]
        : s.battle.units.filter(
            (u) =>
              u.visible && !u.routed && u.men > 0 && u.arrival <= s.battle.time,
          );
    for (const u of units) {
      ctx.fillStyle = u.side === 'player' ? '#9ed3f5' : '#f0a08b';
      ctx.strokeStyle = '#27382a';
      ctx.lineWidth = 1;
      ctx.fillRect(u.x / 8 - 2.5, u.y / 8 - 2.5, 5, 5);
      ctx.strokeRect(u.x / 8 - 2.5, u.y / 8 - 2.5, 5, 5);
    }
    if (s.mode === 'battle') {
      for (const c of s.battle.commanders) {
        ctx.fillStyle = s.selectedCommander === c.id ? '#fff1b7' : '#dbbc70';
        ctx.beginPath();
        ctx.arc(c.x / 8, c.y / 8, 2.5, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
      }
    }
    const camera = scene.cameras.main,
      view = camera.worldView;
    ctx.strokeStyle = '#f9e6a8';
    ctx.lineWidth = 1;
    ctx.strokeRect(view.x / 8, view.y / 8, view.width / 8, view.height / 8);
  }, [model, controls, revision]);
  return (
    <button
      className="minimap"
      aria-label="Recenter the map"
      onClick={(e) => {
        const r = ref.current.getBoundingClientRect();
        controls.current?.scene.cameras.main.centerOn(
          Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * 1440,
          Math.max(0, Math.min(1, (e.clientY - r.top) / r.height)) * 960,
        );
      }}
    >
      <canvas width="180" height="120" ref={ref} />
      <span>
        <span className="north">N</span> THEATER OVERVIEW
      </span>
    </button>
  );
}

export default function App() {
  const [model] = useState(() => {
    let storage;
    try {
      storage = window.localStorage;
    } catch {
      storage = null;
    }
    return new Campaign(storage);
  });
  const [revision, refresh] = useReducer((v) => v + 1, 0);
  const [camp, setCamp] = useState(false),
    [campTab, setCampTab] = useState('army'),
    [confirm, setConfirm] = useState(null),
    [toast, setToast] = useState('');
  const mapRef = useRef(null),
    controls = useRef(null),
    toastTimer = useRef(null);
  const s = model.state,
    battle = s.mode === 'battle';
  const notify = (message) => {
    setToast(message);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(''), 3200);
  };
  useEffect(() => model.subscribe(refresh), [model]);
  useEffect(() => {
    const game = createGame(mapRef.current, model, (c) => {
      controls.current = c;
      refresh();
    });
    const save = () => model.save();
    const hidden = () => {
      if (document.hidden) {
        model.state.paused = true;
        model.publish();
      }
    };
    window.addEventListener('beforeunload', save);
    document.addEventListener('visibilitychange', hidden);
    if (import.meta.env.DEV) window.__fieldCommand = { model, controls };
    return () => {
      game.destroy(true);
      window.removeEventListener('beforeunload', save);
      document.removeEventListener('visibilitychange', hidden);
      clearTimeout(toastTimer.current);
      delete window.__fieldCommand;
    };
  }, [model]);
  useEffect(() => {
    const key = (e) => {
      if (
        camp ||
        confirm ||
        s.report ||
        /INPUT|SELECT|TEXTAREA|BUTTON/.test(e.target.tagName)
      )
        return;
      if (e.code === 'Space') {
        e.preventDefault();
        model.pause();
      }
      if (e.key.toLowerCase() === 'h') model.halt();
      if (e.key.toLowerCase() === 'q') model.selectCorps('c1');
      if (e.key.toLowerCase() === 'w') model.selectCorps('c2');
      if (e.key.toLowerCase() === 'g' && battle)
        model.selectCommander(s.general.id);
      if (e.key.toLowerCase() === 'r' && battle) model.rally();
      if (e.key.toLowerCase() === 'f' && battle) model.fallBack();
      if (e.key.toLowerCase() === 'l' && battle)
        model.setOrderMode(s.orderMode === 'frontline' ? 'move' : 'frontline');
      if (e.key.toLowerCase() === 'v' && battle) model.run();
      if (e.key.toLowerCase() === 't' && battle) model.selectSupply();
      if (e.key.toLowerCase() === 'a' && battle)
        model.select(
          s.battle.units
            .filter((u) => u.side === 'player' && !u.routed)
            .map((u) => u.id),
        );
      if (['0', '1', '2', '3'].includes(e.key))
        model.speed(SPEEDS[Number(e.key)]);
      if (e.key === 'Escape') model.select([]);
    };
    window.addEventListener('keydown', key);
    return () => window.removeEventListener('keydown', key);
  }, [model, camp, confirm, s.report, battle, s]);
  const roster = battle
    ? s.battle.units.filter((u) => u.side === 'player')
    : s.units;
  const selected = roster.filter(
    (u) => s.selected.includes(u.id) && !u.routed && u.men > 0,
  );
  const first = selected[0] || roster[0];
  const commander = s.battle?.commanders.find(
    (c) => c.id === s.selectedCommander,
  );
  const supply =
    battle && s.selectedSupply
      ? s.battle.wagons.find((w) => w.side === 'player')
      : null;
  const objective = battle
    ? {
        ...fieldFor(s.battle).objective,
        type: fieldFor(s.battle).type,
        title: `${fieldFor(s.battle).type === 'defend' ? 'Hold' : 'Secure'} ${fieldFor(s.battle).name}`,
      }
    : null;
  const change = selected.find((u) => u.formationChange)?.formationChange;
  const activeEnemies = battle
    ? s.battle.units.filter((u) => u.side === 'enemy' && u.visible && !u.routed)
    : [];
  const openCamp = (tab = 'army') => {
    s.paused = true;
    model.publish();
    setCampTab(typeof tab === 'string' ? tab : 'army');
    setCamp(true);
  };
  const askReset = () => {
    s.paused = true;
    model.publish();
    setConfirm('reset');
  };
  const askWithdraw = () => {
    s.paused = true;
    model.publish();
    setConfirm('withdraw');
  };
  const firstIcon = unitIcon(first?.kind || 'infantry');
  const FirstIcon = firstIcon;
  return (
    <div className="app-shell">
      <header className="topbar">
        <div className="brand">
          <span className="brand-emblem">
            <Swords size={25} strokeWidth={1.1} />
          </span>
          <div>
            <h1>Field Command</h1>
            <span>THE DANUBE CAMPAIGN</span>
          </div>
        </div>
        <nav className="main-nav" aria-label="Views">
          <button
            className="active"
            aria-label={battle ? 'Battlefield' : 'Campaign'}
            onClick={() => controls.current?.center()}
          >
            <Map size={16} />
            <span>{battle ? 'Battlefield' : 'Campaign'}</span>
          </button>
          <button
            aria-label="Army camp"
            onClick={openCamp}
            disabled={battle || !!s.report}
          >
            <Tent size={17} />
            <span>Army camp</span>
          </button>
        </nav>
        <div className="top-resources">
          <span>
            <Users size={16} />
            <strong>{format(countMen(roster))}</strong>
            <small>men</small>
          </span>
          <span className="money">
            <Coins size={17} />
            <strong>{format(s.cash)}</strong>
            <small>F</small>
          </span>
        </div>
        <div className="header-actions">
          <div className="sound-settings">
            <IconButton
              icon={s.settings.sound ? Volume2 : VolumeX}
              label={s.settings.sound ? 'Mute sound' : 'Enable sound'}
              aria-pressed={s.settings.sound}
              onClick={() => {
                model.setSound(!s.settings.sound);
                controls.current?.audio.unlock();
              }}
            />
            <label className="sound-volume">
              Volume
              <input
                type="range"
                aria-label="Sound volume"
                min="0"
                max="1"
                step="0.05"
                value={s.settings.volume}
                onChange={(e) => {
                  controls.current?.audio.unlock();
                  model.setSound(s.settings.sound, Number(e.target.value));
                }}
              />
            </label>
          </div>
          <IconButton
            icon={Save}
            label="Save campaign"
            onClick={() => {
              model.save();
              notify(
                model.saveFailed
                  ? 'Saving is unavailable in this browser.'
                  : 'Campaign saved.',
              );
            }}
          />
          <IconButton
            icon={RotateCcw}
            label="New campaign"
            onClick={askReset}
          />
        </div>
      </header>
      <main className="theater">
        <div
          className="game-map"
          ref={mapRef}
          role="application"
          aria-label={
            battle
              ? 'Battlefield. Select regiments, then click to issue orders.'
              : 'Campaign map. Click a destination to march your army.'
          }
        />
        <div className={`map-heading ${battle ? 'battle-heading' : ''}`}>
          <span className="eyebrow">
            {battle ? 'TACTICAL ENGAGEMENT' : 'SOUTHERN GERMANY'}
          </span>
          <h2>{battle ? s.battle.name : 'The Danube, 1805'}</h2>
          <span className="weather">
            <span className="weather-sun" /> Clear skies{' '}
            <span className="dot" />{' '}
            {battle
              ? `${Math.floor(s.battle.time / 60)}:${String(Math.floor(s.battle.time % 60)).padStart(2, '0')} elapsed`
              : `October ${6 + Math.floor(s.hours / 24)}, 1805`}
          </span>
        </div>
        <div className="time-panel">
          <div className="time-readout">
            <span className={`live-dot ${s.paused ? 'paused' : ''}`} />
            <strong>
              {s.paused ? 'PAUSED' : battle ? 'IN BATTLE' : 'CAMPAIGN LIVE'}
            </strong>
            <span>{timeOf(s.hours + (battle ? s.battle.time / 120 : 0))}</span>
          </div>
          <div className="time-controls">
            <IconButton
              icon={s.paused ? Play : Pause}
              label={s.paused ? 'Resume time (Space)' : 'Pause time (Space)'}
              className="play-button"
              disabled={!!s.report}
              onClick={() => model.pause()}
            />
            <span className="control-divider" />
            {SPEEDS.map((speed) => (
              <button
                key={speed}
                className={`speed-button ${s.speed === speed ? 'active' : ''}`}
                aria-label={`${speed}x speed`}
                aria-pressed={s.speed === speed}
                onClick={() => model.speed(speed)}
              >
                {speed}&times;
              </button>
            ))}
          </div>
        </div>
        <aside className="objective-panel">
          <div className="section-label">
            <Flag size={13} />{' '}
            {battle ? 'BATTLE OBJECTIVE' : 'CAMPAIGN OBJECTIVE'}
          </div>
          <h3>{battle ? objective.title : 'Secure the Danube'}</h3>
          {battle ? (
            <>
              <div className="strength-comparison">
                <span>
                  <i className="blue-mark" /> {format(countMen(roster))}
                </span>
                <span>
                  {format(countMen(activeEnemies))} sighted{' '}
                  <i className="red-mark" />
                </span>
              </div>
              <p>
                <span>
                  {objective.type === 'defend' ? 'Defense' : 'Occupation'}
                </span>
                <b>
                  {Math.floor(s.battle.objective.player)} / {objective.seconds}{' '}
                  s
                </b>
              </p>
              <div className="balance-meter">
                <span
                  style={{
                    width: `${(countMen(roster) / Math.max(1, countMen(roster) + countMen(activeEnemies))) * 100}%`,
                  }}
                />
              </div>
              {s.battle.units.some((u) => u.arrival > s.battle.time) && (
                <p className="reinforcement-alert">
                  Enemy reinforcements approaching
                </p>
              )}
            </>
          ) : (
            <>
              <p>
                Austrian forces defeated <b>{s.victories} / 3</b>
              </p>
              <div className="objective-progress">
                {s.enemies.map((e) => (
                  <span key={e.id} className={e.defeated ? 'complete' : ''} />
                ))}
              </div>
            </>
          )}
        </aside>
        {!battle && (
          <aside className="dispatch-panel">
            <span className="section-label">FIELD DISPATCHES</span>
            <p>{s.log[0]?.text}</p>
            <span className="dispatch-time">
              {timeOf(s.log[0]?.hours || 0)}
            </span>
          </aside>
        )}
        <div className="map-tools">
          <IconButton
            icon={Plus}
            label="Zoom in"
            onClick={() => controls.current?.zoom(1.2)}
          />
          <IconButton
            icon={Minus}
            label="Zoom out"
            onClick={() => controls.current?.zoom(1 / 1.2)}
          />
          <IconButton
            icon={Maximize}
            label="Center map"
            onClick={() => controls.current?.center()}
          />
        </div>
        <div className="map-scale">
          <span
            style={{
              width: `${60 * (controls.current?.scene.cameras.main.zoom || 1)}px`,
            }}
          />
          <small>{battle ? '250 m' : '10 km'}</small>
        </div>
        {battle &&
          (commander || change || supply || s.orderMode !== 'move') && (
            <div className="order-context" role="status">
              {supply ? (
                <>
                  <Truck size={14} />
                  <strong>Supply train</strong>
                  <span>
                    {Math.ceil(supply.stock)} stores ·{' '}
                    {Math.ceil(supply.health)}% integrity
                  </span>
                </>
              ) : s.orderMode !== 'move' ? (
                <>
                  <MapPin size={14} />
                  <strong>
                    {s.orderMode === 'deploy'
                      ? 'Deployment'
                      : 'Frontline order'}
                  </strong>
                </>
              ) : commander ? (
                <>
                  <Crown size={14} />
                  <strong>{commander.name}</strong>
                  <span>
                    {commander.unavailable
                      ? 'Command unavailable'
                      : commander.shaken
                        ? 'Under pressure'
                        : `${commander.radius} m command`}
                  </span>
                </>
              ) : (
                <>
                  <Rows3 size={14} />
                  <strong>
                    Forming {FORMATIONS[change.to].name.toLowerCase()}
                  </strong>
                  <span>{Math.ceil(change.duration - change.elapsed)} s</span>
                </>
              )}
            </div>
          )}
        {battle && !commander && !supply && (
          <div className="advanced-orders" aria-label="Maneuver orders">
            <IconButton
              icon={MoveHorizontal}
              label="Draw frontline (L)"
              className={s.orderMode === 'frontline' ? 'active' : ''}
              aria-pressed={s.orderMode === 'frontline'}
              disabled={!selected.length}
              onClick={() =>
                model.setOrderMode(
                  s.orderMode === 'frontline' ? 'move' : 'frontline',
                )
              }
            />
            <IconButton
              icon={MapPin}
              label="Deploy regiments"
              className={s.orderMode === 'deploy' ? 'active' : ''}
              aria-pressed={s.orderMode === 'deploy'}
              disabled={!selected.length || s.battle.time > 0 || !s.paused}
              onClick={() =>
                model.setOrderMode(s.orderMode === 'deploy' ? 'move' : 'deploy')
              }
            />
            <IconButton
              icon={Gauge}
              label="Double time (V)"
              className={
                selected.length && selected.every((u) => u.running)
                  ? 'active'
                  : ''
              }
              aria-pressed={
                !!selected.length && selected.every((u) => u.running)
              }
              disabled={!selected.length}
              onClick={() => model.run()}
            />
            <IconButton
              icon={CornerDownLeft}
              label="Fall back facing enemy (F)"
              disabled={!selected.length}
              onClick={() => model.fallBack()}
            />
            <span className="control-divider" />
            <IconButton
              icon={selected.some((u) => u.parentId) ? Merge : Split}
              label={
                selected.some((u) => u.parentId)
                  ? 'Rejoin parent regiment within 90 m'
                  : 'Detach skirmishers'
              }
              disabled={
                !selected.some(
                  (u) =>
                    u.parentId ||
                    (u.kind === 'infantry' &&
                      u.men >= 300 &&
                      !s.battle.units.some((p) => p.parentId === u.id)),
                )
              }
              onClick={() => model.detachSkirmishers()}
            />
            <IconButton
              icon={Truck}
              label={
                selected.some((u) => u.limbered)
                  ? 'Unlimber artillery'
                  : 'Limber artillery'
              }
              className={selected.some((u) => u.limbered) ? 'active' : ''}
              disabled={
                !selected.some((u) => u.kind === 'artillery' && !u.limberChange)
              }
              onClick={() => model.limber()}
            />
            <IconButton
              icon={PersonStanding}
              label={
                selected.some((u) => u.dismounted)
                  ? 'Mount cavalry'
                  : 'Dismount carbine cavalry'
              }
              className={selected.some((u) => u.dismounted) ? 'active' : ''}
              disabled={
                !selected.some(
                  (u) => u.kind === 'cavalry' && u.weapon === 'carbine',
                )
              }
              onClick={() => model.dismount()}
            />
          </div>
        )}
        <div className="orders-bar">
          {supply ? (
            <>
              <Truck size={19} />
              <span className="march-status">
                {supply.health <= 0
                  ? 'Train destroyed'
                  : supply.underAttack
                    ? 'Under attack'
                    : `${Math.ceil(supply.stock)} stores`}
              </span>
              <IconButton
                icon={Shield}
                label="Halt supply train (H)"
                disabled={supply.health <= 0}
                onClick={() => model.halt()}
              />
              <IconButton
                icon={Group}
                label="Select all regiments (A)"
                onClick={() =>
                  model.select(roster.filter((u) => !u.routed).map((u) => u.id))
                }
              />
            </>
          ) : battle && commander ? (
            <>
              <IconButton
                icon={Flag}
                label="Rally nearby troops (R)"
                disabled={
                  commander.cooldown > 0 ||
                  commander.shaken > 0 ||
                  commander.unavailable
                }
                onClick={() => {
                  if (model.rally()) notify('Regiments rallied.');
                  else notify('No eligible regiments in command range.');
                }}
              />
              <span className="rally-status">
                {commander.cooldown > 0
                  ? `${Math.ceil(commander.cooldown)}s`
                  : 'Rally ready'}
              </span>
              <span className="control-divider" />
              <IconButton
                icon={Navigation}
                label="Follow assigned troops"
                className={commander.following ? 'active' : ''}
                onClick={() => model.followCommand()}
              />
              <IconButton
                icon={Shield}
                label="Hold commander position (H)"
                onClick={() => model.halt()}
              />
              <IconButton
                icon={Group}
                label="Select all regiments (A)"
                onClick={() =>
                  model.select(roster.filter((u) => !u.routed).map((u) => u.id))
                }
              />
            </>
          ) : battle ? (
            <>
              <IconButton
                icon={Group}
                label="Select all regiments (A)"
                onClick={() =>
                  model.select(roster.filter((u) => !u.routed).map((u) => u.id))
                }
              />
              <span className="control-divider" />
              <IconButton
                icon={Rows3}
                label="Line formation"
                disabled={!selected.some((u) => u.kind === 'infantry')}
                className={
                  (first?.queuedFormation ||
                    first?.formationChange?.to ||
                    first?.formation) === 'line'
                    ? 'active'
                    : ''
                }
                onClick={() => model.formation('line')}
              />
              <IconButton
                icon={Footprints}
                label="March column"
                disabled={!selected.some((u) => u.kind === 'infantry')}
                className={
                  (first?.queuedFormation ||
                    first?.formationChange?.to ||
                    first?.formation) === 'column'
                    ? 'active'
                    : ''
                }
                onClick={() => model.formation('column')}
              />
              <IconButton
                icon={Square}
                label="Infantry square"
                disabled={!selected.some((u) => u.kind === 'infantry')}
                className={
                  (first?.queuedFormation ||
                    first?.formationChange?.to ||
                    first?.formation) === 'square'
                    ? 'active'
                    : ''
                }
                onClick={() => model.formation('square')}
              />
              <span className="control-divider" />
              <IconButton
                icon={Swords}
                label="Charge nearest enemy"
                disabled={
                  !selected.some(
                    (u) => u.kind !== 'artillery' && !u.formationChange,
                  )
                }
                onClick={() => model.charge()}
              />
              <IconButton
                icon={EyeOff}
                label="Hold fire"
                className={
                  selected.length && selected.every((u) => u.holdFire)
                    ? 'active'
                    : ''
                }
                aria-pressed={
                  !!selected.length && selected.every((u) => u.holdFire)
                }
                disabled={!selected.length}
                onClick={() => model.holdFire()}
              />
              <IconButton
                icon={Shield}
                label="Halt and hold (H)"
                onClick={() => model.halt()}
              />
              <span className="control-divider" />
              <IconButton
                icon={ArrowLeft}
                label="Withdraw army"
                className="danger"
                onClick={askWithdraw}
              />
            </>
          ) : (
            <>
              <span className="march-status">
                <Footprints size={16} />
                {s.army.path.length ? 'Army marching' : 'Army encamped'}
              </span>
              <span className="control-divider" />
              <IconButton
                icon={Shield}
                label="Halt march (H)"
                disabled={!s.army.path.length}
                onClick={() => model.halt()}
              />
              <IconButton
                icon={Crosshair}
                label="Intercept nearest Austrian army"
                disabled={s.victories === 3 || countMen(s.units) === 0}
                onClick={() => {
                  const e = s.enemies
                    .filter((e) => !e.defeated)
                    .map((e) => (model.enemyVisible(e) ? e : e.intel))
                    .sort(
                      (a, b) =>
                        Math.hypot(a.x - s.army.x, a.y - s.army.y) -
                        Math.hypot(b.x - s.army.x, b.y - s.army.y),
                    )[0];
                  if (e) model.moveArmy(e);
                }}
              />
              <IconButton
                icon={Binoculars}
                label="Dispatch scouts (100 F)"
                className={s.recon.remaining > 0 ? 'active' : ''}
                disabled={
                  s.cash < 100 || s.recon.cooldown > 0 || s.victories === 3
                }
                onClick={() => {
                  if (model.scout()) notify('Scouts dispatched.');
                }}
              />
              <span className="campaign-condition">
                <Heart size={12} />
                {Math.round(s.army.condition)}%
              </span>
            </>
          )}
        </div>
        <MiniMap model={model} controls={controls} revision={revision} />
        {toast && (
          <div className="toast" role="status">
            <Check size={16} />
            {toast}
          </div>
        )}
      </main>
      <CommandStrip model={model} openOrganization={() => openCamp('army')} />
      <section className="army-bar" aria-label="Army regiments">
        <div className="army-summary">
          <div className="army-title">
            <FrenchFlag />
            <span>
              {supply
                ? 'Supply train'
                : commander
                  ? commander.name
                  : battle && selected.length > 1
                    ? `${selected.length} regiments selected`
                    : battle
                      ? first?.name
                      : 'Army of the Danube'}
            </span>
          </div>
          <div className="army-strength">
            <strong>
              {supply
                ? Math.ceil(supply.stock)
                : commander
                  ? `${commander.radius} m`
                  : format(
                      countMen(battle && selected.length ? selected : roster),
                    )}
            </strong>
            <span>
              {supply
                ? 'SUPPLY STORES'
                : commander
                  ? 'COMMAND RADIUS'
                  : `MEN ${battle ? 'SELECTED' : 'UNDER ARMS'}`}
            </span>
          </div>
          <div className="army-condition">
            <Heart size={12} />
            <Meter
              value={
                selected.length
                  ? selected.reduce((v, u) => v + u.morale, 0) / selected.length
                  : 100
              }
            />
            <span>
              {supply
                ? `${Math.ceil(supply.health)}% integrity`
                : commander
                  ? commander.unavailable
                    ? 'Unavailable'
                    : commander.shaken
                      ? 'Shaken'
                      : 'Ready'
                  : battle
                    ? 'Morale'
                    : 'Ready'}
            </span>
          </div>
        </div>
        <div className="unit-roster">
          {roster.map((u) => {
            const UIcon = unitIcon(u.kind);
            return (
              <button
                key={u.id}
                className={`unit-card ${s.selected.includes(u.id) ? 'selected' : ''} ${u.routed || !u.men ? 'routed' : ''}`}
                onClick={(e) =>
                  model.select(
                    e.shiftKey
                      ? s.selected.includes(u.id)
                        ? s.selected.filter((id) => id !== u.id)
                        : [...s.selected, u.id]
                      : [u.id],
                  )
                }
                aria-pressed={s.selected.includes(u.id)}
              >
                <div className="unit-card-top">
                  <UIcon size={19} strokeWidth={1.2} />
                  <span>
                    {u.corpsId === 'c1' ? 'I' : 'II'} &middot;{' '}
                    {u.kind === 'artillery'
                      ? `${Math.ceil(u.men / 30)} GUNS`
                      : u.kind === 'cavalry'
                        ? 'CAVALRY'
                        : 'INFANTRY'}
                  </span>
                  <i className={u.routed ? 'status-routed' : ''} />
                </div>
                <strong>{u.name}</strong>
                <div className="unit-card-numbers">
                  <b>{format(u.men)}</b>
                  <span>
                    {u.routed
                      ? 'Routing'
                      : u.men === 0
                        ? 'Depleted'
                        : battle
                          ? u.formationChange
                            ? `${Math.ceil(u.formationChange.duration - u.formationChange.elapsed)}s ${FORMATIONS[u.formationChange.to].name}`
                            : u.holdFire
                              ? 'Hold fire'
                              : `${Math.round(u.morale)}%`
                          : u.experience < 0.5
                            ? 'Recruit'
                            : u.experience < 2
                              ? 'Regular'
                              : 'Veteran'}
                  </span>
                </div>
                <Meter
                  color={u.routed ? 'red' : 'green'}
                  value={(u.men / u.maxMen) * 100}
                />
                {battle && (
                  <div className="unit-readiness">
                    <span
                      aria-label={`Condition ${Math.round(u.condition)} percent`}
                    >
                      <Heart size={9} />
                      {Math.round(u.condition)}%
                    </span>
                    <span
                      aria-label={`Ammunition ${Math.round(u.ammo)} percent`}
                    >
                      <Target size={9} />
                      {Math.round(u.ammo)}%
                    </span>
                  </div>
                )}
                {battle && (
                  <div className="unit-order-state">
                    <span>
                      {u.formationChange
                        ? 'Reforming'
                        : u.queuedFormation
                          ? `Next: ${FORMATIONS[u.queuedFormation].name}`
                          : u.limberChange
                            ? `${Math.ceil(u.limberChange)}s preparing`
                            : u.blocked
                              ? u.blocked
                              : u.fallingBack
                                ? 'Falling back'
                                : u.charging
                                  ? 'Charging'
                                  : u.target
                                    ? 'Moving'
                                    : 'Holding'}
                    </span>
                    <span>
                      {model.commandSupport(u).length
                        ? 'In command'
                        : 'Detached'}
                    </span>
                  </div>
                )}
                {u.formationChange && (
                  <Meter
                    color="gold"
                    value={
                      (u.formationChange.elapsed / u.formationChange.duration) *
                      100
                    }
                  />
                )}
              </button>
            );
          })}
        </div>
        <div className="selected-weapon">
          {supply ? (
            <Truck size={24} strokeWidth={1} />
          ) : commander ? (
            <Crown size={24} strokeWidth={1} />
          ) : (
            <FirstIcon size={24} strokeWidth={1} />
          )}
          <span className="section-label">
            {supply
              ? 'FIELD LOGISTICS'
              : commander
                ? commander.unavailable
                  ? 'COMMAND UNAVAILABLE'
                  : commander.shaken
                    ? 'UNDER PRESSURE'
                    : 'COMMAND SUPPORT'
                : battle
                  ? terrainAt(first || { x: 0, y: 0 }, 'battle', s.battle) ===
                    'woods'
                    ? 'WOODLAND COVER'
                    : terrainAt(first || { x: 0, y: 0 }, 'battle', s.battle) ===
                        'hill'
                      ? 'HIGH GROUND'
                      : 'OPEN GROUND'
                  : 'ISSUED WEAPON'}
          </span>
          <strong>
            {supply
              ? 'Ammunition train'
              : commander
                ? commander.specialty
                : WEAPONS[first?.weapon || 'musket'].name}
          </strong>
          <span>
            {supply
              ? '145 m resupply radius'
              : commander
                ? `${commander.following ? 'Following troops' : 'Manual orders'}`
                : `${WEAPONS[first?.weapon || 'musket'].range} m range`}
          </span>
          {battle && !commander && !supply && (
            <span>
              {Math.floor(first?.kills || 0)} inflicted &middot;{' '}
              {Math.max(0, Math.ceil((first?.reload || 0) * 10) / 10)}s reload
            </span>
          )}
        </div>
      </section>
      <footer className="statusbar">
        <span>
          <span className="save-dot" />
          {model.saveFailed
            ? 'Local save unavailable'
            : 'Campaign saved locally'}
        </span>
        <span>
          {battle ? 'France / Austrian Empire' : '2 Corps / French Empire'}
        </span>
        <span>
          FIELD COMMAND <b>PROTOTYPE 0.3</b>
        </span>
      </footer>
      {camp && (
        <Headquarters
          Modal={Modal}
          model={model}
          initialTab={campTab}
          notify={notify}
          onClose={() => setCamp(false)}
        />
      )}
      {confirm && (
        <Modal
          title={
            confirm === 'reset'
              ? 'Begin a new campaign?'
              : 'Withdraw from battle?'
          }
          eyebrow="COMMAND DECISION"
          onClose={() => setConfirm(null)}
        >
          <p className="confirm-copy">
            {confirm === 'reset'
              ? 'Your current campaign will be replaced. The army, treasury, and Austrian forces will return to their starting positions.'
              : 'Your surviving regiments will regroup at Ulm. Casualties will remain, and no victory reward will be paid.'}
          </p>
          <div className="modal-actions">
            <button className="button" onClick={() => setConfirm(null)}>
              Cancel
            </button>
            <button
              className="button primary"
              onClick={() => {
                confirm === 'reset' ? model.reset() : model.withdraw();
                setConfirm(null);
              }}
            >
              {confirm === 'reset' ? 'New campaign' : 'Withdraw'}
              <ArrowRight size={16} />
            </button>
          </div>
        </Modal>
      )}
      {s.report && (
        <Modal
          title={
            s.report.complete
              ? 'The Danube is secured'
              : s.report.won
                ? 'Victory on the field'
                : s.report.retreat
                  ? 'The army has withdrawn'
                  : 'A costly defeat'
          }
          eyebrow={s.report.name.toUpperCase()}
          className="report-modal"
        >
          <div className={`report-emblem ${s.report.won ? '' : 'lost'}`}>
            {s.report.won ? (
              <Trophy size={42} strokeWidth={1} />
            ) : (
              <Flag size={42} strokeWidth={1} />
            )}
          </div>
          <div className="report-stats">
            <div>
              <span>French losses</span>
              <strong>{format(s.report.casualties)}</strong>
            </div>
            <div>
              <span>Austrian losses</span>
              <strong>{format(s.report.enemyCasualties)}</strong>
            </div>
            <div>
              <span>Victory payment</span>
              <strong className="reward">
                {format(s.report.reward)} <small>F</small>
              </strong>
            </div>
          </div>
          {s.report.loot > 0 && (
            <p className="loot-line">
              {format(s.report.loot)} captured muskets added to reserve
            </p>
          )}
          {!!s.report.regiments?.length && (
            <details className="after-action" open>
              <summary>Regimental returns</summary>
              <table>
                <thead>
                  <tr>
                    <th>Regiment</th>
                    <th>Lost</th>
                    <th>Inflicted</th>
                    <th>XP</th>
                  </tr>
                </thead>
                <tbody>
                  {s.report.regiments.map((u) => (
                    <tr key={u.id}>
                      <th>{u.name}</th>
                      <td>{u.losses}</td>
                      <td>{u.kills}</td>
                      <td>{u.experience.toFixed(1)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {!!s.report.officers?.length && (
                <div className="officer-returns">
                  {s.report.officers.map((o, i) => (
                    <p key={i}>
                      <strong>{o.name}</strong>
                      <span>{o.status}</span>
                    </p>
                  ))}
                </div>
              )}
            </details>
          )}
          {s.report.complete && (
            <p className="loot-line">
              All three Austrian forces have been defeated.
            </p>
          )}
          <div className="modal-actions">
            <button className="button" onClick={() => model.dismissReport()}>
              Campaign map
            </button>
            <button
              className="button primary"
              onClick={() => {
                model.dismissReport();
                openCamp();
              }}
            >
              <Tent size={16} /> Return to camp
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
}
