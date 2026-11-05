import React, { useRef, useState } from 'react';
import {
  ArrowLeft,
  ArrowDownToLine,
  ArrowUpFromLine,
  Award,
  Check,
  ChevronRight,
  Coins,
  Flag,
  Heart,
  Landmark,
  Plus,
  Shield,
  Star,
  Swords,
  Target,
  TrendingUp,
  Truck,
  UserRound,
  Users,
} from 'lucide-react';
import { WEAPONS, countMen, weaponCount } from '../game/model.js';
import {
  SKILLS,
  PERKS,
  RANKS,
  RANK_XP,
  rankOf,
  officerReady,
  officerAssignment,
  commandEfficiency,
} from '../game/progression.js';
import './headquarters.css';

const format = (value) => Math.round(value).toLocaleString();
const unitIcon = (kind) =>
  kind === 'cavalry' ? Swords : kind === 'artillery' ? Target : Shield;
export function Portrait({ officer, napoleon = false, className = '' }) {
  const index = napoleon ? 0 : (officer?.portrait ?? 15);
  return (
    <span
      role="img"
      aria-label={
        napoleon ? 'Napoleon Bonaparte' : officer?.name || 'Unassigned officer'
      }
      className={`officer-portrait ${officer?.dead ? 'fallen' : ''} ${className}`}
      style={{
        backgroundPosition: `${((index % 4) * 100) / 3}% ${(Math.floor(index / 4) * 100) / 3}%`,
      }}
    />
  );
}
export function WeaponArt({ weapon }) {
  const region = {
    musket: [0, 215],
    improved: [215, 195],
    rifle: [376, 188],
    sabre: [555, 145],
    cannon: [700, 324],
    carbine: [376, 188],
    howitzer: [700, 324],
  }[weapon] || [0, 215];
  return (
    <span
      className="weapon-art"
      data-pattern={weapon}
      style={{ aspectRatio: `1536 / ${region[1]}` }}
    >
      <img
        src="/assets/weapons.png"
        alt={WEAPONS[weapon]?.name || 'Service weapon'}
        draggable="false"
        style={{ transform: `translateY(-${(region[0] / 1024) * 100}%)` }}
      />
    </span>
  );
}
function StatBar({ label, value, suffix = '', tone = '' }) {
  return (
    <div className={`hq-stat ${tone}`}>
      <span>
        {label}
        <b>
          {format(value)}
          {suffix}
        </b>
      </span>
      <i>
        <span style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
      </i>
    </div>
  );
}
function OfficerSelect({ model, target }) {
  const s = model.state;
  return (
    <label className="hq-field">
      Commanding officer
      <select
        aria-label={`Officer for ${target.name}`}
        value={target.officerId || ''}
        onChange={(e) => model.assignOfficer(target.id, e.target.value)}
      >
        <option value="" disabled>
          Vacant command
        </option>
        {s.officers
          .filter((o) => o.hired)
          .map((officer) => (
            <option
              key={officer.id}
              value={officer.id}
              disabled={
                !officerReady(officer, s.hours) ||
                rankOf(officer) <
                  (target.kind ? (target.kind === 'artillery' ? 0 : 1) : 3)
              }
            >
              {RANKS[rankOf(officer)]} {officer.name}
              {officer.dead
                ? ' (killed)'
                : officer.woundedUntil > s.hours
                  ? ' (wounded)'
                  : officerAssignment(s, officer.id)?.id !== target.id &&
                      officerAssignment(s, officer.id)
                    ? ` - ${officerAssignment(s, officer.id).name}`
                    : ''}
            </option>
          ))}
      </select>
    </label>
  );
}
function UnitDetail({ model, unit, notify }) {
  const s = model.state,
    officer = s.officers.find((o) => o.id === unit.officerId),
    Icon = unitIcon(unit.kind);
  const [quality, setQuality] = useState('recruits'),
    [requested, setRequested] = useState(Math.max(1, unit.maxMen - unit.men)),
    [skill, setSkill] = useState('firearms');
  const missing = unit.maxMen - unit.men,
    price = quality === 'veterans' ? 6 : 2;
  const count = Math.min(Math.max(0, requested), missing);
  const cap =
    unit.kind === 'artillery' ? 240 : unit.kind === 'cavalry' ? 400 : 1200;
  return (
    <>
      <div className="detail-title">
        <Icon size={19} />
        <span>
          {unit.kind.toUpperCase()}
          <strong>{unit.name}</strong>
        </span>
        <span className="unit-stars">
          {Array.from(
            { length: Math.min(3, Math.floor(unit.experience + 0.25)) },
            (_, i) => (
              <Star key={i} size={12} fill="currentColor" />
            ),
          )}
        </span>
      </div>
      <div className="detail-officer">
        <Portrait officer={officer} />
        <div>
          <span>{officer ? RANKS[rankOf(officer)] : 'COMMAND VACANT'}</span>
          <strong>{officer?.name || 'No officer assigned'}</strong>
          <small>
            {officer?.dead
              ? 'Killed in action'
              : officer?.woundedUntil > s.hours
                ? `Recovering: ${Math.ceil(officer.woundedUntil - s.hours)}h`
                : `${format(commandEfficiency(s, unit) * 100)}% command efficiency`}
          </small>
        </div>
      </div>
      <OfficerSelect model={model} target={unit} />
      <label className="hq-field">
        Regiment name
        <input
          aria-label="Regiment name"
          defaultValue={unit.name}
          maxLength={36}
          onBlur={(e) => model.renameRegiment(unit.id, e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') e.currentTarget.blur();
          }}
        />
      </label>
      <label className="hq-field">
        Corps
        <select
          aria-label={`Corps for ${unit.name}`}
          value={unit.corpsId}
          onChange={(e) => model.assignCorps(unit.id, e.target.value)}
        >
          {s.corps.map((c) => (
            <option
              key={c.id}
              value={c.id}
              disabled={
                c.id !== unit.corpsId &&
                s.units.filter((u) => u.corpsId === c.id).length >= 4
              }
            >
              {c.name} ({s.units.filter((u) => u.corpsId === c.id).length}/4)
            </option>
          ))}
        </select>
      </label>
      <div className="strength-readout">
        <strong>
          {format(unit.men)} <small>/ {format(unit.maxMen)} men</small>
        </strong>
        <span>{unit.experience.toFixed(1)} XP</span>
      </div>
      <label className="hq-field">
        Authorized strength
        <input
          type="range"
          aria-label="Authorized strength"
          min={Math.max(unit.men, unit.kind === 'artillery' ? 30 : 100)}
          max={cap}
          step="1"
          value={Math.min(cap, unit.maxMen)}
          onChange={(e) => {
            model.setUnitSize(unit.id, Number(e.target.value));
            setRequested(Number(e.target.value) - unit.men);
          }}
        />
      </label>
      <div className="hq-skills">
        {Object.entries(SKILLS).map(([key, label]) => (
          <StatBar key={key} label={label} value={unit.skills[key]} />
        ))}
      </div>
      <div className="hq-readiness">
        <StatBar label="Condition" value={unit.condition} suffix="%" />
        <StatBar label="Ammunition" value={unit.ammo} suffix="%" tone="gold" />
      </div>
      <div className="detail-section">
        <h4>Armament</h4>
        <WeaponArt weapon={unit.weapon} />
        <label className="hq-field">
          <select
            aria-label={`Weapon for ${unit.name}`}
            value={unit.weapon}
            onChange={(e) => model.equip(unit.id, e.target.value)}
          >
            {Object.entries(WEAPONS)
              .filter(([, w]) => w.kind === unit.kind)
              .map(([key, weapon]) => (
                <option
                  key={key}
                  value={key}
                  disabled={
                    key !== unit.weapon && s.inventory[key] < weaponCount(unit)
                  }
                >
                  {weapon.name} ({format(s.inventory[key])} reserve)
                </option>
              ))}
          </select>
        </label>
        <div className="detail-inline">
          <span>{WEAPONS[unit.weapon].range} m range</span>
          <span>{Math.round(WEAPONS[unit.weapon].power * 100)}% power</span>
        </div>
      </div>
      <div className="detail-section">
        <h4>
          Replacements <span>{format(missing)} vacancies</span>
        </h4>
        <div className="hq-segmented">
          {['recruits', 'veterans'].map((type) => (
            <button
              key={type}
              className={quality === type ? 'active' : ''}
              onClick={() => setQuality(type)}
            >
              {type === 'recruits' ? 'Recruits · 2 F' : 'Veterans · 6 F'}
            </button>
          ))}
        </div>
        <div className="hq-action-line">
          <input
            type="number"
            aria-label="Replacement count"
            min="1"
            max={Math.max(1, missing)}
            value={requested}
            onChange={(e) => setRequested(Number(e.target.value))}
          />
          <button
            className="hq-button"
            disabled={
              missing <= 0 ||
              count < 1 ||
              !Number.isInteger(requested) ||
              s.cash < price ||
              (unit.kind !== 'artillery' && s.inventory[unit.weapon] <= 0)
            }
            onClick={() => {
              if (model.replenish(unit.id, quality, count))
                notify('Replacements mustered.');
            }}
          >
            <Users size={14} /> Replenish <b>{format(count * price)} F</b>
          </button>
        </div>
        {quality === 'recruits' && missing > 0 && (
          <div className="detail-inline">
            <span>Experience after muster</span>
            <strong>
              {((unit.experience * unit.men) / (unit.men + count)).toFixed(1)}{' '}
              XP
            </strong>
          </div>
        )}
      </div>
      <div className="detail-section">
        <h4>Training</h4>
        <div className="hq-action-line">
          <select
            aria-label="Training discipline"
            value={skill}
            onChange={(e) => setSkill(e.target.value)}
          >
            {Object.entries(SKILLS).map(([key, label]) => (
              <option key={key} value={key}>
                {label} +5
              </option>
            ))}
          </select>
          <button
            className="hq-button"
            disabled={
              s.cash < 450 ||
              unit.trainedUntil > s.hours ||
              unit.skills[skill] >= 100
            }
            onClick={() => model.train(unit.id, skill)}
          >
            <TrendingUp size={14} />
            {unit.trainedUntil > s.hours
              ? `${Math.ceil(unit.trainedUntil - s.hours)}h`
              : '450 F'}
          </button>
        </div>
      </div>
      <div className="detail-section">
        <h4>
          Veteran distinction{' '}
          <span>
            {unit.experience < 0.75
              ? '0.75 XP required'
              : unit.perk
                ? 'Awarded'
                : 'Available'}
          </span>
        </h4>
        <div className="perk-options">
          {Object.entries(PERKS).map(([key, perk]) => (
            <button
              className={unit.perk === key ? 'selected' : ''}
              key={key}
              disabled={!!unit.perk || unit.experience < 0.75}
              onClick={() => model.choosePerk(unit.id, key)}
            >
              <Award size={16} />
              <span>
                <strong>{perk.name}</strong>
                <small>{perk.description}</small>
              </span>
              {unit.perk === key && <Check size={14} />}
            </button>
          ))}
        </div>
      </div>
      <details className="service-record">
        <summary>
          Service record <span>{unit.history.length} engagements</span>
        </summary>
        {unit.history.length ? (
          unit.history.map((entry, i) => (
            <div key={i}>
              <strong>{entry.battle}</strong>
              <span>
                {entry.won
                  ? 'Victory'
                  : entry.retreat
                    ? 'Withdrawal'
                    : 'Defeat'}{' '}
                · {entry.losses} lost · {entry.kills} inflicted
              </span>
            </div>
          ))
        ) : (
          <p>Awaiting first engagement</p>
        )}
      </details>
    </>
  );
}

function RecruitDetail({ model, corpsId, onCreated }) {
  const [kind, setKind] = useState('infantry');
  const spec = {
    infantry: { men: 400, cost: 1200, weapon: 'musket' },
    cavalry: { men: 160, cost: 1600, weapon: 'sabre' },
    artillery: { men: 90, cost: 1500, weapon: 'cannon' },
  }[kind];
  const needed = kind === 'artillery' ? spec.men / 30 : spec.men;
  const s = model.state;
  return (
    <>
      <div className="detail-title">
        <Plus size={20} />
        <span>
          RECRUITMENT<strong>Raise a regiment</strong>
        </span>
      </div>
      <div className="hq-segmented">
        {['infantry', 'cavalry', 'artillery'].map((type) => (
          <button
            key={type}
            className={kind === type ? 'active' : ''}
            onClick={() => setKind(type)}
          >
            {type}
          </button>
        ))}
      </div>
      <WeaponArt weapon={spec.weapon} />
      <div className="recruit-summary">
        <strong>
          {spec.men}
          <small>men</small>
        </strong>
        <strong>
          {format(spec.cost)}
          <small>francs</small>
        </strong>
      </div>
      <div className="detail-inline">
        <span>{WEAPONS[spec.weapon].name}</span>
        <b>{needed} required</b>
      </div>
      <div className="detail-inline">
        <span>Reserve arms</span>
        <b>{format(s.inventory[spec.weapon])}</b>
      </div>
      <button
        className="hq-button primary full"
        disabled={
          s.units.length >= 8 ||
          s.cash < spec.cost ||
          s.inventory[spec.weapon] < needed
        }
        onClick={() => {
          if (model.recruit(kind)) {
            const unit = model.state.units.at(-1);
            if (corpsId) model.assignCorps(unit.id, corpsId);
            onCreated(unit.id);
          }
        }}
      >
        <Plus size={16} /> Commission regiment
      </button>
    </>
  );
}

export default function Headquarters({
  model,
  onClose,
  notify,
  Modal,
  initialTab = 'army',
}) {
  const s = model.state;
  const inspectorRef = useRef(null),
    contentRef = useRef(null);
  const revealDetails = () => {
    if (window.innerWidth <= 700)
      requestAnimationFrame(() =>
        inspectorRef.current?.scrollIntoView({ block: 'start' }),
      );
  };
  const [tab, setTab] = useState(
    ['armory', 'officers'].includes(initialTab)
      ? initialTab
      : initialTab === 'market'
        ? 'armory'
        : 'army',
  );
  const [selected, setSelected] = useState(
    s.selected.find((id) => s.units.some((u) => u.id === id)) || s.units[0].id,
  );
  const [weapon, setWeapon] = useState('musket'),
    [officerId, setOfficerId] = useState(s.officers[0].id),
    [recruitCorps, setRecruitCorps] = useState(null);
  const [quantity, setQuantity] = useState(
      Object.fromEntries(
        Object.entries(WEAPONS).map(([key, w]) => [key, w.lot]),
      ),
    ),
    [dragging, setDragging] = useState(null);
  const [equipId, setEquipId] = useState(s.units[0].id);
  const unit = s.units.find((u) => u.id === selected),
    corps = s.corps.find((c) => c.id === selected),
    officer = s.officers.find((o) => o.id === officerId);
  const selectUnit = (id) => {
    setSelected(id);
    model.select([id]);
    revealDetails();
  };
  return (
    <Modal
      title="Army headquarters"
      eyebrow="ARMY OF THE DANUBE · 1805"
      onClose={onClose}
      className="hq-modal"
    >
      <div className="hq-navigation">
        <div className="hq-tabs" role="tablist" aria-label="Headquarters">
          {[
            ['army', Users, 'Army'],
            ['armory', Landmark, 'Armory'],
            ['officers', UserRound, 'Officers'],
          ].map(([id, Icon, name]) => (
            <button
              role="tab"
              aria-selected={tab === id}
              className={tab === id ? 'active' : ''}
              key={id}
              onClick={() => setTab(id)}
            >
              <Icon size={17} />
              {name}
            </button>
          ))}
        </div>
        <div className="hq-resources">
          <span>
            <Users size={16} />
            {format(countMen(s.units))}
            <small>men</small>
          </span>
          <span>
            <Coins size={16} />
            <b>{format(s.cash)}</b>
            <small>francs</small>
          </span>
          <button
            className="hq-compact-resupply icon-button"
            aria-label={`Resupply army (${format(model.resupplyCost())} F)`}
            data-tip={`Resupply army (${format(model.resupplyCost())} F)`}
            disabled={
              model.resupplyCost() <= 0 || s.cash < model.resupplyCost()
            }
            onClick={() => model.resupply()}
          >
            <Truck size={17} />
          </button>
        </div>
      </div>
      <div className={`headquarters-body ${tab}`}>
        <aside className="hq-sidebar">
          <div className="army-general">
            <Portrait napoleon />
            <span>
              COMMANDER-IN-CHIEF
              <strong>
                Napoleon
                <br />
                Bonaparte
              </strong>
              <small>{s.victories} campaign victories</small>
            </span>
          </div>
          <div className="hq-sidebar-label">
            ORDER OF BATTLE <span>{s.units.length}/8</span>
          </div>
          {s.corps.map((c) => {
            const own = s.units.filter((u) => u.corpsId === c.id);
            return (
              <button
                key={c.id}
                className={`hq-corps-link ${selected === c.id ? 'selected' : ''}`}
                onClick={() => {
                  setTab('army');
                  setSelected(c.id);
                }}
              >
                <Flag size={17} />
                <span>
                  <strong>{c.name}</strong>
                  <small>
                    {own.length} regiments · {format(countMen(own))} men
                  </small>
                </span>
                <ChevronRight size={14} />
              </button>
            );
          })}
          <div className="hq-logistics">
            <h4>Field readiness</h4>
            <StatBar
              label="Army condition"
              value={s.army.condition}
              suffix="%"
            />
            <StatBar
              label="Supply train"
              value={s.supply / 5}
              suffix="%"
              tone="gold"
            />
            <button
              className="hq-button full"
              disabled={
                model.resupplyCost() <= 0 || s.cash < model.resupplyCost()
              }
              onClick={() => model.resupply()}
            >
              <Truck size={15} />
              Resupply <b>{format(model.resupplyCost())} F</b>
            </button>
            <span className="hq-date">
              October {6 + Math.floor(s.hours / 24)}, 1805 ·{' '}
              {String(Math.floor(s.hours % 24)).padStart(2, '0')}:00
            </span>
          </div>
          <button className="hq-return" onClick={onClose}>
            <ArrowLeft size={16} /> Return to campaign
          </button>
        </aside>
        <main className="hq-content" ref={contentRef}>
          {tab === 'army' && (
            <>
              <div className="hq-content-heading">
                <div>
                  <span>IMPERIAL FORCES</span>
                  <h3>Army organization</h3>
                </div>
                <button
                  className="hq-button"
                  disabled={s.units.length >= 8}
                  onClick={() => {
                    setSelected('new');
                    setRecruitCorps(null);
                    revealDetails();
                  }}
                >
                  <Plus size={15} />
                  Raise regiment
                </button>
              </div>
              <div className="hq-organization">
                {s.corps.map((c) => {
                  const own = s.units.filter((u) => u.corpsId === c.id),
                    commander = s.officers.find((o) => o.id === c.officerId);
                  return (
                    <section
                      key={c.id}
                      className={`hq-corps ${dragging && own.length < 4 ? 'drop-ready' : ''}`}
                      style={{ '--corps-color': c.color }}
                      onDragOver={(e) => {
                        if (own.length < 4) e.preventDefault();
                      }}
                      onDrop={(e) => {
                        e.preventDefault();
                        model.assignCorps(
                          e.dataTransfer.getData('text/plain'),
                          c.id,
                        );
                        setDragging(null);
                      }}
                    >
                      <button
                        className={`hq-corps-header ${selected === c.id ? 'selected' : ''}`}
                        onClick={() => {
                          setSelected(c.id);
                          revealDetails();
                        }}
                      >
                        <Portrait officer={commander} />
                        <span>
                          <strong>{c.name}</strong>
                          <small>{commander?.name || 'Vacant command'}</small>
                          <b>
                            {format(countMen(own))} men <i>{own.length} / 4</i>
                          </b>
                        </span>
                      </button>
                      <div className="corps-specialty">
                        <Award size={13} />
                        {commander && officerReady(commander, s.hours)
                          ? c.specialty === 'Drill'
                            ? 'Drill +20%'
                            : 'Morale recovery +90%'
                          : 'Command unavailable'}
                      </div>
                      <div className="hq-regiments">
                        {own.map((u) => {
                          const Icon = unitIcon(u.kind),
                            o = s.officers.find((o) => o.id === u.officerId);
                          return (
                            <button
                              key={u.id}
                              className={`hq-regiment ${selected === u.id ? 'selected' : ''}`}
                              draggable
                              onDragStart={(e) => {
                                e.dataTransfer.setData('text/plain', u.id);
                                setDragging(u.id);
                              }}
                              onDragEnd={() => setDragging(null)}
                              onClick={() => selectUnit(u.id)}
                            >
                              <Portrait officer={o} />
                              <span className="regiment-body">
                                <span className="regiment-type">
                                  <Icon size={13} />
                                  {u.kind}
                                  <span>
                                    {u.experience >= 0.75 && (
                                      <Star size={12} fill="currentColor" />
                                    )}
                                  </span>
                                </span>
                                <strong>{u.name}</strong>
                                <small>{o?.name || 'Vacant command'}</small>
                                <span className="regiment-strength">
                                  <b>{format(u.men)}</b>
                                  <small>/ {format(u.maxMen)}</small>
                                  <span>{u.experience.toFixed(1)} XP</span>
                                </span>
                                <i className="strength-line">
                                  <span
                                    style={{
                                      width: `${(u.men / u.maxMen) * 100}%`,
                                    }}
                                  />
                                </i>
                              </span>
                            </button>
                          );
                        })}
                        {Array.from({ length: 4 - own.length }, (_, i) => (
                          <button
                            className="hq-empty"
                            key={i}
                            aria-label={`Raise regiment in ${c.name}`}
                            onClick={() => {
                              setSelected('new');
                              setRecruitCorps(c.id);
                              revealDetails();
                            }}
                          >
                            <Plus size={20} />
                            <span>Vacant regiment position</span>
                          </button>
                        ))}
                      </div>
                    </section>
                  );
                })}
              </div>
            </>
          )}
          {tab === 'armory' && (
            <>
              <div className="hq-content-heading">
                <div>
                  <span>ORDNANCE DEPARTMENT</span>
                  <h3>Armory &amp; requisitions</h3>
                </div>
                <span className="hq-note">7 patterns available</span>
              </div>
              <div className="hq-armory">
                {Object.entries(WEAPONS).map(([key, w]) => {
                  const amount = Number(quantity[key]),
                    valid = Number.isSafeInteger(amount) && amount > 0,
                    buy = valid ? Math.min(amount, s.market[key]) : 0,
                    sell = valid ? Math.min(amount, s.inventory[key]) : 0;
                  return (
                    <div
                      className={`hq-weapon-row ${weapon === key ? 'selected' : ''}`}
                      key={key}
                    >
                      <button
                        className="weapon-choice"
                        onClick={() => {
                          setWeapon(key);
                          setEquipId(
                            s.units.find((u) => u.kind === w.kind)?.id || '',
                          );
                          revealDetails();
                        }}
                      >
                        <WeaponArt weapon={key} />
                        <strong>{w.name}</strong>
                        <small>
                          {w.kind} · {w.range} m · {Math.round(w.power * 100)}%
                          power
                        </small>
                      </button>
                      <div className="weapon-stock">
                        <span>
                          Reserve <b>{format(s.inventory[key])}</b>
                        </span>
                        <span>
                          Dealer <b>{format(s.market[key])}</b>
                        </span>
                      </div>
                      <div className="weapon-transaction">
                        <label>
                          Quantity
                          <input
                            type="number"
                            min="1"
                            max="10000"
                            aria-label={`Quantity for ${w.name}`}
                            value={quantity[key]}
                            onChange={(e) =>
                              setQuantity({
                                ...quantity,
                                [key]: e.target.value,
                              })
                            }
                          />
                        </label>
                        <button
                          className="hq-button"
                          aria-label={`Buy ${w.name}`}
                          disabled={!buy || s.cash < buy * w.price}
                          onClick={() => {
                            if (model.trade(key, 'buy', amount))
                              notify(`${buy} ${w.name} purchased.`);
                          }}
                        >
                          <ArrowDownToLine size={14} />
                          <span>
                            Buy {buy}
                            <small>{format(buy * w.price)} F</small>
                          </span>
                        </button>
                        <button
                          className="hq-button"
                          aria-label={`Sell ${w.name}`}
                          disabled={!sell}
                          onClick={() => {
                            if (model.trade(key, 'sell', amount))
                              notify(`${sell} ${w.name} sold.`);
                          }}
                        >
                          <ArrowUpFromLine size={14} />
                          <span>
                            Sell {sell}
                            <small>{format(sell * w.resale)} F</small>
                          </span>
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </>
          )}
          {tab === 'officers' && (
            <>
              <div className="hq-content-heading">
                <div>
                  <span>GENERAL STAFF</span>
                  <h3>Officer corps</h3>
                </div>
                <span className="hq-note">
                  {s.officers.filter((o) => o.hired && !o.dead).length}{' '}
                  commissioned
                </span>
              </div>
              <div className="hq-officers">
                {s.officers.map((o) => {
                  const assignment = officerAssignment(s, o.id);
                  return (
                    <button
                      key={o.id}
                      className={`hq-officer-card ${officerId === o.id ? 'selected' : ''} ${o.dead ? 'fallen' : ''}`}
                      onClick={() => {
                        setOfficerId(o.id);
                        revealDetails();
                      }}
                    >
                      <Portrait officer={o} />
                      <div>
                        <span>{RANKS[rankOf(o)]}</span>
                        <strong>{o.name}</strong>
                        <small>
                          {o.dead
                            ? 'Killed in action'
                            : o.woundedUntil > s.hours
                              ? `Wounded · ${Math.ceil(o.woundedUntil - s.hours)}h`
                              : !o.hired
                                ? `${format(o.cost)} F commission`
                                : assignment?.name || 'Reserve officer'}
                        </small>
                        <b>
                          {o.specialty} <span>{Math.floor(o.xp)} XP</span>
                        </b>
                      </div>
                    </button>
                  );
                })}
              </div>
            </>
          )}
        </main>
        <aside
          className="hq-inspector"
          aria-label="Selected details"
          ref={inspectorRef}
        >
          <button
            className="hq-mobile-back hq-button"
            onClick={() =>
              contentRef.current?.scrollIntoView({ block: 'start' })
            }
          >
            <ArrowLeft size={15} />
            {tab === 'army'
              ? 'Army organization'
              : tab === 'armory'
                ? 'Armory'
                : 'Officer corps'}
          </button>
          {tab === 'army' &&
            (unit ? (
              <UnitDetail
                key={unit.id}
                model={model}
                unit={unit}
                notify={notify}
              />
            ) : selected === 'new' ? (
              <RecruitDetail
                model={model}
                corpsId={recruitCorps}
                onCreated={selectUnit}
              />
            ) : corps ? (
              <>
                <div className="detail-title">
                  <Flag size={20} />
                  <span>
                    CORPS COMMAND<strong>{corps.name}</strong>
                  </span>
                </div>
                <Portrait
                  officer={s.officers.find((o) => o.id === corps.officerId)}
                  className="large-portrait"
                />
                <h3 className="inspector-name">{corps.commander}</h3>
                <OfficerSelect model={model} target={corps} />
                <div className="detail-section">
                  <h4>Command authority</h4>
                  <div className="detail-inline">
                    <span>Regiment capacity</span>
                    <b>4</b>
                  </div>
                  <div className="detail-inline">
                    <span>Field command radius</span>
                    <b>175 m</b>
                  </div>
                  <div className="detail-inline">
                    <span>Specialty</span>
                    <b>{corps.specialty}</b>
                  </div>
                  <div className="detail-inline">
                    <span>Rally recovery</span>
                    <b>45 seconds</b>
                  </div>
                </div>
                <button
                  className="hq-button full"
                  onClick={() => {
                    setOfficerId(corps.officerId || s.officers[0].id);
                    setTab('officers');
                  }}
                >
                  <UserRound size={15} /> Officer service record
                </button>
              </>
            ) : null)}
          {tab === 'armory' && (
            <>
              <div className="detail-title">
                <Target size={20} />
                <span>
                  WEAPON PATTERN<strong>{WEAPONS[weapon].name}</strong>
                </span>
              </div>
              <WeaponArt weapon={weapon} />
              <div className="detail-section">
                <h4>Specifications</h4>
                <div className="detail-inline">
                  <span>Range</span>
                  <b>{WEAPONS[weapon].range} m</b>
                </div>
                <div className="detail-inline">
                  <span>Firepower</span>
                  <b>{Math.round(WEAPONS[weapon].power * 100)}%</b>
                </div>
                <div className="detail-inline">
                  <span>Purchase / resale</span>
                  <b>
                    {WEAPONS[weapon].price} / {WEAPONS[weapon].resale} F
                  </b>
                </div>
              </div>
              <label className="hq-field">
                Issue to regiment
                <select
                  aria-label="Equipment recipient"
                  value={equipId}
                  onChange={(e) => setEquipId(e.target.value)}
                >
                  {s.units.map((u) => (
                    <option
                      key={u.id}
                      value={u.id}
                      disabled={u.kind !== WEAPONS[weapon].kind}
                    >
                      {u.name}
                    </option>
                  ))}
                </select>
              </label>
              {(() => {
                const recipient = s.units.find((u) => u.id === equipId);
                if (!recipient) return null;
                const previous = WEAPONS[recipient.weapon],
                  next = WEAPONS[weapon];
                return (
                  <>
                    <div className="detail-inline">
                      <span>Current pattern</span>
                      <b>{previous.name}</b>
                    </div>
                    <div className="comparison-stats">
                      <span>
                        Range{' '}
                        <b
                          className={
                            next.range >= previous.range
                              ? 'positive'
                              : 'negative'
                          }
                        >
                          {next.range - previous.range >= 0 ? '+' : ''}
                          {next.range - previous.range} m
                        </b>
                      </span>
                      <span>
                        Power{' '}
                        <b
                          className={
                            next.power >= previous.power
                              ? 'positive'
                              : 'negative'
                          }
                        >
                          {next.power - previous.power >= 0 ? '+' : ''}
                          {Math.round((next.power - previous.power) * 100)}%
                        </b>
                      </span>
                    </div>
                    <div className="detail-inline">
                      <span>Arms required</span>
                      <b>{weaponCount(recipient)}</b>
                    </div>
                    <button
                      className="hq-button primary full"
                      disabled={
                        recipient.kind !== next.kind ||
                        recipient.weapon === weapon ||
                        s.inventory[weapon] < weaponCount(recipient)
                      }
                      onClick={() => model.equip(recipient.id, weapon)}
                    >
                      <Check size={15} />
                      Issue weapons
                    </button>
                  </>
                );
              })()}
            </>
          )}
          {tab === 'officers' && officer && (
            <>
              <Portrait officer={officer} className="large-portrait" />
              <div className="officer-rank">{RANKS[rankOf(officer)]}</div>
              <h3 className="inspector-name">{officer.name}</h3>
              <div className="detail-inline">
                <span>Specialty</span>
                <b>{officer.specialty}</b>
              </div>
              <div className="detail-inline">
                <span>Service status</span>
                <b>
                  {officer.dead
                    ? 'Killed in action'
                    : officer.woundedUntil > s.hours
                      ? 'Recovering'
                      : officer.hired
                        ? 'Commissioned'
                        : 'Available'}
                </b>
              </div>
              <StatBar
                label="Rank progress"
                value={
                  rankOf(officer) === 4
                    ? 100
                    : ((officer.xp - RANK_XP[rankOf(officer)]) /
                        (RANK_XP[rankOf(officer) + 1] -
                          RANK_XP[rankOf(officer)])) *
                      100
                }
                suffix="%"
                tone="gold"
              />
              <div className="detail-inline">
                <span>{Math.floor(officer.xp)} service XP</span>
                <b>{RANKS[Math.min(4, rankOf(officer) + 1)]}</b>
              </div>
              {!officer.hired ? (
                <button
                  className="hq-button primary full"
                  disabled={s.cash < officer.cost}
                  onClick={() => model.hireOfficer(officer.id)}
                >
                  <Plus size={15} />
                  Commission <b>{format(officer.cost)} F</b>
                </button>
              ) : (
                <label className="hq-field">
                  Assignment
                  <select
                    aria-label={`Assignment for ${officer.name}`}
                    disabled={!officerReady(officer, s.hours)}
                    value={officerAssignment(s, officer.id)?.id || ''}
                    onChange={(e) =>
                      model.assignOfficer(e.target.value, officer.id)
                    }
                  >
                    <option value="" disabled>
                      Reserve officer
                    </option>
                    {[...s.corps, ...s.units].map((target) => (
                      <option
                        key={target.id}
                        value={target.id}
                        disabled={
                          rankOf(officer) <
                          (target.kind
                            ? target.kind === 'artillery'
                              ? 0
                              : 1
                            : 3)
                        }
                      >
                        {target.name}
                      </option>
                    ))}
                  </select>
                </label>
              )}
              {officer.woundedUntil > s.hours && !officer.dead && (
                <div className="officer-recovery">
                  <Heart size={16} />
                  {Math.ceil(officer.woundedUntil - s.hours)} campaign hours to
                  recovery
                </div>
              )}
            </>
          )}
        </aside>
      </div>
    </Modal>
  );
}
