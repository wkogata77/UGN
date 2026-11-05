import React, { useEffect, useReducer, useRef, useState } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import {
  ArrowLeft,
  Binoculars,
  CircleSlash,
  Coins,
  Crosshair,
  Crown,
  Flag,
  Footprints,
  Gauge as GaugeIcon,
  Heart,
  Map,
  Maximize,
  Minus,
  MousePointer2,
  Mountain,
  Pause,
  Play,
  Plus,
  RotateCcw,
  Rows3,
  Shield,
  Square,
  Swords,
  Target,
  Tent,
  Truck,
  Users,
  Volume2,
  VolumeX,
  X,
} from 'lucide-react';
import { DepthCampaign, createFixedClock, fireStatus } from './model.js';
import { DepthRenderer } from './DepthRenderer.js';
import { SPEEDS, WEAPONS, countMen } from '../game/model.js';
import { fieldFor } from '../game/battlefields.js';
import Headquarters from '../components/Headquarters.jsx';
import './depth.css';

const format = (n) => Math.round(n || 0).toLocaleString();
const cursor = (Icon, color) =>
  `url("data:image/svg+xml,${encodeURIComponent(renderToStaticMarkup(<Icon color={color} width={26} height={26} strokeWidth={2} />))}") 13 13, crosshair`;
const cursors = {
  attack: cursor(Swords, '#ffd1bd'),
  move: cursor(Footprints, '#fff0be'),
  inspect: cursor(MousePointer2, '#ffffff'),
  blocked: cursor(CircleSlash, '#dca28d'),
};
const iconFor = (kind) =>
  kind === 'artillery' ? Target : kind === 'cavalry' ? Swords : Shield;

function Tool({ icon: Icon, label, active, ...props }) {
  return (
    <button
      type="button"
      className={`depth-tool ${active ? 'is-active' : ''}`}
      title={label}
      aria-label={label}
      aria-pressed={active === undefined ? undefined : active}
      {...props}
    >
      <Icon size={18} strokeWidth={1.6} />
    </button>
  );
}

function Dialog({ title, eyebrow, onClose, className = '', children }) {
  const ref = useRef(null);
  useEffect(() => {
    const before = document.activeElement;
    ref.current.focus();
    const key = (e) => {
      if (e.key === 'Escape') {
        e.stopPropagation();
        onClose?.();
      }
      if (e.key !== 'Tab') return;
      const focusable = [
        ...ref.current.querySelectorAll(
          'button:not(:disabled), input:not(:disabled), select:not(:disabled), a[href]',
        ),
      ].filter((el) => el.getClientRects().length);
      const first = focusable[0],
        last = focusable.at(-1);
      if (
        e.shiftKey &&
        (document.activeElement === first ||
          document.activeElement === ref.current)
      ) {
        e.preventDefault();
        last?.focus();
      } else if (
        !e.shiftKey &&
        (document.activeElement === last ||
          document.activeElement === ref.current)
      ) {
        e.preventDefault();
        first?.focus();
      }
    };
    const element = ref.current;
    element.addEventListener('keydown', key);
    return () => {
      element.removeEventListener('keydown', key);
      before?.focus();
    };
  }, [onClose]);
  return (
    <div className="modal-backdrop">
      <section
        className={`modal ${className}`}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        ref={ref}
        tabIndex={-1}
      >
        <div className="modal-heading">
          <div>
            <span className="eyebrow">
              {className === 'hq-modal'
                ? 'ARMY OF ITALY / FIELD STUDY'
                : eyebrow}
            </span>
            <h2>{title}</h2>
          </div>
          {onClose && <Tool icon={X} label="Close" onClick={onClose} />}
        </div>
        {children}
      </section>
    </div>
  );
}

function Gauge({ icon: Icon, name, value, tone = 'green' }) {
  return (
    <div className={`depth-gauge ${tone}`}>
      <Icon size={12} />
      <span>{name}</span>
      <b>{format(value)}%</b>
      <i>
        <em style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
      </i>
    </div>
  );
}

export default function DepthDemo() {
  const [models, setModels] = useState(() => ({
    campaign: new DepthCampaign(),
    battle: new DepthCampaign(true),
  }));
  const [tab, setTab] = useState('campaign');
  const model = models[tab];
  const [, refresh] = useReducer((n) => n + 1, 0);
  const [ready, setReady] = useState(false),
    [error, setError] = useState(''),
    [inspected, setInspected] = useState(null);
  const [camp, setCamp] = useState(false),
    [confirm, setConfirm] = useState(null),
    [toast, setToast] = useState('');
  const [relief, setRelief] = useState(true),
    [ranges, setRanges] = useState(true),
    [touchOrders, setTouchOrders] = useState(false);
  const mapRef = useRef(null),
    minimapRef = useRef(null),
    controls = useRef(null),
    toastTimer = useRef(null);
  const options = useRef({ relief, ranges, touchOrders });
  options.current = {
    relief,
    ranges,
    touchOrders,
    keyboardBlocked: !!(camp || confirm),
  };
  const notify = (message) => {
    setToast(message);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(''), 3000);
  };
  useEffect(() => model.subscribe(refresh), [model]);
  useEffect(() => {
    controls.current?.invalidate();
  });
  useEffect(() => {
    let disposed = false,
      renderer = null,
      frame = 0,
      previous = 0;
    const clock = createFixedClock(model);
    setReady(false);
    setError('');
    setInspected(null);
    const hidden = () => {
      controls.current?.invalidate();
      if (document.hidden) {
        model.state.paused = true;
        clock.reset();
        model.publish(false);
      }
      previous = 0;
    };
    document.addEventListener('visibilitychange', hidden);
    DepthRenderer.create(mapRef.current, model, {
      cursors,
      minimap: () => minimapRef.current,
      inspect: setInspected,
      notify,
      error: setError,
      cameraBlocked: () => options.current.keyboardBlocked,
      reducedMotion: () =>
        window.matchMedia('(prefers-reduced-motion: reduce)').matches,
    })
      .then((instance) => {
        if (disposed) {
          instance.dispose();
          return;
        }
        renderer = instance;
        controls.current = instance;
        if (!options.current.relief) instance.setRelief(false);
        instance.showRanges = options.current.ranges;
        instance.touchOrders = options.current.touchOrders;
        setReady(true);
        const animate = (now) => {
          if (disposed) return;
          const delta = previous ? (now - previous) / 1000 : 0;
          previous = now;
          clock.advance(delta);
          instance.frame(delta);
          frame = requestAnimationFrame(animate);
        };
        frame = requestAnimationFrame(animate);
        if (import.meta.env.DEV)
          window.__depthDemo = { model, renderer: instance, clock };
      })
      .catch((e) => {
        if (!disposed) setError(e.message || 'The map could not be loaded.');
      });
    return () => {
      disposed = true;
      cancelAnimationFrame(frame);
      renderer?.dispose();
      controls.current = null;
      model.state.paused = true;
      document.removeEventListener('visibilitychange', hidden);
      delete window.__depthDemo;
    };
  }, [model]);
  useEffect(() => () => clearTimeout(toastTimer.current), []);
  useEffect(() => {
    if (controls.current) controls.current.showRanges = ranges;
  }, [ranges]);
  useEffect(() => {
    if (controls.current) controls.current.touchOrders = touchOrders;
  }, [touchOrders]);
  useEffect(() => {
    const clear = () => controls.current?.cameraKeys.clear();
    const key = (e) => {
      if (
        camp ||
        confirm ||
        model.state.report ||
        e.ctrlKey ||
        e.metaKey ||
        e.altKey ||
        e.isComposing ||
        e.target.isContentEditable ||
        /INPUT|SELECT|TEXTAREA/.test(e.target.tagName)
      ) {
        clear();
        return;
      }
      if (['KeyW', 'KeyA', 'KeyS', 'KeyD'].includes(e.code)) {
        e.preventDefault();
        controls.current?.cameraKeys.add(e.code);
        controls.current?.invalidate();
        return;
      }
      if (e.target.tagName === 'BUTTON') return;
      if (e.code === 'Space') {
        e.preventDefault();
        model.pause();
      }
      if (e.key === 'Escape') {
        model.select([]);
        setInspected(null);
      }
      if (e.key.toLowerCase() === 'h') model.halt();
      if (e.key.toLowerCase() === 'q') model.selectCorps('c1');
      if (e.key.toLowerCase() === 'e') model.selectCorps('c2');
    };
    const release = (e) => controls.current?.cameraKeys.delete(e.code);
    window.addEventListener('keydown', key);
    window.addEventListener('keyup', release);
    window.addEventListener('blur', clear);
    window.addEventListener('focusin', clear);
    document.addEventListener('visibilitychange', clear);
    return () => {
      clear();
      window.removeEventListener('keydown', key);
      window.removeEventListener('keyup', release);
      window.removeEventListener('blur', clear);
      window.removeEventListener('focusin', clear);
      document.removeEventListener('visibilitychange', clear);
    };
  }, [model, camp, confirm]);
  const s = model.state,
    battle = s.mode === 'battle';
  const roster = battle
    ? s.battle.units.filter((u) => u.side === 'player')
    : s.units;
  const entities = ready ? controls.current?.entities() || [] : [];
  const selected = battle
    ? roster.filter((u) => s.selected.includes(u.id) && !u.routed && u.men > 0)
    : [];
  const battleRoster = battle
    ? [
        ...roster,
        ...s.battle.commanders
          .filter((c) => !c.hostId)
          .map((c) => ({ ...c, kind: 'general' })),
        ...s.battle.wagons
          .filter((w) => w.side === 'player')
          .map((w) => ({ ...w, kind: 'wagon', name: 'Supply train' })),
      ]
    : [];
  const unit = entities.find((u) => u.id === inspected);
  const target =
    unit?.side === 'enemy' && battle && selected[0]
      ? fireStatus(selected[0], unit, s.battle)
      : null;
  const closeCamp = React.useCallback(() => setCamp(false), []);
  const rallyCommander = battle
    ? s.battle.commanders.find(
        (c) =>
          c.id === s.selectedCommander ||
          (c.hostId && c.hostId === selected[0]?.id),
      )
    : null;
  const openCamp = () => {
    s.paused = true;
    model.publish(false);
    setCamp(true);
  };
  const switchTab = (value) => {
    if (value === tab) return;
    s.paused = true;
    setTab(value);
  };
  const reset = () => {
    setModels((current) => ({
      ...current,
      [tab]: new DepthCampaign(tab === 'battle'),
    }));
    setConfirm(null);
  };
  return (
    <div className={`depth-demo ${battle ? 'depth-battle' : ''}`}>
      <header className="depth-header">
        <a
          href="/"
          className="depth-back"
          title="Open the original game on this server"
          aria-label="Return to original game"
        >
          <ArrowLeft size={18} />
        </a>
        <div className="depth-brand">
          <Swords size={25} strokeWidth={1.1} />
          <div>
            <h1>Field Command</h1>
            <span>ITALIAN THEATER / FIELD STUDY</span>
          </div>
        </div>
        <nav className="depth-tabs" aria-label="Demo views">
          <button
            aria-label="Campaign"
            className={tab === 'campaign' ? 'is-active' : ''}
            onClick={() => switchTab('campaign')}
          >
            <Map size={16} />
            <span>Campaign</span>
          </button>
          <button
            aria-label="Battlefield"
            className={tab === 'battle' ? 'is-active' : ''}
            onClick={() => switchTab('battle')}
          >
            <Swords size={16} />
            <span>Battlefield</span>
          </button>
        </nav>
        <div className="depth-resources">
          <span>
            <Users size={14} />
            {format(countMen(roster))}
          </span>
          <span>
            <Coins size={14} />
            {format(s.cash)} F
          </span>
        </div>
        <Tool
          icon={Tent}
          label="Army headquarters"
          disabled={battle || !!s.report}
          onClick={openCamp}
        />
        <Tool
          icon={s.settings.sound ? Volume2 : VolumeX}
          label={s.settings.sound ? 'Mute sound' : 'Enable sound'}
          onClick={() => {
            model.setSound(!s.settings.sound);
            controls.current?.audio.unlock();
          }}
        />
      </header>
      <main className="depth-stage">
        <div
          ref={mapRef}
          className="depth-map"
          role="application"
          aria-label={battle ? 'Battlefield map' : 'Campaign map'}
        />
        <div className="depth-heading" data-map-obstacle>
          <span className="depth-eyebrow">
            {battle
              ? 'TACTICAL ENGAGEMENT'
              : 'NORTHERN ITALY / ILLUSTRATIVE SECTOR'}
          </span>
          <h2>{battle ? 'The Valeggio Crossing' : 'The Po Valley'}</h2>
          <p>
            {battle
              ? `${Math.floor(s.battle.time / 60)}:${String(Math.floor(s.battle.time % 60)).padStart(2, '0')} elapsed`
              : `April 1796 / ${String(Math.floor(s.hours % 24)).padStart(2, '0')}:${String(Math.floor((s.hours % 1) * 60)).padStart(2, '0')}`}
            <span>Clear skies</span>
          </p>
        </div>
        <aside className="depth-objective" data-map-obstacle>
          <span>
            <Flag size={13} />
            {battle ? 'BATTLE OBJECTIVE' : 'ORDERS'}
          </span>
          <strong>
            {battle ? 'Secure the crossing' : 'Engage the advance guard'}
          </strong>
          {battle ? (
            <>
              <div className="depth-objective-progress">
                <i
                  style={{
                    width: `${Math.min(100, (s.battle.objective.player / fieldFor(s.battle).objective.seconds) * 100)}%`,
                  }}
                />
              </div>
              <small>
                {Math.floor(s.battle.objective.player)} /{' '}
                {fieldFor(s.battle).objective.seconds}s held
              </small>
              {s.battle.objective.enemy > 0 && (
                <small className="depth-alert">
                  Enemy hold: {Math.floor(s.battle.objective.enemy)} /{' '}
                  {fieldFor(s.battle).objective.seconds + 60}s
                </small>
              )}
              {s.battle.units.some((u) => u.arrival > s.battle.time) && (
                <small className="depth-alert">
                  Enemy reserves approaching
                </small>
              )}
            </>
          ) : (
            <small>Army of Italy / forward operations</small>
          )}
        </aside>
        <div className="depth-map-tools" data-map-obstacle>
          <Tool
            icon={Plus}
            label="Zoom in"
            onClick={() => controls.current?.setZoom(1.2)}
          />
          <Tool
            icon={Minus}
            label="Zoom out"
            onClick={() => controls.current?.setZoom(1 / 1.2)}
          />
          <Tool
            icon={Maximize}
            label="Center map"
            onClick={() => controls.current?.home()}
          />
          <span />
          <Tool
            icon={Mountain}
            label={
              relief
                ? 'Terrain relief on; compare with flat terrain'
                : 'Restore terrain relief'
            }
            active={relief}
            onClick={() => {
              controls.current?.setRelief(!relief);
              setRelief(!relief);
            }}
          />
          <Tool
            icon={Crosshair}
            label="Show weapon range"
            active={ranges}
            disabled={!battle}
            onClick={() => setRanges(!ranges)}
          />
          <Tool
            icon={Footprints}
            label="Touch order mode"
            active={touchOrders}
            onClick={() => setTouchOrders(!touchOrders)}
          />
          <Tool
            icon={RotateCcw}
            label="Reset this demo"
            onClick={() => {
              s.paused = true;
              model.publish(false);
              setConfirm('reset');
            }}
          />
        </div>
        <button
          className="depth-minimap"
          aria-label="Recenter using overview map"
          data-map-obstacle
          onClick={(e) => {
            const r = minimapRef.current.getBoundingClientRect();
            const renderer = controls.current;
            if (!renderer) return;
            renderer.center = {
              x:
                Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * 1440,
              y: Math.max(0, Math.min(1, (e.clientY - r.top) / r.height)) * 960,
            };
            renderer.updateCamera();
          }}
        >
          <canvas width="150" height="100" ref={minimapRef} />
          <span>N / THEATER OVERVIEW</span>
        </button>
        {unit && (
          <aside
            className={`depth-inspector ${unit.side === 'enemy' ? 'enemy' : ''}`}
            data-map-obstacle
            aria-label="Unit information"
          >
            <div className="depth-inspector-title">
              <span>
                {unit.kind === 'general' ? (
                  <Crown size={16} />
                ) : unit.kind === 'wagon' ? (
                  <Truck size={16} />
                ) : (
                  <Shield size={16} />
                )}
                {unit.name}
              </span>
              <Tool
                icon={X}
                label="Close unit information"
                onClick={() => {
                  setInspected(null);
                }}
              />
            </div>
            <div
              className="depth-unit-art"
              style={{
                '--unit-col':
                  unit.kind === 'general'
                    ? 2
                    : unit.kind === 'wagon'
                      ? 3
                      : unit.kind === 'cavalry'
                        ? unit.side === 'player'
                          ? 2
                          : 3
                        : unit.kind === 'artillery'
                          ? unit.side === 'player'
                            ? 0
                            : 1
                          : unit.side === 'player'
                            ? 0
                            : 1,
                '--unit-row': ['artillery', 'general', 'wagon'].includes(
                  unit.kind,
                )
                  ? 1
                  : 0,
              }}
            />
            <div className="depth-inspector-body">
              <strong>
                {unit.kind === 'wagon'
                  ? `${format(unit.stock)} supplies`
                  : unit.kind === 'general'
                    ? 'Army command'
                    : `${unit.side === 'enemy' ? '~' : ''}${format(unit.men)} men`}
              </strong>
              <small>
                {unit.uncertain
                  ? 'Last known position'
                  : unit.weapon
                    ? WEAPONS[unit.weapon].name
                    : unit.kind === 'general'
                      ? 'Independent headquarters'
                      : unit.kind === 'wagon'
                        ? 'Ammunition reserve'
                        : 'Field army'}
              </small>
              {unit.side === 'player' && unit.condition !== undefined && (
                <>
                  <Gauge
                    icon={Heart}
                    name="Morale"
                    value={unit.morale ?? 100}
                  />
                  <Gauge
                    icon={Footprints}
                    name="Fatigue"
                    value={100 - unit.condition}
                    tone="gold"
                  />
                </>
              )}
              {unit.weapon && (
                <div className="depth-inspector-facts">
                  <span>
                    Range <b>{WEAPONS[unit.weapon].range}</b>
                  </span>
                  {unit.side === 'player' && (
                    <span>
                      Ammo <b>{format(unit.ammo)}%</b>
                    </span>
                  )}
                </div>
              )}
              {target && <small className="depth-target-state">{target}</small>}
              {battle &&
                s.battle.commanders.some((c) => c.hostId === unit.id) && (
                  <small className="depth-host">
                    <Crown size={11} /> Corps command attached
                  </small>
                )}
            </div>
          </aside>
        )}
        {toast && (
          <div className="depth-toast" role="status" data-map-obstacle>
            {toast}
          </div>
        )}
        {(!ready || error) && (
          <div className="depth-loading" role="status">
            <Mountain size={26} />
            <strong>{error || 'Preparing the theater...'}</strong>
            {error && <a href="/">Return to original game</a>}
          </div>
        )}
        <footer
          className={`depth-command-bar ${battle ? 'has-roster' : ''}`}
          data-map-obstacle
        >
          <div className="depth-clock">
            <Tool
              icon={s.paused ? Play : Pause}
              label={s.paused ? 'Resume time' : 'Pause time'}
              disabled={!ready || !!s.report || !!error}
              onClick={() => model.pause()}
            />
            <span className={s.paused ? '' : 'running'}>
              {s.paused ? 'PAUSED' : battle ? 'IN BATTLE' : 'MARCHING'}
            </span>
            <div className="depth-speeds">
              {SPEEDS.map((speed) => (
                <button
                  key={speed}
                  aria-label={`${speed}x speed`}
                  aria-pressed={speed === s.speed}
                  className={speed === s.speed ? 'is-active' : ''}
                  onClick={() => model.speed(speed)}
                >
                  {speed}x
                </button>
              ))}
            </div>
          </div>
          <div className="depth-corps">
            {s.corps.map((corps) => (
              <button
                key={corps.id}
                disabled={!battle}
                className={
                  battle && selected.some((u) => u.corpsId === corps.id)
                    ? 'is-active'
                    : ''
                }
                onClick={() => {
                  setInspected(null);
                  model.selectCorps(corps.id);
                }}
                title={`${corps.commander} / ${roster.filter((u) => u.corpsId === corps.id).length} regiments`}
              >
                <span>{corps.id === 'c1' ? 'I' : 'II'}</span>
                <small>
                  {corps.name}
                  <b>
                    {format(
                      countMen(roster.filter((u) => u.corpsId === corps.id)),
                    )}
                  </b>
                </small>
              </button>
            ))}
          </div>
          {battle ? (
            <div
              className="depth-orders"
              role="toolbar"
              aria-label="Selected unit actions"
            >
              <Tool
                icon={Rows3}
                label="Line formation"
                active={
                  selected.length > 0 &&
                  selected.every((u) => u.formation === 'line')
                }
                disabled={!selected.some((u) => u.kind === 'infantry')}
                onClick={() => model.formation('line')}
              />
              <Tool
                icon={Users}
                label="Column formation"
                active={
                  selected.length > 0 &&
                  selected.every((u) => u.formation === 'column')
                }
                disabled={!selected.some((u) => u.kind === 'infantry')}
                onClick={() => model.formation('column')}
              />
              <Tool
                icon={Square}
                label="Square formation"
                active={
                  selected.length > 0 &&
                  selected.every((u) => u.formation === 'square')
                }
                disabled={!selected.some((u) => u.kind === 'infantry')}
                onClick={() => model.formation('square')}
              />
              <Tool
                icon={CircleSlash}
                label="Halt selected units"
                disabled={
                  !selected.length && !s.selectedCommander && !s.selectedSupply
                }
                onClick={() => model.halt()}
              />
              <Tool
                icon={GaugeIcon}
                label="Run"
                active={selected.length > 0 && selected.every((u) => u.running)}
                disabled={!selected.length}
                onClick={() => model.run()}
              />
              <Tool
                icon={Crosshair}
                label="Engage enemy"
                disabled={!selected.length}
                onClick={() => {
                  if (!model.engageEnemy())
                    notify('No visible enemy can be engaged.');
                }}
              />
              <Tool
                icon={Swords}
                label="Charge into melee"
                active={
                  selected.length > 0 && selected.every((u) => u.charging)
                }
                disabled={
                  !selected.some(
                    (u) =>
                      u.kind !== 'artillery' &&
                      !u.formationChange &&
                      u.condition >= 25 &&
                      !u.dismounted,
                  )
                }
                onClick={() => model.charge()}
              />
              <Tool
                icon={Shield}
                label="Melee only (hold fire)"
                active={
                  selected.length > 0 && selected.every((u) => u.holdFire)
                }
                disabled={!selected.length}
                onClick={() => model.holdFire()}
              />
              <Tool
                icon={RotateCcw}
                label="Fall back"
                disabled={!selected.length}
                onClick={() => model.fallBack()}
              />
              <Tool
                icon={Flag}
                label="Rally nearby regiments"
                disabled={
                  !rallyCommander ||
                  rallyCommander.cooldown > 0 ||
                  rallyCommander.unavailable ||
                  !!rallyCommander.shaken
                }
                onClick={() => {
                  if (!model.rally(rallyCommander.id))
                    notify('No nearby regiments need rallying.');
                }}
              />
              <Tool
                icon={ArrowLeft}
                label="Withdraw from battle"
                onClick={() => {
                  s.paused = true;
                  model.publish(false);
                  setConfirm('withdraw');
                }}
              />
            </div>
          ) : (
            <div className="depth-orders">
              <button className="depth-camp-button" onClick={openCamp}>
                <Tent size={17} />
                <span>Army camp</span>
              </button>
              <Tool
                icon={Binoculars}
                label="Reconnaissance"
                disabled={s.cash < 100 || s.recon.cooldown > 0}
                onClick={() => model.scout()}
              />
            </div>
          )}
          {battle && (
            <div className="depth-roster" role="group" aria-label="Army units">
              {battleRoster.map((u) => {
                const general = u.kind === 'general',
                  supply = u.kind === 'wagon';
                const Icon = general ? Crown : supply ? Truck : iconFor(u.kind);
                const active = general
                  ? s.selectedCommander === u.id
                  : supply
                    ? !!s.selectedSupply
                    : s.selected.includes(u.id);
                const lost = general
                  ? u.unavailable
                  : supply
                    ? u.health <= 0
                    : u.men <= 0;
                const incoming =
                  !general && !supply && u.arrival > s.battle.time;
                const condition = supply
                  ? u.health
                  : general
                    ? 100
                    : u.condition;
                const status = lost
                  ? 'Lost'
                  : incoming
                    ? 'Incoming'
                    : u.routed
                      ? 'Routing'
                      : u.formationChange
                        ? 'Reforming'
                        : u.charging
                          ? 'Charging'
                          : u.running
                            ? 'Running'
                            : u.holdFire
                              ? 'Melee only'
                              : general
                                ? 'Army command'
                                : supply
                                  ? `${format(u.stock)} supplies`
                                  : `${format(u.men)} men`;
                return (
                  <button
                    key={u.id}
                    className={`depth-roster-unit ${active ? 'is-active' : ''} ${u.routed ? 'is-routing' : ''}`}
                    aria-label={
                      general
                        ? 'Select army general'
                        : supply
                          ? 'Select supply train'
                          : `Select ${u.name}`
                    }
                    aria-pressed={active}
                    disabled={!!(lost || incoming)}
                    title={`${u.name}: ${status}${general || supply ? '' : `, morale ${Math.round(u.morale)}%, fatigue ${Math.round(100 - u.condition)}%`}`}
                    onClick={(event) => {
                      if (general) model.selectCommander(u.id);
                      else if (supply) model.selectSupply();
                      else
                        model.select(
                          event.shiftKey || event.ctrlKey || event.metaKey
                            ? s.selected.includes(u.id)
                              ? s.selected.filter((id) => id !== u.id)
                              : [...s.selected, u.id]
                            : [u.id],
                        );
                      setInspected(u.id);
                    }}
                    onDoubleClick={() => {
                      const r = controls.current;
                      if (r) {
                        r.center = { x: u.x, y: u.y };
                        r.updateCamera();
                      }
                    }}
                  >
                    <Icon size={18} />
                    <span>
                      <b>{u.name}</b>
                      <small>{status}</small>
                    </span>
                    <i className="depth-roster-morale">
                      <em
                        style={{
                          width: `${general || supply ? 100 : Math.max(0, u.morale)}%`,
                        }}
                      />
                    </i>
                    <i className="depth-roster-condition">
                      <em
                        style={{
                          width: `${Math.max(0, Math.min(100, condition ?? 100))}%`,
                        }}
                      />
                    </i>
                  </button>
                );
              })}
            </div>
          )}
        </footer>
      </main>
      {camp && (
        <Headquarters
          model={model}
          onClose={closeCamp}
          notify={notify}
          Modal={Dialog}
        />
      )}
      {confirm && (
        <Dialog
          title={
            confirm === 'reset'
              ? 'Reset this field study?'
              : 'Withdraw the army?'
          }
          eyebrow="FIELD COMMAND"
          onClose={() => setConfirm(null)}
          className="depth-dialog"
        >
          <p>
            {confirm === 'reset'
              ? 'Only this in-memory demo will restart. Your saved campaign is unchanged.'
              : 'Survivors will return to the campaign. Abandoned positions will be lost.'}
          </p>
          <div className="depth-dialog-actions">
            <button onClick={() => setConfirm(null)}>Cancel</button>
            <button
              onClick={() => {
                if (confirm === 'reset') reset();
                else {
                  model.finishBattle(false, true);
                  setConfirm(null);
                  setInspected(null);
                }
              }}
            >
              {confirm === 'reset' ? 'Restart demo' : 'Withdraw'}
            </button>
          </div>
        </Dialog>
      )}
      {s.report && (
        <Dialog
          title={
            s.report.won
              ? 'Victory'
              : s.report.retreat
                ? 'Army withdrawn'
                : 'Defeat'
          }
          eyebrow={s.report.name}
          className="depth-dialog"
        >
          <div className="depth-report-stats">
            <span>
              Our losses<b>{format(s.report.casualties)}</b>
            </span>
            <span>
              Enemy losses<b>{format(s.report.enemyCasualties)}</b>
            </span>
            <span>
              Award<b>{format(s.report.reward)} F</b>
            </span>
          </div>
          <div className="depth-report-units">
            {s.report.regiments.map((u) => (
              <div key={u.id}>
                <span>{u.name}</span>
                <b>{format(u.men)} returned</b>
              </div>
            ))}
          </div>
          <div className="depth-dialog-actions">
            <button
              onClick={() => {
                model.dismissReport();
                setInspected(null);
              }}
            >
              Return to campaign
            </button>
          </div>
        </Dialog>
      )}
    </div>
  );
}
